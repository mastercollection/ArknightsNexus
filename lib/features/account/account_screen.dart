import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/account_profile.dart';
import '../../domain/operator.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/account/account_import_service.dart';
import '../../services/account/yostar_account_client.dart';
import '../../services/operator_service.dart';
import '../../ui/nexus_ui.dart' show NexusMessageType, showNexusMessage;
import '../../ui/redesign/rd_widgets.dart';
import '../settings/settings_dialogs.dart';
import '../shared/number_format.dart';
import '../shared/region_sync.dart';

/// My Account: signs in to a Yostar game account (email code), copies its
/// depot and training into the user data and shows the imported profile
/// with training counts per rarity.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  static const routeName = 'account';

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

/// Operators of the selected region released there (unreleased ones are
/// left out of the totals).
final _regionOperatorsProvider =
    FutureProvider.autoDispose<List<OperatorSummary>>((ref) async {
  final region = ref.watch(regionProvider);
  ref.watch(dataRevisionProvider);
  try {
    await ref.watch(regionEnsureProvider.future);
  } catch (_) {
    // Logged by RegionReadiness; count whatever is cached.
  }
  final operators = await ref
      .watch(operatorServiceProvider)
      .listOperators(OperatorQuery(region: region));
  return [
    for (final operator in operators)
      if (operator.unreleasedSource == null) operator,
  ];
});

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  YostarServer? _server;
  AccountImportService? _service;
  bool _codeSent = false;
  bool _busy = false;
  bool _loginOpen = false;
  String _error = '';

  NexusI18n get _i18n => ref.read(i18nProvider);

  @override
  void dispose() {
    _service?.close();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  YostarServer get _selectedServer =>
      _server ??
      YostarServer.ofRegion(ref.read(regionProvider)) ??
      YostarServer.kr;

  void _selectServer(YostarServer server) {
    if (server == _selectedServer) {
      return;
    }
    _service?.close();
    setState(() {
      _server = server;
      _service = null;
      _codeSent = false;
      _error = '';
    });
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      return;
    }
    _service?.close();
    final service = AccountImportService(
      _selectedServer,
      ref.read(userDataServiceProvider),
    );
    setState(() {
      _service = service;
      _busy = true;
      _error = '';
    });
    try {
      await service.sendCode(email);
      if (mounted) {
        setState(() => _codeSent = true);
        showNexusMessage(
          context,
          _i18n.t('account.login.codeSent', {'email': email}),
          type: NexusMessageType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    final service = _service;
    final code = _code.text.trim();
    if (service == null || code.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await service.importAccount(_email.text, code);
      if (!mounted) {
        return;
      }
      ref.read(dataRevisionProvider.notifier).state++;
      service.close();
      setState(() {
        _service = null;
        _codeSent = false;
        _loginOpen = false;
        _code.clear();
      });
      showNexusMessage(
        context,
        _i18n.t('account.imported', {
          'operators': result.operators,
          'items': result.itemKinds,
          'plans': result.updatedPlans,
        }),
        type: NexusMessageType.success,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove() async {
    final i18n = _i18n;
    final confirmed = await showSettingsConfirm(
      context: context,
      title: i18n.t('account.summary.remove'),
      message: i18n.t('account.summary.removeConfirm'),
      confirmText: i18n.t('common.confirm'),
      cancelText: i18n.t('common.cancel'),
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(userDataServiceProvider).clearAccount();
      ref.read(dataRevisionProvider.notifier).state++;
    } catch (error) {
      if (mounted) {
        showNexusMessage(context, '$error', type: NexusMessageType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final compact = context.rdLayout == RdLayout.compact;
    final account = ref.watch(accountProfileProvider);
    final profile = account.valueOrNull;
    final gap = compact ? 12.0 : 16.0;

    final content = <Widget>[
      if (account.hasError) ...[
        RdNotice(
          text: '${account.error}',
          tone: RdNoticeTone.danger,
          showIcon: false,
        ),
        SizedBox(height: gap),
      ],
      if (profile != null) ...[
        _profileCard(i18n, compact, profile),
        SizedBox(height: gap),
      ],
      if (profile == null || _loginOpen) ...[
        _loginCard(i18n, compact),
        SizedBox(height: gap),
      ],
      if (profile != null) _statsCard(i18n, compact, profile),
    ];

    final title = i18n.t('shell.nav.account');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RdPageHeader(title: title),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: content,
                    ),
                  ),
                ),
              ],
            )
          : SafeArea(
              left: false,
              child: SingleChildScrollView(
                padding: rdPagePadding(context),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(title, style: RdText.pageTitle),
                        ),
                        const SizedBox(height: 4),
                        Text(i18n.t('account.subtitle'), style: RdText.muted),
                        const SizedBox(height: 24),
                        ...content,
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  double _buttonHeight(bool compact) => compact ? 48 : 40;

  Widget _loginCard(NexusI18n i18n, bool compact) {
    const bodyStyle =
        TextStyle(fontSize: 13, height: 1.55, color: RdColors.text2);
    if (!accountImportSupported) {
      return _AccountCard(
        compact: compact,
        title: i18n.t('account.login.title'),
        children: [
          RdNotice(text: i18n.t('account.login.webUnsupported')),
        ],
      );
    }
    final server = _selectedServer;
    final field = compact ? 48.0 : 40.0;
    final sendButton = RdButton(
      key: const Key('account-send-code'),
      label: i18n.t(
        _codeSent ? 'account.login.resendCode' : 'account.login.sendCode',
      ),
      onPressed: _busy ? null : _sendCode,
      height: field,
    );
    return _AccountCard(
      compact: compact,
      title: i18n.t('account.login.title'),
      children: [
        Text(i18n.t('account.login.description'), style: bodyStyle),
        const SizedBox(height: 12),
        RdNotice(
          text: i18n.t('account.login.warning'),
          tone: RdNoticeTone.warn,
        ),
        const SizedBox(height: 16),
        _Label(i18n.t('account.login.server')),
        RdSelect<YostarServer>(
          label: i18n.t('account.login.server'),
          value: server,
          height: field,
          fontSize: compact ? 15 : 14,
          options: [
            for (final option in YostarServer.values)
              RdSelectOption(
                option,
                regionLabels[option.region] ?? option.name.toUpperCase(),
              ),
          ],
          onChanged: _busy ? (_) {} : _selectServer,
        ),
        const SizedBox(height: 12),
        _Label(i18n.t('account.login.email')),
        Row(
          children: [
            Expanded(
              child: _AccountField(
                key: const Key('account-email'),
                controller: _email,
                height: field,
                hint: 'doctor@example.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enabled: !_busy,
                onSubmitted: (_) => _sendCode(),
              ),
            ),
            const SizedBox(width: 8),
            sendButton,
          ],
        ),
        const SizedBox(height: 12),
        _Label(i18n.t('account.login.code')),
        _AccountField(
          key: const Key('account-code'),
          controller: _code,
          height: field,
          hint: '000000',
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          enabled: _codeSent && !_busy,
          onSubmitted: (_) => _import(),
        ),
        const SizedBox(height: 16),
        RdButton(
          key: const Key('account-import'),
          label: i18n.t(
            _busy && _codeSent
                ? 'account.login.importing'
                : 'account.login.submit',
          ),
          icon: Icons.download_outlined,
          variant: RdButtonVariant.primary,
          busy: _busy && _codeSent,
          onPressed: _codeSent && !_busy ? _import : null,
          height: _buttonHeight(compact),
          expand: true,
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          RdNotice(
            text: _error,
            tone: RdNoticeTone.danger,
            showIcon: false,
          ),
        ],
        const SizedBox(height: 12),
        Text(i18n.t('account.login.privacy'), style: RdText.small),
      ],
    );
  }

  Widget _profileCard(NexusI18n i18n, bool compact, AccountProfile profile) {
    final now = DateTime.now();
    final region = ref.watch(regionProvider);
    final joined = profile.registeredAt;
    final dateFormat = DateFormat('yyyy-MM-dd');
    final stats = <(String, String)>[
      (
        i18n.t('account.summary.ap'),
        '${profile.currentAp(now)}/${profile.maxAp}',
      ),
      (i18n.t('account.summary.lmd'), formatWholeNumber(profile.gold)),
      (i18n.t('account.summary.orundum'), formatWholeNumber(profile.orundum)),
      (
        i18n.t('account.summary.originium'),
        formatWholeNumber(profile.originium),
      ),
      (
        i18n.t('account.summary.depot'),
        i18n.t('account.summary.depotKinds', {
          'count': formatWholeNumber(profile.inventoryKinds),
        }),
      ),
    ];
    final accountRegion = YostarServer.values
        .where((server) => server.region.value == profile.region)
        .firstOrNull
        ?.region;

    return _AccountCard(
      compact: compact,
      title: null,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              profile.nickNumber.isEmpty
                  ? profile.nickName
                  : '${profile.nickName}#${profile.nickNumber}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: RdColors.text,
              ),
            ),
            Text('Lv.${profile.level}', style: RdText.mono(fontSize: 15)),
            if (accountRegion != null)
              RdPill(label: regionLabels[accountRegion] ?? profile.region),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          [
            'UID ${profile.uid}',
            if (joined != null)
              i18n.t('account.summary.joined', {
                'date': dateFormat.format(joined),
                'days': now.difference(joined).inDays,
              }),
          ].join(' · '),
          style: RdText.small,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, value) in stats)
              _StatTile(label: label, value: value),
          ],
        ),
        if (accountRegion != null && accountRegion != region) ...[
          const SizedBox(height: 12),
          RdNotice(
            text: i18n.t('account.summary.otherRegion', {
              'account': regionLabels[accountRegion],
              'region': regionLabels[region],
            }),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                i18n.t('account.summary.syncedAt', {
                  'time':
                      DateFormat('yyyy-MM-dd HH:mm').format(profile.syncedAt),
                }),
                style: RdText.small,
              ),
            ),
            if (accountImportSupported) ...[
              RdButton(
                key: const Key('account-resync'),
                label: i18n.t('account.summary.resync'),
                icon: Icons.refresh,
                variant: RdButtonVariant.tonal,
                onPressed: () => setState(() {
                  _loginOpen = !_loginOpen;
                  _server ??= YostarServer.values
                      .where((server) => server.region.value == profile.region)
                      .firstOrNull;
                }),
                height: _buttonHeight(compact),
              ),
              const SizedBox(width: 8),
            ],
            RdButton(
              key: const Key('account-remove'),
              label: i18n.t('account.summary.remove'),
              variant: RdButtonVariant.ghost,
              onPressed: _busy ? null : _remove,
              height: _buttonHeight(compact),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statsCard(NexusI18n i18n, bool compact, AccountProfile profile) {
    final operators = ref.watch(_regionOperatorsProvider).valueOrNull;
    if (operators == null) {
      return const SizedBox.shrink();
    }
    final rows = [
      for (var rarity = 6; rarity >= 1; rarity--)
        _RarityStats.of(rarity, operators, profile),
    ];
    final owned = rows.fold(0, (sum, row) => sum + row.owned);
    final total = rows.fold(0, (sum, row) => sum + row.total);
    final headers = [
      i18n.t('account.stats.rarity'),
      i18n.t('account.stats.owned'),
      i18n.t('account.stats.finalElite'),
      i18n.t('account.stats.maxLevel'),
      i18n.t('account.stats.fullPotential'),
      i18n.t('account.stats.mastery3'),
    ];
    const headerStyle = TextStyle(fontSize: 12, color: RdColors.text3);
    final cellStyle = RdText.mono(fontSize: compact ? 13 : 14);

    TableRow row(List<Widget> cells) => TableRow(
          children: [
            for (final cell in cells)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: cell,
              ),
          ],
        );

    return _AccountCard(
      compact: compact,
      title: i18n.t('account.stats.title'),
      children: [
        Text(
          '${i18n.t('account.stats.total')} $owned/$total'
          '${total == 0 ? '' : ' · ${(owned * 100 / total).round()}%'}',
          style: RdText.secondary,
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.4)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: RdColors.hairline),
          ),
          children: [
            row([
              for (final header in headers)
                Text(header, style: headerStyle, maxLines: 2),
            ]),
            for (final stats in rows)
              row([
                Text(
                  '${stats.rarity}★',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: RdColors.rarity,
                  ),
                ),
                Text('${stats.owned}/${stats.total}', style: cellStyle),
                Text(
                  stats.rarity >= 3 ? '${stats.finalElite}' : '—',
                  style: cellStyle,
                ),
                Text('${stats.maxLevel}', style: cellStyle),
                Text('${stats.fullPotential}', style: cellStyle),
                Text(
                  stats.rarity >= 3 ? '${stats.mastery3}' : '—',
                  style: cellStyle,
                ),
              ]),
          ],
        ),
        const SizedBox(height: 8),
        Text(i18n.t('account.stats.note'), style: RdText.small),
      ],
    );
  }
}

