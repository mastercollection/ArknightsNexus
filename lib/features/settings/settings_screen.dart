import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../core/platform/app_platform.dart';
import '../../domain/sync_status.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/diagnostics_service.dart';
import '../../ui/nexus_ui.dart' show NexusMessageType, showNexusMessage;
import '../../ui/redesign/rd_widgets.dart';
import '../home/home_region_sync.dart' show RdRegionSelect;
import 'settings_dialogs.dart';

const _globeIcon = 'assets/icons/globe.svg';
const _appIcon = 'assets/icons/app/nexus-beacon.svg';

/// Port of `src/pages/settings.vue` (`layout: 'home'`), redesigned after
/// `DesktopSettings.dc.html` / `MobileSettings.dc.html`: header with back and
/// refresh, then region, sync status, UserData and diagnostics cards (an
/// auto-fit grid on PC, one column on phones) and the error banner.
///
/// The Tauri `user_data.json` migration has no control here: the user data
/// repository imports a legacy file by itself on first read.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const routeName = 'settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  RegionSyncStatus? _syncStatus;
  DiagnosticsSummary? _diagnosticsSummary;
  bool _isLoading = true;

  /// A manual sync is running (the loading line and refresh spinner say
  /// "syncing" instead of "loading").
  bool _isSyncing = false;
  String _errorMessage = '';
  bool _userDataBusy = false;
  bool _diagnosticsBusy = false;
  int _loadToken = 0;

  bool get _isAndroidPlatform =>
      _diagnosticsSummary?.platform == AppPlatform.android;

  String? get _logDir {
    final file = _diagnosticsSummary?.logFilePath;
    return file == null || file.isEmpty ? null : p.dirname(file);
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  NexusI18n get _i18n => ref.read(i18nProvider);

  Future<void> _loadSettings() async {
    final token = ++_loadToken;
    final region = ref.read(regionProvider);
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final results = await Future.wait<Object?>([
        ref.read(regionSyncServiceProvider).getRegionSyncStatus(region),
        ref.read(diagnosticsServiceProvider).getSummary(),
      ]);
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() {
        _syncStatus = results[0] as RegionSyncStatus?;
        _diagnosticsSummary = results[1] as DiagnosticsSummary?;
      });
    } catch (error) {
      if (mounted && token == _loadToken) {
        setState(() => _errorMessage = '$error');
      }
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSettingsSync() async {
    final region = ref.read(regionProvider);
    setState(() {
      _isLoading = true;
      _isSyncing = true;
      _errorMessage = '';
    });
    try {
      await ref
          .read(regionSyncServiceProvider)
          .syncRegion(region)
          .drain<void>();
      ref.read(dataRevisionProvider.notifier).state++;
      if (mounted) {
        setState(() => _isSyncing = false);
      }
      await _loadSettings();
      if (mounted) {
        showNexusMessage(
          context,
          _i18n.t('home.messages.syncCompleted'),
          type: NexusMessageType.success,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
        _isSyncing = false;
      });
      showNexusMessage(context, '$error', type: NexusMessageType.error);
    }
  }

  Future<void> _handleExportUserData() async {
    setState(() => _userDataBusy = true);
    try {
      final content = await ref.read(userDataServiceProvider).exportUserData();
      final exported =
          await ref.read(userDataFileServiceProvider).saveJson(content);
      if (exported && mounted) {
        showNexusMessage(
          context,
          _i18n.t('home.messages.userDataExported'),
          type: NexusMessageType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showNexusMessage(context, '$error', type: NexusMessageType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _userDataBusy = false);
      }
    }
  }

  Future<void> _handleImportUserData() async {
    final i18n = _i18n;
    final confirmed = await showSettingsConfirm(
      context: context,
      title: i18n.t('home.settings.userDataImport'),
      message: i18n.t('home.messages.userDataImportConfirm'),
      confirmText: i18n.t('common.confirm'),
      cancelText: i18n.t('common.cancel'),
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _userDataBusy = true);
    try {
      final content = await ref.read(userDataFileServiceProvider).openJson();
      if (content == null) {
        return;
      }
      await ref.read(userDataServiceProvider).importUserData(content);
      ref.read(dataRevisionProvider.notifier).state++;
      if (mounted) {
        showNexusMessage(
          context,
          i18n.t('home.messages.userDataImported'),
          type: NexusMessageType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showNexusMessage(context, '$error', type: NexusMessageType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _userDataBusy = false);
      }
    }
  }

  Future<void> _handleOpenDiagnosticsLogDir() async {
    final i18n = _i18n;
    final android = _isAndroidPlatform;
    final diagnostics = ref.read(diagnosticsServiceProvider);
    setState(() => _diagnosticsBusy = true);
    try {
      if (android) {
        final exported = await diagnostics.exportLog();
        if (mounted) {
          showNexusMessage(
            context,
            i18n.t('home.messages.logsExported', {
              'file': p.basename(exported.path),
            }),
            type: NexusMessageType.success,
          );
        }
      } else {
        await diagnostics.openLogFolder();
        final summary = await diagnostics.getSummary();
        if (mounted) {
          setState(() => _diagnosticsSummary = summary);
          showNexusMessage(
            context,
            i18n.t('home.messages.logsOpened'),
            type: NexusMessageType.success,
          );
        }
      }
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('settings diagnostics action failed', error, stackTrace);
      if (mounted) {
        await showSettingsAlert(
          context: context,
          title: i18n.t('home.settings.diagnosticsTitle'),
          message: android
              ? i18n.t('home.messages.logsExportFailed')
              : i18n.t('home.messages.logsOpenFailed'),
          detail: _logDir,
          confirmText: i18n.t('common.confirm'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _diagnosticsBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    ref.listen(regionProvider, (previous, next) {
      if (previous != next) {
        _loadSettings();
      }
    });
    final compact = context.rdLayout == RdLayout.compact;

    final header = _SettingsHeader(
      compact: compact,
      title: i18n.t('home.settings.title'),
      description: i18n.t('home.settings.pageDescription'),
      backTooltip: i18n.t('common.back'),
      // settings.vue: `router.push('/')`.
      onBack: () => context.go('/'),
      refresh: RdIconButton(
        key: const Key('settings-topbar-sync'),
        icon: Icons.refresh,
        tooltip: i18n.t('rd.settings.refreshTooltip'),
        spinning: _isSyncing,
        onPressed: _isLoading ? null : _handleSettingsSync,
      ),
    );

    final cards = [
      _regionCard(i18n, compact),
      _syncCard(i18n, compact),
      _userDataCard(i18n, compact),
      _diagnosticsCard(i18n, compact),
    ];

    final content = <Widget>[
      if (_isLoading) ...[
        _LoadingLine(
          label: _isSyncing
              ? i18n.t('rd.settings.syncing')
              : i18n.t('rd.settings.loading'),
        ),
        SizedBox(height: compact ? 14 : 22),
      ],
      if (compact)
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          cards[i],
        ]
      else
        _CardGrid(children: cards),
      if (_errorMessage.isNotEmpty) ...[
        SizedBox(height: compact ? 14 : 22),
        _ErrorBanner(message: _errorMessage, compact: compact),
      ],
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, const SizedBox(height: 22), ...content],
                ),
              ),
            ),
    );
  }

  Widget _regionCard(NexusI18n i18n, bool compact) {
    return _SettingsCard(
      compact: compact,
      title: i18n.t('home.settings.regionTitle'),
      description: Text(
        i18n.t('home.settings.regionDescription'),
        style: _descriptionStyle(compact),
      ),
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: RdColors.white3,
            borderRadius: BorderRadius.circular(RdRadii.pill),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1F6DA9FF),
                ),
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 0.86,
                    child: SvgPicture.asset(_globeIcon, width: 18, height: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RdRegionSelect(
                  semanticLabel: i18n.t('rd.settings.regionLabel'),
                  height: compact ? 44 : 40,
                  fontSize: compact ? 15 : 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _syncCard(NexusI18n i18n, bool compact) {
    final ready = _syncStatus?.isReady == true;
    return _SettingsCard(
      compact: compact,
      title: i18n.t('home.settings.syncStatusTitle'),
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ready ? RdColors.success : RdColors.gold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ready
                    ? i18n.t('home.settings.syncReady')
                    : i18n.t('home.settings.syncNeeded'),
                style: const TextStyle(fontSize: 14, color: RdColors.secondary),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${regionLabels[ref.watch(regionProvider)]}',
                style: const TextStyle(fontSize: 14, color: RdColors.muted),
              ),
            ],
          ),
        ),
        _SettingsActionButton(
          key: const Key('sync-region-button'),
          compact: compact,
          label: _isSyncing
              ? i18n.t('rd.settings.syncBusy')
              : i18n.t('home.settings.syncAction'),
          onPressed: _isLoading ? null : _handleSettingsSync,
        ),
      ],
    );
  }

  Widget _userDataCard(NexusI18n i18n, bool compact) {
    final description = i18n.t('home.settings.userDataDescription');
    const fileName = 'user_data.json';
    final split = description.indexOf(fileName);
    final style = _descriptionStyle(compact);
    final exportButton = _SettingsActionButton(
      key: const Key('export-user-data-button'),
      compact: compact,
      label: i18n.t('home.settings.userDataExport'),
      onPressed: _userDataBusy ? null : _handleExportUserData,
    );
    final importButton = _SettingsActionButton(
      key: const Key('import-user-data-button'),
      compact: compact,
      label: i18n.t('home.settings.userDataImport'),
      onPressed: _userDataBusy ? null : _handleImportUserData,
    );
    return _SettingsCard(
      compact: compact,
      title: i18n.t('home.settings.userDataTitle'),
      // The file name is set in monospace like the canvas `<code>`.
      description: split < 0
          ? Text(description, style: style)
          : Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(text: description.substring(0, split)),
                  TextSpan(
                    text: fileName,
                    style: RdText.mono(
                      fontSize: compact ? 12 : 13,
                      color: RdColors.secondary,
                    ),
                  ),
                  TextSpan(
                    text: description.substring(split + fileName.length),
                  ),
                ],
              ),
            ),
      children: [
        if (compact) ...[
          exportButton,
          importButton,
        ] else
          Row(
            children: [
              Expanded(child: exportButton),
              const SizedBox(width: 8),
              Expanded(child: importButton),
            ],
          ),
      ],
    );
  }

  Widget _diagnosticsCard(NexusI18n i18n, bool compact) {
    final summary = _diagnosticsSummary;
    TableRow line(String label, String value, {double fontSize = 13}) {
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 6),
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xBDD6E5FF)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SelectableText(
              value,
              style: RdText.mono(fontSize: fontSize),
            ),
          ),
        ],
      );
    }

    return _SettingsCard(
      compact: compact,
      gap: compact ? 12 : 14,
      title: i18n.t('home.settings.diagnosticsTitle'),
      description: Text(
        _isAndroidPlatform
            ? i18n.t('home.settings.diagnosticsDescriptionAndroid')
            : i18n.t('home.settings.diagnosticsDescriptionDesktop'),
        style: _descriptionStyle(compact),
      ),
      children: [
        Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            line(
              i18n.t('home.settings.diagnosticsVersionLabel'),
              summary?.appVersion ?? '...',
            ),
            line(
              i18n.t('home.settings.diagnosticsPlatformLabel'),
              summary?.platform.name ?? '...',
            ),
            line(
              i18n.t('home.settings.diagnosticsPathLabel'),
              summary == null ? '...' : (_logDir ?? ''),
              fontSize: compact ? 12 : 13,
            ),
          ],
        ),
        _SettingsActionButton(
          key: const Key('diagnostics-logs-button'),
          compact: compact,
          label: _diagnosticsBusy
              ? i18n.t('rd.settings.diagnosticsBusy')
              : _isAndroidPlatform
                  ? i18n.t('home.settings.diagnosticsExportLogs')
                  : i18n.t('home.settings.diagnosticsOpenLogs'),
          onPressed: _diagnosticsBusy || _logDir == null
              ? null
              : _handleOpenDiagnosticsLogDir,
        ),
      ],
    );
  }
}

