# StreamNook Follow / Relationship v14 Drops Context Guard

## What v13 proved

The Flutter app was not sending a real StreamNook-style Android/Drops token.
The diagnostics showed:

```text
tokenSource=legacyWebTokenProviderAsDropsToken
clientIdSource=sharedPreferences:new_twitch_app_twitch_drops_client_id
clientId=kimne78kx3ncx6brgo4mv6wki5h1ko
validate: client_id=kimne78kx3ncx6brgo4mv6wki5h1ko
```

`kimne78kx3ncx6brgo4mv6wki5h1ko` is the Twitch Web GQL client ID, not the Android/Drops client ID. That means the token stored in the Drops slot was actually a Web-context token.

## StreamNook reference

The StreamNook Rust service supplied in the project uses:

```text
Follow / Unfollow:
- DropsAuthService::get_token()
- TWITCH_ANDROID_CLIENT_ID
- Authorization: OAuth <drops token>
- FollowButton_FollowUser / FollowButton_UnfollowUser APQ hashes

Check status:
- TwitchService::get_token()
- Helix /channels/followed
```

## v14 behavior

- Rejects Twitch Web client ID when choosing the Drops/Android client ID.
- Rejects tokens whose OAuth validation `client_id` does not match the selected Android/Drops client ID.
- Automatically ignores a stored Drops client ID if it is the Twitch Web client ID.
- `TwitchDropsAuthService.loadStoredSession()` clears the contaminated Drops token if the stored Drops client ID is the Web client ID.

## Required user action after applying v14

After applying v14, log in to Drops again so the stored token is issued for the Android/Drops client ID.

Expected diagnostics after a correct Drops login:

```text
clientId=kd1unb4b3q4t58fwlpcbzcbnm76a8fp
validate: client_id=kd1unb4b3q4t58fwlpcbzcbnm76a8fp
```

If diagnostics still show `kimne78...`, the app is still using a Web token in the Drops slot.
