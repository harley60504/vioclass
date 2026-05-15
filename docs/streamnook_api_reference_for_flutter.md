# StreamNook API Reference（給 Flutter Twitch App 參考）

> 用途：整理 StreamNook 目前公開在 Tauri invoke handler 與相關服務裡的 API / command / event 名稱，方便之後在 Flutter 專案重現功能時對照。  
> 注意：這是「架構與 API 名稱參考」，不是直接搬程式碼。StreamNook repo root 我沒有確認到授權檔，因此不要直接複製原始碼。

---

## 0. 推薦移植策略

### 建議抄「架構」，不要照搬 legacy PubSub
StreamNook 的強項是把 Twitch 功能拆成：

```text
前端 UI
→ Tauri invoke command
→ Rust service
→ Twitch Helix / Twitch GQL / IRC / WebSocket event
```

Flutter 版建議對應成：

```text
Flutter Widget
→ Controller / Runtime
→ Feature API Service
→ Transport API Service
```

### Flutter 專案建議拆法

```text
lib/features/twitch/api/
├─ twitch_api_constants.dart
├─ twitch_gql_api_service.dart
├─ twitch_helix_api_service.dart
├─ twitch_hermes_api_service.dart
├─ twitch_irc_api_service.dart
├─ twitch_channel_points_api_service.dart
├─ twitch_prediction_api_service.dart
├─ twitch_pinned_chat_api_service.dart
├─ twitch_hype_train_api_service.dart
├─ twitch_watch_streak_api_service.dart
├─ twitch_drops_api_service.dart
├─ twitch_moderation_api_service.dart
└─ twitch_user_profile_api_service.dart
```

### 最穩資料流

```text
初始狀態：GQL / Helix snapshot
即時更新：Hermes / EventSub / IRC / WebSocket event
UI 顯示：只吃整理後的 model，不直接吃 raw JSON
補償策略：事件漏掉時用 polling 或手動 refresh
```

---

# 1. App / System Commands

```text
get_app_version
get_app_name
get_app_description
get_app_authors
get_window_size
calculate_aspect_ratio_size
calculate_aspect_ratio_size_preserve_video
get_system_info
start_analytics_dashboard
is_dev_environment
is_admin_user
check_dashboard_available
is_dashboard_running
auto_start_dashboard_for_admin
get_emoji_image
read_clipboard_text_native
```

用途：
- App metadata
- 視窗尺寸
- 系統資訊
- analytics dashboard
- emoji image helper
- native clipboard

---

# 2. Twitch Auth / Account Commands

```text
twitch_login
twitch_start_device_login
twitch_complete_device_login
twitch_logout
clear_webview_data
has_stored_credentials
verify_token_health
force_refresh_token
get_twitch_token
```

用途：
- Device code login
- 登出
- 清 WebView data
- token health check
- refresh token
- 取得目前 Twitch token

Flutter 對應：
```text
TwitchOAuthApiService
TwitchWebAuthTokenProvider
TwitchAuthService
```

---

# 3. Twitch Stream / Browse / Discovery Commands

```text
get_followed_streams
get_channel_info
get_user_info
get_recommended_streams
get_recommended_streams_paginated
open_browser_url
focus_window
get_top_games
get_top_games_paginated
get_streams_by_game
search_channels
search_categories
get_category_info
get_user_by_id
get_user_by_login
get_all_followed_channels
get_offline_last_broadcasts
check_stream_online
get_streams_by_game_name
get_clips_by_game
get_videos_by_game
get_user_videos
```

用途：
- 追隨直播
- 推薦直播
- 遊戲分類
- 搜尋頻道 / 分類
- 影片 / clip
- 開啟外部網址
- focus 視窗

Flutter 對應：
```text
TwitchHelixApiService
TwitchStreamApiService
TwitchUserApiService
```

---

# 4. Follow / Relationship Commands

```text
follow_channel
unfollow_channel
check_following_status
```

用途：
- 追隨 / 取消追隨
- 檢查追隨狀態

Flutter 對應：
```text
TwitchRelationshipApiService
```

---

# 5. Whisper Commands

```text
send_whisper
start_whisper_listener
get_whisper_history
search_whisper_user
import_all_whisper_history
load_whisper_storage
save_whisper_storage
save_whisper_conversation
append_whisper_message
delete_whisper_conversation
get_whisper_storage_path
migrate_whispers_from_localstorage
```

用途：
- Whisper 傳送
- Whisper EventSub listener
- whisper history
- whisper local storage

Flutter 對應：
```text
TwitchWhisperApiService
TwitchWhisperStorageService
```

---

# 6. Streaming / Playback Commands

```text
start_stream
stop_stream
get_stream_qualities
change_stream_quality
get_streamlink_diagnostics
is_streamlink_available
```

用途：
- Streamlink 啟動 / 停止
- 取得畫質
- 切畫質
- Streamlink diagnostics

Flutter 對應：
```text
TwitchPlaybackService
TwitchStreamlinkApiService
```

備註：
- 你的 Flutter 目前走 media_kit / Dart HLS proxy，這部分可以只參考概念。
- StreamNook 的 Streamlink 架構比較偏 Tauri desktop。

---

# 7. Multi-stream / Multi-nook Commands

