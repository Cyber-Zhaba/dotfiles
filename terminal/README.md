# Terminal keybinds

tmux splits horizontally on `Alt+Shift+Enter`. With legacy key encoding a
terminal sends that byte-for-byte identically to `Alt+Enter`, so tmux sees only
the vertical-split binding and the horizontal one never fires. The fix is to
make the terminal emit CSI-u for those two chords; tmux already runs with
`extended-keys on` and `extended-keys-format csi-u`.

`install.sh` appends `ghostty.conf` or `kitty.conf` to the matching config when
it finds one, guarded by a marker comment so re-running changes nothing.

Alacritty is **not** patched automatically: its bindings live in a TOML array
(`[keyboard] bindings = [...]`), and blindly appending a second `[keyboard]`
table would produce an invalid config. Merge `alacritty.toml` into the existing
array by hand.
