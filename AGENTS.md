# Power Word: Toolbox

WoW retail addon (interface 120001) for Discipline Priests. Tracks PI requests, Atonement counts, Radiance cooldowns, and Void Shield deck state via moveable widget overlays.

## Project Structure

```
Core/Init.lua                   — namespace (PWT), defaults, migration, event dispatch, slash commands
Modules/
  PI.lua                        — Power Infusion whisper tracking, glow/sound/overlay alerts
  Atonement.lua                 — Atonement aura count + lowest timer widget
  Radiance.lua                  — Two charge bars with talent-based CD detection
  RaidFrames.lua                — Raid frame finder (Grid2 / Danders / Cell / ElvUI / Blizzard)
  VoidShieldDeck.lua            — Void Shield 3-card deck tracker with texture-based proc detection
Options/
  UI.lua                        — Options window shell; tab creation, show/hide, font apply
  General.lua                   — Module enable toggles, audio channel, font, slash command list
  PI_Options.lua                — PI priority list editor, glow/sound/overlay/early-request config
  Atonement_Options.lua         — Atonement widget settings
  Radiance_Options.lua          — Radiance bar size/color/position settings
  VoidShieldDeck_Options.lua    — Void Shield display, proc alert, sound, desync settings
PowerWordToolbox.toc            — Addon metadata; files load in declaration order
```

## Architecture

**Namespace:** `local _, PWT = ...` in every file. All modules live on `PWT` (e.g., `PWT.PI`, `PWT.Radiance`).

**SavedVariables:** `PowerWordToolboxDB`. Loaded in `ADDON_LOADED`, migrated by `MigrateDB()`, then assigned to `PWT.db`. Defaults live in `PWT.defaults`.

**Event dispatch:** A single frame in `Core/Init.lua` handles all WoW events and calls module methods. Modules don't register their own events.

**UI tabs:** Each Options file calls `UI:AddTab(key, label, index)` at load time. Tabs are enabled/disabled via `UI:SetTabEnabled(key, bool)`. Each tab's sync function (`UI:SyncPI()`, etc.) is called by `UI:SwitchTab()`.

**Spec guard:** All Disc-specific modules check `PWT.isDisc` before acting. `PWT:CheckSpec()` runs on login and spec change.

## Non-Obvious Details

### VoidShieldDeck
- Proc detection reads `GetActionTexture(slot)` for slots 1–180. Slots 73–180 are addon bars (Bartender4, Dominos, ElvUI) — using only 1–72 misses them.
- `pwsSlot` is re-validated on every Penance cast via `GetActionInfo`; stale cache (user moved PWS off bar) is caught immediately and triggers a full rescan.
- `procAvailable = false` is the false-positive guard. When false, `OnPenanceCast` takes the early-return branch and skips all texture detection entirely.
- Cast history is a ring buffer (`CAST_HISTORY_MAX = 4`); `RecordOutcome` is O(1). History survives natural deck resets but clears on login/encounter/challenge reset.
- Deck state persists across `/reload` via `SaveState` (PLAYER_LOGOUT) and `RestoreState` (PLAYER_ENTERING_WORLD). Does not survive a DC.
- Three independent draggable sub-widgets (`chanceWidget`, `deckWidget`, `cardsWidget`) each save position separately in the DB.
- `CheckDesync` has one condition: 4 consecutive no-procs → `cardsRemaining=1, procAvailable=true`. The back-to-back proc condition was removed. `CheckDesync` must run before `ResetDeck` when the deck empties — the desync fix may set `cardsRemaining` to a non-zero value, which should skip the reset.

### PI
- Uses LibCustomGlow (bundled) for the raid-frame target highlight.
- Early request: when PI is on CD and a whisper arrives within `earlyRequestWindow` seconds of readiness, a countdown overlay runs (`earlyCountdownTicker` at 0.1s intervals). `CancelEarlyCountdown()` is called by `ClearAllGlows()`.

### Radiance
- Talent detection (`DetectBrightPupil`) scans the full `C_Traits` node tree; each node is wrapped in `pcall` to avoid taint crashes on protected data.
- Charge consumption is deferred one frame via `C_Timer.After(0, ...)` so an Evangelism proc (free Radiance) in the same frame can cancel the pending consumption by nilling `pendingRadianceTime`.
- `OnUpdate` is throttled to 20fps (0.05s) during recharge; `SetWidth` and `SetText` are dirty-checked before calling.

### Atonement
- `issecretvalue()` guards appear throughout to avoid errors on WoW-protected aura fields.
- `mouseFollow` mode: widget tracks cursor each `OnUpdate`. `skipNextPositionSave = true` prevents capturing the cursor position as the saved widget position when mouseFollow is disabled.
- Lock state is controlled by a `MakeLockResetRow` button in the Position section (not a checkbox). The lock button dims and ignores clicks when mouseFollow is active.

### Options UI
- `UI.FRAME_W = 840`, `UI.TAB_BAR_W = 160`, `UI.HEADER_H = 64`.
- `CONTENT_W = 648` = FRAME_W - TAB_BAR_W - PAD*2 (PAD padding on both left and right of content area). Always use `CONTENT_W` for element widths inside tab panels — using `FRAME_W` pushes elements off-screen.
- Window chrome: sidebar logo header (left, `TAB_BAR_W` wide) + content section header (right) both at `HEADER_H = 64`. A full-width gold accent line separates both headers from the content below. A vertical separator runs at `x = TAB_BAR_W` full height.
- Tab buttons: full-width (no horizontal gaps), `TAB_H = 44`. Each tab has a spell icon sourced via `C_Spell.GetSpellTexture(spellID)` or a direct file ID — no custom icon assets. Icon tints update in `SwitchTab`.
- The content header title/description updates on every tab switch via `TAB_META` table in `UI.lua`. `UI.contentHeaderTitle` and `UI.contentHeaderDesc` are set there.
- Dragging: header child frames (`sidebarHeader`, `contentHeader`) use `RegisterForDrag("LeftButton")` + `OnDragStart` to call `optionsFrame:StartMoving()`. They must NOT call `StartMoving()` from `OnMouseDown` — that causes a double-fire with the parent's `OnDragStart` and makes the window jump.
- Custom dropdowns use a `TOOLTIP`-strata floating Frame plus a full-screen `DIALOG`-strata click-outside watcher frame.
- PI tab: Alert Settings and Name Overlay are always-visible sections (no collapsible toggles). `piScrollChild:SetHeight(1000)` is a static value — no dynamic recalculation needed.
- `VS_CONTENT_H` in `VoidShieldDeck_Options.lua` must be updated manually if sections are added or removed.
- `MakeSectionHeader(parent, anchor, yOffset, title)` returns a Frame of height 22 with a left accent bar. Anchor content to its `BOTTOMLEFT`.
- `MakeLockResetRow(parent, onLock, onUnlock, onReset, lockedLabel, unlockedLabel)` returns a frame with `.lockBtn`, `.resetBtn`, `.setLocked(bool)`.
- `MakeCheckbox` returns a frame with `.set(bool)`, `.get()`, `.lbl` (the label FontString), `.totalHeight`.

## Slash Commands

| Command | Action |
|---|---|
| `/pwtb` | Open options |
| `/pwtb debug` | Toggle debug mode |
| `/pwtb rdebug` | Toggle Radiance cast event debug logging |
| `/pwtb status` | Print full addon state |
| `/pwtb spellcheck` | Check PI cooldown state |
| `/pwtb seqreset` | Reset PI sequence to position 1 |
| `/pwtb reset` | Re-centre options window |
