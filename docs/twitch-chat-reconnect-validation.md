# Chat reconnect validation — 2026-10-28

## Reproduced defects

- A disconnect/error during the initial USERSTATE wait was overwritten by the
  final connected flag, causing foreground recovery to skip the dead session.
- IRC RECONNECT messages did not make the runtime eligible for recovery.
- The optional write connection's raw disconnect/error stream was not observed.

## Bounded verification

- Before the fix, all three new runtime state tests failed as expected.
- After the fix, 76 related tests passed (runtime state, history startup and
  account/lifecycle handling). The external-network test is skipped by default.
- Six controller/runtime integration cases cover disconnect, error and server
  RECONNECT for single and dual transports. Each checks a failed retry, a later
  successful retry, no overlapping dial while pending, retained history, new
  message delivery, no redundant startup fetch and intentional shutdown.
- These six cases use injected transports and a manually advanced periodic
  timer, with normal asynchronous stream cancellation. The initial widget-clock
  variant stalled during stream cancellation; it did not establish a production
  cleanup deadlock, so no production cleanup change was made for it.
- An explicit anonymous live-network test passed against Twitch IRC: ROOMSTATE
  arrived on the first connection and again after reconnecting a real socket.
  Only the server RECONNECT control signal was injected. No account credentials
  or user-authored chat text were sent. This verifies room join, not receipt of
  an actual new chat post or a real server-initiated disconnect.

## Limit

This validates the identified state failures and recovery path. It does not
establish that every intermittent device/network disconnect has the same cause.
These changes are not included in the already published 2.0.11 release.

## Immediate recovery update — 2026-10-29

- Runtime disconnect notifications now queue recovery immediately, outside the
  notification callback. Failed attempts wait 2, 4, 8, then 15 seconds; further
  failures stay at 15 seconds. The periodic check cannot bypass a queued delay.
- Success resets the delay. Backgrounding, intentional disconnect, replacing
  the runtime and disposing cancel queued recovery and detach owned listeners
  as appropriate. Foreground return can recover without the old delay.
- All 76 related tests passed. The six controller/runtime cases now assert the
  immediate first attempt, each backoff interval and its cap, no overlapping
  attempts, success resetting the delay, background cancellation and foreground
  recovery, retained messages and no extra history fetch. Timer callbacks are
  advanced explicitly while transport cancellation uses normal asynchronous
  scheduling. The external-network check was not repeated for this update.
