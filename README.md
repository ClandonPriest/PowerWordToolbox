# Power Word: Toolbox

A Discipline Priest utility addon for World of Warcraft. Provides four independent modules that can each be enabled or disabled separately: Power Infusion tracking, Atonement count display, Radiance cooldown bars, and Void Shield deck tracking.

Open the options window with `/pwtb`.

---

## Modules

### Power Infusion

Tracks PI whisper requests from your group members and highlights the highest-priority target on your raid frames with a glow effect and optional sound alert.

**Setup:**
1. Enable the module on the General tab.
2. Open the Power Infusion tab.
3. Choose a mode:
   - **Priority List** — on any combat whisper, glows the first player from your list who is currently in the group. Add players in priority order; drag rows to reorder, click × to remove.
   - **PI Sequence** — glows players in a fixed sequence, advancing one position per whisper. Resets automatically on boss pull. The "Repeat last entry" option loops the final player instead of cycling back to position 1.
4. Configure alert settings to your preference:
   - **Glow** — choose between a full overlay or outer border glow style, pick a color, and adjust opacity/pulse speed. Use the Test button to preview on your own frame.
   - **Sound** — pick a sound and volume. Preview plays immediately.
   - **Early Request** — when PI is still on cooldown and a whisper arrives within the grace window (default 5s), the glow triggers early with a countdown overlay so you can pre-aim.
5. Optionally enable the **Name Overlay** — a floating frame showing the PI target's name and icon. Unlock it to drag it anywhere on screen.

---

### Atonement Tracker

Displays the current number of active Atonements on your group and optionally shows the shortest remaining timer so you know when to refresh before Penance.

**Setup:**
1. Enable the module on the General tab.
2. Open the Atonement tab and configure:
   - **Show lowest Atonement timer** — adds a countdown that turns yellow below 6s and red below 3s.
   - **Follow mouse cursor** — the widget floats near your cursor as you cast, useful if you prefer to not lock it to a fixed position. Choose which corner of the widget attaches to the cursor.
   - **Text Size** — set the font size for the count and timer numbers independently.
3. Use **Unlock to Move** in the Position section to drag the widget anywhere, then **Lock Position** to save it.
4. **Reset Position** returns the widget to the screen centre.

The widget background and resize handle appear when unlocked. Lock it before raiding to keep it clean.

---

### Radiance Bars

Two charge bars that fill as your Power Word: Radiance charges come off cooldown. Gives you a quick at-a-glance view of how far through the cooldown each charge is without watching cooldown numbers.

The cooldown is detected automatically from your talents — 15s with Bright Pupil, 18s baseline. The detected talent is shown at the top of the tab.

**Setup:**
1. Enable the module on the General tab.
2. Open the Radiance Bars tab and configure size, fill color, and whether to show a countdown timer on the actively recharging bar.
3. Use **Unlock to Move** to drag the bars anywhere, then **Lock Position** to save.

---

### Void Shield Deck

Tracks your Void Shield talent deck. Void Shield works as a 3-card deck (2 non-proc cards and 1 proc card). Each Penance cast draws a card; the proc chance is 1-in-remaining cards. The module displays your current proc chance, how many cards remain in the deck, and fires a sound + visual alert the moment a proc is detected.

**How detection works:** the module watches the texture of your Power Word: Shield action bar button after each Penance cast. When it detects the Void Shield texture, a proc has occurred.

**Widgets:** three independent draggable elements — the proc chance display, the deck card count, and the individual card indicators. Each can be positioned separately.

**Setup:**
1. Enable the module on the General tab.
2. Open the Void Shield tab and configure:
   - **Display** — toggle each of the three sub-widgets on or off, adjust their sizes and colors.
   - **Proc Alert** — enable a sound and/or on-screen flash when a proc is detected. Choose the sound from the dropdown.
   - **Desync correction** — if the tracker falls out of sync (4 Penance casts with no proc detected), it automatically corrects to the most likely deck state.
3. Position each widget independently using the lock/unlock buttons in the Position section.

> **Note:** Void Shield requires Power Word: Shield to be on an action bar (any bar, including addon bars). If you remove it from your bars mid-session the tracker will warn you.

---

## General Settings

- **Audio Channel** — which WoW audio channel sounds play through (SFX, Master, Music, Ambience, Dialog).
- **Interface Font** — changes the font used throughout the addon's UI. Supports LibSharedMedia fonts if installed.

---

## Slash Commands

| Command | What it does |
|---|---|
| `/pwtb` | Open the options window |
| `/pwtb debug` | Toggle debug logging to chat |
| `/pwtb status` | Print full addon state to chat |
| `/pwtb reset` | Re-centre the options window if it goes off-screen |
| `/pwtb seqreset` | Reset the PI sequence back to position 1 |
