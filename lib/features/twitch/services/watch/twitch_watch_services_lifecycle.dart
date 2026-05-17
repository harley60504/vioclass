// PATCH VERSION: twitch_watch_services_lifecycle_stage187d
//
// Lifecycle helper for Watch composition services.
// This keeps resource teardown near the Watch service graph so WatchPage can
// gradually stop owning individual service/runtime disposal details.

import 'twitch_watch_services.dart';

extension TwitchWatchServicesLifecycle on TwitchWatchServices {
  void disposeOwnedResources() {
    playerRuntime.dispose();
    playerSession.release();
    apiClient.close(force: true);
  }
}