```text
start_multi_nook
stop_multi_nook
stop_all_multi_nooks
get_active_multi_nooks
register_active_channel
unregister_active_channel
```

用途：
- 多開直播
- 註冊目前觀看的 channel
- 對 prediction event 過濾很重要

Flutter 對應：
```text
TwitchMultiStreamService
TwitchActiveChannelRegistry
```

---

# 8. Chat Core Commands

```text
start_chat
stop_chat
send_chat_message
join_chat_channel
leave_chat_channel
start_multi_chat
parse_historical_messages
update_chat_settings
clear_chat
```

用途：
- IRC chat connect / disconnect
- 發送訊息
- 加入 / 離開聊天室
- 多聊天室
- 歷史訊息 parse
- chat settings
- 清聊天室

Flutter 對應：
```text
TwitchIrcApiService
TwitchChatStreamService
TwitchChatSender
```

---

# 9. Chat Moderation Commands

```text
delete_chat_message
ban_user
unban_user
add_channel_moderator
remove_channel_moderator
add_channel_vip
remove_channel_vip
update_suspicious_user_status
update_user_chat_color
block_user
unblock_user
get_channel_moderators
get_channel_vips
get_chatters_by_role
send_chat_announcement
send_shoutout
start_commercial
start_raid
cancel_raid
create_stream_marker
warn_chat_user
update_shield_mode
```

用途：
- 刪訊息
- ban / timeout / unban
- mod / VIP 管理
- suspicious user
- chat color
- block / unblock
- moderators / VIPs / chatters
- announcement
- shoutout
- commercial
- raid
- stream marker
- warning
- shield mode

Flutter 對應：
```text
TwitchModerationApiService
TwitchChatActionService
```

---

# 10. Discord / Magne Presence Commands

```text
connect_discord
disconnect_discord
set_idle_discord_presence
update_discord_presence
clear_discord_presence

connect_magne
disconnect_magne
set_idle_magne_presence
update_magne_presence
clear_magne_presence
```

用途：
- Discord rich presence
- Magne presence

Flutter 版可選：
```text
TwitchPresenceIntegrationService
```

---

# 11. Settings / Update / Component Commands

```text
load_settings
save_settings
download_streamlink_installer
verify_streamlink_installation
get_installed_streamlink_version
get_latest_streamlink_version
get_installed_ttvlol_version
get_current_app_version
get_latest_app_version
download_and_install_app_update
get_latest_ttvlol_version
download_and_install_ttvlol_plugin
get_release_notes
send_test_notification
```

用途：
- app settings
- Streamlink installation
- ttvlol plugin version
- app update
- release notes
- test notification

Flutter 對應：
```text
TwitchSettingsService
TwitchUpdateService
TwitchComponentService
```

---

# 12. Badge Commands

```text
fetch_global_badges
get_cached_global_badges
prefetch_global_badges
force_refresh_global_badges
get_badge_cache_age
get_badges_missing_metadata
debug_list_twitch_badges
debug_compare_badge_sources
fetch_channel_badges
get_twitch_credentials
get_user_badges

get_user_badges_unified
get_user_badges_with_earned_unified
parse_badge_string
prefetch_global_badges_unified
prefetch_channel_badges_unified
prefetch_third_party_badges
clear_badge_cache_unified
clear_channel_badge_cache_unified
get_global_badge_collection
fetch_badge_metadata
```

用途：
- Twitch global badges
- channel badges
- user badges
- badge cache
- third-party badges
- unified badge service

Flutter 對應：
```text
TwitchBadgeApiService
TwitchBadgeCacheService
TwitchBadgeRenderCache
```

---

# 13. Cache Commands

```text
save_emote_by_id
load_emote_by_id
save_emotes_to_cache
load_emotes_from_cache
save_badges_to_cache
load_badges_from_cache
clear_cache
get_cache_statistics
save_favorite_emotes_cache
load_favorite_emotes_cache
add_favorite_emote_cache
remove_favorite_emote_cache
```

用途：
- emote cache
- badge cache
- favorite emotes
- cache statistics

Flutter 對應：
```text
TwitchCacheService
TwitchEmoteCacheService
TwitchFavoriteEmoteService
```

---

# 14. Universal Cache Commands

```text
get_universal_cached_item
save_universal_cached_item
sync_universal_cache_data
cleanup_universal_cache
clear_all_universal_cache
get_universal_cache_statistics
assign_badge_positions
export_manifest
download_and_cache_file
get_cached_file
get_cached_files
get_all_universal_cached_items
get_universal_cached_items_batch
auto_sync_universal_cache_if_stale
```

用途：
- 通用 cache
- manifest export
- 檔案下載與 cache
- batch cached items
- stale auto sync

Flutter 對應：
```text
TwitchUniversalCacheService
```

---

# 15. Cosmetics / Profile Cache Commands

```text
cache_user_cosmetics
get_cached_user_cosmetics
cache_third_party_badges
get_cached_third_party_badges
prefetch_user_cosmetics

get_user_profile
refresh_user_profile
clear_profile_cache
preload_badge_databases
get_user_profile_complete
clear_user_profile_cache
clear_user_profile_cache_for_user
```

用途：
- user cosmetics
- third-party badges
- user profile cache
- complete user profile aggregation

Flutter 對應：
```text
TwitchUserProfileApiService
TwitchCosmeticsCacheService
```

