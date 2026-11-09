# Ubuntu desktop (Niri / GNOME / Ubuntu)

Точки входа (реализация в `src/`):

| Скрипт | Действие |
|--------|----------|
| `download_desired_apps.sh` | `apt install` из `desired-apps.toml` |
| `update_desired_apps.sh` | `apt upgrade` |
| `apply_settings_to_desired_apps.sh` | zsh + Oh My Zsh + dotfiles |
| `delete_desired_apps.sh` | Удалить пакеты из списка |
| `setup_desktop.sh` | `download` + `apply` подряд |

```bash
git clone https://github.com/Xander-Lein/setup.git
cd setup/ubuntu_desktop
bash setup_desktop.sh
```

Тестирование на живой Ubuntu — отдельным шагом.
