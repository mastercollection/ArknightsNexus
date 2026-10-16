/// Redesign strings shared by several areas (close buttons, sync progress,
/// plan links) that `src/i18n.ts` does not have. Keys are looked up after
/// `nexus_messages.g.dart`; give every key a value for all five locales.
const Map<String, Map<String, String>> commonExtraMessages = {
  'kr': {
    'common.close': '닫기',
    'common.syncing': '동기화 중…',
    'common.openPlan': '계획 열기 →',
    // Operators of the selected region (native · unreleased).
    'common.operatorCount': '{count}명',
    'common.operatorCountUnreleased': '{count}명 · 미실장 {unreleased}명',
  },
  'cn': {
    'common.close': '关闭',
    'common.syncing': '同步中…',
    'common.openPlan': '打开计划 →',
    // Operators of the selected region (native · unreleased).
    'common.operatorCount': '{count}名',
    'common.operatorCountUnreleased': '{count}名 · 未实装 {unreleased}名',
  },
  'jp': {
    'common.close': '閉じる',
    'common.syncing': '同期中…',
    'common.openPlan': '計画を開く →',
    // Operators of the selected region (native · unreleased).
    'common.operatorCount': '{count}名',
    'common.operatorCountUnreleased': '{count}名 · 未実装 {unreleased}名',
  },
  'tw': {
    'common.close': '關閉',
    'common.syncing': '同步中…',
    'common.openPlan': '開啟計畫 →',
    // Operators of the selected region (native · unreleased).
    'common.operatorCount': '{count}名',
    'common.operatorCountUnreleased': '{count}名 · 未實裝 {unreleased}名',
  },
  'en': {
    'common.close': 'Close',
    'common.syncing': 'Syncing…',
    'common.openPlan': 'Open plan →',
    // Operators of the selected region (native · unreleased).
    'common.operatorCount': '{count} operators',
    'common.operatorCountUnreleased':
        '{count} operators · {unreleased} unreleased',
    // `src/i18n.ts` has no English hero title; the redesign showed this.
    'home.hero.title': 'Exploration Hub',
  },
};
