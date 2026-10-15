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
import '../shared/region_select.dart';
import '../shared/region_sync.dart';
import 'settings_dialogs.dart';

const _globeIcon = 'assets/icons/globe.svg';

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
  DiagnosticsSummary? _diagnosticsSummary;
  bool _isLoading = true;

  /// Error of the last manual sync or diagnostics load. Status load errors
  /// come from [regionSyncStatusProvider].
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

  /// Loads the diagnostics summary; the sync status is
  /// [regionSyncStatusProvider], shared with the home page.
  Future<void> _loadSettings() async {
    final token = ++_loadToken;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final summary = await ref.read(diagnosticsServiceProvider).getSummary();
      if (!mounted || token != _loadToken) {
        return;
      }
      setState(() => _diagnosticsSummary = summary);
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

  /// Runs the shared [RegionSyncController], so the home controls show the
  /// same busy state; the refreshed status arrives through
  /// [regionSyncStatusProvider].
  Future<void> _handleSettingsSync() async {
    setState(() => _errorMessage = '');
    final error = await ref.read(regionSyncControllerProvider.notifier).sync();
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() => _errorMessage = '$error');
      showNexusMessage(context, '$error', type: NexusMessageType.error);
      return;
    }
    await _loadSettings();
    if (mounted) {
      showNexusMessage(
        context,
        _i18n.t('home.messages.syncCompleted'),
        type: NexusMessageType.success,
      );
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
    final syncing = ref.watch(regionSyncControllerProvider);
    final statusAsync = ref.watch(regionSyncStatusProvider);
    final loading = _isLoading || syncing || statusAsync.isLoading;
    final errorMessage = _errorMessage.isNotEmpty
        ? _errorMessage
        : statusAsync.hasError
            ? '${statusAsync.error}'
            : '';

    final header = RdPageHeader(
      title: i18n.t('home.settings.title'),
      subtitle: i18n.t('home.settings.pageDescription'),
      subtitleMaxLines: compact ? 1 : 2,
      compactTitleStyle: RdText.mobileTitle.copyWith(fontSize: 18),
      backKey: const Key('settings-back'),
      backTooltip: i18n.t('common.back'),
      // settings.vue: `router.push('/')`.
      onBack: () => context.go('/'),
      leading: const RdAppMark(size: 28),
      actions: [
        RdIconButton(
          key: const Key('settings-topbar-sync'),
          icon: Icons.refresh,
          tooltip: i18n.t('rd.settings.refreshTooltip'),
          spinning: syncing,
          onPressed: loading ? null : _handleSettingsSync,
        ),
      ],
    );

    final cards = [
      _regionCard(i18n, compact),
      _syncCard(i18n, compact, statusAsync.valueOrNull, syncing, loading),
      _userDataCard(i18n, compact),
      _diagnosticsCard(i18n, compact),
    ];

    final content = <Widget>[
      if (loading) ...[
        _LoadingLine(
          label: syncing
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
        // repeat(auto-fit, minmax(340px, 1fr)), align-items: start.
        RdAutoGrid(
          minTileWidth: 340,
          gap: 16,
          maxColumns: cards.length,
          children: cards,
        ),
      if (errorMessage.isNotEmpty) ...[
        SizedBox(height: compact ? 14 : 22),
        RdNotice(
          text: errorMessage,
          tone: RdNoticeTone.danger,
          showIcon: false,
        ),
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

  Widget _syncCard(
    NexusI18n i18n,
    bool compact,
    RegionSyncStatus? status,
    bool syncing,
    bool loading,
  ) {
    final ready = status?.isReady == true;
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
        RdButton(
          key: const Key('sync-region-button'),
          label: syncing
              ? i18n.t('common.syncing')
              : i18n.t('home.settings.syncAction'),
          onPressed: loading ? null : _handleSettingsSync,
          variant: RdButtonVariant.tonal,
          height: compact ? 48 : 44,
          expand: true,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _userDataCard(NexusI18n i18n, bool compact) {
    final description = i18n.t('home.settings.userDataDescription');
    const fileName = 'user_data.json';
    final split = description.indexOf(fileName);
    final style = _descriptionStyle(compact);
    final exportButton = RdButton(
      key: const Key('export-user-data-button'),
      label: i18n.t('home.settings.userDataExport'),
      onPressed: _userDataBusy ? null : _handleExportUserData,
      variant: RdButtonVariant.tonal,
      height: compact ? 48 : 44,
      expand: true,
      maxLines: 3,
    );
    final importButton = RdButton(
      key: const Key('import-user-data-button'),
      label: i18n.t('home.settings.userDataImport'),
      onPressed: _userDataBusy ? null : _handleImportUserData,
      variant: RdButtonVariant.tonal,
      height: compact ? 48 : 44,
      expand: true,
      maxLines: 3,
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
        RdButton(
          key: const Key('diagnostics-logs-button'),
          label: _diagnosticsBusy
              ? i18n.t('rd.settings.diagnosticsBusy')
              : _isAndroidPlatform
                  ? i18n.t('home.settings.diagnosticsExportLogs')
                  : i18n.t('home.settings.diagnosticsOpenLogs'),
          onPressed: _diagnosticsBusy || _logDir == null
              ? null
              : _handleOpenDiagnosticsLogDir,
          variant: RdButtonVariant.tonal,
          height: compact ? 48 : 44,
          expand: true,
          maxLines: 3,
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
