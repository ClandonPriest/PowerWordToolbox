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
4. Configure alert settings:
   - **Glow** — choose between a full overlay or outer border ring style, pick a color, and adjust opacity and pulse speed. Use the Test button to preview on your own frame.
   - **Sound** — pick a sound and volume. Supports LibSharedMedia if installed.
   - **Early Request** — when PI is still on cooldown and a whisper arrives within the grace window (default 5s before it comes back), the glow triggers early with a live countdown so you can pre-aim.
5. Optionally enable the **Name Overlay** — a floating bouncing frame showing the PI target's name and icon. Unlock it to drag it anywhere on screen.

---

### Atonement Tracker

Displays the current number of active Atonements on your group and optionally shows the shortest remaining timer so you know when to refresh before Penance.

**Setup:**
1. Enable the module on the General tab.
2. Open the Atonement tab and configure:
   - **Show lowest Atonement timer** — adds a countdown below the count that turns yellow below 6s and red below 3s.
   - **Follow mouse cursor** — the widget floats near your cursor as you cast. Choose which corner of the widget attaches to the cursor.
   - **Text Size** — set font sizes for the count and timer independently.
3. Use **Unlock to Move** in the Position section to drag the widget anywhere, then **Lock Position** to save it.
4. **Reset Position** returns the widget to the screen centre.

The drag handle and background appear only when unlocked. Lock before raiding to keep the display clean.

---

### Radiance Bars

Two charge bars showing how far through the cooldown each Power Word: Radiance charge is. Gives an at-a-glance fill progress without watching numbers.

The cooldown is detected automatically from your talents — 15s with Bright Pupil, 18s baseline. The detected talent is shown at the top of the tab.

**Setup:**
1. Enable the module on the General tab.
2. Open the Radiance Bars tab and configure bar size, fill color, text color, and whether to show a countdown timer on the actively recharging charge.
3. Use **Unlock to Move** to drag the bars anywhere, then **Lock Position** to save.

---

### Void Shield Deck

Tracks your Void Shield proc. Void Shield works as a 3-card deck: 2 non-proc cards and 1 proc card. Each Penance cast draws one card. The proc chance is 1-in-remaining-cards. The tracker shows your current proc chance, cards remaining in the deck, and fires a configurable sound and visual alert the moment a proc is detected.

**How detection works:** after each Penance cast, the tracker checks the texture of your Power Word: Shield action bar slot. When it sees the Void Shield icon, a proc has occurred.

**Three independent draggable widgets:**
- **Chance** — shows the current proc probability (e.g. 50%, 100%)
- **Deck** — shows cards remaining out of 3
- **Cards** — colour-coded card indicators (green = proc card, red = no-proc cards)

**Setup:**
1. Enable the module on the General tab.
2. Open the Void Shield tab:
   - **Display** — toggle each widget on or off; adjust font sizes, card sizes, and custom colors for each card type.
   - **Cards Rotated** — switches the card indicators from a horizontal row to a vertical stack.
   - **Proc Alert** — enable a floating Void Shield icon that appears when a proc is detected. Configure its size, position, and frame strata.
   - **Proc Sound** — plays a sound on proc detection. Supports LibSharedMedia for custom sounds.
3. Position each widget independently using its lock/unlock button in the Position section.

**Unknown state:** the tracker enters an unknown state (shows `?`) on login, after a potential disconnect, or when it cannot confidently determine the deck position. It clears automatically when a confirmed resync pattern is detected in your cast history, or when entering a raid encounter or starting a new Mythic+ key.

> **Note:** Void Shield requires Power Word: Shield to be on an action bar (any bar, including addon bars like Bartender4 or ElvUI). If PWS is removed from your bars mid-session, a warning will appear on screen.

---

## General Settings

- **Audio Channel** — which WoW audio channel sounds play through (SFX, Master, Music, Ambience, Dialog).
- **Interface Font** — changes the font used across the addon's UI. Supports LibSharedMedia fonts if installed.
- **Show Chat Messages** — toggles all addon chat output.
- **Show Login Message** — toggles the "Loaded!" message on login.

---

## Slash Commands

All commands work with `/pwtb`, `/powerwordtoolbox`, `/ptw`, or `/pwt`.

| Command | What it does |
|---|---|
| `/pwtb` | Open the options window |
| `/pwtb help` | Print all slash commands to chat |
| `/pwtb debug` | Toggle debug logging to chat |
| `/pwtb rdebug` | Toggle Radiance cast event debug logging |
| `/pwtb status` | Print full addon state to chat |
| `/pwtb spellcheck` | Check the PI cooldown tracker state |
| `/pwtb seqreset` | Reset the PI sequence back to position 1 |
| `/pwtb reset` | Re-centre the options window if it goes off-screen |
| `/pwtb coords` | Print the saved and current player coordinates used by the Void Shield position check |
| `/pwtb vsguide` | Open the Void Shield deck guide |
| `/pwtb casthistory` | Print the Void Shield cast history to chat |
| `/pwtb mplusguard` | Print the M+ event guard state (for testing) |
| `/pwtb forceunknown` | Force the Void Shield deck into unknown state (for testing) |
| `/pwtb forceknown` | Force the Void Shield deck into a known state (for testing — values will be incorrect) |