---

# 16. Drops Commands

```text
get_drops_settings
update_drops_settings
get_active_drop_campaigns
get_drops_inventory
get_drop_progress
claim_drop
check_channel_points
claim_channel_points
get_drops_statistics
get_claimed_drops
get_channel_points_history
get_channel_points_balance
get_all_channel_points_balances
start_drops_monitoring
stop_drops_monitoring
update_monitoring_channel
```

用途：
- drops campaigns
- drops inventory
- drops progress
- claim drop
- drops monitoring
- channel points balance/history

Flutter 對應：
```text
TwitchDropsApiService
TwitchDropsMonitorService
```

---

# 17. Mining Commands

```text
start_auto_mining
start_campaign_mining
get_eligible_channels_for_campaign
start_campaign_mining_with_channel
stop_auto_mining
get_mining_status
is_auto_mining
```

用途：
- 自動掛 drops
- campaign mining
- eligible channels
- mining status

Flutter 可選：
```text
TwitchDropsMiningService
```

---

# 18. Drops Authentication Commands

```text
start_drops_device_flow
poll_drops_token
drops_logout
is_drops_authenticated
validate_drops_token
open_drop_details
```

用途：
- drops 專用 device flow
- drops token polling
- drops auth validation

Flutter 對應：
```text
TwitchDropsAuthService
```

---

# 19. Prediction Commands

```text
place_prediction
get_active_prediction
get_channel_points_for_channel
```

用途：
- 下注 prediction
- 查目前 active prediction
- 查指定頻道的 channel points balance / icon / name

Flutter 對應：
```text
TwitchPredictionApiService
```

建議 model：
```text
TwitchPredictionSnapshot
TwitchPredictionOutcome
TwitchPredictionStatus
TwitchPredictionBetResult
```

建議流程：
```text
進聊天室 → get_active_prediction(channelLogin)
Hermes event → prediction-created / updated / locked / ended
下注 → place_prediction(eventId, outcomeId, points, channelId)
成功 → 本地扣點 + 延遲 refresh channel points
```

---

# 20. Watch Token Allocation Commands

```text
set_reserved_channel
get_reserved_channel
```

用途：
- 保留目前掛台 / 觀看 channel
- drops mining / prediction active channel 過濾可用

Flutter 對應：
```text
TwitchWatchTokenService
```

---

# 21. Channel Points Rewards Commands

```text
get_channel_rewards
redeem_channel_reward
send_highlighted_message
unlock_random_emote
get_modifiable_emotes
unlock_modified_emote
unlock_chosen_emote
```

用途：
- 取得 channel point rewards
- 兌換 reward
- 高亮訊息
- 解鎖 random emote
- 解鎖 modified emote
- 解鎖 chosen emote

Flutter 對應：
```text
TwitchChannelPointsApiService
```

建議 model：
```text
TwitchChannelPointsContext
TwitchChannelPointReward
TwitchChannelPointRedeemResult
TwitchHighlightedMessageRequest
TwitchEmoteUnlockOption
```

---

# 22. Component Commands

```text
check_components_installed
get_bundled_streamlink_path
get_local_component_versions
get_remote_component_versions
check_for_bundle_update
extract_bundled_components
download_and_install_bundle
```

注意：
- main.rs 裡 `extract_bundled_components` 出現兩次，實作上應該只需要一個。

用途：
- bundled components
- Streamlink path
- component update

Flutter 對應：
```text
TwitchComponentManagerService
```

---

# 23. Layout / Message History Commands

```text
get_user_message_history
get_user_message_history_limited
clear_user_message_history
get_user_history_count
```

用途：
- 使用者訊息歷史
- user profile card
- moderation context

Flutter 對應：
```text
TwitchChatUserHistoryService
```

---

# 24. Emoji Commands

```text
convert_emoji_shortcodes
```

用途：
- emoji shortcode → emoji/image

Flutter 對應：
```text
TwitchEmojiService
```

---

# 25. Emote Commands

```text
fetch_channel_emotes
get_emote_by_name
clear_emote_cache
```

用途：
- channel emotes
- emote lookup
- emote cache reset

Flutter 對應：
```text
TwitchEmoteApiService
TwitchEmotePickerController
```

---

# 26. 7TV Commands

```text
seventv_graphql

get_seventv_auth_status
get_seventv_login_url
store_seventv_token
validate_seventv_token
logout_seventv
set_seventv_paint
set_seventv_badge
open_seventv_login_window
receive_seventv_token

get_all_seventv_badges
get_all_seventv_paints
```

用途：
- 7TV GraphQL
- 7TV auth
- 7TV paints / badges
- global cosmetics

Flutter 對應：
```text
TwitchSevenTvApiService
TwitchSevenTvCosmeticsService
```

---

# 27. Automation / Whisper Scraper Commands

```text
scrape_whispers
receive_whisper_export
emit_whisper_progress
```

用途：
- whisper scrape / export
- progress event

Flutter 可選：
```text
TwitchWhisperImportService
```

---

# 28. Log / Activity Commands

```text
log_message
track_activity
get_recent_logs
get_logs_by_level
get_recent_activity
clear_logs
```

用途：
- diagnostic logging
- recent activity
- log filtering

Flutter 對應：
```text
TwitchDiagnosticLogService
```

