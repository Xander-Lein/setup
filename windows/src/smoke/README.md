# Smoke tests

| Script | Purpose |
|--------|---------|
| `Invoke-SetupHostSmoke.ps1` | Pester + all `*.bat --dry-run` |
| `Test-AiWorkflowLink.ps1` | commands/skills after `link_ai_workflow_cursor.ps1` |
| `Initialize-HyperVSmokeVm.ps1` | Create `LibrarySetupSmoke` VM (Admin + Hyper-V) |

```powershell
powershell -ExecutionPolicy Bypass -File src\smoke\Invoke-SetupHostSmoke.ps1
```

Hyper-V (elevated PowerShell, feature enabled):

```powershell
powershell -ExecutionPolicy Bypass -File src\smoke\Initialize-HyperVSmokeVm.ps1
```

Attach a Windows ISO, install the guest OS, then run `setup_system.bat --dry-run` from the shared copy under `%LOCALAPPDATA%\Library\setup\vm-share\setup`.
