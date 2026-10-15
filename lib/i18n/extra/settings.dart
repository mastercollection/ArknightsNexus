/// Redesign strings for the settings area that `src/i18n.ts` does not have.
/// Keys are looked up after `nexus_messages.g.dart`; give every key a value
/// for all five locales (kr, cn, jp, tw, en).
const Map<String, Map<String, String>> settingsExtraMessages = {
  'kr': {
    'rd.settings.loading': '동기화 상태와 진단 정보를 불러오는 중…',
    'rd.settings.syncing': '지역 데이터를 동기화하는 중…',
    'rd.settings.syncBusy': '동기화 중…',
    'rd.settings.diagnosticsBusy': '처리 중…',
    'rd.settings.refreshTooltip': '새로고침 (동기화 실행)',
    'rd.settings.regionLabel': '지역 / 언어',
  },
  'cn': {
    'rd.settings.loading': '正在加载同步状态与诊断信息…',
    'rd.settings.syncing': '正在同步地区数据…',
    'rd.settings.syncBusy': '同步中…',
    'rd.settings.diagnosticsBusy': '处理中…',
    'rd.settings.refreshTooltip': '刷新（执行同步）',
    'rd.settings.regionLabel': '地区 / 语言',
  },
  'jp': {
    'rd.settings.loading': '同期状態と診断情報を読み込み中…',
    'rd.settings.syncing': '地域データを同期中…',
    'rd.settings.syncBusy': '同期中…',
    'rd.settings.diagnosticsBusy': '処理中…',
    'rd.settings.refreshTooltip': '更新（同期を実行）',
    'rd.settings.regionLabel': '地域 / 言語',
  },
  'tw': {
    'rd.settings.loading': '正在載入同步狀態與診斷資訊…',
    'rd.settings.syncing': '正在同步地區資料…',
    'rd.settings.syncBusy': '同步中…',
    'rd.settings.diagnosticsBusy': '處理中…',
    'rd.settings.refreshTooltip': '重新整理（執行同步）',
    'rd.settings.regionLabel': '地區 / 語言',
  },
  'en': {
    'rd.settings.loading': 'Loading sync status and diagnostics…',
    'rd.settings.syncing': 'Syncing region data…',
    'rd.settings.syncBusy': 'Syncing…',
    'rd.settings.diagnosticsBusy': 'Working…',
    'rd.settings.refreshTooltip': 'Refresh (run sync)',
    'rd.settings.regionLabel': 'Region / Locale',
  },
};