---

# 29. EventSub Commands

```text
connect_eventsub
disconnect_eventsub
is_eventsub_connected
get_eventsub_session_id
```

用途：
- Twitch EventSub WebSocket
- session id
- connection status

Flutter 對應：
```text
TwitchEventSubApiService
```

建議：
- 官方方向比 legacy PubSub 穩。
- 但某些 Web-only 功能仍可能要 Hermes / GQL。

---

# 30. Chat Identity Commands

```text
fetch_chat_identity_badges
update_chat_identity
receive_badge_data
receive_update_result
```

用途：
- 使用者聊天身份
- badge selection
- chat identity update

Flutter 對應：
```text
TwitchChatIdentityService
```

---

# 31. Hype Train Commands

```text
get_hype_train_status
get_bulk_hype_train_status
```

用途：
- 單頻道 Hype Train 狀態
- 多頻道 Hype Train 批次狀態

Flutter 對應：
```text
TwitchHypeTrainApiService
TwitchHypeTrainController
```

建議顯示：
```text
Header 下方 banner
level / progress / goal / expiresAt
倒數 timer 只更新 banner，不重建 chat list
```

---

# 32. Resub Notification Commands

```text
get_resub_notification
use_resub_token
```

用途：
- resub notification
- 使用 resub token 發送 resub message

Flutter 對應：
```text
TwitchResubApiService
```

---

# 33. Channel Panels Commands

```text
get_channel_about_data
```

用途：
- 取得頻道 About panel
- streamer profile / panels

Flutter 對應：
```text
TwitchChannelPanelApiService
```

---

# 34. Pinned Chat Commands

```text
get_pinned_chat_messages
```

用途：
- 取得置頂留言
- StreamNook README 提到 pinned chat 走 GQL snapshot + 5 秒 polling

Flutter 對應：
```text
TwitchPinnedChatApiService
TwitchPinnedChatController
```

建議流程：
```text
進聊天室 → 立即 fetch pinned message
每 5 秒 polling
id 沒變 → 不 notify
id 變了 → 更新 pinned bar
聊天室隱藏 / player dispose → stop polling
```

---

# 35. Diagnostic Logging Commands

```text
set_diagnostics_enabled
is_diagnostics_enabled
```

用途：
- 開關 diagnostics
- 查 diagnostics 狀態

Flutter 對應：
```text
TwitchDiagnosticLogService
```

---

# 36. Watch Streak Commands

```text
get_watch_streak
get_watch_streaks_batch
share_watch_streak
```

用途：
- 單頻道 watch streak
- 多頻道 watch streak batch
- 分享 watch streak

Flutter 對應：
```text
TwitchWatchStreakApiService
TwitchWatchStreakBannerController
```

---

# 37. Proxy Health Commands

```text
get_proxy_list
check_proxy_health
generate_optimal_proxy_args
```

用途：
- proxy list
- proxy health check
- 生成最佳 proxy args

Flutter 對應：
```text
TwitchProxyHealthService
```

---

# 38. Real-time Topics / Events 參考

## 38.1 WebSocket / Topic 名稱

StreamNook 的 channel points websocket service 使用過這些 topic：

```text
community-points-user-v1.<userId>
video-playback-by-id.<channelId>
predictions-channel-v1.<channelId>
predictions-user-v1.<userId>
```

用途：
- `community-points-user-v1`：忠誠點數 earned/spent/claim-available
- `predictions-channel-v1`：prediction created/updated/locked/ended
- `predictions-user-v1`：使用者 prediction 結果
- `video-playback-by-id`：stream up/down 相關

注意：
- 這類 legacy PubSub topic 不建議完全照搬 endpoint。
- Flutter 目前可用 Hermes / Web GQL / EventSub 做替代。

---

## 38.2 Channel Points Events

```text
channel-points-earned
channel-points-claim-available
channel-points-spent
```

payload 概念：
```text
channel_id
channel_login
channel_display_name
points
reason
balance
claim_id
```

Flutter 對應：
```text
TwitchChannelPointsEvent
TwitchChannelPointsBalanceChanged
TwitchChannelPointsClaimAvailable
```

---

## 38.3 Prediction Events

```text
prediction-created
prediction-updated
prediction-locked
prediction-ended
```

payload 概念：
```text
channel_id
prediction_id
title
status
outcomes[]
winning_outcome_id
prediction_window_seconds
created_at
```

Flutter 對應：
```text
TwitchPredictionEvent
TwitchPredictionSnapshot
TwitchPredictionOutcome
```

狀態機建議：
```text
ACTIVE
LOCKED
RESOLVE_PENDING
RESOLVED
CANCELED
REFUNDED
```

---

# 39. StreamNook 值得模仿的 UI / Controller 設計

## 39.1 Prediction Overlay

功能：
```text
進聊天室先查 get_active_prediction
監聽 prediction-created / updated / locked / ended
顯示倒數
顯示 channel points balance
選 outcome
輸入下注點數
快速下注 10 / 100 / 1000 / ALL
下注後顯示 Bet Placed
結算時顯示 win / loss / refund / announced
```

Flutter 建議：
```text
TwitchPredictionController
TwitchPredictionCard
TwitchPredictionBetSheet
```

---

## 39.2 Channel Points

