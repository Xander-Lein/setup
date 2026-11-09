# Windows 11

Точки входа (остальное в `src/`):

| Bat | Действие |
|-----|----------|
| `download_desired_apps.bat` | Установить приложения из `desired-apps.toml` (winget + GitHub), без upgrade |
| `update_desired_apps.bat` | Обновить те же приложения |
| `apply_settings_to_desired_apps.bat` | Терминал, системные утилиты, Neovim и ассоциации из `desired-apps-settings.toml` |
| `delete_desired_apps.bat` | Удалить приложения **с этого ПК** (git не трогает) |
| `setup_system.bat` | Полная идемпотентная настройка Windows |
| `refresh_session.bat` | Применить буфер/языки без выхода и без перезагрузки ПК (перезапуск оболочки) |

Конфиги:

- `desired-apps.toml` — список приложений
- `desired-apps-settings.toml` — ассоциации файлов и прочие настройки

Первый запуск на новом ПК:

```bat
download_desired_apps.bat
apply_settings_to_desired_apps.bat
```

Полная настройка одной командой:

```bat
setup_system.bat --verbose --no-reboot
```

Доступные параметры `setup_system.bat`:

```text
--dry-run    показать действия без изменений
--verbose    подробный лог
--no-reboot  не перезагружать ПК (по умолчанию: вместо reboot — перезапуск Explorer и Shell)
```

Логи сохраняются в `%LOCALAPPDATA%\Library\setup\logs`.

Обычный запуск точек установки и обновления автоматически запрашивает права
администратора один раз. `winget` передаёт установщикам
`--accept-package-agreements`, `--disable-interactivity` и `--silent`, но
отдельные приложения могут всё равно показать собственное окно или запрос UAC.
Это ограничение конкретного установщика, а не TOML-конфигурации.

Для Everything первый запуск может предложить установить системную службу для
индексации NTFS. Это отдельная настройка самого Everything; без службы поиск
файлов работает в пользовательском режиме.

После `apply_settings` / `setup_system` setup **сам** перезапускает оболочку Windows
(`ShellExperienceHost`, `ctfmon`, проводник ~2 с). **Перезагрузка ПК не обязательна.**

Если `Win+V` или индикатор языка отстаёт — один раз `refresh_session.bat`. Скрипт
в автозагрузке на следующий **вход** в Windows подстрахует то же без reboot.

## Модули

Внутренняя реализация находится в `src/`:

- `modules/install_package_managers.ps1` — проверка `winget`;
- `modules/configure_system_utilities.ps1` — языки, буфер обмена и хоткеи;
- `modules/configure_neovim.ps1` — базовый Neovim;
- `apps_settings/` — конфигурации терминала и приложений.

Windows настраивается на польский и русский языки. Переключение раскладки —
`Alt+Shift`, история буфера — `Win+V`, терминал — `Win+T`, Everything —
`Win+F`, Zen Browser — `Win+B`, Диспетчер задач — `Win+M`.

Терминал: **Alacritty → MSYS2 → zsh** (`Win+T`). Hotkeys: **Ctrl+Shift+C/V**, **Shift+стрелки**, **Ctrl+Backspace/Delete**. Во **встроенном терминале Cursor** эти сочетания перехватывает редактор — см. `src/apps_settings/cursor/README.md`.

Тесты:

```powershell
powershell -ExecutionPolicy Bypass -File src\run-tests.ps1
```

Интеграция Cursor в проект: скопируйте `src\link_ai_workflow_cursor.ps1` в корень проекта и запустите:

```powershell
powershell -ExecutionPolicy Bypass -File .\link_ai_workflow_cursor.ps1
```

Скрипт клонирует или обновляет `https://github.com/Xander-Lein/ai_workflow`
в общем локальном кэше, создаёт `.cursor` как junction и добавляет скрипт
с `.cursor/` в `.gitignore` проекта.
