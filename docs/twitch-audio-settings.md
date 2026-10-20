# 播放器音效（2026-10-09）

入口：設定 → 播放器 → 音效。Windows 使用完整 mpv 音效濾鏡，
不新增控制列按鈕，不更動登入、音量與靜音儲存，不重新開啟媒體。

預設關閉；增益 0～6 dB，五段 EQ 為 125 / 500 / 1000 / 4000 / 8000 Hz，
各 -6～6 dB。Windows 可開柔和壓縮、EQ、增益；處理最後加峰值限制。
Android 未啟用濾鏡，僅原生增益，過大可能破音。兩者皆不能保證聽力安全。

依據 [mpv audio filters](https://mpv.io/manual/stable/#audio-filters) 與
[FFmpeg filters](https://ffmpeg.org/ffmpeg-filters.html)：
Windows 處理鏈為 `equalizer` → `acompressor` → `volume` → `alimiter`。
舊 2023 bundle 未編入 `volume` / `acompressor` / `alimiter`，也缺少 `aresample`。
已換固定的完整 LGPL x86_64 基線建置；不換 Dart fork 或 ANGLE。

建置入口：`windows/vioclass_mpv_audio.cmake`，2026-10-09-fd9265a905。
Archive SHA256：9847d016c1d9704cb550b691eb69ce58500e8531256b0aa01427f4d1629ea3da。
DLL SHA256：48276397da952e9c5e8ca8423dd17dfa05e1ad7b2011fa0c5a9038a96838c4d7。
[來源、建置腳本](https://github.com/zhongfly/mpv-winbuild)
與 [固定 release](https://github.com/zhongfly/mpv-winbuild/releases/tag/2026-10-09-fd9265a905)。
CMake 對 archive 與 DLL 都校驗，取代 bundle 中原 libmpv-2.dll，不修改 Pub 快取。
不是浮動 latest，也不是本機手動塞 DLL。GitHub Windows build 同樣走此入口。
正式發佈前須帶上原生元件授權資訊與可取得對應源碼的說明。

Android 降級增益使用 `volume = 基礎音量 × 10^(dB/20)`，上限設定為 200%。
基礎音量仍為原來的 0～100%；靜音基礎值 0 放大後仍為 0。
原生屬性寫入後讀回核對，關閉音效即還原基礎音量與 100% 上限。

## 保存與失敗處理

- 獨立 SharedPreferences JSON key：`twitch_player_audio_v1`，schema version 1。
- 有限數值、上下界、五段固定長度驗證；無效資料回原音。
- 滑桿放開才提交；操作序列化，原生提交後保存。冷啟動或播放器重建重套。
- 原音 / 全中性設定不寫入原生屬性。
- Windows 確認 runtime commit 後用 `af`；增益在 limiter 前，原生基礎音量不再額外放大。
- Android `supportsFilters=false`，只提供原生增益，不假裝有峰值保護。
- 原生同步例外或音效 filter error 日誌：清除音效並保存關閉狀態，顯示簡短提示。
- `setProperty` 是非同步原生提交：無錯誤日誌不等於已驗證實際音質。
  不宣稱能預先枚舉所有裝置的 FFmpeg filter 支援。需實機試聽。

## 驗證

自動測試 `docs/twitch_audio_settings_test.dart`：原音無寫入、處理順序、
數值及 schema、防資料改寫、序列提交、重建還原、同步及非同步錯誤回復、
缺少 FFmpeg 濾鏡時仍可套用增益、完整套件增益位於 limiter 前，共 10 項。

`docs/twitch_audio_mpv_probe.dart` 是獨立 Flutter 原生驗證入口；
使用暫存 WAV 與 `ao=null` / `ao=pcm`，不讀登入資料、不播放聲音。
測試 +3 / +6 dB、50% 基礎音量、靜音、關閉還原；核對 native volume、
確有播放進度及無 error 日誌，另外逐項與組合驗證濾鏡。
實際 PCM：原音 RMS 0.0345219，+3 dB RMS 0.0487330，比值 1.41165；
高振幅 +6 dB 峰值 0.949999988，未超過 0.95 上限。
暫存檔只刪此測試自己產生的檔案。
這不是主 App 入口。驗證後重新啟動 `lib/main.dart`。

手動（Windows 與 Android 分別測試）：

1. 低音量開始，開音效、增益 +3 dB，確認聲音提高且畫面不中斷。
2. Windows 調低音 / 高音，開防突然大聲試聽；Android 這些控制应停用。
3. 靜音仍完全無聲；取消靜音不改原本音量百分比。
4. 關閉音效應立即原音；重設全部歸零且關閉。
5. 切台 / VOD / 小窗、重開 App 設定仍在；不影響影片速度或登入。
6. 裝置不支援時查看是否還原原音，不能把「UI 設定保存」當成 DSP 有效。

VOD 倍速、截圖、同步偏移及即時頻譜視覺化尚未加入，本輪限音效。
