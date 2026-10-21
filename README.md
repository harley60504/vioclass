# VioClass

**Watch Twitch, rewind live streams, and keep chatting — on Windows and Android.**

**在 Windows 與 Android 看 Twitch、回看直播、持續聊天。**

An unofficial Twitch client built with Flutter, bringing live streams, DVR, VODs, clips, chat, and channel browsing into one app.

以 Flutter 開發的非官方 Twitch 用戶端，將直播、DVR 回看、VOD、剪輯、聊天室與頻道瀏覽整合在同一個 App。

**[Download / 下載最新版](https://github.com/harley60504/vioclass/releases/latest)** · [繁體中文](#繁體中文) · [English](#english) · [Report a problem / 回報問題](https://github.com/harley60504/vioclass/issues)

## 繁體中文

### 這是什麼？

VioClass 是給 Twitch 觀眾使用的 Windows／Android App。你可以看直播、往回看錯過的片段、參與聊天，也能用迷你播放器邊看邊逛頻道，不必一直切回瀏覽器。

### 主要功能

- **直播與回看**：切換畫質、拖曳時間軸，以及在來源支援時使用 DVR 回看直播。
- **VOD 與剪輯**：在 App 內播放過往影片與剪輯，搭配 VOD 聊天重播。
- **聊天室互動**：貼圖、回覆串、使用者資料、置頂留言、預測下注、忠誠列車與頻道點數。
- **私訊**：查看對話與歷史訊息，輸入貼圖時直接預覽圖案，長按訊息複製。
- **追隨與探索**：追隨直播、瀏覽與搜尋，以及實況主介紹、影片和剪輯頁面。
- **迷你播放器**：App 內迷你播放，Android 另支援子母畫面。
- **Drops 與點數**：查看活動、庫存、進度與領取狀態。
- **開台與私訊提醒**：Android 支援背景通知；Windows 使用 App 內通知。

### 下載與開始使用

前往 **[最新版下載頁](https://github.com/harley60504/vioclass/releases/latest)**，在 **Assets** 選擇適合的檔案：

| 平台 | 下載檔案 | 使用方式 |
| --- | --- | --- |
| Windows | `VioClass-版本-windows.zip` | 解壓縮整個資料夾後執行 `vioclass.exe`，請勿只移出執行檔。 |
| Android 手機／平板 | `VioClass-版本.apk` | 在裝置上安裝 APK；系統可能要求允許此來源安裝應用程式。 |

可先以訪客模式瀏覽、觀看公開內容；登入 Twitch 後可使用個人追隨、發言及其他需要帳號的互動功能。個別內容與功能仍取決於頻道及 Twitch 的存取限制。

### 使用須知

- **DVR 不是每個頻道都有**：可回看範圍取決於來源提供的直播片段與是否開放直播存檔，不保證固定秒數或完整回看。
- **Android 背景通知受系統限制**：需開啟相關功能並允許通知／背景執行。省電設定可能延遲通知；強制停止 App 後不能保證繼續收件。
- **Windows 最小化不會跳出桌面通知**：目前提醒顯示在 App 內，並非 Windows 系統通知。
- 本專案仍持續開發。若遇到問題，請在 [Issues](https://github.com/harley60504/vioclass/issues) 提供 App 版本、裝置及重現步驟；請勿貼上 token、Cookie 或私人訊息。

## English

### What is VioClass?

VioClass is a Windows and Android app for Twitch viewers. Watch live streams, rewind missed moments when available, join chat, and browse channels while keeping a mini player open — without constantly switching back to a browser.

### Features

- **Live playback and rewind**: quality selection, a seekable timeline, and live DVR when supported by the source.
- **VODs and clips**: play past broadcasts and clips inside the app, with VOD chat replay.
- **Chat interactions**: emotes, reply threads, user profiles, pinned messages, predictions, Hype Trains, and channel points.
- **Whispers**: conversations and message history, inline emote previews while typing, and long-press to copy.
- **Following and discovery**: followed streams, browsing, search, and channel About, Videos, and Clips pages.
- **Mini player**: an in-app mini player plus Picture-in-Picture on Android.
- **Drops and points**: campaigns, inventory, progress, and claim status.
- **Live and whisper alerts**: background notifications on Android; in-app notifications on Windows.

### Download and get started

Open the **[latest release](https://github.com/harley60504/vioclass/releases/latest)** and choose a file under **Assets**:

| Platform | Download | Getting started |
| --- | --- | --- |
| Windows | `VioClass-version-windows.zip` | Extract the entire folder and run `vioclass.exe`. Keep the accompanying files together. |
| Android phones / tablets | `VioClass-version.apk` | Install the APK on your device. Android may ask you to allow installation from that source. |

Try guest mode to browse and watch public content. Sign in with Twitch for your followed channels, sending chat messages, and other account-based interactions. Content availability and individual features remain subject to channel settings and Twitch access restrictions.

### Things to know

- **DVR availability varies**: rewind depends on available live segments and whether the channel exposes an active archive. A fixed rewind window or full-stream DVR is not guaranteed.
- **Android background delivery depends on the OS**: enable the relevant features and allow notification/background permissions. Battery restrictions can delay delivery; force-stopping the app can prevent background reception.
- **Windows alerts are in-app only**: they do not appear as desktop notifications while the window is minimized.
- This project is under active development. Report problems in [Issues](https://github.com/harley60504/vioclass/issues) with the app version, device, and reproduction steps. Never include tokens, cookies, or private messages.

## Development / 開發

Install a Flutter SDK compatible with this project's `pubspec.yaml`, then run:

```bash
flutter pub get
flutter run -d windows
```

Checks and builds:

```bash
flutter analyze
flutter build windows --release
flutter build apk --release
```

The repository's release workflow builds the Windows ZIP and signed Android APK. Android release signing requires your own signing configuration.

## Disclaimer / 聲明

VioClass is an independent, unofficial project and is not affiliated with or endorsed by Twitch. Twitch names and trademarks belong to their respective owners.

VioClass 是獨立開發的非官方專案，與 Twitch 無隸屬或官方背書關係。Twitch 名稱與商標屬於其各自權利人。
