# TriggerWatcher

TriggerWatcher logs button and trigger activations to chat and/or console for admins and SourceTV. It is the successor to the old ButtonNotifier plugin (repository name: sm-plugin-ButtonNotifier).

## Features
- Notify modes per client: None, Chat, Console, or Both.
- Clean, short chat messages with a [TW] prefix.
- Detailed console/server logs with user ID and entity info.
- Spam throttling for rapid button presses.
- Optional entWatch-core (entWatch 4) integration to ignore special items.

## Installation
1) Compile (or download latest release) and install the plugin.
2) Place translations in the SourceMod translations folder.

Files:
- Plugin: addons/sourcemod/plugins/TriggerWatcher.smx
- Translations: addons/sourcemod/translations/TriggerWatcher.phrases.txt

## Configuration
Cvars:
- sm_TriggerWatcher_block_spam_delay (default 5)
  - Spam notification delay in seconds. Set to 0 to disable spam blocking.

## User Settings
Players can open the cookie menu entry "TriggerWatcher Settings" to select per-category display mode:
- Buttons
- Triggers

> [!IMPORTANT]
> Upgrade Guide: v2 -> v3
### This release is a rename and cleanup of the legacy ButtonNotifier plugin.

Key changes:
- Plugin renamed: ButtonNotifier -> TriggerWatcher
- Repository renamed: sm-plugin-ButtonNotifier -> sm-plugin-TriggerWatcher
- Cookie key renamed: TriggerWatcher_display
- Cvar change: removed sm_TriggerWatcher_block_spam (delay now controls spam blocking)

Recommended upgrade steps:
1) Replace the old .smx with TriggerWatcher.smx
2) Install new translations with TriggerWatcher.phrases.txt
3) Remove old configs/cookies if you want a clean slate

## Notes
- Console logging uses detailed output including user ID and entity info.
- Chat logging is intentionally short to avoid spam.
