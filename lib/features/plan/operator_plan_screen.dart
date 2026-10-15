import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data_sources/image_source.dart';
import '../../domain/building_formula.dart';
import '../../domain/item.dart';
import '../../domain/operator.dart';
import '../../domain/user_data.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/user_data_service.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'plan_auto_persist.dart';
import 'plan_materials_grid.dart';
import 'plan_widgets.dart';
import 'plan_totals.dart';

const _autosaveDelay = Duration(milliseconds: 400);
const _toastDuration = Duration(seconds: 3);

/// Operator plan page (`src/pages/plan/[operatorId].vue`) in the redesign
/// layout: current/target elite, level, skill levels 1-10 (8-10 = mastery
/// M1-M3) and module stages on the left, the live cost breakdown on the
/// right (stacked on narrow screens). Edits autosave after a 400ms debounce;
/// the header pill shows the save state and a failed save also raises a
/// toast with the error message.
class OperatorPlanScreen extends ConsumerStatefulWidget {
  const OperatorPlanScreen({
    required this.operatorId,
    super.key,
  });

  static const routeName = 'operator-plan';

  final String operatorId;

  @override
  ConsumerState<OperatorPlanScreen> createState() => _OperatorPlanScreenState();
}

class _OperatorPlanScreenState extends ConsumerState<OperatorPlanScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  OperatorDetail? _operator;
  UserPlanOperator? _localPlan;
  Map<String, ItemEntry> _itemsById = const {};
  BuildingFormulaBundle _buildingFormulas = const BuildingFormulaBundle();
  Map<String, File> _moduleTypeIcons = const {};
  bool _detailExpandRecipes = false;
  int _loadToken = 0;

  PlanSaveStatus _saveStatus = PlanSaveStatus.idle;
  bool _lastSaveFailed = false;
  String? _toastMessage;
  Timer? _toastTimer;

  late final PlanAutoPersist<UserPlanOperator?> _autoPersist = PlanAutoPersist(
    delay: _autosaveDelay,
    snapshot: () => _buildTrackedPlanSignature(_localPlan),
    enabled: () => !_isLoading && _localPlan != null,
    persist: () async {
      final plan = _localPlan;
      if (plan == null) {
        return null;
      }
      return _userDataService.saveUserPlanOperator(plan);
    },
    applyPersisted: (saved) {
      if (saved != null && mounted) {
        setState(() => _localPlan = saved);
      }
    },
    onPersistingChanged: _handlePersistingChanged,
    onError: (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('plan autosave failed', error, stackTrace);
      _lastSaveFailed = true;
      if (mounted) {
        _showToast('$error');
      }
    },
  );

  /// Captured up front so a flush during [dispose] does not touch `ref`.
  late final UserDataService _userDataService;

  @override
  void initState() {
    super.initState();
    _userDataService = ref.read(userDataServiceProvider);
    Future.microtask(_loadDetailPage);
  }

  @override
  void didUpdateWidget(OperatorPlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operatorId != widget.operatorId) {
      _loadDetailPage();
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    // The Vue page drops a pending debounce on unmount; flushing it instead
    // keeps edits made right before navigating back.
    _autoPersist.dispose(flush: true);
    super.dispose();
  }

  String get _operatorId => widget.operatorId.trim();

  void _handlePersistingChanged(bool persisting) {
    if (!mounted) {
      return;
    }
    if (persisting) {
      _lastSaveFailed = false;
      setState(() => _saveStatus = PlanSaveStatus.saving);
      return;
    }
    setState(() {
      _saveStatus = _lastSaveFailed
          ? PlanSaveStatus.failed
          : _autoPersist.hasPendingSave
              ? PlanSaveStatus.saving
              : PlanSaveStatus.saved;
    });
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(_toastDuration, _dismissToast);
  }

  void _dismissToast() {
    _toastTimer?.cancel();
    _toastTimer = null;
    if (mounted && _toastMessage != null) {
      setState(() => _toastMessage = null);
    }
  }

  Future<void> _loadDetailPage() async {
    final i18n = ref.read(i18nProvider);
    if (_operatorId.isEmpty) {
      setState(() {
        _errorMessage = i18n.t('planPage.detail.notFoundDescription');
        _isLoading = false;
      });
      return;
    }

    final token = ++_loadToken;
    final region = ref.read(regionProvider);
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      // A reload (region switch included) turns the recipe expansion off.
      _detailExpandRecipes = false;
      _saveStatus = PlanSaveStatus.idle;
    });

    try {
      final detailFuture = ref
          .read(operatorServiceProvider)
          .getOperatorDetail(region, _operatorId);
      final planFuture = ref.read(userDataServiceProvider).getUserPlan();
      final referencesFuture =
          loadPlanReferenceData(ref.read(itemServiceProvider), region);
      final detail = await detailFuture;
      final plan = await planFuture;
      final references = await referencesFuture;
      if (!mounted || token != _loadToken) {
        return;
      }

      if (detail == null) {
        setState(() {
          _operator = null;
          _localPlan = null;
          _errorMessage = i18n.t('planPage.detail.notFoundDescription');
        });
        _autoPersist.markPersisted('');
        return;
      }

      final costService = ref.read(planCostServiceProvider);
      setState(() {
        _operator = detail;
        _localPlan = costService.resolvePlanOperator(
          detail,
          costService.getPlanByOperatorId(plan, detail.id),
        );
        _itemsById = references.itemsById;
        _buildingFormulas = references.formulas;
      });
      _autoPersist.markPersisted(_buildTrackedPlanSignature(_localPlan));
      await _loadModuleTypeImageSources(detail, token);
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('plan detail load failed', error, stackTrace);
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _operator = null;
        _localPlan = null;
        _itemsById = const {};
        _buildingFormulas = const BuildingFormulaBundle();
        _errorMessage = '$error';
      });
      _autoPersist.markPersisted('');
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadModuleTypeImageSources(
    OperatorDetail detail,
    int token,
  ) async {
    final imageService = ref.read(imageCacheServiceProvider);
    final entries = await Future.wait([
      for (final module in _visibleModules(detail))
        () async {
          final typeIcon = module.typeIcon.trim();
          if (typeIcon.isEmpty) {
            return null;
          }
          try {
            final resolved = await imageService.resolve(
              ImageRequest(kind: CachedImageKind.moduleType, id: typeIcon),
            );
            return resolved.isReady && resolved.file != null
                ? MapEntry(module.uniEquipId, resolved.file!)
                : null;
          } catch (_) {
            return null;
          }
        }(),
    ]);
    if (!mounted || token != _loadToken) {
      return;
    }
    setState(() {
      _moduleTypeIcons =
          Map.fromEntries(entries.whereType<MapEntry<String, File>>());
    });
  }

  void _updatePlan(UserPlanOperator Function(UserPlanOperator plan) update) {
    final plan = _localPlan;
    if (plan == null) {
      return;
    }
    setState(() => _localPlan = update(plan));
    _autoPersist.notifyChanged();
    if (_autoPersist.hasPendingSave || _autoPersist.isPersisting) {
      setState(() => _saveStatus = PlanSaveStatus.saving);
    } else if (_saveStatus == PlanSaveStatus.saving) {
      // Edited back to the persisted values: nothing left to save.
      setState(() => _saveStatus = PlanSaveStatus.saved);
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/plan');
    }
  }

  String _saveLabel(NexusI18n i18n) => switch (_saveStatus) {
        PlanSaveStatus.idle => i18n.t('rd.plan.saveIdle'),
        PlanSaveStatus.saving => i18n.t('planPage.detail.saving'),
        PlanSaveStatus.saved => i18n.t('planPage.detail.saved'),
        PlanSaveStatus.failed => i18n.t('rd.plan.saveFailed'),
      };

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    ref.listen(regionProvider, (previous, next) => _loadDetailPage());
    ref.listen(dataRevisionProvider, (previous, next) => _loadDetailPage());

    final compact = context.rdLayout == RdLayout.compact;
    final operator = _operator;
    final plan = _localPlan;
    final ready = _errorMessage.isEmpty &&
        !_isLoading &&
        operator != null &&
        plan != null;

    final header = RdPageHeader(
      eyebrow: compact ? null : i18n.t('rd.plan.detailEyebrow'),
      title: operator?.name ?? i18n.t('planPage.detail.title'),
      subtitle: i18n.t('planPage.detail.description'),
      onBack: _goBack,
      backTooltip: i18n.t('rd.plan.backToPlan'),
      actions: [
        if (ready)
          PlanSaveStatusPill(status: _saveStatus, label: _saveLabel(i18n)),
      ],
    );

    final Widget body;
    if (_errorMessage.isNotEmpty) {
      body = RdStatePanel(
        kind: RdStateKind.error,
        layout: RdStateLayout.left,
        title: i18n.t('planPage.detail.errorTitle'),
        detail: _errorMessage,
        action: RdButton(
          label: i18n.t('planPage.actions.retry'),
          onPressed: _loadDetailPage,
          variant: RdButtonVariant.tonal,
          height: context.rdLayout == RdLayout.compact ? 44 : 40,
        ),
      );
    } else if (!ready) {
      body = _DetailSkeleton(label: i18n.t('rd.plan.loading'));
    } else {
      body = _buildContent(i18n, operator, plan, compact);
    }

    return PlanPageFrame(
      header: header,
      overlay: _toastMessage == null
          ? null
          : PlanErrorToast(
              message: _toastMessage!,
              dismissLabel: i18n.t('rd.plan.dismissAlert'),
              onDismiss: _dismissToast,
            ),
      children: [body],
    );
  }

  Widget _buildContent(
    NexusI18n i18n,
    OperatorDetail operator,
    UserPlanOperator plan,
    bool compact,
  ) {
    final gap = compact ? 12.0 : 14.0;
    final hasModules = _visibleModules(operator).isNotEmpty;
    final mainCards = [
      _buildStateCard(i18n, operator, plan, compact),
      _buildSkillsCard(i18n, operator, plan, compact),
      if (hasModules) _buildModulesCard(i18n, operator, plan, compact),
    ];
    final asideCards = _buildAside(i18n, operator, plan, compact);

    Widget stack(List<Widget> cards) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              cards[i],
            ],
          ],
        );

    // `flex: 12 1 520px` | `flex: 8 1 340px` with an 18px gap, wrapping.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gutter = 18.0;
        const mainBasis = 520.0;
        const asideBasis = 340.0;
        final width = constraints.maxWidth;
        if (compact || width < mainBasis + asideBasis + gutter) {
          return stack([...mainCards, ...asideCards]);
        }
        final free = width - gutter - mainBasis - asideBasis;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: mainBasis + free * 0.6, child: stack(mainCards)),
            const SizedBox(width: gutter),
            Expanded(child: stack(asideCards)),
          ],
        );
      },
    );
  }

  Widget _buildStateCard(
    NexusI18n i18n,
    OperatorDetail operator,
    UserPlanOperator plan,
    bool compact,
  ) {
    final costService = ref.read(planCostServiceProvider);
    final currentCap =
        costService.getEliteLevelCap(operator, plan.current.elite);
    final targetCap = costService.getEliteLevelCap(operator, plan.target.elite);
    final currentTitle = i18n.t('planPage.detail.currentTitle');
    final targetTitle = i18n.t('planPage.detail.targetTitle');
    final eliteLabel = i18n.t('planPage.detail.elite');
    final levelLabel = i18n.t('planPage.detail.level');

    UserPlanOperatorState withElite(UserPlanOperatorState state, int elite) {
      // watch(() => localPlan.*.elite): clamp the level to the new cap.
      final cap = costService.getEliteLevelCap(operator, elite);
      return state.copyWith(elite: elite, level: math.min(state.level, cap));
    }

    Widget elitePicker({required bool target}) {
      final side = target ? 'target' : 'current';
      return RdSegmented<int>(
        key: Key('plan-$side-elite'),
        segments: [
          for (final elite in const [0, 1, 2])
            RdSegment(
              elite,
              'E$elite',
              leading: RdEliteIcon(elite, excludeSemantics: true),
              key: Key('plan-$side-elite-$elite'),
            ),
        ],
        selected: target ? plan.target.elite : plan.current.elite,
        height: compact ? 44 : 40,
        semanticLabel: '${target ? targetTitle : currentTitle} $eliteLabel',
        onChanged: (elite) => _updatePlan(
          (plan) => target
              ? plan.copyWith(target: withElite(plan.target, elite))
              : plan.copyWith(current: withElite(plan.current, elite)),
        ),
      );
    }

    Widget levelStepper({required bool target}) {
      final side = target ? 'target' : 'current';
      final sideTitle = target ? targetTitle : currentTitle;
      return PlanLevelStepper(
        inputKey: Key('plan-$side-level'),
        value: target ? plan.target.level : plan.current.level,
        max: target ? targetCap : currentCap,
        fieldLabel: '$sideTitle $levelLabel',
        decreaseLabel: i18n.t('rd.plan.levelDecrease', {'side': sideTitle}),
        increaseLabel: i18n.t('rd.plan.levelIncrease', {'side': sideTitle}),
        onChanged: (level) => _updatePlan(
          (plan) => target
              ? plan.copyWith(target: plan.target.copyWith(level: level))
              : plan.copyWith(current: plan.current.copyWith(level: level)),
        ),
      );
    }

    final Widget comparison;
    if (compact) {
      final shortCurrent = i18n.t('rd.plan.current');
      final shortTarget = i18n.t('rd.plan.target');
      comparison = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GroupLabel(eliteLabel),
          const SizedBox(height: 8),
          _LabeledRow(
            label: shortCurrent,
            width: 52,
            child: elitePicker(target: false),
          ),
          const SizedBox(height: 8),
          _LabeledRow(
            label: shortTarget,
            width: 52,
            child: elitePicker(target: true),
          ),
          const SizedBox(height: 10),
          _GroupLabel(levelLabel),
          const SizedBox(height: 8),
          _LabeledRow(
            label: shortCurrent,
            width: 52,
            child: levelStepper(target: false),
          ),
          const SizedBox(height: 8),
          _LabeledRow(
            label: shortTarget,
            width: 52,
            child: levelStepper(target: true),
          ),
        ],
      );
    } else {
      comparison = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompareRow(
            label: '',
            current: _ColumnTitle(currentTitle),
            target: _ColumnTitle(targetTitle),
          ),
          const SizedBox(height: 10),
          _CompareRow(
            label: eliteLabel,
            current: elitePicker(target: false),
            target: elitePicker(target: true),
          ),
          const SizedBox(height: 10),
          _CompareRow(
            label: levelLabel,
            current: levelStepper(target: false),
            target: levelStepper(target: true),
          ),
        ],
      );
    }

    return RdCard.tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RdPortrait(
                charId: operator.id,
                name: operator.name,
                size: compact ? 60 : 72,
                radius: 24,
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlanStars(
                      rarity: operator.rarity,
                      fontSize: compact ? 10 : 11,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      operator.name,
                      style: TextStyle(
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: RdColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${i18n.profession(operator.profession)} / ${operator.branch}',
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: RdColors.secondary2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          RdInset(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RdHeading(
                  i18n.t('planPage.detail.stateTitle'),
                  description: i18n.t('planPage.detail.stateDescription'),
                  descriptionStyle: RdText.caption,
                ),
                SizedBox(height: compact ? 10 : 12),
                comparison,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard(
    NexusI18n i18n,
    OperatorDetail operator,
    UserPlanOperator plan,
    bool compact,
  ) {
    final currentLabel = i18n.t('planPage.detail.currentSkill');
    final targetLabel = i18n.t('planPage.detail.targetSkill');
    String masteryLabel(int rank) =>
        i18n.t('rd.plan.masteryRank', {'rank': rank});

    Widget picker(int index, {required bool target}) {
      final side = target ? 'target' : 'current';
      final skill = operator.skills[index];
      final state = target ? plan.target : plan.current;
      return PlanSkillLevelPicker(
        key: Key('plan-$side-skill-$index'),
        chipKeyPrefix: 'plan-$side-skill-$index',
        selected: state.skillLevels.elementAtOrNull(index),
        semanticLabel: '${skill.name} ${target ? targetLabel : currentLabel}',
        masteryLabel: masteryLabel,
        onChanged: (level) => _updatePlan((plan) {
          final source = target ? plan.target : plan.current;
          final next = source.withSkillLevel(index, level);
          return target
              ? plan.copyWith(target: next)
              : plan.copyWith(current: next);
        }),
      );
    }

    return RdCard.tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdHeading(
            i18n.t('planPage.detail.skillsTitle'),
            description: '${i18n.t('planPage.detail.skillsDescription')} '
                '${i18n.t('planPage.detail.skillLevelHint')}',
            descriptionStyle: RdText.caption,
          ),
          for (var index = 0; index < operator.skills.length; index++) ...[
            SizedBox(height: compact ? 10 : 12),
            RdInset(
              padding: EdgeInsets.all(compact ? 12 : 14),
              radius: compact ? RdRadii.inner : 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (!compact) ...[
                        Text(
                          i18n.t('rd.plan.skillIndex', {'index': index + 1}),
                          style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.88,
                            color: RdColors.muted,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          operator.skills[index].name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 14 : 15,
                            fontWeight: FontWeight.w700,
                            color: RdColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SkillRoute(
                        from: plan.current.skillLevels.elementAtOrNull(index) ??
                            1,
                        to: plan.target.skillLevels.elementAtOrNull(index) ?? 1,
                        masteryLabel: masteryLabel,
                        fontSize: compact ? 11 : 12,
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  if (compact) ...[
                    _SmallLabel(currentLabel),
                    const SizedBox(height: 6),
                    picker(index, target: false),
                    const SizedBox(height: 8),
                    _SmallLabel(targetLabel),
                    const SizedBox(height: 6),
                    picker(index, target: true),
                  ] else ...[
                    _LabeledRow(
                      label: currentLabel,
                      width: 88,
                      child: picker(index, target: false),
                    ),
                    const SizedBox(height: 8),
                    _LabeledRow(
                      label: targetLabel,
                      width: 88,
                      child: picker(index, target: true),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModulesCard(
    NexusI18n i18n,
    OperatorDetail operator,
    UserPlanOperator plan,
    bool compact,
  ) {
    return RdCard.tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdHeading(
            i18n.t('planPage.detail.modulesTitle'),
            description: i18n.t('planPage.detail.modulesDescription'),
            descriptionStyle: RdText.caption,
          ),
          for (final module in _visibleModules(operator)) ...[
            SizedBox(height: compact ? 10 : 12),
            _buildModuleBlock(i18n, module, plan, compact),
          ],
        ],
      ),
    );
  }

  Widget _buildModuleBlock(
    NexusI18n i18n,
    OperatorModule module,
    UserPlanOperator plan,
    bool compact,
  ) {
    final maxStage = module.maxStage;
    final stages = [for (var stage = 0; stage <= maxStage; stage++) stage];
    final locked = i18n.t('planPage.detail.moduleLocked');
    final icon = _moduleTypeIcons[module.uniEquipId];
    final id = module.uniEquipId;
    final typeLabel = module.typeIcon.trim().toUpperCase();
    final currentLabel = i18n.t('planPage.detail.currentModule');
    final targetLabel = i18n.t('planPage.detail.targetModule');

    Widget picker({required bool target}) {
      final side = target ? 'target' : 'current';
      return RdSegmented<int>(
        key: Key('plan-$side-module-$id'),
        segments: [
          for (final stage in stages)
            RdSegment(
              stage,
              stage == 0 ? locked : 'Stage $stage',
              key: Key('plan-$side-module-$id-$stage'),
            ),
        ],
        selected: target
            ? plan.target.module(id)?.targetStage
            : plan.current.module(id)?.currentStage,
        height: compact ? 44 : 40,
        semanticLabel:
            '${module.uniEquipName} ${target ? targetLabel : currentLabel}',
        onChanged: (stage) => _updatePlan(
          (plan) => target
              ? plan.copyWith(
                  target: plan.target.withModuleStage(id, targetStage: stage),
                )
              : plan.copyWith(
                  current: plan.current.withModuleStage(
                    id,
                    currentStage: stage,
                  ),
                ),
        ),
      );
    }

    return RdInset(
      padding: EdgeInsets.all(compact ? 12 : 14),
      radius: compact ? RdRadii.inner : 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: compact ? 36 : 40,
                  height: compact ? 36 : 40,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xD9071224),
                    borderRadius: BorderRadius.circular(RdRadii.control),
                    border: Border.all(color: RdColors.white8),
                  ),
                  child: Image.file(icon, fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  module.uniEquipName,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: RdColors.text,
                  ),
                ),
              ),
              if (typeLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1F8BD6FF),
                    borderRadius: BorderRadius.circular(RdRadii.pill),
                  ),
                  child: Text(
                    typeLabel,
                    style: planMono(11, color: const Color(0xFFCDEEFF)),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          if (compact) ...[
            _SmallLabel(currentLabel),
            const SizedBox(height: 6),
            picker(target: false),
            const SizedBox(height: 8),
            _SmallLabel(targetLabel),
            const SizedBox(height: 6),
            picker(target: true),
          ] else ...[
            _LabeledRow(
              label: currentLabel,
              width: 88,
              child: picker(target: false),
            ),
            const SizedBox(height: 8),
            _LabeledRow(
              label: targetLabel,
              width: 88,
              child: picker(target: true),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAside(
    NexusI18n i18n,
    OperatorDetail operator,
    UserPlanOperator plan,
    bool compact,
  ) {
    final totals = PlanTotals.single(
      ref.read(planCostServiceProvider),
      operator,
      plan,
      _itemsById,
    );
    final breakdown = totals.breakdown;
    final farming = totals.farming;
    final showExp = totals.showExp;
    final showLmd = totals.showLmd;
    final showOverview = showExp || showLmd;
    final lmdItemId = totals.lmdId;
    final lmdShortage = totals.lmdShortage;
    final expLabel = i18n.t('planPage.summary.expLabel');
    final lmdLabel = i18n.t('planPage.summary.lmdLabel');

    final result = RdCard.tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdHeading(
            i18n.t('planPage.detail.summaryTitle'),
            description: i18n.t('planPage.detail.summaryDescription'),
            descriptionStyle: RdText.caption,
          ),
          if (showOverview) ...[
            SizedBox(height: compact ? 10 : 12),
            RdAutoGrid(
              columns: 2,
              gap: compact ? 8 : 10,
              children: [
                if (showExp)
                  PlanResourceCard(
                    inset: true,
                    label: expLabel,
                    itemId: expItemId,
                    iconId: _itemsById[expItemId]?.iconId,
                    itemName: _itemsById[expItemId]?.name ?? expLabel,
                    value: formatPlanNumber(farming.exp),
                    tint: PlanColors.expTint,
                    linkLabel: i18n.t('rd.plan.itemDetail', {
                      'name': _itemsById[expItemId]?.name ?? expLabel,
                    }),
                    onOpenItem: () => context.push('/items/$expItemId'),
                  ),
                if (showLmd)
                  PlanResourceCard(
                    inset: true,
                    label: lmdLabel,
                    itemId: lmdItemId,
                    iconId: farming.lmdItem?.iconId,
                    itemName: farming.lmdItem?.name ?? lmdLabel,
                    value: formatPlanNumber(farming.lmd),
                    tint: PlanColors.lmdTint,
                    linkLabel: i18n.t('rd.plan.itemDetail', {
                      'name': farming.lmdItem?.name ?? lmdLabel,
                    }),
                    shortageLabel: lmdShortage > 0
                        ? i18n.t('planPage.summary.shortageOnly', {
                            'shortage': formatPlanNumber(lmdShortage),
                          })
                        : null,
                    onOpenItem: () => context.push('/items/$lmdItemId'),
                  ),
              ],
            ),
            SizedBox(height: compact ? 10 : 12),
            RdInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    i18n.t('planPage.summary.farmingTitle'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: RdColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    i18n.t('planPage.summary.farmingDescription'),
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: RdColors.secondary2,
                    ),
                  ),
                  if (showExp) ...[
                    const SizedBox(height: 8),
                    PlanFarmingRow(
                      label: expLabel,
                      code: farming.expStage.code,
                      chip: i18n.t('planPage.summary.runs', {
                        'count': farming.expStage.runs,
                      }),
                    ),
                  ],
                  if (showLmd) ...[
                    const SizedBox(height: 8),
                    PlanFarmingRow(
                      label: lmdLabel,
                      code: farming.lmdStage.code,
                      chip: i18n.t('planPage.summary.runs', {
                        'count': farming.lmdStage.runs,
                      }),
                    ),
                  ],
                  const SizedBox(height: 8),
                  PlanFarmingRow(
                    gold: true,
                    label: '$expLabel + $lmdLabel',
                    chip: i18n.t('planPage.summary.totalSanity', {
                      'count': formatPlanNumber(farming.totalSanity),
                    }),
                  ),
                ],
              ),
            ),
          ],
          if (breakdown.errors.isNotEmpty) ...[
            SizedBox(height: compact ? 10 : 12),
            PlanValidationBox(messages: breakdown.errors),
          ],
        ],
      ),
    );

    final heading = RdHeading(
      i18n.t('planPage.summary.materialsTitle'),
      description: i18n.t('planPage.summary.materialsDescription'),
      descriptionStyle: RdText.caption,
    );
    final grid = PlanMaterialsGrid(
      materials: breakdown.materials,
      emptyLabel: i18n.t('planPage.detail.noMaterials'),
      itemsById: _itemsById,
      formulas: _buildingFormulas,
      columns: 2,
      expanded: _detailExpandRecipes,
      showShortage: true,
      onToggleExpand: () =>
          setState(() => _detailExpandRecipes = !_detailExpandRecipes),
    );
    final materials = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [heading, const SizedBox(height: 10), grid],
          )
        : RdCard.tile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [heading, const SizedBox(height: 14), grid],
            ),
          );

    return [result, materials];
  }
}

