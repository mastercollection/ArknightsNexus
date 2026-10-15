/// Redesign strings for the settings area that `src/i18n.ts` does not have.
/// Keys are looked up after `nexus_messages.g.dart`; give every key a value
/// for all five locales (kr, cn, jp, tw, en).
const Map<String, Map<String, String>> settingsExtraMessages = {
  'kr': {
    'rd.settings.loading': '동기화 상태와 진단 정보를 불러오는 중…',
    'rd.settings.syncing': '지역 데이터를 동기화하는 중…',
    'rd.settings.diagnosticsBusy': '처리 중…',
    'rd.settings.refreshTooltip': '새로고침 (동기화 실행)',
    'rd.settings.regionLabel': '지역 / 언어',
    'rd.settings.userDataDescriptionWeb':
        '즐겨찾기, 육성 계획, 아이템 보유 수량은 이 브라우저에 저장됩니다. 다른 기기나 브라우저로 옮기려면 user_data.json으로 내보내고 가져오세요.',
    'rd.settings.diagnosticsDescriptionWeb':
        '웹 버전은 로그 파일 없이 브라우저 개발자 도구의 콘솔에 기록합니다.',
    'rd.settings.aboutTitle': '정보',
    'rd.settings.aboutDescription': 'ArknightsNexus 소개와 개인정보처리방침을 확인합니다.',
    'rd.settings.aboutPage': '소개',
    'rd.settings.privacyPage': '개인정보처리방침',
  },
  'cn': {
    'rd.settings.loading': '正在加载同步状态与诊断信息…',
    'rd.settings.syncing': '正在同步地区数据…',
    'rd.settings.diagnosticsBusy': '处理中…',
    'rd.settings.refreshTooltip': '刷新（执行同步）',
    'rd.settings.regionLabel': '地区 / 语言',
    'rd.settings.userDataDescriptionWeb':
        '收藏、养成计划与物品持有数量保存在此浏览器中。如需迁移到其他设备或浏览器，请导出并导入 user_data.json。',
    'rd.settings.diagnosticsDescriptionWeb': '网页版不生成日志文件，日志记录在浏览器开发者工具的控制台中。',
    'rd.settings.aboutTitle': '关于',
    'rd.settings.aboutDescription': '查看 ArknightsNexus 介绍与隐私政策。',
    'rd.settings.aboutPage': '介绍',
    'rd.settings.privacyPage': '隐私政策',
  },
  'jp': {
    'rd.settings.loading': '同期状態と診断情報を読み込み中…',
    'rd.settings.syncing': '地域データを同期中…',
    'rd.settings.diagnosticsBusy': '処理中…',
    'rd.settings.refreshTooltip': '更新（同期を実行）',
    'rd.settings.regionLabel': '地域 / 言語',
    'rd.settings.userDataDescriptionWeb':
        'お気に入り、育成計画、アイテム所持数はこのブラウザに保存されます。別の端末やブラウザへ移すには user_data.json をエクスポートしてインポートしてください。',
    'rd.settings.diagnosticsDescriptionWeb':
        'Web 版はログファイルを作らず、ブラウザの開発者ツールのコンソールに記録します。',
    'rd.settings.aboutTitle': '情報',
    'rd.settings.aboutDescription': 'ArknightsNexus の紹介とプライバシーポリシーを確認します。',
    'rd.settings.aboutPage': '紹介',
    'rd.settings.privacyPage': 'プライバシーポリシー',
  },
  'tw': {
    'rd.settings.loading': '正在載入同步狀態與診斷資訊…',
    'rd.settings.syncing': '正在同步地區資料…',
    'rd.settings.diagnosticsBusy': '處理中…',
    'rd.settings.refreshTooltip': '重新整理（執行同步）',
    'rd.settings.regionLabel': '地區 / 語言',
    'rd.settings.userDataDescriptionWeb':
        '收藏、養成計畫與物品持有數量儲存在此瀏覽器中。如需移至其他裝置或瀏覽器，請匯出並匯入 user_data.json。',
    'rd.settings.diagnosticsDescriptionWeb': '網頁版不產生日誌檔案，日誌記錄在瀏覽器開發者工具的主控台中。',
    'rd.settings.aboutTitle': '關於',
    'rd.settings.aboutDescription': '查看 ArknightsNexus 介紹與隱私權政策。',
    'rd.settings.aboutPage': '介紹',
    'rd.settings.privacyPage': '隱私權政策',
  },
  'en': {
    'rd.settings.loading': 'Loading sync status and diagnostics…',
    'rd.settings.syncing': 'Syncing region data…',
    'rd.settings.diagnosticsBusy': 'Working…',
    'rd.settings.refreshTooltip': 'Refresh (run sync)',
    'rd.settings.regionLabel': 'Region / Locale',
    'rd.settings.userDataDescriptionWeb':
        'Favorites, plans and owned item counts are stored in this browser. To move them to another device or browser, export and import user_data.json.',
    'rd.settings.diagnosticsDescriptionWeb':
        'The web version keeps no log file; it logs to the browser developer tools console.',
    'rd.settings.aboutTitle': 'About',
    'rd.settings.aboutDescription':
        'About ArknightsNexus and its privacy policy.',
    'rd.settings.aboutPage': 'About',
    'rd.settings.privacyPage': 'Privacy Policy',
  },
};