功能：
```text
顯示目前點數
可顯示自訂點數名稱與圖示
兌換 reward
領取 bonus claim
下注 / 兌換後 refresh balance
```

Flutter 建議：
```text
TwitchChannelPointsController
TwitchChannelPointsSheet
TwitchChannelPointRewardList
```

---

## 39.3 Pinned Chat

功能：
```text
GQL polling
顯示 pinned message
可展開 / 收合
只在 pinned id 變更時更新
```

Flutter 建議：
```text
TwitchPinnedChatController
TwitchPinnedChatBar
```

---

## 39.4 Emote Picker

功能：
```text
Twitch / BTTV / 7TV / FFZ / favorites / emoji
搜尋
favorite emote
lazy image loading
tooltip preview
zero-width emote 標示
```

Flutter 建議：
```text
TwitchEmotePickerController
TwitchEmotePickerPanel
TwitchEmoteGrid
```

---

# 40. Flutter 版建議最先補的檔案

## API service

```text
lib/features/twitch/api/twitch_channel_points_api_service.dart
lib/features/twitch/api/twitch_prediction_api_service.dart
lib/features/twitch/api/twitch_pinned_chat_api_service.dart
lib/features/twitch/api/twitch_hype_train_api_service.dart
lib/features/twitch/api/twitch_watch_streak_api_service.dart
lib/features/twitch/api/twitch_drops_api_service.dart
```

## Controller / Runtime

```text
lib/features/twitch/chat/services/twitch_channel_points_controller.dart
lib/features/twitch/chat/services/twitch_prediction_controller.dart
lib/features/twitch/chat/services/twitch_pinned_chat_controller.dart
```

## UI

```text
lib/features/twitch/presentation/widgets/chat/twitch_prediction_card.dart
lib/features/twitch/presentation/widgets/chat/twitch_pinned_chat_bar.dart
lib/features/twitch/presentation/sheets/twitch_channel_points_sheet.dart
lib/features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart
```

---

# 41. 最小可行重現順序

## Phase 1：聊天室互動基礎

```text
1. Channel id / viewer id resolver
2. Channel points balance
3. Channel points rewards
4. Redeem reward
5. Claim available bonus
```

## Phase 2：Prediction

```text
1. get active prediction snapshot
2. Hermes / event listener update
3. prediction card
4. make prediction
5. balance refresh after bet
```

## Phase 3：Pinned Chat

```text
1. GQL get pinned messages
2. 5 sec polling
3. pinned bar
4. id changed only notify
```

## Phase 4：進階功能

```text
1. Hype train status
2. Watch streak
3. Drops campaign
4. User profile complete
5. Moderator actions
```

---

# 42. 你的 Flutter 專案對應重構圖

```text
TwitchFrostyChatPanel
├─ TwitchPinnedChatBar
├─ TwitchPredictionCard
├─ TwitchFrostyChatList
└─ TwitchFrostyChatInput
   ├─ Emote button
   ├─ Channel points button
   └─ Send button

TwitchFrostyChatRuntime
├─ TwitchChatStreamService
├─ TwitchChatExtrasService
├─ TwitchPredictionController
└─ TwitchPinnedChatController

API layer
├─ TwitchGqlApiService
├─ TwitchHelixApiService
├─ TwitchHermesApiService
├─ TwitchIrcApiService
├─ TwitchChannelPointsApiService
├─ TwitchPredictionApiService
└─ TwitchPinnedChatApiService
```

---

# 43. 注意事項

1. 不要在 Flutter Widget 裡直接解析一堆 raw GQL JSON。
2. 不要讓 pinned chat polling 每 5 秒 rebuild 整個聊天室。
3. Prediction card 倒數要只更新 card，不要影響 chat list。
4. Channel points balance 事件可能漏，要用 GQL refresh 補。
5. 下注成功後要本地 optimistic update，再 refresh balance。
6. official_chat_panel 舊 wrapper 可以留，但主線應該直接走 Frosty。
7. StreamNook 沒有確認 license，不建議直接複製原始碼。


---

# 36. StreamNook 對照：Prediction / Channel Points / Emote Menu 細節

這一節是給 Flutter 版之後改 API 時先查的「實作對照」。原則是：**先看 StreamNook 已經驗證過的 GQL / hash / response path，再改 Dart API，不要靠猜欄位。**

## 36.1 Prediction：讀取目前賭盤

StreamNook command：

```text
get_active_prediction(channel_login)
```

GQL：

```graphql
query GetChannelPrediction($login: String!) {
  channel(name: $login) {
    id
    activePredictionEvent {
      id
      status
      title
      predictionWindowSeconds
      createdAt
      lockedAt
      endedAt
      winningOutcome {
        id
      }
      outcomes {
        id
        title
        color
        totalPoints
        totalUsers
      }
    }
  }
}
```

Flutter 對應：

```text
lib/features/twitch/api/engagement/twitch_prediction_api_service.dart
lib/features/twitch/models/engagement/twitch_prediction.dart
lib/features/twitch/presentation/widgets/chat/twitch_chat_engagement_strip.dart
```

目前 Flutter 應該至少解析：

```text
prediction.id
prediction.status
prediction.title
prediction.predictionWindowSeconds
prediction.createdAt
prediction.lockedAt
prediction.endedAt
prediction.winningOutcome.id
outcomes[].id
outcomes[].title
outcomes[].color
outcomes[].totalPoints
outcomes[].totalUsers
```

