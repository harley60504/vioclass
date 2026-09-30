# Beta 版本發布

VioClass 的 GitHub Actions 發布流程可建立 Android APK 與 Windows ZIP。手動執行時，`channel` 預設為 `beta`；Beta 會建立 GitHub prerelease，正式版則選 `stable`。

## 第一次設定

GitHub repository 的 Actions secrets 必須包含：

- `ANDROID_KEYSTORE_BASE64`：固定 Android release keystore 的 Base64 內容。
- `ANDROID_KEYSTORE_PASSWORD`：keystore 密碼。
- `ANDROID_KEY_PASSWORD`：`vioclass-release` alias 的 key 密碼。

同一台手機要直接覆蓋更新，之後每次建置都必須沿用同一份 keystore，而且新版本號必須高於手機上的版本。

## 發布 Beta

1. 到 GitHub repository 的 **Actions**。
2. 選擇 **Build and Release**，按 **Run workflow**。
3. 從 `main` 執行，輸入比目前版本更高的 `X.Y.Z`。
4. `channel` 選 `beta`，需要時填寫 notes。

完成後會建立 `vX.Y.Z-beta` prerelease，並附上：

- `VioClass-X.Y.Z.apk`
- `VioClass-X.Y.Z-windows.zip`

第一次需從 GitHub Releases 手動安裝 Beta APK。之後 Beta App 的設定頁更新檢查會同時看到較新的 Beta 或正式版；正式版 App 仍只會看到正式版。

每次 Beta 都要使用新的 `X.Y.Z`，不要用相同版本重建來測試手機覆蓋更新。
