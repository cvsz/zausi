@echo off
rem ============================================================================
rem  Install.cmd - AUSI Model Developer infrastructure toolchain bootstrap
rem  Installs operator CLIs referenced by docs\AUSI-OPERATIONS-GUIDE.md Stage 1
rem  (git, terraform, helm, kubectl, python) via winget, falling back to choco.
rem  Idempotent: anything already on PATH is skipped. This installer touches NO
rem  cluster and applies NOTHING - production mutation requires human approval
rem  through the agy skill flow (see skills\agy\SKILL.md and the blueprint
rem  Tier-3 red line in docs\AUSI-SUPER-ULTRA-ORCHESTRATOR-BLUEPRINT.md).
rem ============================================================================
setlocal EnableExtensions

echo ============================================================================
echo   AUSI Model Developer - Infrastructure Toolchain Installer
echo ============================================================================

where git       >nul 2>nul && echo [OK]    git found        || call :try_install git      Git.Git
where terraform >nul 2>nul && echo [OK]    terraform found  || call :try_install tf       Hashicorp.Terraform
where helm      >nul 2>nul && echo [OK]    helm found       || call :try_install helm     Kubernetes.Helm
where kubectl   >nul 2>nul && echo [OK]    kubectl found    || call :try_install kubectl  Kubernetes.kubectl
where python    >nul 2>nul && echo [OK]    python found     || call :try_install py       Python.Python.3.12

echo.
echo Post-install verification:
echo   terraform version ^&^& helm version ^&^& kubectl version --client
echo Then follow docs\AUSI-OPERATIONS-GUIDE.md starting at Stage 1.
goto :eof

:try_install
rem %1 = friendly name, %2 = winget package id
echo [..] Installing %1 via winget (%2)...
winget install --id=%2 --accept-source-agreements --accept-package-agreements -e
if errorlevel 1 (
    echo [WARN] winget failed for %1; trying chocolatey if present...
    where choco >nul 2>nul && choco install %1 -y --no-progress
)
goto :eof