顯示策略：

```text
ACTIVE / LOCKED / RESOLVE_PENDING：顯示賭盤卡片
RESOLVED / CANCELED / REFUNDED / ENDED：短暫顯示結果卡片，約 4~5 秒後自動隱藏
```

賠率計算：

```text
odds = totalPool / outcome.totalPoints
```

若某 outcome 點數為 0，先不顯示賠率，避免除以 0。

## 36.2 Prediction：下注

StreamNook command：

```text
place_prediction(event_id, outcome_id, points, channel_id)
```

GQL：

```graphql
mutation MakePrediction($input: MakePredictionInput!) {
  makePrediction(input: $input) {
    prediction {
      id
      points
    }
    error {
      code
    }
  }
}
```

Variables：

```json
{
  "input": {
    "eventID": "prediction id",
    "outcomeID": "outcome id",
    "points": 100,
    "transactionID": "uuid"
  }
}
```

Flutter 對應：

```text
lib/features/twitch/api/engagement/twitch_drops_prediction_api_service.dart
```

備註：StreamNook 的 `selectedOutcome` / `hasPlacedBet` 主要是前端本地狀態。若使用者不是在本 App 內下注，`GetChannelPrediction` 這條目前不保證會回 viewer 自己選哪邊。要做跨裝置 YOU 標示時，先找 viewer-specific prediction query 或做 raw debug，不要直接猜欄位。

## 36.3 Channel Points Rewards

StreamNook 使用 persisted query：

```text
operationName: ChannelPointsContext
sha256Hash: 374314de591e69925fce3ddc2bcf085796f56ebb8cad67a0daa3165c03adc345
variables:
  channelLogin
  includeGoalTypes: ["CREATOR", "BOOST"]
```

Flutter 對應：

```text
lib/features/twitch/api/engagement/twitch_channel_points_api_service.dart
lib/features/twitch/parsers/engagement/twitch_channel_points_reward_parser.dart
lib/features/twitch/models/engagement/twitch_channel_points_models.dart
```

Reward parser 注意事項：

```text
customRewards：自訂 reward
automaticRewards：內建 reward
pricingType == BITS：不要當 Channel Points reward 顯示
cost：優先用 Twitch 回傳 cost；cost 為空時再 fallback minimumCost / defaultCost
redeemCost：送 mutation 的 cost 要保留，不要被 runtime 重建時覆蓋成 UI 顯示值
```

## 36.4 Channel Points：Choose an Emote to Unlock

StreamNook 使用：

```text
EMOTE_PICKER_USER_SUBSCRIPTION_PRODUCTS_HASH
511bebfb513d0127d24a7fe49aa2b7717306a611e1f4269a93e0cc76e8a65a81
```

Flutter 對應：

```text
lib/features/twitch/api/engagement/twitch_channel_points_emote_api_service.dart
lib/features/twitch/parsers/engagement/twitch_channel_points_emote_parser.dart
lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_emote_overlay.dart
```

目前 Flutter parser 的安全白名單：

```text
只吃 subscriptionProducts[*].emotes[*]
只收 product.tier == "1000"
只收 emote.setID == product.emoteSetID
不 fallback 到 lockedChannelEmotes / globalEmotes / third-party emotes
```

目的：避免把「台主有但不能用這個 reward 解鎖」的貼圖混進 Choose menu。

## 36.5 Channel Points：Modify a Single Emote

StreamNook 相關 hash：

```text
MODIFY_EMOTE_OWNED_EMOTES_HASH
  e882551bf6a6abf14a1ec2deac4fe9a0af22f89f863818f7228da98d6b849cb4

AVAILABLE_EMOTES_FOR_CHANNEL_HASH
  6c45e0ecaa823cc7db3ecdd1502af2223c775bdcfb0f18a3a0ce9a0b7db8ef6c

UNLOCK_MODIFIED_EMOTE_HASH
  30e8cc29b1d6d96809f5e35f5e7a550ae8bf5d26966a9637d919477ffd0bfc52
```

目前 Flutter 狀態：

```text
Choose menu 已接近 StreamNook
Modify menu 還需要再對照 StreamNook owned emote / available modifier source
不要把 Choose emote 清單直接拿來當 Modify 清單
```

建議後續拆法：

```text
TwitchChannelPointsEmoteApiService.getChooseUnlockableEmotes()
TwitchChannelPointsEmoteApiService.getOwnedModifiableEmotes()
TwitchChannelPointsEmoteApiService.getAvailableModifiedEmotesForChannel()

TwitchChannelPointsEmoteParser.parseChooseUnlockableEmotes()
TwitchChannelPointsEmoteParser.parseModifyOwnedEmotes()
TwitchChannelPointsEmoteParser.parseModifiedEmoteOptions()
```

Modify UI 流程：

```text
1. 先選「可修改的已擁有 emote」
2. 再選該 emote 對應的 modifier / modified emote
3. 最後送 selectedModifier.id 作為 mutation 的 emoteID
```

## 36.6 Channel Points：Built-in reward mutation 對照

