# Status item does not dim on unfocused display (2026-10-21)

## Symptom

On a multi-display Mac, the menu bar on the unfocused display dims. Native
items and third-party items (Bitwarden) dim. Our status item stays at full
brightness. User observation confirmed Bitwarden fades; this rules out any
first-party-only limitation.

## Root cause [measured]

AppKit replicates each `NSStatusItem` to secondary displays as a bitmap
snapshot drawn by `NSStatusItemReplicantView`. The dim gate:

    alreadyStyled = ((button.image == nil) || button.image.isTemplate)
                     && didInactiveTemplateStyling

If `alreadyStyled` is true, AppKit assumes the cell already dimmed its own
template content and draws the snapshot at alpha 1.0. Otherwise it calls
`-[NSStatusItemReplicantView setSnapshotImage:needsInactiveTemplateStyling:...]`,
which draws the whole snapshot (SwiftUI content included) at
`+[NSStatusItemReplicantView inactiveAlphaForAppearance:]` = 0.5.

We leave `button.image == nil`, so the gate is true for an *empty* cell and
the dim pass is skipped.

Measured locations (local AppKit.framework, arm64):

- `-[NSStatusItem _redrawReplicantSnapshot:sourceView:]` at `0x18cba5564`;
  gate at `0x18cba57c4-0x18cba5930`.
- `-[NSStatusItemReplicantView setSnapshotImage:...]` at `0x18cf96984`;
  `inactiveAlphaForAppearance:` at `0x18cf96d30` returns 0.5 for aqua and
  darkAqua.

## Prior art [cited]

- Bitwarden sets a template image, so it takes the dim path:
  `bitwarden/clients` `apps/desktop/src/main/tray.main.ts:34-36`.
- exelban/stats fixed the same symptom with `button.image = NSImage()`:
  commits `11b34498c47fb8d013b1cb4553c8dcdfe4aad5e4`,
  `9f2135f41a44e2f2baa61fbbbf2c657397478173`.
  Issue: https://github.com/exelban/stats/issues/2131
- Similar stacked-title case: https://github.com/steipete/CodexBar/issues/4532
  (their fix rasterizes to a template image; rejected for us, see below).

## Fix decision

Assign a shared, empty, non-template `NSImage()` to `button.image` in
`StatusItemController.init`. The gate then reads `alreadyStyled = false`
and AppKit applies its own 0.5 snapshot dim to the full item.

Self-applied opacity or desaturation is rejected: it would drift from the
system dim level and double-dim once the gate is fixed. Template-image
rasterization (CodexBar path) is rejected: template images strip color
channels, destroying colored metric dots and warning/critical tints.

## Accepted risks

- With `allowsVibrancy` true and a non-template image, AppKit toggles the
  image's template flag during snapshot redraw. The image is empty
  (no pixels), so no visual effect.
- VoiceOver announcement order and `button.bounds` must stay unchanged;
  covered by existing accessibility and layout tests.

## Design acceptance checklist (VAC)

Adapted from the designer's Design Blueprint (session
2026-10-21T21-32-40-807Z). Under the approved fix, the dim is AppKit's
system snapshot alpha (0.5, measured above). No self-applied opacity
exists in the code, so no VAC checks app-side opacity code. VAC-1,
VAC-2, and VAC-3 require the human dual-display check.

- VAC-1 Light unfocused dimming: on an unfocused display in Light
  appearance, the item dims uniformly and matches adjacent native items
  (Clock, Control Center) and Bitwarden.
- VAC-2 Dark unfocused dimming: same check in Dark appearance.
- VAC-3 Refocus restore: focus return restores full brightness at once;
  no persistent dimming or ghosting.
- VAC-4 Zero layout shift: in both states, block widths (39 pt standard,
  50 pt network), row heights (11 pt), spacing, and text positions stay
  bit-identical. No wrapping, clipping, or reflow.
- VAC-5 Hierarchy: 8 pt secondary labels stay subordinate to 12 pt
  monospaced primary values in both states.
- VAC-6 MEM pressure dot keeps its green/yellow/red hue when dimmed; it
  must not read as neutral gray (gray means "unknown" pressure).
- VAC-7 Network dots keep hue when dimmed: upload red, download
  cyan (dark) / blue (light).
- VAC-8 Warning/critical value tints (orange/red) stay distinguishable
  from standard text when dimmed.
- VAC-9 Discrete transitions: status item code contains zero
  `.animation`, zero `.contentTransition`, and no CoreAnimation fades.
- VAC-10 Popover interplay: while the popover is open the item renders
  at full brightness (the popover only opens from the focused display;
  transient dismissal on focus loss restores the dim).
- VAC-11 VoiceOver invariance: accessibility title ("Stats Lite") and
  composite label stay bit-identical across focus states; VoiceOver
  never speaks "dimmed" or "inactive".