TextStyle _descriptionStyle(bool compact) => TextStyle(
      fontSize: compact ? 13 : 14,
      height: 1.6,
      color: RdColors.muted,
    );

/// Settings header: back, app mark, title + description, refresh. A rounded
/// bar inside the page on PC, a full-width bar on phones.
class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.compact,
    required this.title,
    required this.description,
    required this.backTooltip,
    required this.onBack,
    required this.refresh,
  });

  final bool compact;
  final String title;
  final String description;
  final String backTooltip;
  final VoidCallback onBack;
  final Widget refresh;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        RdIconButton(
          key: const Key('settings-back'),
          icon: Icons.chevron_left,
          tooltip: backTooltip,
          filled: !compact,
          onPressed: onBack,
        ),
        SizedBox(width: compact ? 10 : 14),
        Container(
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1730),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x598BD6FF)),
          ),
          child: ExcludeSemantics(child: SvgPicture.asset(_appIcon)),
        ),
        SizedBox(width: compact ? 10 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: compact
                      ? const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: RdColors.text,
                        )
                      : RdText.pageTitle,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                description,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: compact ? RdText.small : RdText.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        refresh,
      ],
    );
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: const BoxDecoration(
          color: RdColors.header,
          border: Border(bottom: BorderSide(color: RdColors.line)),
        ),
        child: SafeArea(bottom: false, child: row),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: RdColors.header,
        borderRadius: BorderRadius.circular(RdRadii.card),
        border: Border.all(color: RdColors.line),
      ),
      child: row,
    );
  }
}

