import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../settings/twitch_app_language_controller.dart';

class VioClassLocalizations {
  final Locale locale;

  const VioClassLocalizations(this.locale);

  static const LocalizationsDelegate<VioClassLocalizations> delegate =
      _VioClassLocalizationsDelegate();

  static VioClassLocalizations of(BuildContext context) {
    return Localizations.of<VioClassLocalizations>(
          context,
          VioClassLocalizations,
        ) ??
        const VioClassLocalizations(Locale('zh', 'TW'));
  }

  bool get isEnglish => locale.languageCode == 'en';

  String t(String text) {
    if (!isEnglish) return text;
    return _englishText[text] ?? text;
  }

  String get settingsTitle => isEnglish ? 'Settings' : '設定';
  String get settingsSubtitle =>
      isEnglish ? 'Chat and player preferences' : '聊天室與播放器偏好';
  String get accountTab => isEnglish ? 'Account' : '帳號';
  String get accountTabDescription => isEnglish ? 'Login and account' : '登入與帳號';
  String get chatTab => isEnglish ? 'Chat' : '聊天';
  String get chatTabDescription => isEnglish ? 'Chat display' : '聊天室顯示';
  String get playerTab => isEnglish ? 'Player' : '播放器';
  String get playerTabDescription => isEnglish ? 'Playback defaults' : '播放預設';
  String get appearanceTab => isEnglish ? 'Appearance' : '外觀';
  String get appearanceTabDescription =>
      isEnglish ? 'Fonts and language' : '字體與語言';
  String get updatesTab => isEnglish ? 'Updates' : '更新';
  String get updatesTabDescription => isEnglish ? 'Version checks' : '版本檢查';
  String get appFontTitle => isEnglish ? 'App font' : 'App 字體';
  String get appFontSubtitle => isEnglish
      ? 'Windows and Android use the same selection'
      : 'Windows 和 Android 會套用同一個選擇';
  String get importingFont => isEnglish ? 'Importing' : '匯入中';
  String get importFont => isEnglish ? 'Import font' : '匯入字體';
  String get fontPreview => isEnglish
      ? 'Preview: chat text, titles, and buttons use this font together.'
      : '預覽：聊天室中文字體、標題和按鈕會一起套用。';
  String get builtInFontDescription => isEnglish
      ? 'Built-in Noto Sans TC for consistent cross-platform text'
      : '內建 Noto Sans TC，跨平台一致';
  String get systemFontDescription =>
      isEnglish ? 'Use the device default font' : '使用裝置預設字體';
  String get customFontDescription =>
      isEnglish ? 'Custom imported font' : '自訂匯入字體';
  String get removeFontTooltip => isEnglish ? 'Remove font' : '移除字體';
  String get appLanguageTitle => isEnglish ? 'App language' : 'App 語言';
  String get appLanguageSubtitle => isEnglish
      ? 'Choose a language or follow the system setting'
      : '可手動選擇，也可以跟隨系統語言';
  String get appLanguageSystemDescription => isEnglish
      ? 'Use the language selected by Windows or Android'
      : '使用 Windows 或 Android 目前的系統語言';
  String get appLanguageTraditionalChineseDescription =>
      isEnglish ? 'Use Traditional Chinese in VioClass' : 'VioClass 固定使用繁體中文';
  String get appLanguageEnglishDescription =>
      isEnglish ? 'Use English in VioClass' : 'VioClass 固定使用英文';
  String get updateTitle => isEnglish ? 'VioClass Updates' : 'VioClass 更新';
  String get updateStartupSubtitle =>
      isEnglish ? 'A new version is ready to install' : '有新版本可以安裝';
  String get updateSubtitle =>
      isEnglish ? 'Check and install updates' : '檢查與安裝更新';

  String languageModeLabel(TwitchAppLanguageMode mode) {
    return switch (mode) {
      TwitchAppLanguageMode.system => isEnglish ? 'Follow system' : '跟隨系統',
      TwitchAppLanguageMode.zhTw => isEnglish ? 'Traditional Chinese' : '繁體中文',
      TwitchAppLanguageMode.en => 'English',
    };
  }

  String languageModeDescription(TwitchAppLanguageMode mode) {
    return switch (mode) {
      TwitchAppLanguageMode.system => appLanguageSystemDescription,
      TwitchAppLanguageMode.zhTw => appLanguageTraditionalChineseDescription,
      TwitchAppLanguageMode.en => appLanguageEnglishDescription,
    };
  }
}

