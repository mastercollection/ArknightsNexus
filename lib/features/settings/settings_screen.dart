import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../core/platform/app_platform.dart';
import '../../core/platform/site_links.dart';
import '../../domain/sync_status.dart';
import '../../i18n/nexus_i18n.dart';
import '../../services/diagnostics_service.dart';
import '../../ui/nexus_ui.dart' show NexusMessageType, showNexusMessage;
import '../../ui/redesign/rd_widgets.dart';
import '../shared/region_data_label.dart';
import '../shared/region_operator_counts.dart';
import '../shared/region_select.dart';
import '../shared/region_sync.dart';
import 'settings_dialogs.dart';

/// Port of `src/pages/settings.vue` (`layout: 'home'`), redesigned after
/// `PcSettings.dc.html` / `MSettings.dc.html`: the title, then region, data
/// sync and UserData cards next to the about and diagnostics cards (two
/// columns on wide PC windows, one column otherwise), and the error banner.
/// Diagnostics start collapsed; the log path is copied, not shown.
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
  bool _diagnosticsOpen = false;
  int _loadToken = 0;

  bool get _isAndroidPlatform =>
      _diagnosticsSummary?.platform == AppPlatform.android;

  /// The web build keeps no log file: no path and no log button.
  bool get _isWebPlatform => _diagnosticsSummary?.platform == AppPlatform.web;

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
              'file': p.basename(exported),
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

  Future<void> _handleCopyLogPath() async {
    final path = _logDir;
    if (path == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: path));
    if (mounted) {
      showNexusMessage(
        context,
        _i18n.t('rd.settings.pathCopied'),
        type: NexusMessageType.success,
      );
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

    final left = [
      _regionCard(i18n, compact),
      _syncCard(i18n, compact, statusAsync.valueOrNull, syncing, loading),
      _userDataCard(i18n, compact),
    ];
    final right = [
      _aboutCard(i18n, compact),
      _diagnosticsCard(i18n, compact),
    ];
    final gap = compact ? 12.0 : 20.0;

    Widget column(List<Widget> cards) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              cards[i],
            ],
          ],
        );

    final cards = compact
        ? column([...left, ...right])
        : LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return column([...left, ...right]);
              }
              return Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: column(left)),
                      SizedBox(width: gap),
                      Expanded(child: column(right)),
                    ],
                  ),
                ),
              );
            },
          );

    final content = <Widget>[
      if (loading) ...[
        _LoadingLine(
          label: syncing
              ? i18n.t('rd.settings.syncing')
              : i18n.t('rd.settings.loading'),
        ),
        SizedBox(height: gap),
      ],
      cards,
      if (errorMessage.isNotEmpty) ...[
        SizedBox(height: gap),
        RdNotice(
          text: errorMessage,
          tone: RdNoticeTone.danger,
          showIcon: false,
        ),
      ],
    ];

    final title = i18n.t('shell.nav.settings');
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: RdText.pageTitle),
                    ),
                    const SizedBox(height: 24),
                    ...content,
                  ],
                ),
              ),
            ),
    );
  }

  double _buttonHeight(bool compact) => compact ? 48 : 44;

  Widget _regionCard(NexusI18n i18n, bool compact) {
    return _SettingsCard(
      compact: compact,
      title: i18n.t('home.settings.regionTitle'),
      children: [
        ExcludeSemantics(
          child: Text(
            i18n.t('rd.settings.regionField'),
            style: const TextStyle(fontSize: 12, color: RdColors.text3),
          ),
        ),
        const SizedBox(height: 6),
        RdRegionSelect(
          semanticLabel: i18n.t('rd.settings.regionLabel'),
          height: compact ? 48 : 40,
          fontSize: compact ? 15 : 14,
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
    final region = ref.watch(regionProvider);
    final counts = ready
        ? ref.watch(regionOperatorCountsProvider).valueOrNull ??
            (status!.operatorCount > 0
                ? RegionOperatorCounts(
                    native: status.operatorCount,
                    unreleased: 0,
                  )
                : null)
        : null;
    const detailStyle = TextStyle(fontSize: 14, color: RdColors.text2);
    final time = formatSyncTime(status?.fetchedAt);
    final statusBlock = Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ready ? RdColors.success : RdColors.warning,
                ),
              ),
              Text(
                regionDataLabel(region, status),
                key: const Key('settings-data-version'),
                style: RdText.mono(fontSize: 14),
              ),
              if (!ready)
                Text(
                  '· ${i18n.t('home.settings.syncNeeded')}',
                  style: detailStyle,
                )
              else if (counts != null)
                OperatorCountsText(
                  key: const Key('settings-operator-counts'),
                  i18n: i18n,
                  counts: counts,
                  prefix: '· ',
                  style: detailStyle,
                ),
            ],
          ),
          if (time != null) ...[
            const SizedBox(height: 4),
            Text(
              i18n.t('rd.settings.lastSync', {'time': time}),
              key: const Key('settings-sync-time'),
              style: const TextStyle(fontSize: 12, color: RdColors.text3),
            ),
          ],
        ],
      ),
    );
    final button = RdButton(
      key: const Key('sync-region-button'),
      label:
          syncing ? i18n.t('common.syncing') : i18n.t('rd.settings.syncButton'),
      icon: Icons.refresh,
      busy: syncing,
      onPressed: loading ? null : _handleSettingsSync,
      variant: RdButtonVariant.primary,
      height: _buttonHeight(compact),
      expand: compact,
    );
    return _SettingsCard(
      compact: compact,
      title: i18n.t('rd.settings.syncTitle'),
      children: compact
          ? [statusBlock, const SizedBox(height: 12), button]
          : [
              Row(
                children: [
                  Expanded(child: statusBlock),
                  const SizedBox(width: 16),
                  button,
                ],
              ),
            ],
    );
  }

  Widget _userDataCard(NexusI18n i18n, bool compact) {
    final description = i18n.t(
      _isWebPlatform
          ? 'rd.settings.userDataDescriptionWeb'
          : 'home.settings.userDataDescription',
    );
    const fileName = 'user_data.json';
    final split = description.indexOf(fileName);
    const style = TextStyle(fontSize: 13, height: 1.5, color: RdColors.text3);
    Widget button(String key, String label, IconData icon, VoidCallback run) {
      return Expanded(
        child: RdButton(
          key: Key(key),
          label: label,
          icon: icon,
          onPressed: _userDataBusy ? null : run,
          height: _buttonHeight(compact),
          expand: true,
          maxLines: 2,
        ),
      );
    }

    return _SettingsCard(
      compact: compact,
      title: i18n.t('rd.settings.userDataTitle'),
      children: [
        // The file name is set in monospace like the canvas `<code>`.
        if (split < 0)
          Text(description, style: style)
        else
          Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: description.substring(0, split)),
                TextSpan(
                  text: fileName,
                  style: RdText.mono(fontSize: 12, color: RdColors.text2),
                ),
                TextSpan(
                  text: description.substring(split + fileName.length),
                ),
              ],
            ),
          ),
        SizedBox(height: compact ? 12 : 14),
        Row(
          children: [
            button(
              'export-user-data-button',
              i18n.t('rd.settings.export'),
              Icons.file_upload_outlined,
              _handleExportUserData,
            ),
            SizedBox(width: compact ? 8 : 10),
            button(
              'import-user-data-button',
              i18n.t('rd.settings.import'),
              Icons.file_download_outlined,
              _handleImportUserData,
            ),
          ],
        ),
      ],
    );
  }

  /// App version and platform, then the project site's intro and privacy
  /// pages where the platform can open them (on the web build they sit next
  /// to the app).
  Widget _aboutCard(NexusI18n i18n, bool compact) {
    final summary = _diagnosticsSummary;
    Widget fact(String label, String value, Key key) {
      return Container(
        constraints: BoxConstraints(minHeight: compact ? 44 : 36),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: RdColors.text2),
              ),
            ),
            SelectableText(
              value,
              key: key,
              style: RdText.mono(fontSize: 14),
            ),
          ],
        ),
      );
    }

    Widget link(String key, String label, String page) {
      return Semantics(
        link: true,
        child: InkWell(
          key: Key(key),
          onTap: () => SiteLinks.open(page),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 48 : 44),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 14, color: RdColors.text),
                  ),
                ),
                const Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: RdColors.text3,
                ),
              ],
            ),
          ),
        ),
      );
    }

    const divider = Divider(height: 1, thickness: 1, color: RdColors.hairline);
    return _SettingsCard(
      compact: compact,
      title: i18n.t('rd.settings.aboutTitle'),
      children: [
        fact(
          i18n.t('home.settings.diagnosticsVersionLabel'),
          summary?.appVersion ?? '...',
          const Key('settings-app-version'),
        ),
        fact(
          i18n.t('home.settings.diagnosticsPlatformLabel'),
          summary?.platform.name ?? '...',
          const Key('settings-platform'),
        ),
        if (SiteLinks.canOpen) ...[
          const SizedBox(height: 8),
          divider,
          link(
            'settings-about-link',
            i18n.t('rd.settings.aboutPage'),
            SiteLinks.aboutPage,
          ),
          divider,
          link(
            'settings-privacy-link',
            i18n.t('rd.settings.privacyPage'),
            SiteLinks.privacyPage,
          ),
        ],
      ],
    );
  }

  /// Collapsed by default: a header button that opens the description and
  /// the log controls (open the folder on desktop, export on Android, copy
  /// the folder path). The web build has only the description.
  Widget _diagnosticsCard(NexusI18n i18n, bool compact) {
    final open = _diagnosticsOpen;
    final padding = compact ? 16.0 : 20.0;
    final header = Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        key: const Key('settings-diagnostics-toggle'),
        borderRadius: BorderRadius.circular(RdRadii.card),
        onTap: () => setState(() => _diagnosticsOpen = !open),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 52 : 60),
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  i18n.t('rd.settings.diagnosticsTitle'),
                  style: RdText.sectionTitle,
                ),
              ),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: RdColors.text2,
              ),
            ],
          ),
        ),
      ),
    );
    final logsButton = RdButton(
      key: const Key('diagnostics-logs-button'),
      label: _diagnosticsBusy
          ? i18n.t('rd.settings.diagnosticsBusy')
          : _isAndroidPlatform
              ? i18n.t('home.settings.diagnosticsExportLogs')
              : i18n.t('home.settings.diagnosticsOpenLogs'),
      icon: Icons.folder_open_outlined,
      onPressed: _diagnosticsBusy || _logDir == null
          ? null
          : _handleOpenDiagnosticsLogDir,
      height: _buttonHeight(compact),
      expand: true,
      maxLines: 2,
    );
    final copyButton = RdButton(
      key: const Key('diagnostics-copy-path'),
      label: i18n.t('rd.settings.copyPath'),
      icon: Icons.content_copy_outlined,
      onPressed: _logDir == null ? null : _handleCopyLogPath,
      variant: RdButtonVariant.ghost,
      height: _buttonHeight(compact),
      expand: compact,
    );
    final body = Padding(
      key: const Key('settings-diagnostics-body'),
      padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isWebPlatform
                ? i18n.t('rd.settings.diagnosticsDescriptionWeb')
                : _isAndroidPlatform
                    ? i18n.t('home.settings.diagnosticsDescriptionAndroid')
                    : i18n.t('home.settings.diagnosticsDescriptionDesktop'),
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: RdColors.text3,
            ),
          ),
          if (!_isWebPlatform) ...[
            SizedBox(height: compact ? 10 : 12),
            if (compact) ...[
              logsButton,
              const SizedBox(height: 10),
              copyButton,
            ] else
              Row(
                children: [
                  Expanded(child: logsButton),
                  const SizedBox(width: 10),
                  copyButton,
                ],
              ),
          ],
        ],
      ),
    );
    return RdCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, if (open) body],
      ),
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
              backgroundColor: RdColors.accentSoft,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: RdColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings section: surface-2 card with a 15/600 heading.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.compact,
    required this.title,
    required this.children,
  });

  final bool compact;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RdCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: RdText.sectionTitle),
          ),
          SizedBox(height: compact ? 10 : 12),
          ...children,
        ],
      ),
    );
  }
}
