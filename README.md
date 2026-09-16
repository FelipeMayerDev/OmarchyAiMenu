# Omarchy AI Assistant

A standalone centered input for asking an installed AI harness. The normal Omarchy
menu stays unchanged; follow-up questions remain in the assistant window and session.
Answers render Markdown and fenced code blocks. When the model offers suggested
replies, click one to send it as the next message in the same session.
Type `/new` to clear the conversation and start a fresh harness session.

Open settings from the top-left gear or right-click the bar icon. Installed
OpenCode, Codex, Claude, and OMP harnesses are detected automatically; their local
model catalogs and supported effort levels populate the selectors.
Harnesses that are not installed are omitted from settings.
The overlay uses the theme's standard menu glass (translucent fill, themed border,
compositor blur) and animates closed like the built-in menus.
Answers stream into the conversation as the harness generates them. A YOLO mode
toggle lets the assistant run commands without asking, using each harness's own
bypass mechanism. Selections persist when you press Save in settings.

## Install

At least one harness must already be installed and authenticated (for example,
OpenCode):

```bash
opencode providers
```

Then install and enable this repository:

omarchy plugin add https://github.com/FelipeMayerDev/OmarchyAiMenu.git --enable
```

Open it from its bar icon or bind a key to:

```lua
o.bind("ALT + P", "AI assistant", "omarchy-shell shell toggle focky.ai-menu '{}'")
```

The bar icon is optional; add `{ "id": "focky.ai-menu" }` to the bar layout in
`~/.config/omarchy/shell.json` if you prefer a clickable entry. The keybind alone
is enough.

## Check

```bash
omarchy plugin validate .
node test.js
```
