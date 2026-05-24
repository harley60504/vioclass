import '../../api/core/twitch_api_client.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import 'twitch_drops_connection_page_stage249.dart';

class TwitchDropsConnectionPage extends TwitchDropsConnectionPageStage249 {
  const TwitchDropsConnectionPage({
    super.key,
    required TwitchApiClient apiClient,
    required TwitchDropsAuthService dropsAuthService,
  }) : super(
          apiClient: apiClient,
          dropsAuthService: dropsAuthService,
        );
}
