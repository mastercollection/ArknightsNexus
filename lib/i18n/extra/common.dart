/// Redesign strings shared by several areas (close buttons, sync progress,
/// plan links) that `src/i18n.ts` does not have. Keys are looked up after
/// `nexus_messages.g.dart`; give every key a value for all five locales.
const Map<String, Map<String, String>> commonExtraMessages = {
  'kr': {
    'common.close': '닫기',
    'common.syncing': '동기화 중…',
    'common.openPlan': '계획 열기 →',
  },
  'cn': {
    'common.close': '关闭',
    'common.syncing': '同步中…',
    'common.openPlan': '打开计划 →',
  },
  'jp': {
    'common.close': '閉じる',
    'common.syncing': '同期中…',
    'common.openPlan': '計画を開く →',
  },
  'tw': {
    'common.close': '關閉',
    'common.syncing': '同步中…',
    'common.openPlan': '開啟計畫 →',
  },
  'en': {
    'common.close': 'Close',
    'common.syncing': 'Syncing…',
    'common.openPlan': 'Open plan →',
    // `src/i18n.ts` has no English hero title; the redesign showed this.
    'home.hero.title': 'Exploration Hub',
  },
};