```text
SendHighlightedChatMessage
  persisted hash: bb187d763156dc5c25c6457e1b32da6c5033cb7504854e6d33a8b876d10444b6

UnlockRandomSubscriberEmote
  persisted hash: f548e89966b21d0094f3dc35233232eb6ec76d63e02594c8a494407712a85350

UnlockModifiedSubscriberEmote
  persisted hash: 30e8cc29b1d6d96809f5e35f5e7a550ae8bf5d26966a9637d919477ffd0bfc52

UnlockChosenSubscriberEmote
  inline mutation，目前不要硬找 persisted hash
```

原則：

```text
兌換 mutation 不要跟 menu parser 綁死。
Menu 負責提供正確 emote id / modified emote id。
Redeem API 只負責送 Twitch 要的 mutation payload。
```

---

# 44. Follow / Relationship 查證記錄（2026-05-14）

> 目的：避免後續再用猜的方式改 Follow / Unfollow。之後要做 Follow 相關功能時，先看本節，再去 StreamNook repo 對照 `TwitchService::follow_channel`、`TwitchService::unfollow_channel`、`TwitchService::check_following_status` 的實作。

## 44.1 已確認的 StreamNook 呼叫鏈

StreamNook 的 Follow / Unfollow 不是單純打開 Twitch WebView 讓使用者自己按，而是：

```text
React UI
→ Tauri invoke command
→ Rust command
→ TwitchService
→ Twitch Helix / Twitch GQL
```

前端已確認使用：

```text
invoke('follow_channel', { targetUserId })
invoke('unfollow_channel', { targetUserId })
invoke('check_following_status', { targetUserId })
```

目前確認的前端來源：

```text
src/components/SearchProfileModal.tsx
src/stores/contextMenuStore.ts
```

後端 command 對應：

```text
src-tauri/src/commands/twitch.rs
follow_channel(target_user_id)
unfollow_channel(target_user_id)
check_following_status(target_user_id)
```

真正要對照的核心實作位置：

```text
src-tauri/src/services/twitch_service.rs
TwitchService::follow_channel
TwitchService::unfollow_channel
TwitchService::check_following_status
```

## 44.2 Flutter 版不可再混用 token

StreamNook 至少有兩套 Twitch token，Flutter 對應時一定要分清楚：

| Token 類型 | StreamNook 來源 | 主要用途 | Follow/Unfollow 可否使用 |
|---|---|---|---|
| 主 Twitch OAuth token | `TwitchService::get_token()` | 一般 Twitch API、IRC、追隨查詢、moderation | 應優先使用 |
| Drops Android token | `DropsAuthService::get_token()`，`TWITCH_ANDROID_CLIENT_ID` | Drops / Channel Points / Prediction 類功能 | 不應直接用於 Follow/Unfollow |
| Web cookie auth-token | Twitch WebView / Web cookie | Web GQL、播放、部分 Web-only API | 視 API 而定，不應預設用於 Follow/Unfollow |

Flutter 對應規則：

```text
Follow / Unfollow / Check Following → 主 OAuth token
IRC chat read/write → 主 OAuth token
Channel Points / Drops / Prediction → Drops token 或 Web/GQL token，依實際 API 對照
Playback m3u8 → Web GQL / playback token，不等於主 OAuth token
```

## 44.3 IRC 與 Follow 的 token 分工

StreamNook 的 IRC service 是 Rust backend 連官方 Twitch IRC：

```text
irc.chat.twitch.tv:6667
PASS oauth:<token>
NICK <login>
```

IRC 使用的是：

```text
TwitchService::get_token()
```

也就是主 OAuth token，不是 Drops Android token。Flutter 版若要模仿 StreamNook 的聊天室架構，也應維持：

```text
TwitchAuthService.getValidAccessToken() → IRC
TwitchDropsAuthService.getToken() → drops / points / prediction 類功能
```

## 44.4 Follow 狀態查詢建議

`check_following_status` 不要和 Follow/Unfollow mutation 綁死。建議 Flutter 版優先做成獨立 API：

```text
TwitchRelationshipApiService.checkFollowingStatus(targetUserId)
```

建議路線：

```text
優先：Helix /channels/followed 或 StreamNook 實際使用的查詢方式
Token：主 OAuth token
Client-ID：Flutter App 自己的 Twitch app client id
```

注意：讀取「是否已追隨」通常比執行 Follow/Unfollow 穩定，不能因為 `checkFollowingStatus` 成功，就推論 `followChannel` mutation 一定可用。

## 44.5 Follow / Unfollow GQL 查證方向

目前已查到 StreamNook 相關線索包含：

```text
FollowButton_FollowUser
FollowButton_UnfollowUser
targetID
persistedQuery
sha256Hash
```

因此 StreamNook 很可能不是用自寫 inline GraphQL mutation，而是接近 Twitch Web APQ / persisted query 形式：

```json
{
  "operationName": "FollowButton_FollowUser",
  "variables": {
    "input": {
      "targetID": "<channel_user_id>",
      "disableNotifications": false
    }
  },
  "extensions": {
    "persistedQuery": {
      "version": 1,
      "sha256Hash": "<必須查 StreamNook 實際值，不可猜>"
    }
  }
}
```

Unfollow 可能形式：

```json
{
  "operationName": "FollowButton_UnfollowUser",
  "variables": {
    "input": {
      "targetID": "<channel_user_id>"
    }
  },
  "extensions": {
    "persistedQuery": {
      "version": 1,
      "sha256Hash": "<必須查 StreamNook 實際值，不可猜>"
    }
  }
}
```