/// `role="status"` spinner line shown while loading or syncing.
class _LoadingLine extends StatelessWidget {
  const _LoadingLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: RdColors.accent,
              backgroundColor: Color(0x4085B6FF),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: RdColors.secondary2),
            ),
          ),
        ],
      ),
    );
  }
}

/// `repeat(auto-fit, minmax(340px, 1fr))`, `align-items: start`.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});

  final List<Widget> children;

  static const _gap = 16.0;
  static const _minWidth = 340.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _gap) ~/ (_minWidth + _gap))
            .clamp(1, children.length);
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          if (rows.isNotEmpty) {
            rows.add(const SizedBox(height: _gap));
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: start + i < children.length
                        ? children[start + i]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.compact,
    required this.title,
    required this.children,
    this.description,
    this.gap,
  });

  final bool compact;
  final String title;
  final Widget? description;
  final List<Widget> children;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final spacing = gap ?? (compact ? 8.0 : 10.0);
    return RdCard(
      padding: compact
          ? const EdgeInsets.all(16)
          : const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      radius: compact ? RdRadii.tile : RdRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: compact ? 16 : 17,
                fontWeight: FontWeight.w700,
                color: RdColors.text,
              ),
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            description!,
          ],
          for (final child in children) ...[
            SizedBox(height: spacing),
            child,
          ],
        ],
      ),
    );
  }
}

/// Accent-tinted action button of the settings cards (44px on PC, 48px on
/// phones); greyed out while disabled.
class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.compact,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final bool compact;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? RdColors.tonalFill : RdColors.white3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RdRadii.control),
          side: BorderSide(
            color: enabled ? RdColors.tonalBorder : RdColors.white8,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RdRadii.control),
          onTap: onPressed,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 48 : 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: enabled ? RdColors.text : RdColors.placeholder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.compact});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: RdColors.dangerFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RdColors.dangerBorder),
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            height: 1.5,
            color: RdColors.dangerText,
          ),
        ),
      ),
    );
  }
}
