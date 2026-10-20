# Android 主頁與背景收件（2026-10-09）

- Android 主頁直接提供私訊入口及未讀徽章；App 更新只保留設定中的更新頁，不在主頁選單或開啟 App 時另彈更新頁。Windows 外框保持原樣。
- Android 不顯示 App 內通知島、通知列或通知 toast。忠誠點數、開台和私訊沿用 `TwitchSystemNotificationService` 系統通知及原點擊導覽。
- 設定 → 帳號 → 通知與背景收件，新增預設關閉的「背景收件」。使用 `flutter_background` 1.3.1 保持既有 isolate 與同一條 EventSub 收件連線，不新增 OAuth/token 或 GQL、IRC 協議。
- 新增一般偏好鍵 `vioclass_android_background_receiving_v1`，僅保存開關。手動啟用才允許套件請求電池最佳化豁免；恢復已保存設定只在已登入、App 前景且權限已存在時啟動，不偷偷彈授權視窗。
- 常駐系統通知「VioClass 背景收件」會占用 ID 1；一般系統通知從 ID 1000 起，避免覆蓋。關閉或登出停止服務；登出保留使用者偏好，再登入可恢復。
- Android Manifest 宣告 foreground service、specialUse subtype、wake lock 與電池豁免權限。沒有 mediaPlayback 權限、沒有改播放器。關閉 Wi-Fi lock；前景服務仍使用 CPU partial wake lock，會增加耗電。
- `stopWithTask=true`，移除 App 工作時停止服務。強制停止、系统回收、網路斷線、省電政策或 Twitch 授權失效仍可能中斷；不保證離線或殺程序後即时收件，不設開機自啟、不新增伺服器推播。
- `specialUse` 用於使用者明確啟用的持續 Twitch 收件。未來若上架 Google Play，需要按當時政策申報／審查服務與電池豁免用途，不能把 GitHub 側載可用當作商店審核通過。

## 手機驗收

1. 主頁只有私訊按鈕，更新在設定；沒有 App 內通知島。
2. 未登入開關不啟用；拒絕背景權限不假裝啟用。
3. 登入並開啟後，確認常駐通知，鎖屏／切出 App 後由另一帳號發私訊並開台，核對系統通知與開啟對話。
4. 關閉開關及登出時常駐通知消失；重開 App／再登入只按已保存偏好與已有權限恢復。
5. 從最近工作移除／強制停止後不自啟；重新開啟私訊會使用既有官方同步補齊。

來源：Android foreground services https://developer.android.com/develop/background-work/services/fgs ，套件來源 https://github.com/JulianAssmann/flutter_background 。本機沒有 Android 裝置，實際鎖屏收件仍需手機驗收。
