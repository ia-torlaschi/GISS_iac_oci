@echo off
REM =============================================================================
REM  RUNPLAN OCI LANDING ZONES GISS v3.7 - PLAN ONLY (SIN APPLY)
REM  Flujo: init -> validate -> plan -> show (SOLO LECTURA, NO APLICA CAMBIOS)
REM
REM  USO:
REM  1. Abre cmd.exe y ejecuta este archivo
REM  2. Cada modulo genera init, validate, plan y show (como .txt)
REM  3. Revisa los archivos log_plan/*.txt para auditar cambios
REM  4. ESTE SCRIPT NO EJECUTA TERRAFORM APPLY NI POWERSHELL WRAPPERS
REM  5. Cuando estes listo, aplica manualmente desde el markdown RUNPLAN_OCI_LANDING_ZONES_v3.7.md
REM
REM  Modulos en orden:
REM    00 - Foundation
REM    01 - Identity
REM    02 - Network
REM    03 - Security Services
REM    04 - ExaCS Infrastructure
REM    05 - ExaCS Database
REM    06 - Observability Logs
REM    07 - Observability Monitor
REM    08 - Storage
REM =============================================================================

setlocal enabledelayedexpansion
cd /d C:\gitlab\GISS_iac_oci

echo.
echo ==============================================================================
echo  [00] FOUNDATION - ga_ioci0000_iac-oci-foundation
echo ==============================================================================
echo.
pause
cd /d C:\gitlab\GISS_iac_oci\ga_ioci0000_iac-oci-foundation

if not exist log_plan mkdir log_plan

echo [00.1] terraform init
terraform init > log_plan\00_init.log 2>&1
type log_plan\00_init.log
pause

echo.
echo [00.2] terraform validate
terraform validate > log_plan\01_validate.log 2>&1
type log_plan\01_validate.log
pause

echo.
echo [00.3] terraform plan -out tfplan
terraform plan -compact-warnings ^
  -var-file .\oci-credentials.auto.tfvars.json ^
  -var-file .\giss_foundation_v3.7.json ^
  -out .\log_plan\02_foundation_v3.7.tfplan > log_plan\02_foundation_v3.7.plan.log 2>&1
type log_plan\02_foundation_v3.7.plan.log
pause

echo.
echo [00.4] terraform show plan como texto para revisar
terraform show -no-color .\log_plan\02_foundation_v3.7.tfplan ^
  > log_plan\03_foundation_v3.7.plan.txt
echo PLAN guardado en: log_plan\03_foundation_v3.7.plan.txt
pause

echo.
echo ==============================================================================
echo  [01] IDENTITY - ga_ioci0010_iac-oci-identity (PLAN ONLY)
echo ==============================================================================
echo.
pause
cd /d C:\gitlab\GISS_iac_oci\ga_ioci0010_iac-oci-identity

if not exist log_plan mkdir log_plan

echo [01.1] terraform init
terraform init > log_plan\00_init.log 2>&1
type log_plan\00_init.log
pause

echo.
echo [01.2] terraform validate
terraform validate > log_plan\01_validate.log 2>&1
type log_plan\01_validate.log
pause

echo.
echo [01.3] terraform plan -out tfplan (con foundation_dependencies)
terraform plan -compact-warnings ^
  -var-file .\oci-credentials.auto.tfvars.json ^
  -var-file .\giss_identity_v3.7.json ^
  -var-file .\dependencies\foundation_dependencies.auto.tfvars.json ^
  -out .\log_plan\02_identity_v3.7.tfplan > log_plan\02_identity_v3.7.plan.log 2>&1
type log_plan\02_identity_v3.7.plan.log
pause

echo.
echo [01.4] terraform show plan como texto para revisar
terraform show -no-color .\log_plan\02_identity_v3.7.tfplan ^
  > log_plan\03_identity_v3.7.plan.txt
echo PLAN guardado en: log_plan\03_identity_v3.7.plan.txt
pause

echo.
echo ==============================================================================
echo  [02] NETWORK - ga_ioci0020_iac-oci-network (PLAN ONLY)
echo ==============================================================================
echo.
pause
cd /d C:\gitlab\GISS_iac_oci\ga_ioci0020_iac-oci-network

if not exist log_plan mkdir log_plan

echo [02.1] terraform init
terraform init > log_plan\00_init.log 2>&1
type log_plan\00_init.log
pause

echo.
echo [02.2] terraform validate
terraform validate > log_plan\01_validate.log 2>&1
type log_plan\01_validate.log
pause

echo.
echo [02.3] terraform plan -out tfplan (con foundation_dependencies + identity_dependencies)
terraform plan -compact-warnings ^
  -var-file .\oci-credentials.auto.tfvars.json ^
  -var-file .\giss_network_base_v3.7.json ^
  -var-file .\dependencies\foundation_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\identity_dependencies.auto.tfvars.json ^
  -out .\log_plan\02_network_v3.7.tfplan > log_plan\02_network_v3.7.plan.log 2>&1
type log_plan\02_network_v3.7.plan.log
pause

echo.
echo [02.4] terraform show plan como texto para revisar
terraform show -no-color .\log_plan\02_network_v3.7.tfplan ^
  > log_plan\03_network_v3.7.plan.txt
echo PLAN guardado en: log_plan\03_network_v3.7.plan.txt
pause

echo.
echo ==============================================================================
echo  [03] SECURITY SERVICES - ga_ioci0030_iac-oci-security-svc (PLAN ONLY)
echo ==============================================================================
echo.
pause
cd /d C:\gitlab\GISS_iac_oci\ga_ioci0030_iac-oci-security-svc

if not exist log_plan mkdir log_plan

echo [03.1] terraform init
terraform init > log_plan\00_init.log 2>&1
type log_plan\00_init.log
pause

echo.
echo [03.2] terraform validate
terraform validate > log_plan\01_validate.log 2>&1
type log_plan\01_validate.log
pause

echo.
echo [03.3] terraform plan -out tfplan (con foundation + identity + network dependencies)
terraform plan -compact-warnings ^
  -var-file .\oci-credentials.auto.tfvars.json ^
  -var-file .\giss_security_services_v3.7.json ^
  -var-file .\dependencies\foundation_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\identity_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\network_dependencies.auto.tfvars.json ^
  -out .\log_plan\02_security_svc_v3.7.tfplan > log_plan\02_security_svc_v3.7.plan.log 2>&1
type log_plan\02_security_svc_v3.7.plan.log
pause

echo.
echo [03.4] terraform show plan como texto para revisar
terraform show -no-color .\log_plan\02_security_svc_v3.7.tfplan ^
  > log_plan\03_security_svc_v3.7.plan.txt
echo PLAN guardado en: log_plan\03_security_svc_v3.7.plan.txt
pause

echo.
echo ==============================================================================
echo  [04] EXACS INFRASTRUCTURE - ga_ioci0040_iac-oci-exa-infra (PLAN ONLY)
echo ==============================================================================
echo.
pause
cd /d C:\gitlab\GISS_iac_oci\ga_ioci0040_iac-oci-exa-infra

if not exist log_plan mkdir log_plan

echo [04.1] terraform init
terraform init > log_plan\00_init.log 2>&1
type log_plan\00_init.log
pause

echo.
echo [04.2] terraform validate
terraform validate > log_plan\01_validate.log 2>&1
type log_plan\01_validate.log
pause

echo.
echo [04.3] terraform plan -out tfplan (con foundation + identity + network dependencies)
terraform plan -compact-warnings ^
  -var-file .\oci-credentials.auto.tfvars.json ^
  -var-file .\giss_exa_infra_v3.7.json ^
  -var-file .\dependencies\foundation_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\identity_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\network_dependencies.auto.tfvars.json ^
  -out .\log_plan\02_exa_infra_v3.7.tfplan > log_plan\02_exa_infra_v3.7.plan.log 2>&1
type log_plan\02_exa_infra_v3.7.plan.log
pause

echo.
echo [04.4] terraform show plan como texto para revisar
terraform show -no-color .\log_plan\02_exa_infra_v3.7.tfplan ^
  > log_plan\03_exa_infra_v3.7.plan.txt
echo PLAN guardado en: log_plan\03_exa_infra_v3.7.plan.txt
pause

echo.
echo ==============================================================================
echo  [05] EXACS DATABASE - ga_ioci0041_iac-oci-exa-database (PLAN ONLY)
echo ==============================================================================
echo.
pause
cd /d C:\gitlab\GISS_iac_oci\ga_ioci0041_iac-oci-exa-database

if not exist log_plan mkdir log_plan

echo [05.1] terraform init
terraform init > log_plan\00_init.log 2>&1
type log_plan\00_init.log
pause

echo.
echo [05.2] terraform validate
terraform validate > log_plan\01_validate.log 2>&1
type log_plan\01_validate.log
pause

echo.
echo [05.3] terraform plan -out tfplan (con foundation + identity + network dependencies)
terraform plan -compact-warnings ^
  -var-file .\oci-credentials.auto.tfvars.json ^
  -var-file .\giss_exa_database_v3.7.json ^
  -var-file .\dependencies\foundation_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\identity_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\network_dependencies.auto.tfvars.json ^
  -out .\log_plan\02_exa_database_v3.7.tfplan > log_plan\02_exa_database_v3.7.plan.log 2>&1
type log_plan\02_exa_database_v3.7.plan.log
pause

echo.
echo [05.4] terraform show plan como texto para revisar
terraform show -no-color .\log_plan\02_exa_database_v3.7.tfplan ^
  > log_plan\03_exa_database_v3.7.plan.txt
echo PLAN guardado en: log_plan\03_exa_database_v3.7.plan.txt
pause

echo.
echo ==============================================================================
echo  [06] OBSERVABILITY LOGS - ga_ioci0050_iac-oci-obs-logs (PLAN ONLY)
echo ==============================================================================
echo.
pause
cd /d C:\gitlab\GISS_iac_oci\ga_ioci0050_iac-oci-obs-logs

if not exist log_plan mkdir log_plan

echo [06.1] terraform init
terraform init > log_plan\00_init.log 2>&1
type log_plan\00_init.log
pause

echo.
echo [06.2] terraform validate
terraform validate > log_plan\01_validate.log 2>&1
type log_plan\01_validate.log
pause

echo.
echo [06.3] terraform plan -out tfplan (con foundation + identity + network dependencies)
terraform plan -compact-warnings ^
  -var-file .\oci-credentials.auto.tfvars.json ^
  -var-file .\giss_obs_logs_v3.7.json ^
  -var-file .\dependencies\foundation_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\identity_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\network_dependencies.auto.tfvars.json ^
  -out .\log_plan\02_obs_logs_v3.7.tfplan > log_plan\02_obs_logs_v3.7.plan.log 2>&1
type log_plan\02_obs_logs_v3.7.plan.log
pause

echo.
echo [06.4] terraform show plan como texto para revisar
terraform show -no-color .\log_plan\02_obs_logs_v3.7.tfplan ^
  > log_plan\03_obs_logs_v3.7.plan.txt
echo PLAN guardado en: log_plan\03_obs_logs_v3.7.plan.txt
pause

echo.
echo ==============================================================================
echo  [07] OBSERVABILITY MONITOR - ga_ioci0060_iac-oci-obs-monitor (PLAN ONLY)
echo ==============================================================================
echo.
pause
cd /d C:\gitlab\GISS_iac_oci\ga_ioci0060_iac-oci-obs-monitor

if not exist log_plan mkdir log_plan

echo [07.1] terraform init
terraform init > log_plan\00_init.log 2>&1
type log_plan\00_init.log
pause

echo.
echo [07.2] terraform validate
terraform validate > log_plan\01_validate.log 2>&1
type log_plan\01_validate.log
pause

echo.
echo [07.3] terraform plan -out tfplan (con foundation + identity + network dependencies)
terraform plan -compact-warnings ^
  -var-file .\oci-credentials.auto.tfvars.json ^
  -var-file .\giss_obs_monitor_v3.7.json ^
  -var-file .\dependencies\foundation_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\identity_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\network_dependencies.auto.tfvars.json ^
  -out .\log_plan\02_obs_monitor_v3.7.tfplan > log_plan\02_obs_monitor_v3.7.plan.log 2>&1
type log_plan\02_obs_monitor_v3.7.plan.log
pause

echo.
echo [07.4] terraform show plan como texto para revisar
terraform show -no-color .\log_plan\02_obs_monitor_v3.7.tfplan ^
  > log_plan\03_obs_monitor_v3.7.plan.txt
echo PLAN guardado en: log_plan\03_obs_monitor_v3.7.plan.txt
pause

echo.
echo ==============================================================================
echo  [08] STORAGE - ga_ioci0070_iac-oci-storage (PLAN ONLY)
echo ==============================================================================
echo.
pause
cd /d C:\gitlab\GISS_iac_oci\ga_ioci0070_iac-oci-storage

if not exist log_plan mkdir log_plan

echo [08.1] terraform init
terraform init > log_plan\00_init.log 2>&1
type log_plan\00_init.log
pause

echo.
echo [08.2] terraform validate
terraform validate > log_plan\01_validate.log 2>&1
type log_plan\01_validate.log
pause

echo.
echo [08.3] terraform plan -out tfplan (con foundation + identity + network dependencies)
terraform plan -compact-warnings ^
  -var-file .\oci-credentials.auto.tfvars.json ^
  -var-file .\giss_storage_v3.7.json ^
  -var-file .\dependencies\foundation_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\identity_dependencies.auto.tfvars.json ^
  -var-file .\dependencies\network_dependencies.auto.tfvars.json ^
  -out .\log_plan\02_storage_v3.7.tfplan > log_plan\02_storage_v3.7.plan.log 2>&1
type log_plan\02_storage_v3.7.plan.log
pause

echo.
echo [08.4] terraform show plan como texto para revisar
terraform show -no-color .\log_plan\02_storage_v3.7.tfplan ^
  > log_plan\03_storage_v3.7.plan.txt
echo PLAN guardado en: log_plan\03_storage_v3.7.plan.txt
pause

echo.
echo ==============================================================================
echo  FINALIZACION: PLAN COMPLETADO (SIN CAMBIOS APLICADOS)
echo ==============================================================================
echo.
echo Todos los planes han sido generados y guardados en log_plan/ de cada modulo
echo Revisa todos los archivos .txt antes de proceder al apply
echo.
echo Para aplicar los cambios, sigue los pasos del markdown:
echo   C:\gitlab\GISS_iac_oci\RUNPLAN_OCI_LANDING_ZONES_v3.7.md
echo.
pause

