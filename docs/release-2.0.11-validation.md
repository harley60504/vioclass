# VioClass 2.0.11 validation

- `flutter analyze --no-pub`: no issues found. Subsequent changes only normalized two files' line endings and completed test cleanup; no additional analyzer run was performed.
- Release regression selection: 24 changed/new test files, initially 524 passed and 42 failed.
- Bounded comparison: archived only Dart sources, assets, dependency manifests and the three failing test files from release commit `2ab57d73e24357b619cddd35746b58ee148e2b35`, without native platform directories or account data. Under the same local SDK, 41 identical failures already occurred in 2.0.10.
- The remaining failure was the rail-navigation fixture leaving the newly bounded 15-second Hermes handshake deadline pending. Its teardown now advances fake time past that deadline. The exact affected test then passed; production connection behavior was not changed for this cleanup.
- Existing baseline failures remain in chat-profile copy/entry expectations and whisper UI/storage-failure fixtures. This is not an all-tests-green release. Those failures were not disabled or silently changed to pass.
- Earlier targeted notification checks passed 36 tests, including close-button hover above the Navigator, outside-click dismissal without swallowing player input, and notification history preservation.
- Windows and Android profile builds were repeatedly installed/launched during review. PiP transition verification retained playback/media service and login. These bounded observations do not certify every intermittent network condition or Samsung's floating-indicator animation.

Raw device screenshots, exploratory diagnostics and user-session recordings remain local and are not release assets. The committed decoder fixture is synthetic test media used by the Chroma integration check.
