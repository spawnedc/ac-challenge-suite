# ac-challenge-suite

A WoW 3.3.5a addon that gives players a minimap-button UI for `mod-challenge-suite`'s server-side challenges (Hardcore permadeath, and any future ones the server adds) — showing live status and letting players activate a challenge themselves, without needing a GM.

## Install

Copy this repository into the client's `Interface/AddOns/ChallengeSuite` folder (the folder name must match the addon name for the `.toc` to be picked up).

## Usage

- A minimap button (via LibDBIcon-1.0) shows challenge status; hover it for a tooltip listing every challenge the server reports and its current state, click it to open a management panel with an "Enable" button per challenge you're eligible for.
- `/cs` toggles the panel, for players who've hidden the minimap.
- The minimap icon prefers the real Hardcore aura's icon (spell `666666`) when the companion `ac-challenge-suite-clientpatch` is installed; otherwise it falls back to a stock Blizzard icon so it's never blank.

## Protocol

This addon speaks the addon-message protocol documented in `mod-challenge-suite`'s own README (`CHALLENGE_SUITE\t<COMMAND>[\t<body>]` over the `CHAT_MSG_ADDON` channel) — that document is the source of truth for the wire format; this repo just implements the client side of it:

- `Core.lua` parses incoming `STATE`/`SHOW_PANEL` messages into `ChallengeSuite.state` and fires listeners UI.lua hooks into, sends `HELLO` once on login, and exposes `ChallengeSuite:RequestEnable(id)` to whisper an `ENABLE` request back to the server.
- `UI.lua` owns the LibDataBroker object, minimap button, tooltip, and management panel.

## Vendored libraries

`Libs/` bundles `LibStub`, `CallbackHandler-1.0`, `LibDataBroker-1.1`, and `LibDBIcon-1.0` — standard, widely-embedded WoW addon libraries (all public-domain / permissively licensed for exactly this kind of embedding), fetched from their canonical upstream repositories.

## Testing outside the game client

`tests/wow_stub_harness.lua` is a minimal WoW API stub environment (frames, `CreateFrame`, `SendAddonMessage`, `GetSpellInfo`, etc.) that loads the real vendored libraries plus `Core.lua`/`UI.lua` under a stock Lua 5.1 interpreter and exercises the full flow — login/`HELLO`, parsing a `STATE` message, `RequestEnable`, the `/cs` slash command, and the real `LibDBIcon-1.0` minimap-button registration path. It can't replace testing in a live client, but it catches protocol-parsing and API-usage mistakes without needing one. Run it with:

```
lua5.1 tests/wow_stub_harness.lua
```