const Map<String, String> _englishText = <String, String>{
  'Twitch': 'Twitch',
  '追隨': 'Following',
  '瀏覽': 'Browse',
  '檢查中': 'Checking',
  '搜尋直播、遊戲或實況主': 'Search streams, games, or streamers',
  '清除搜尋': 'Clear search',
  '遊戲分類': 'Game categories',
  '語言篩選': 'Language filter',
  '重新整理': 'Refresh',
  'Drops 連接': 'Drops connection',
  '載入更多失敗，重試': 'Load more failed. Retry',
  '載入更多': 'Load more',
  '已經到底了': 'You are all caught up',
  '未登入': 'Not signed in',
  '未登入 Twitch': 'Not signed in to Twitch',
  '檢查登入狀態...': 'Checking sign-in status...',
  '已登入': 'Signed in',
  '完整登入': 'Fully signed in',
  '已登入，但權限不完整': 'Signed in, but permissions are incomplete',
  'Token 已保存': 'Token saved',
  '登入狀態待驗證': 'Sign-in status needs verification',
  '登入狀態讀取失敗': 'Failed to read sign-in status',
  '已登出': 'Signed out',
  '探索直播': 'Browse streams',
  '輸入標籤篩選': 'Filter by tag',
  '加入標籤': 'Add tag',
  '清除標籤': 'Clear tags',
  '目前已載入分類中找不到結果': 'No results in the loaded category',
  '全部語言': 'All languages',
  '搜尋語言或代碼，例如 zh / en / ja': 'Search language or code, such as zh / en / ja',
  '關閉': 'Close',
  '需要先完成 Twitch 登入授權，才能讀取探索直播。':
      'Sign in to Twitch before loading browse streams.',
  '探索直播讀取失敗': 'Failed to load browse streams',
  '探索直播暫時讀取失敗，稍後再試或重新整理。':
      'Browse streams could not be loaded. Try again later or refresh.',
  '目前沒有可顯示直播': 'No streams to show',
  '可以清除分類、語言或標籤篩選後重新整理。':
      'Clear category, language, or tag filters and refresh.',
  '找不到符合條件的頻道': 'No matching channels',
  '已載入的直播沒有結果，Twitch 頻道搜尋暫時失敗。':
      'No loaded streams matched, and Twitch channel search failed.',
  '可以清除搜尋文字、分類、語言或標籤篩選。':
      'Clear search text, category, language, or tag filters.',
  '正在搜尋更多頻道...': 'Searching more channels...',
  '搜尋到的直播': 'Live search results',
  '搜尋到的未開台頻道': 'Offline channel results',
  '追隨直播': 'Followed streams',
  '搜尋到的 VOD': 'VOD search results',
  '搜尋到的片段': 'Clip search results',
  '目前沒有追隨中的直播': 'No followed channels are live',
  '目前追隨頻道沒有直播': 'No followed channels are live',
  '直播清單為空，離線追隨頻道也暫時讀取失敗。':
      'The live list is empty, and offline followed channels could not be loaded.',
  '稍後重新整理，或切到瀏覽頁探索其他直播。':
      'Refresh later, or switch to Browse to find other streams.',
  '已載入的追隨清單沒有結果，Twitch 頻道搜尋暫時失敗。':
      'No loaded followed channels matched, and Twitch channel search failed.',
  '可以清除搜尋文字、遊戲分類或語言篩選。':
      'Clear search text, game category, or language filter.',
  '需要先完成 Twitch 登入授權，才能讀取追隨直播。':
      'Sign in to Twitch before loading followed streams.',
  '追隨直播暫時讀取失敗，稍後再試或重新整理。':
      'Followed streams could not be loaded. Try again later or refresh.',
  '追隨頁讀取失敗': 'Failed to load following',
  '追隨直播讀取失敗': 'Failed to load followed streams',
  '登入後可以查看追隨中的直播。': 'Sign in to see followed live streams.',
  '追隨中的直播': 'Followed streams',
  '未開台追隨頻道': 'Offline followed channels',
  '正在整理未開台的追隨頻道...': 'Organizing offline followed channels...',
  '目前追隨直播中找不到這個分類': 'This category was not found in followed live streams',
  '需要登入 Twitch': 'Twitch sign-in required',
  '重新檢查': 'Check again',
  '用 WebView 登入': 'Sign in with WebView',
  '追隨頁需要 OAuth token。請先完成 Twitch 登入。':
      'The Following page needs an OAuth token. Please sign in to Twitch first.',
  '設定': 'Settings',
  '全部分類': 'All categories',
  '搜尋遊戲分類': 'Search game categories',
  '目前找不到這個分類': 'This category was not found',
  '繼續載入更多分類再搜尋': 'Load more categories and keep searching',
  '載入分類失敗，重試': 'Failed to load categories. Retry',
  '載入更多分類': 'Load more categories',
  '分類已經到底了': 'No more categories',
  '目前未開台，點擊後會先播放最新 VOD；沒有 VOD 則顯示關台圖。':
      'Currently offline. Opening this will play the latest VOD first; if there is no VOD, the offline screen is shown.',
  '觀看': 'Watch',
  '媒體庫': 'Library',
  '暫停': 'Pause',
  '播放': 'Play',
  '取消靜音': 'Unmute',
  '靜音': 'Mute',
  '隱藏聊天室': 'Hide chat',
  '顯示聊天室': 'Show chat',
  '離開全螢幕': 'Exit fullscreen',
  '全螢幕': 'Fullscreen',
  '播放進度': 'Playback progress',
  '打開播放進度': 'Open playback progress',
  '返回': 'Back',
  '回主畫面': 'Home',
  '取消追隨': 'Unfollow',
  '訂閱': 'Subscribe',
  '關於 / VOD': 'About / VOD',
  '建立片段': 'Create clip',
  '隱藏置頂留言': 'Hide pinned message',
  '顯示置頂留言': 'Show pinned message',
  '隱藏賭盤通知': 'Hide prediction',
  '顯示賭盤通知': 'Show prediction',
  '沒有賭盤': 'No prediction',
  '直播': 'Live',
  '離線': 'Offline',
  '聊天室訊息送出失敗': 'Failed to send chat message',
  '輸入聊天室訊息...': 'Send a message...',
  '送出': 'Send',
  '畫質': 'Quality',
  '畫質：': 'Quality: ',
  '尚未載入畫質清單': 'Quality list has not loaded yet',
  '尚未取得畫質': 'Quality is not available yet',
  '自動 / 原始': 'Auto / Source',
  '自動': 'Auto',
  '高畫質': 'High quality',
  '中畫質': 'Medium quality',
  '低畫質': 'Low quality',
  '音訊': 'Audio',
  '其他': 'Other',
  '純音訊': 'Audio only',
  '尚未載入直播': 'Stream has not loaded yet',
  '播放器暫時無法載入，請稍後再試。': 'The player could not load. Please try again later.',
  '播放器預覽': 'Player preview',
  '位觀眾': 'viewers',
  '目前裝置不支援系統子母畫面': 'System picture-in-picture is not supported on this device',
  '系統子母畫面': 'System picture-in-picture',
  '緩衝中': 'Buffering',
  '直播最新': 'Live edge',
  '播放中': 'Playing',
  '已暫停': 'Paused',
  '搜尋': 'Search',
  '直播小窗': 'Mini player',
  '子母畫面': 'Picture-in-picture',
  '目前裝置不支援子母畫面': 'Picture-in-picture is not supported on this device',
  '片段': 'Clip',
  '關於': 'About',
  '關於圖片讀取失敗': 'Failed to load about panels',
  '這個頻道目前沒有關於圖片面板。': 'This channel does not have any about panels yet.',
  '關於面板': 'About panels',
  '社群連結': 'Social links',
  '開啟連結': 'Open link',
  '清空搜尋': 'Clear search',
  '片段讀取失敗': 'Failed to load clips',
  '片段暫時讀取失敗，稍後再試或重新整理。':
      'Clips could not be loaded. Try again later or refresh.',
  '重試': 'Retry',
  '目前沒有片段': 'No clips',
  '這個頻道沒有可顯示的精華片段。': 'This channel has no clips to show.',
  '搜尋片段': 'Search clips',
  '找不到符合的片段': 'No matching clips',
  '可以換個關鍵字，或清空搜尋回到全部片段。':
      'Try another keyword, or clear search to show all clips.',
  '載入中': 'Loading',
  '已顯示目前可讀取的片段': 'All currently available clips are shown',
  '未命名片段': 'Untitled clip',
  '已建立片段': 'Clip created',
  '由': 'Created by',
  '建立片段-meta': 'created clip',
  'VOD 讀取失敗': 'Failed to load VODs',
  'VOD 暫時讀取失敗，稍後再試或重新整理。':
      'VODs could not be loaded. Try again later or refresh.',
  '目前沒有 VOD': 'No VODs',
  '這個頻道沒有可顯示的過去直播。': 'This channel has no past broadcasts to show.',
  '搜尋 VOD': 'Search VODs',
  '找不到符合的 VOD': 'No matching VODs',
  '可以換個關鍵字，或清空搜尋回到全部 VOD。':
      'Try another keyword, or clear search to show all VODs.',
  '已顯示目前可讀取的 VOD': 'All currently available VODs are shown',
  '未命名 VOD': 'Untitled VOD',
  '直播存檔中': 'Live archive',
  '目前直播中，點擊會進直播觀看頁': 'Currently live. Click to open the live watch page',
  '次觀看': 'views',
  'Twitch 帳號': 'Twitch account',
  '登入狀態與權限檢查': 'Sign-in status and permissions',
  '完整登入 / 修復登入': 'Full sign-in / repair sign-in',
  '登出': 'Sign out',
  '聊天室字體': 'Chat font',
  '直播聊天室與 VOD 聊天回放共用': 'Used by live chat and VOD chat replay',
  '重設': 'Reset',
  '顯示訊息時間': 'Show message timestamps',
  '在每則聊天室訊息前顯示發送時間': 'Show the sent time before each chat message',
  '自動載入連結預覽': 'Auto-load link previews',
  '只會自動載入內建可信網域和你加入的網域':
      'Only built-in trusted domains and domains you add are auto-loaded',
  '新增可信網域，例如 example.com': 'Add trusted domain, e.g. example.com',
  '加入': 'Add',
  '播放預設': 'Playback defaults',
  '下一次進入直播或 VOD 頁面時套用': 'Applied the next time you open a live stream or VOD',
  '預設音量': 'Default volume',
  '開始時靜音': 'Mute on start',
  '播放器會保留音量值，但進頁面時先以靜音套用':
      'The player keeps the volume value, but starts muted when opening a page',
  '預設顯示聊天室': 'Show chat by default',
  '新開觀看頁時先顯示右側聊天欄': 'Show the right chat column when opening a watch page',
  '允許 Android 子母畫面': 'Allow Android picture-in-picture',
  '離開 App 或手動開啟時，才會進入系統子母畫面':
      'Enter system picture-in-picture only when leaving the app or opening it manually',
  '離開觀看頁保留小窗': 'Keep mini player when leaving watch',
  '從直播、VOD 或片段回主畫面時保留 App 內小窗':
      'Keep the in-app mini player when returning home from live, VOD, or clips',
  '正在檢查 GitHub 最新版本...': 'Checking the latest GitHub release...',
  '正在下載並準備更新...': 'Downloading and preparing update...',
  '更新檢查失敗，稍後再試。': 'Update check failed. Try again later.',
  '尚未檢查更新。': 'Updates have not been checked yet.',
  '找到新版': 'New version found',
  '目前已是最新版本。': 'You are on the latest version.',
  'App 更新': 'App updates',
  '讓 VioClass 維持在最新版': 'Keep VioClass up to date',
  '開啟 App 時檢查更新': 'Check for updates when opening the app',
  '有新版本時提醒你安裝': 'Notify you when a new version is ready',
  '稍後': 'Later',
  '立即檢查': 'Check now',
  '安裝中': 'Installing',
  '開啟下載頁': 'Open download page',
  '下載並安裝': 'Download and install',
  '目前版本': 'Current version',
  '最新版本': 'Latest version',
  '調整訊息文字與貼圖大小': 'Adjust message text and emote size',
  '回覆串': 'Reply thread',
  '依回覆關係顯示；提及標記不聚集': 'Grouped by reply relationship; mentions are not threaded',
  '已複製這則聊天室訊息': 'Copied this chat message',
  '上文': 'Previous',
  '目前': 'Current',
  '回覆': 'Reply',
  '提及': 'Mention',
  '點數餘額': 'Points balance',
  '獎勵清單': 'Rewards',
  '領取': 'Claim',
  '點': 'points',
  '點忠誠點數': 'loyalty points',
  '領取可用忠誠點數獎勵': 'Claim available loyalty points',
  '忠誠點數': 'Channel Points',
  '讀取點數與可兌換項目': 'Loading points and rewards',
  '可用': 'available',
  '目前無法兌換這個獎勵，請稍後再試。':
      'This reward cannot be redeemed right now. Please try again later.',
  'Channel Points emote menu 目前先暫時關閉。':
      'The Channel Points emote menu is temporarily unavailable.',
  '聊天室訊息': 'Chat message',
  '輸入要送出的訊息': 'Enter the message to send',
  '送出兌換': 'Redeem',
  '立即兌換': 'Redeem now',
  '兌換內容': 'Redeem content',
  '輸入兌換內容': 'Enter redeem content',
  '發燒列車': 'Hype Train',
  '等級': 'Level',
  '總計': 'Total',
  '進度': 'Progress',
  '開始': 'Started',
  '到期': 'Expires',
  '結束': 'Ended',
  '冷卻': 'Cooldown',
  '類型': 'Type',
  '共享列車': 'Shared train',
  '是': 'Yes',
  '否': 'No',
  '主要貢獻': 'Top contributions',
  '目前沒有貢獻資料': 'No contribution data yet',
  '共享列車參與者': 'Shared train participants',
  '目前沒有共享列車參與者': 'No shared train participants yet',
  '貼圖': 'Emotes',
  '最近 / 最愛 / Twitch / 7TV / BTTV / FFZ｜長按收藏':
      'Recent / Favorites / Twitch / 7TV / BTTV / FFZ | Long press to favorite',
  '最近': 'Recent',
  '最愛': 'Favorites',
  '頻道': 'Channel',
  '全域': 'Global',
  '已解鎖': 'Unlocked',
  '搜尋貼圖名稱': 'Search emotes',
  '正在載入貼圖...': 'Loading emotes...',
  '沒有可用貼圖': 'No emotes available',
  '長按取消收藏': 'Long press to remove favorite',
  '長按加入收藏': 'Long press to add favorite',
  '人': 'users',
  '此邊': 'this side',
  '已下注': 'Bet placed',
  '同步中': 'Syncing',
  '選項': 'Option',
  '勝出': 'Winner',
  '已鎖住': 'Locked',
  '我的': 'My',
  '賠率': 'odds',
  '這個賭盤目前不能下注': 'This prediction is not accepting bets',
  '只能繼續加注同一邊，另一邊已鎖住':
      'You can only add points to the same side; the other side is locked',
  '選擇下方選項送出下注': 'Choose an option below to place your bet',
  '賭盤預測': 'Prediction',
  '下注點數': 'Points to bet',
  '鎖盤剩': 'Locks in',
  '已鎖盤': 'Locked',
  '結算剩': 'Resolving in',
  '等待結算': 'Waiting for result',
  '結算': 'Resolved',
  '特殊訊息': 'Special messages',
  '連續觀看、續訂與聊天室身分': 'Watch streaks, resubs, and chat identity',
  '特殊訊息暫時載入失敗，稍後再試。':
      'Special messages could not be loaded. Please try again later.',
  '聊天室身分更新失敗，稍後再試。': 'Failed to update chat identity. Please try again later.',
  '可分享訊息': 'Shareable messages',
  '可以分享你的連續觀看訊息': 'You can share your watch streak message',
  '目前沒有可分享的連續觀看訊息': 'No watch streak message is available to share',
  '個月': 'months',
  '連續觀看': 'Watch streak',
  '續訂': 'Resub',
  '續訂訊息': 'Resub message',
  '目前沒有可分享的續訂訊息': 'No resub message is available to share',
  '連續': 'Streak',
  '本次': 'This time',
  '可以分享你的續訂訊息': 'You can share your resub message',
  '聊天室身分徽章': 'Chat identity badges',
  '目前沒有可切換的徽章': 'No badges available to switch',
  '系統提示': 'System notices',
  '點擊複製：': 'Click to copy: ',
  '已複製：': 'Copied: ',
  '切換到 VOD 聊天回放': 'Switch to VOD chat replay',
  '切換到直播聊天室': 'Switch to live chat',
  '正在讀取 VOD 聊天...': 'Loading VOD chat...',
  '等待影片時間軸上的聊天...': 'Waiting for chat on the video timeline...',
  'VOD 聊天暫時讀取失敗，稍後再試。': 'VOD chat could not be loaded. Please try again later.',
  '等待聊天室訊息...': 'Waiting for chat messages...',
  '進入直播後': 'after entering the stream',
  '則新訊息': 'new messages',
  '回到最新訊息': 'Back to latest messages',
  '已複製置頂留言': 'Copied pinned message',
  '置頂留言': 'Pinned message',
  '置頂': 'pinned',
  '點一下收合 · 長按複製': 'Tap to collapse · long press to copy',
  '貼圖載入中': 'Loading emotes',
  '有可領獎勵': 'reward available',
  '重新整理忠誠點數': 'Refresh Channel Points',
  '暫時讀取失敗，稍後再試。': 'could not be loaded. Please try again later.',
  '目前沒有可顯示的忠誠點數獎勵。': 'No Channel Points rewards to show.',
  '尚未載入忠誠點數資料。': 'Channel Points data has not loaded yet.',
  '請重新整理，或確認目前頻道是否有開放忠誠點數獎勵。':
      'Refresh, or check whether this channel has Channel Points rewards enabled.',
  '點數不足': 'Not enough points',
  '需要輸入': 'Input required',
  '需要訊息': 'Message required',
  '需要貼圖與效果': 'Emote and effect required',
  '需要貼圖': 'Emote required',
  '自訂': 'Custom',
  '內建': 'Built-in',
  '選擇修改效果': 'Choose an effect',
  '重新載入': 'Reload',
  '選擇貼圖': 'Choose emote',
  '正在讀取貼圖清單...': 'Loading emote list...',
  '貼圖清單暫時載入失敗，稍後再試。': 'Emote list could not be loaded. Please try again later.',
  '這個頻道目前沒有可修改的訂閱貼圖。':
      'This channel has no modifiable subscriber emotes right now.',
  '沒有符合搜尋條件的貼圖': 'No emotes match your search',
  '沒有符合的 Channel Points 貼圖': 'No matching Channel Points emotes',
  '這個貼圖沒有可用的修改效果。': 'This emote has no available effects.',
  '選擇': 'Choose',
  '黑白': 'Black and white',
  '水平翻轉': 'Horizontal flip',
  '壓縮': 'Squish',
  '太陽眼鏡': 'Sunglasses',
  '思考中': 'Thinking',
  '取消': 'Cancel',
  '訂閱頁暫時載入失敗，請稍後重試。':
      'The subscribe page could not be loaded. Please try again later.',
  '請先輸入片段標題。': 'Enter a clip title first.',
  '片段長度需介於 5 到 60 秒。': 'Clip length must be between 5 and 60 seconds.',
  '剪輯片段': 'Edit clip',
  '正在準備可剪輯片段...': 'Preparing clip editor...',
  '片段標題': 'Clip title',
  '建立中': 'Creating',
  '片段已建立': 'Clip created',
  '片段準備失敗。': 'Failed to prepare clip.',
  '請先補 Drops / Android 授權。':
      'Please complete Drops / Android authorization first.',
  '這個實況主可能沒有開放片段。': 'This streamer may not allow clips.',
  '片段剪輯暫時失敗，請稍後再試。': 'Clip editing failed. Please try again later.',
  '訂閱頁暫時無法開啟，請稍後再試。':
      'The subscribe page could not be opened. Please try again later.',
  '切換全螢幕失敗，請稍後再試。': 'Failed to toggle fullscreen. Please try again later.',
  'OAuth 暫時載入失敗，請稍後再試。': 'OAuth could not be loaded. Please try again later.',
  '觀看頁暫時載入失敗，請稍後再試。':
      'The watch page could not be loaded. Please try again later.',
  'VOD 載入失敗，沒有切回直播。': 'VOD failed to load, and live playback was not restored.',
  'VOD 暫時載入失敗，請稍後再試。': 'VOD could not be loaded. Please try again later.',
  '播放器暫時載入失敗，請稍後再試。': 'The player could not be loaded. Please try again later.',
  '片段暫時載入失敗，請稍後再試。': 'Clip could not be loaded. Please try again later.',
  '目前找不到可回看的直播 VOD。': 'No replayable live VOD was found.',
  'DVR 回放載入失敗。': 'DVR replay failed to load.',
  '目前找不到可用的 DVR 播放來源。': 'No available DVR playback source was found.',
  'VOD 畫質切換失敗，請稍後再試。': 'Failed to switch VOD quality. Please try again later.',
  '聊天室暫時連線失敗，稍後再試。': 'Chat connection failed. Please try again later.',
  '聊天身分暫時無法更新，請稍後再試。':
      'Chat identity could not be updated. Please try again later.',
  '已套用徽章': 'Badge applied',
  '位觀眾-card': 'viewers',
  '未命名直播': 'Untitled stream',
  '未分類': 'Uncategorized',
  '未知實況主': 'Unknown streamer',
  '大小': 'Size',
  '小': 'Small',
  '大': 'Large',
  '預覽': 'Preview',
  '這是聊天室訊息預覽': 'This is a chat message preview',
  '追隨頁、聊天室發言、官方貼圖與部分互動功能需要 OAuth token。':
      'Following, sending chat messages, official emotes, and some interactive features require an OAuth token.',
  '這個頻道目前沒有關於面板。': 'This channel does not have about panels yet.',
  '目前在直播最新位置': 'Already at live edge',
  '跳到直播最新位置': 'Jump to live edge',
  '目前未開台': 'Currently offline',
  '播放器已停用': 'Player is disabled',
  '連結': 'Link',
  '連結預覽': 'Link preview',
  '不自動載入的連結': 'Link not auto-loaded',
  '正在載入預覽': 'Loading preview',
  'Twitch 片段': 'Twitch clip',
  'YouTube 影片': 'YouTube video',
  '建立的片段': 'created clip',
  '複製': 'Copy',
  '開啟': 'Open',
  '網址格式不正確': 'Invalid URL',
  '無法開啟連結': 'Could not open link',
  '已複製連結': 'Link copied',
  '關盤': 'Locks in',
  '即將關盤': 'Locking soon',
  '發燒列車結束': 'Hype Train complete',
  '感謝大家的支援': 'Thanks for the support',
  '已選擇': 'Selected',
  '〔空訊息〕': '[empty message]',
  '獎勵': 'Reward',
  '首聊': 'First chat',
  '聊天室活動暫時讀取失敗，稍後再試。':
      'Chat activity could not be loaded. Please try again later.',
  '關閉通知': 'Dismiss notification',
  '發送': 'Send',
  '測試': 'Test',
  '高亮訊息': 'Highlighted message',
  '訂閱分享': 'Subscription share',
  '忠誠點數訊息': 'Channel Points message',
  '官方特殊訊息': 'Official special message',
  '分享連續觀看': 'Share watch streak',
  '送出訊息並分享連續觀看。': 'Send a message and share your watch streak.',
  '分享': 'Share',
  '分享訂閱訊息': 'Share resub message',
  '送出訊息並分享續訂訊息。': 'Send a message and share your resub.',
  '特殊訊息預覽': 'Special message preview',
  '預覽模式不會送出 Twitch 特殊訊息。':
      'Preview mode will not send a Twitch special message.',
  '在下方輸入欄輸入內容，按送出後兌換。': 'Enter text below, then send to redeem.',
  '已準備': 'Ready',
  '獎勵詳情': 'Reward details',
  '兌換完成': 'Redeemed',
  '已解鎖貼圖': 'Unlocked emote',
  '完成': 'Done',
  '說明': 'Description',
  '沒有說明': 'No description',
  '花費': 'Cost',
  '狀態': 'Status',
};

extension VioClassLocalizationsContext on BuildContext {
  VioClassLocalizations get vio => VioClassLocalizations.of(this);
}

class _VioClassLocalizationsDelegate
    extends LocalizationsDelegate<VioClassLocalizations> {
  const _VioClassLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'zh' || locale.languageCode == 'en';
  }

  @override
  Future<VioClassLocalizations> load(Locale locale) {
    final resolved = locale.languageCode == 'en'
        ? const Locale('en')
        : const Locale('zh', 'TW');
    return SynchronousFuture<VioClassLocalizations>(
      VioClassLocalizations(resolved),
    );
  }

  @override
  bool shouldReload(_VioClassLocalizationsDelegate old) => false;
}
