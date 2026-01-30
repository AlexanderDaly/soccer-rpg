# Bug Report: Desktop Windows Not Interactive

## Summary
Windows inside the in‑game desktop (OS) cannot be interacted with: buttons don’t respond and the close/minimize controls are nonfunctional. This appears to be caused by the window container (`WindowLayer`) ignoring mouse input, which prevents its child windows from receiving GUI events.

## Environment
- Project: Soccer Career RPG (Godot 4.2+)
- Area: In‑game desktop UI
- Scene: `res://scenes/desktop/desktop_shell.tscn`

## Steps to Reproduce
1. Launch the game and enter the desktop/OS environment.
2. Open any app (e.g., “Save Manager” or “Training Center”).
3. Try to click buttons inside the window or the close/minimize buttons in the title bar.

## Expected Behavior
- Window UI controls respond to clicks (buttons trigger actions, close/minimize works).

## Actual Behavior
- Buttons and window controls do nothing; clicks appear to be ignored.

## Suspected Root Cause
`WindowLayer` in `desktop_shell.tscn` is set to `mouse_filter = 2` (MOUSE_FILTER_IGNORE). In Godot, a `Control` with `mouse_filter = IGNORE` is skipped for mouse hit‑testing, which prevents its children from receiving GUI input. Since all windows are added under `WindowLayer`, they never receive mouse events.

**Evidence**
- `res://scenes/desktop/desktop_shell.tscn`:
  - Node: `WindowLayer`
  - Property: `mouse_filter = 2`

## Suggested Fix
- Set `WindowLayer.mouse_filter` to `MOUSE_FILTER_PASS` or `MOUSE_FILTER_STOP` so it (and its children) can receive mouse events.
- (Optional) Apply the same adjustment to `NotificationContainer` if notification toasts should be clickable.

## Impact
- Blocks all interactions within desktop app windows, making the OS environment unusable.