## 44.6 之前踩過的錯誤，之後不要再重複

不要再用以下方式硬猜：

```text
❌ 自訂 operationName：PrivateGqlRelationship_FollowUser
❌ 自訂 operationName：PrivateGqlRelationship_UnfollowUser
❌ 在 Follow payload 裡查 id
❌ 在 Unfollow payload 裡查 user
❌ 直接用 Drops Android token 做 Follow/Unfollow
❌ 看到 StreamNook 有 command 就直接猜 query 欄位
```

已遇到的錯誤：

```text
Cannot query field "id" on type "Follow"
Cannot query field "user" on type "UnfollowUserPayload"
failed integrity check, path: [unfollowUser]
```

判斷：

```text
field error → selection set 寫錯
integrity error → token / operationName / APQ / header / client context 可能和 Twitch Web 預期不一致
```

## 44.7 之後實作 Flutter Follow 的正確流程

在還沒查到 StreamNook `sha256Hash` 前，不要再給 ZIP 覆蓋檔。正確流程：

```text
1. 先從 StreamNook 抓出完整 TwitchService::follow_channel function
2. 抓出完整 TwitchService::unfollow_channel function
3. 抓出完整 TwitchService::check_following_status function
4. 確認 token 來源：主 OAuth / cookie / drops / Web auth-token
5. 確認 Authorization header：Bearer 或 OAuth
6. 確認 Client-ID：TWITCH_APP_CLIENT_ID 或 TWITCH_GQL_CLIENT_ID
7. 確認 GQL body：inline query 或 persistedQuery
8. 確認 FollowButton_FollowUser hash
9. 確認 FollowButton_UnfollowUser hash
10. 再改 Flutter API service
```

建議 Flutter 檔案：

```text
lib/features/twitch/api/channel/twitch_relationship_api_service.dart
lib/features/twitch/api/twitch_gql_api_service.dart
lib/features/twitch/api/twitch_helix_api_service.dart
```

建議 API 介面：

```dart
abstract class TwitchRelationshipApiService {
  Future<TwitchUserLite> getUserByLogin(String login);
  Future<bool> checkFollowingStatus(String targetUserId);
  Future<void> followChannel(String targetUserId);
  Future<void> unfollowChannel(String targetUserId);
}
```

## 44.8 查 StreamNook 功能時的標準流程

之後查任何 StreamNook 功能，都照這個順序：

```text
1. 先查前端 invoke 名稱
2. 再查 src-tauri/src/commands/*.rs command
3. 再查 service function
4. 確認 token provider
5. 確認 endpoint / GQL operationName / persisted hash
6. 確認 variables / input key 大小寫
7. 確認 response path
8. 確認錯誤處理
9. 最後才改 Flutter
```

不要跳過 service function 直接根據名稱猜 API。

---

# 45. Token 分工快速表

| 功能 | StreamNook 參考 | Flutter 建議 token | 備註 |
|---|---|---|---|
| IRC chat | `irc_service.rs` → `TwitchService::get_token()` | 主 OAuth token | `PASS oauth:<token>` |
| Follow 狀態查詢 | `check_following_status` | 主 OAuth token | 可優先 Helix |
| Follow / Unfollow | `follow_channel` / `unfollow_channel` | 主 OAuth token，必要時 GQL APQ | 不用 drops token |
| Channel Points balance | channel points service | Drops / Web GQL token，依實際對照 | 不要猜 |
| Prediction 下注 | prediction command | Drops / Web GQL token，依實際對照 | 要保留 transactionID |
| Drops claim | drops service | Drops Android token | `TWITCH_ANDROID_CLIENT_ID` |
| Playback m3u8 | playback service / GQL | Playback token / Web GQL | 不等於主 OAuth |
| Badge / Profile | GQL / Helix 混合 | 主 OAuth 或 public GQL | 依 endpoint |


---

# 46. Follow / Relationship v14 診斷結論

v13 diagnostics 顯示 Flutter 當時送出的 Follow / Unfollow 不是 StreamNook 的 Android/Drops context，而是：

```text
tokenSource=legacyWebTokenProviderAsDropsToken
clientId=kimne78kx3ncx6brgo4mv6wki5h1ko
validate.client_id=kimne78kx3ncx6brgo4mv6wki5h1ko
```

`kimne78kx3ncx6brgo4mv6wki5h1ko` 是 Twitch Web GQL Client-ID，不是 StreamNook `TWITCH_ANDROID_CLIENT_ID`。

v14 修正方向：

```text
1. Follow / Unfollow 仍走 StreamNook DropsAuthService + Android Client-ID + APQ hash 路線。
2. 但在送 mutation 前先 validate token。
3. 如果 validate 回來的 client_id 是 Twitch Web Client-ID，直接擋下，不再送 GQL。
4. TwitchDropsAuthService 會清掉被 Web Client-ID 汙染的 Drops session。
5. 使用者需要重新做 Drops device flow login。
```

正確狀態應該看到：

```text
clientId=kd1unb4b3q4t58fwlpcbzcbnm76a8fp
validate.client_id=kd1unb4b3q4t58fwlpcbzcbnm76a8fp
```