/// `Lv.1 → Rank 3` with the mastery images in place of the Rank labels.
class _SkillRoute extends StatelessWidget {
  const _SkillRoute({
    required this.from,
    required this.to,
    required this.masteryLabel,
    required this.fontSize,
  });

  final int from;
  final int to;
  final String Function(int rank) masteryLabel;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlanSkillLevelBadge(
          level: from,
          masteryLabel: masteryLabel,
          fontSize: fontSize,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '→',
            style: TextStyle(fontSize: fontSize, color: RdColors.secondary),
          ),
        ),
        PlanSkillLevelBadge(
          level: to,
          masteryLabel: masteryLabel,
          fontSize: fontSize,
        ),
      ],
    );
  }
}

/// PC compare grid row: 88px label | current | target.
class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.current,
    required this.target,
  });

  final String label;
  final Widget current;
  final Widget target;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: RdColors.secondary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: current),
        const SizedBox(width: 10),
        Expanded(child: target),
      ],
    );
  }
}

class _ColumnTitle extends StatelessWidget {
  const _ColumnTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: RdColors.muted,
      ),
    );
  }
}

/// Fixed-width label column + control.
class _LabeledRow extends StatelessWidget {
  const _LabeledRow({
    required this.label,
    required this.width,
    required this.child,
  });

  final String label;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: width,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: RdColors.muted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: RdColors.secondary,
      ),
    );
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, color: RdColors.muted),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      child: const RdCard.tile(
        child: RdPulse(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RdSkeleton(height: 20, widthFactor: 0.32),
              SizedBox(height: 14),
              RdSkeleton(
                height: 180,
                radius: 16,
                color: RdColors.white5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `buildTrackedPlanSignature` from the Vue page.
String _buildTrackedPlanSignature(UserPlanOperator? plan) {
  if (plan == null) {
    return '';
  }
  final current = plan.current;
  final target = plan.target;
  return [
    'c:${current.elite}:${current.level}:${current.skillLevels.join(',')}',
    current.modules.map((m) => '${m.moduleId}=${m.currentStage}').join(','),
    't:${target.elite}:${target.level}:${target.skillLevels.join(',')}',
    target.modules.map((m) => '${m.moduleId}=${m.targetStage}').join(','),
  ].join('|');
}

List<OperatorModule> _visibleModules(OperatorDetail detail) =>
    detail.modules.where((module) => module.maxStage > 0).toList();