/// Training counts of the owned [rarity]★ operators of a region.
class _RarityStats {
  const _RarityStats({
    required this.rarity,
    required this.total,
    required this.owned,
    required this.finalElite,
    required this.maxLevel,
    required this.fullPotential,
    required this.mastery3,
  });

  /// Level cap of the final elite per rarity (1★ to 6★).
  static const _maxLevels = [30, 30, 55, 70, 80, 90];

  factory _RarityStats.of(
    int rarity,
    List<OperatorSummary> operators,
    AccountProfile profile,
  ) {
    final finalElite = rarity >= 4 ? 2 : (rarity == 3 ? 1 : 0);
    final cap = _maxLevels[rarity - 1];
    var total = 0;
    var owned = 0;
    var elite = 0;
    var maxLevel = 0;
    var potential = 0;
    var mastery = 0;
    for (final operator in operators) {
      if (operator.rarity != rarity) {
        continue;
      }
      total++;
      final account = profile.operator(operator.id);
      if (account == null) {
        continue;
      }
      owned++;
      if (account.elite >= finalElite) {
        elite++;
        if (account.level >= cap) {
          maxLevel++;
        }
      }
      if (account.potential >= 5) {
        potential++;
      }
      if (account.maxMastery >= 3) {
        mastery++;
      }
    }
    return _RarityStats(
      rarity: rarity,
      total: total,
      owned: owned,
      finalElite: elite,
      maxLevel: maxLevel,
      fullPotential: potential,
      mastery3: mastery,
    );
  }

  final int rarity;
  final int total;
  final int owned;
  final int finalElite;
  final int maxLevel;
  final int fullPotential;
  final int mastery3;
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.compact,
    required this.title,
    required this.children,
  });

  final bool compact;
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RdCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(title!, style: RdText.sectionTitle),
            ),
            SizedBox(height: compact ? 10 : 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ExcludeSemantics(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: RdColors.text3),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: RdColors.inner,
        borderRadius: BorderRadius.circular(RdRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: RdText.small),
          const SizedBox(height: 2),
          Text(
            value,
            style: RdText.mono(fontSize: 16).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field in the redesign's control style (like [RdSearchField]).
class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.controller,
    required this.height,
    required this.hint,
    required this.keyboardType,
    required this.autofillHints,
    required this.enabled,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final double height;
  final String hint;
  final TextInputType keyboardType;
  final List<String> autofillHints;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: enabled ? RdColors.field : RdColors.surface2,
        borderRadius: BorderRadius.circular(RdRadii.control),
        border: Border.all(color: RdColors.border),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        autocorrect: false,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 15, color: RdColors.text),
        cursorColor: RdColors.accent,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 15, color: RdColors.text3),
        ),
      ),
    );
  }
}
