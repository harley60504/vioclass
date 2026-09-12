/// Test-only coordination for the Android player-engine A/B branch.
///
/// When an external diagnostic engine (ExoPlayer/video_player or LibVLC) owns
/// the visible video, foreground recovery must not wake the shared media_kit
/// player in the background. Production main does not contain this file.
class TwitchPlayerEngineDiagnosticState {
  TwitchPlayerEngineDiagnosticState._();

  static bool externalPlaybackActive = false;
  static String engineLabel = 'media_kit';
}
