$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectDirectory
try {
    & flutter test --no-pub docs/twitch_emote_picker_flow_test.dart docs/twitch_watch_chat_keyboard_test.dart docs/twitch_whisper_inbox_test.dart --reporter expanded
    if ($LASTEXITCODE -ne 0) {
        throw 'Twitch UI regression tests failed. See the failing test above.'
    }
} finally {
    Pop-Location
}
