@echo off
setlocal enabledelayedexpansion

REM ==============================================================================
REM  RUNWRAPPERS_OCI_LANDING_ZONES_v3.7.cmd
REM ==============================================================================
REM  Proposito: Ejecutar los wrappers PowerShell para generar y distribuir
REM            los archivos tfvars de dependencias de cada modulo upstream.
REM
REM  Orden de ejecucion:
REM    1. Foundation wrapper    -> genera foundation_dependencies.auto.tfvars.json
REM    2. Identity wrapper      -> genera identity_dependencies.auto.tfvars.json
REM    3. Network wrapper       -> genera network_dependencies.auto.tfvars.json
REM
REM  PREREQUISITOS:
REM    - Todos los terraform apply deben estar COMPLETOS en Foundation, Identity, Network
REM    - Los outputs deben estar disponibles en terraform state
REM    - PowerShell 7+ debe estar instalado
REM
REM  USO:
REM    cmd /c RUNWRAPPERS_OCI_LANDING_ZONES_v3.7.cmd
REM ==============================================================================
echo.
echo ==============================================================================
echo  WRAPPERS: Generar y Distribuir Dependencias
echo ==============================================================================
echo.
echo Prerequisitos: terraform apply COMPLETADO en Foundation, Identity, Network
echo.
pause

set "ROOT_DIR=c:\gitlab\GISS_iac_oci"
set "LOG_DIR=%ROOT_DIR%\log_wrappers"

setlocal
if not exist "%LOG_DIR%" (mkdir "%LOG_DIR%")

REM ==============================================================================
REM  [00] FOUNDATION WRAPPER
REM ==============================================================================
echo ==============================================================================
echo  [00] FOUNDATION WRAPPER - Generar foundation_dependencies.auto.tfvars.json
echo ==============================================================================
echo.
echo [00.1] Navegando a Foundation module
cd /d c:\gitlab\ga_ioci0000_iac-oci-foundation
echo PWD: %cd%
pause

echo.
echo [00.2] Ejecutando wrapper Foundation
echo Comando: powershell -NoProfile -ExecutionPolicy Bypass -File .\dependencies\foundation_dependencies.ps1 -DistributeDownstream $true
powershell -NoProfile -ExecutionPolicy Bypass -File .\dependencies\foundation_dependencies.ps1 -DistributeDownstream $true > "%LOG_DIR%\00_foundation_wrapper.log" 2>&1
type "%LOG_DIR%\00_foundation_wrapper.log"
if errorlevel 1 (
  echo [ERROR] Fallo wrapper Foundation. Revisa: %LOG_DIR%\00_foundation_wrapper.log
  exit /b 1
)
pause

REM ==============================================================================
REM  [01] IDENTITY WRAPPER
REM ==============================================================================
echo ==============================================================================
echo  [01] IDENTITY WRAPPER - Generar identity_dependencies.auto.tfvars.json
echo ==============================================================================
echo.
echo [01.1] Navegando a Identity module
cd /d c:\gitlab\ga_ioci0010_iac-oci-identity
echo PWD: %cd%
pause

echo.
echo [01.2] Ejecutando wrapper Identity
echo Comando: powershell -NoProfile -ExecutionPolicy Bypass -File .\dependencies\identity_dependencies.ps1 -DistributeDownstream $true
powershell -NoProfile -ExecutionPolicy Bypass -File .\dependencies\identity_dependencies.ps1 -DistributeDownstream $true > "%LOG_DIR%\01_identity_wrapper.log" 2>&1
type "%LOG_DIR%\01_identity_wrapper.log"
if errorlevel 1 (
  echo [ERROR] Fallo wrapper Identity. Revisa: %LOG_DIR%\01_identity_wrapper.log
  exit /b 1
)
pause

REM ==============================================================================
REM  [02] NETWORK WRAPPER
REM ==============================================================================
echo ==============================================================================
echo  [02] NETWORK WRAPPER - Generar network_dependencies.auto.tfvars.json
echo ==============================================================================
echo.
echo [02.1] Navegando a Network module
cd /d c:\gitlab\ga_ioci0020_iac-oci-network
echo PWD: %cd%
pause

echo.
echo [02.2] Ejecutando wrapper Network
echo Comando: powershell -NoProfile -ExecutionPolicy Bypass -File .\dependencies\network_dependencies.ps1 -DistributeDownstream $true
powershell -NoProfile -ExecutionPolicy Bypass -File .\dependencies\network_dependencies.ps1 -DistributeDownstream $true > "%LOG_DIR%\02_network_wrapper.log" 2>&1
type "%LOG_DIR%\02_network_wrapper.log"
if errorlevel 1 (
  echo [ERROR] Fallo wrapper Network. Revisa: %LOG_DIR%\02_network_wrapper.log
  exit /b 1
)
pause

REM ==============================================================================
REM  VERIFICACION: Confirmar tfvars distribuidos
REM ==============================================================================
echo.
echo ==============================================================================
echo  VERIFICACION: Confirmar archivos tfvars en todos los directorios
echo ==============================================================================
echo.

setlocal enabledelayedexpansion
set "error_count=0"
set "success_count=0"

