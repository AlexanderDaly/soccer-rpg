# Bug Report 002: Cannot Click on Buttons in Game OS

## Summary
In the in‑game OS/desktop environment, nothing is clickable (desktop icons, window buttons, taskbar). Mouse input appears blocked by full‑screen overlay controls.

## Steps to Reproduce
1. Enter the OS/desktop scene.
2. Attempt to click any desktop icon or app window button.
3. Observe that nothing responds.

## Expected Behavior
Desktop icons and window controls respond to mouse clicks.

## Actual Behavior
All clicks are ignored; UI is non‑interactive.

## Likely Root Cause
Two full‑screen `Control` nodes in `desktop_shell.tscn` are set to `mouse_filter = 1` (PASS). In Godot, a full‑screen Control with PASS still becomes the input target and blocks controls behind it. The topmost node `NotificationContainer` covers the entire screen, so it intercepts all mouse input.

### Evidence
- `scenes/desktop/desktop_shell.tscn`
  - `NotificationContainer`: `mouse_filter = 1` (PASS), full‑screen, topmost in scene tree.
  - `WindowLayer`: `mouse_filter = 1` (PASS), full‑screen.

## Suggested Fix
- Set `NotificationContainer.mouse_filter` to `MOUSE_FILTER_IGNORE` so it does not block clicks when empty.
- Consider setting `WindowLayer.mouse_filter` to `MOUSE_FILTER_IGNORE` (or only enable input when a window is under the cursor) to avoid blocking desktop icons.

## Impact
Blocks all interaction in the OS environment, making the UI unusable.
