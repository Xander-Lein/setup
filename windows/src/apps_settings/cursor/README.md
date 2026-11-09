# Терминал Cursor / VS Code

Горячие клавиши из `setup` настроены для **Alacritty** (`Win+T`).

Во встроенном терминале Cursor **`Ctrl+Shift+C` / `Ctrl+Shift+V` перехватывает сам редактор**, а не zsh. Для copy/paste в IDE — это нормально, для zsh-hotkeys — открой отдельное окно Alacritty.

Если нужны те же сочетания во встроенном терминале, отключи стандартные бинды в Cursor (Keyboard Shortcuts → `terminal.copySelection` / `terminal.paste`) и включи `Terminal › Integrated: Send Keybindings To Shell`.