REM Verifica Identity
if exist "c:\gitlab\ga_ioci0010_iac-oci-identity\dependencies\foundation_dependencies.auto.tfvars.json" (
  echo [OK] Identity: foundation_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Identity: foundation_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

REM Verifica Network - necesita foundation + identity
if exist "c:\gitlab\ga_ioci0020_iac-oci-network\dependencies\foundation_dependencies.auto.tfvars.json" (
  echo [OK] Network: foundation_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Network: foundation_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0020_iac-oci-network\dependencies\identity_dependencies.auto.tfvars.json" (
  echo [OK] Network: identity_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Network: identity_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

REM Verifica Security SVC - necesita foundation + identity + network
if exist "c:\gitlab\ga_ioci0030_iac-oci-security-svc\dependencies\foundation_dependencies.auto.tfvars.json" (
  echo [OK] Security-SVC: foundation_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Security-SVC: foundation_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0030_iac-oci-security-svc\dependencies\identity_dependencies.auto.tfvars.json" (
  echo [OK] Security-SVC: identity_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Security-SVC: identity_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0030_iac-oci-security-svc\dependencies\network_dependencies.auto.tfvars.json" (
  echo [OK] Security-SVC: network_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Security-SVC: network_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

REM Verifica ExaCS Infra
if exist "c:\gitlab\ga_ioci0040_iac-oci-exa-infra\dependencies\foundation_dependencies.auto.tfvars.json" (
  echo [OK] ExaCS-Infra: foundation_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] ExaCS-Infra: foundation_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0040_iac-oci-exa-infra\dependencies\identity_dependencies.auto.tfvars.json" (
  echo [OK] ExaCS-Infra: identity_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] ExaCS-Infra: identity_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0040_iac-oci-exa-infra\dependencies\network_dependencies.auto.tfvars.json" (
  echo [OK] ExaCS-Infra: network_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] ExaCS-Infra: network_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

REM Verifica ExaCS Database
if exist "c:\gitlab\ga_ioci0041_iac-oci-exa-database\dependencies\foundation_dependencies.auto.tfvars.json" (
  echo [OK] ExaCS-Database: foundation_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] ExaCS-Database: foundation_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0041_iac-oci-exa-database\dependencies\identity_dependencies.auto.tfvars.json" (
  echo [OK] ExaCS-Database: identity_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] ExaCS-Database: identity_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0041_iac-oci-exa-database\dependencies\network_dependencies.auto.tfvars.json" (
  echo [OK] ExaCS-Database: network_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] ExaCS-Database: network_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

REM Verifica Obs Logs
if exist "c:\gitlab\ga_ioci0050_iac-oci-obs-logs\dependencies\foundation_dependencies.auto.tfvars.json" (
  echo [OK] Obs-Logs: foundation_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Obs-Logs: foundation_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0050_iac-oci-obs-logs\dependencies\identity_dependencies.auto.tfvars.json" (
  echo [OK] Obs-Logs: identity_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Obs-Logs: identity_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0050_iac-oci-obs-logs\dependencies\network_dependencies.auto.tfvars.json" (
  echo [OK] Obs-Logs: network_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Obs-Logs: network_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

REM Verifica Obs Monitor
if exist "c:\gitlab\ga_ioci0060_iac-oci-obs-monitor\dependencies\foundation_dependencies.auto.tfvars.json" (
  echo [OK] Obs-Monitor: foundation_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Obs-Monitor: foundation_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0060_iac-oci-obs-monitor\dependencies\identity_dependencies.auto.tfvars.json" (
  echo [OK] Obs-Monitor: identity_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Obs-Monitor: identity_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0060_iac-oci-obs-monitor\dependencies\network_dependencies.auto.tfvars.json" (
  echo [OK] Obs-Monitor: network_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Obs-Monitor: network_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

REM Verifica Storage
if exist "c:\gitlab\ga_ioci0070_iac-oci-storage\dependencies\foundation_dependencies.auto.tfvars.json" (
  echo [OK] Storage: foundation_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Storage: foundation_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0070_iac-oci-storage\dependencies\identity_dependencies.auto.tfvars.json" (
  echo [OK] Storage: identity_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Storage: identity_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

if exist "c:\gitlab\ga_ioci0070_iac-oci-storage\dependencies\network_dependencies.auto.tfvars.json" (
  echo [OK] Storage: network_dependencies.auto.tfvars.json
  set /a success_count+=1
) else (
  echo [ERROR] Storage: network_dependencies.auto.tfvars.json FALTA
  set /a error_count+=1
)

echo.
echo ==============================================================================
echo  RESULTADO: !success_count! OK, !error_count! ERRORES
echo ==============================================================================

if !error_count! equ 0 (
  echo.
  echo [SUCCESS] Todos los archivos tfvars estan distribuidos correctamente!
  echo.
) else (
  echo.
  echo [WARNING] !error_count! archivo(s) no encontrado(s). Verifica la ejecucion.
  echo.
)

endlocal

REM ==============================================================================
REM  FINALIZACION
REM ==============================================================================
echo.
echo Archivos de log de wrappers:
echo   - %LOG_DIR%\00_foundation_wrapper.log
echo   - %LOG_DIR%\01_identity_wrapper.log
echo   - %LOG_DIR%\02_network_wrapper.log
echo.
pause

endlocal
