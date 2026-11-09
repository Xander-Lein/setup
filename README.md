# setup

Monorepo: приложения и настройки по **ОС/дистро**. В git не входят: `wallpapers/`, `.cursor/` (junction через [ai_workflow](https://github.com/Xander-Lein/ai_workflow)).

| Каталог | Назначение |
|---------|------------|
| [`windows/`](windows/) | Windows 11 — winget, GitHub, Alacritty + MSYS2 + zsh |
| [`ubuntu_desktop/`](ubuntu_desktop/) | Ubuntu desktop — apt + zsh dotfiles |

## Новый ПК (Windows)

```bat
git clone https://github.com/Xander-Lein/setup.git
cd setup\windows
setup_system.bat --verbose --no-reboot
```

Без перезагрузки ПК после настройки: `refresh_session.bat`.

## Ubuntu desktop

```bash
git clone https://github.com/Xander-Lein/setup.git
cd setup/ubuntu_desktop
bash setup_desktop.sh
```

Полноценное тестирование на Ubuntu — отдельно, по запросу.

## Cursor AI workflow

```powershell
# В корне любого проекта (скопируйте link_ai_workflow_cursor.ps1 или укажите путь из setup):
powershell -ExecutionPolicy Bypass -File .\windows\src\link_ai_workflow_cursor.ps1 -ProjectRoot .
```

Подключает [Xander-Lein/ai_workflow](https://github.com/Xander-Lein/ai_workflow) из GitHub: commands, skills, rules, agents, hooks; обновляет `.gitignore`.

## Конфиги

| Файл | Содержимое |
|------|------------|
| `*/desired-apps.toml` | Что установить |
| `*/desired-apps-settings.toml` | Настройки (ассоциации Windows, zsh profile) |

Точки входа в каталоге ОС; реализация в `src/`.
