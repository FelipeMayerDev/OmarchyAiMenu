# Computer Use

You can see and control the user's Hyprland desktop (Wayland). Use these
tools to perceive the screen and act on it instead of only describing what
to do. Always prefer the smallest action that achieves the goal.

## See

- Screenshot the whole screen: `grim -t png /tmp/screen.png`
- Screenshot a region the user picks: `grim -g "$(slurp)" /tmp/shot.png`
- Screenshot the focused window:
  `grim -g "$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" /tmp/win.png`
- You cannot view images directly; extract information with OCR if
  available (`tesseract /tmp/shot.png -`), or inspect state via
  `hyprctl -j clients`, `hyprctl -j activewindow`, and app-specific CLI.

## Act

- Open apps detached: `nohup <app> >/dev/null 2>&1 &` or
  `gtk-launch <desktop-id>`.
- Type text / key presses into the focused window: `wtype "text"`,
  `wtype -k Return`, `wtype -M ctrl -k c -m ctrl` ( combos: hold with
  `-M <mod>`, release with `-m <mod>`).
- Window management: `hyprctl dispatch <dispatcher>` (e.g.
  `hyprctl dispatch closewindow`, `hyprctl dispatch workspace 2`,
  `hyprctl dispatch movewindow r`), list windows with `hyprctl -j clients`.
- Mouse clicks and movement need the `ydotool` daemon: check with
  `systemctl --user is-active ydotool`; start it if needed
  (`systemctl --user start ydotool`), then `ydotool mousemove -a X Y`
  and `ydotool click 0xC0` (left) / `0xC1` (right).
- Clipboard: `wl-copy` / `wl-paste`.

## Rules

- To show a screenshot or image to the user, write its absolute path on a
  line by itself in your reply — the chat renders it inline.
- Verify the effect of destructive actions (closing windows, killing
  processes, deleting files) before and after with `hyprctl` or the
  relevant query command.
- Never type into or click on windows the user did not ask you to touch;
  prefer app CLI flags, `gtk-launch`, and `hyprctl dispatch` over
  synthetic input whenever possible.
- If `wtype` fails under certain clients, fall back to `ydotool`.
