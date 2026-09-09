# Raid Callouts

Raid Callouts is a small World of Warcraft 3.3.5 addon created by **xLT69x**
for raid leaders and assistants. It creates a futuristic blue, movable panel
of one-click raid warning buttons and includes a draggable minimap button.

<img width="252" height="222" alt="RaidCallOuts Frame" src="https://github.com/user-attachments/assets/714a3362-2002-480f-bbf7-dcde3bcfd6ed" />

## Install

1. Download or copy the `RaidCallouts` folder.
2. Put it in your WoW installation's `Interface/AddOns` folder.
3. Make sure the folder contains `RaidCallouts.toc` and `RaidCallouts.lua`.
4. Start the game and enable **Raid Callouts** on the AddOns screen.

The addon does not require Ace3 or any other library.

## Included buttons

- Everyone Follow Me
- Back to me
- Go Go GO !
- Kill > `%t` <

`%t` is replaced by the name of your current target when the button is
clicked. If you have no target, it becomes `No Target`.

## Slash commands

```text
/rc
/rc toggle
/rc hide
/rc config
/rc lock
/rc unlock
/rc minimap
/rc add Button Label | Raid warning text
/rc remove ButtonNumber
/rc reset
/rc help
```

Examples:

```text
/rc add Spread Out | Spread out now!
/rc add Interrupt | Interrupt > %t <
/rc add Skull Target | {skull} Kill > %t < {skull}
/rc remove 5
```

The panel position, options, and custom buttons are saved account-wide. You
must be in a raid and be raid leader or raid assistant to send
`RAID_WARNING` messages.
Callout buttons use the World of Warcraft 3.3.5 raid-roster rank API so they
work correctly for both raid leaders and promoted raid assistants.

Left-click the minimap logo to show or hide the panel. Right-click it to lock
or unlock the panel, or drag it to reposition it around the minimap.

## Configuration

Type `/rc config` to open the standalone Raid Callouts configuration window.
It does not depend on Blizzard's Interface Options window.

<img width="635" height="535" alt="RaidCallouts config3" src="https://github.com/user-attachments/assets/dbe73782-f200-41ce-9502-fcd066fee5b9" />
<img width="637" height="540" alt="RaidCallouts config2" src="https://github.com/user-attachments/assets/eee5bac2-a834-41ae-b4ff-ebf436681e45" />
<img width="642" height="540" alt="RaidCallouts config1" src="https://github.com/user-attachments/assets/20b4a841-c9c5-4d32-b145-5d66bd1f4b84" />


The blue configuration panel includes:

- Locking, minimap visibility, creator credit, startup messages, sent-message
  confirmations, and sound options
- A customizable no-target replacement for `%t`
- Window scale, width, and opacity controls
- Button height, opacity, and font size controls
- Minimap button distance and compact, standard, or large size presets
- A callout editor for adding, renaming, rewriting, reordering, deleting, and
  resetting raid-warning buttons

## Raid markers

Marker names in braces are converted to native Wrath raid-icon tokens:

```text
{star} {circle} {diamond} {triangle}
{moon} {square} {cross} {skull}
```

You can also use `{rt1}` through `{rt8}` directly. Marker names are
case-insensitive. The **Callouts** configuration tab includes clickable marker
icons that append the correct token to the selected message field.
