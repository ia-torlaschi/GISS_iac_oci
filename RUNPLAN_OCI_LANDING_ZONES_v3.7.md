# RUNPLAN OCI Landing Zones GISS v3.7

Guía operativa paso a paso para ejecutar terraform en los 8 módulos de infraestructura.

## Tabla de contenidos

- [Introducción](#introducción)
- [Flujo General](#flujo-general)
- [Módulo 00: Foundation](#módulo-00-foundation)
- [Módulo 01: Identity](#módulo-01-identity)
- [Módulo 02: Network](#módulo-02-network)
- [Módulo 03: Security Services](#módulo-03-security-services)
- [Módulo 04: ExaCS Infrastructure](#módulo-04-exacs-infrastructure)
- [Módulo 05: ExaCS Database](#módulo-05-exacs-database)
- [Módulo 06: Observability Logs](#módulo-06-observability-logs)
- [Módulo 07: Observability Monitor](#módulo-07-observability-monitor)
- [Módulo 08: Storage](#módulo-08-storage)
- [Post-Ejecución](#post-ejecución)

---

## Introducción

### Objetivo

Ejecutar terraform plan, review y apply secuencialmente en 8 módulos OCI, respetando dependencias y generando logs trazables en cada módulo.

### Pre-requisitos

- Terraform 1.15.5+
- OCI CLI 3.85.0+
- Credenciales OCI configuradas en `oci-credentials.auto.tfvars.json`
- cmd.exe (Command Prompt nativo de Windows, NO PowerShell)

### Estructura de Logs

Cada módulo genera una carpeta `log_plan/` con:
- `00_init.log` → resultado de `terraform init`
- `01_validate.log` → resultado de `terraform validate`
- `02_*.plan.log` → logs de `terraform plan`
- `03_*.plan.txt` → plan en texto (para auditar antes de aplicar)
- `04_*.apply.log` → logs de `terraform apply`

---

## Flujo General

```
[00] Foundation
    ↓ genera foundation_dependencies.auto.tfvars.json
    ↓ distribuye a todos los módulos posteriores

[01] Identity (usa foundation_dependencies)
    ↓ genera identity_dependencies.auto.tfvars.json
    ↓ distribuye a todos los módulos posteriores

[02] Network (usa foundation + identity)
    ↓ genera network_dependencies.auto.tfvars.json
    ↓ distribuye a todos los módulos posteriores

[03-08] Módulos restantes (usan foundation + identity + network)
```

### Patrón por Módulo

1. **cd** al módulo
2. **terraform init**
3. **terraform validate**
4. **terraform plan** (con tfvars acumulativos)
5. **terraform show** → archivo `.txt` para auditar
6. **⏸ Pausa manual** → revisa `.txt`
7. **terraform apply**
8. **PS wrapper** → genera/distribuye tfvars (solo Foundation, Identity, Network)

---

## Módulo 00: Foundation

### Paso 1: Navegar

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0000_iac-oci-foundation
```

### Paso 2: Crear carpeta log_plan

```batch
if not exist log_plan mkdir log_plan
```

### Paso 3: terraform init

```batch
terraform init 2>&1 | tee log_plan\00_init.log
```

**Espera a que termine. Revisa `log_plan\00_init.log`.**

### Paso 4: terraform validate

```batch
terraform validate 2>&1 | tee log_plan\01_validate.log
```

**Espera a que termine. Revisa `log_plan\01_validate.log`.**

### Paso 5: terraform plan

```batch
terraform plan -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_foundation_v3.7.json -out=.\log_plan\02_foundation_v3.7.tfplan 2>&1 | tee log_plan\02_foundation_v3.7.plan.log
```

**Espera a que termine.**

### Paso 6: terraform show (convertir a texto)

```batch
terraform show -no-color .\log_plan\02_foundation_v3.7.tfplan > log_plan\03_foundation_v3.7.plan.txt
```

**Abre `log_plan\03_foundation_v3.7.plan.txt` y audita los cambios.**

### Paso 7: terraform apply

Una vez auditado, ejecuta:

```batch
terraform apply .\log_plan\02_foundation_v3.7.tfplan 2>&1 | tee log_plan\04_foundation_v3.7.apply.log
```

**Espera a que termine.**

### Paso 8: Generar y distribuir foundation_dependencies

```batch
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd C:\gitlab\GISS_iac_oci\ga_ioci0000_iac-oci-foundation\dependencies; .\foundation_dependencies.ps1"
```

**Este script genera `foundation_dependencies.auto.tfvars.json` y lo copia a todos los módulos posteriores.**

---

## Módulo 01: Identity

### Paso 1: Navegar

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0010_iac-oci-identity
```

### Paso 2: Crear carpeta log_plan

```batch
if not exist log_plan mkdir log_plan
```

### Paso 3: terraform init

```batch
terraform init 2>&1 | tee log_plan\00_init.log
```

### Paso 4: terraform validate

```batch
terraform validate 2>&1 | tee log_plan\01_validate.log
```

### Paso 5: terraform plan (con foundation_dependencies)

```batch
terraform plan -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_identity_v3.7.json -var-file=.\dependencies\foundation_dependencies.auto.tfvars.json -out=.\log_plan\02_identity_v3.7.tfplan 2>&1 | tee log_plan\02_identity_v3.7.plan.log
```

### Paso 6: terraform show

```batch
terraform show -no-color .\log_plan\02_identity_v3.7.tfplan > log_plan\03_identity_v3.7.plan.txt
```

**Audita `log_plan\03_identity_v3.7.plan.txt`.**

### Paso 7: terraform apply

```batch
terraform apply .\log_plan\02_identity_v3.7.tfplan 2>&1 | tee log_plan\04_identity_v3.7.apply.log
```

### Paso 8: Generar y distribuir identity_dependencies

```batch
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd C:\gitlab\GISS_iac_oci\ga_ioci0010_iac-oci-identity\dependencies; .\identity_dependencies.ps1"
```

---

## Módulo 02: Network

### Paso 1: Navegar

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0020_iac-oci-network
```

### Paso 2: Crear carpeta log_plan

```batch
if not exist log_plan mkdir log_plan
```

### Paso 3: terraform init

```batch
terraform init 2>&1 | tee log_plan\00_init.log
```

### Paso 4: terraform validate

```batch
terraform validate 2>&1 | tee log_plan\01_validate.log
```

### Paso 5: terraform plan (con foundation + identity dependencies)

```batch
terraform plan -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_network_base_v3.7.json -var-file=.\dependencies\foundation_dependencies.auto.tfvars.json -var-file=.\dependencies\identity_dependencies.auto.tfvars.json -out=.\log_plan\02_network_v3.7.tfplan 2>&1 | tee log_plan\02_network_v3.7.plan.log
```

### Paso 6: terraform show

```batch
terraform show -no-color .\log_plan\02_network_v3.7.tfplan > log_plan\03_network_v3.7.plan.txt
```

**Audita `log_plan\03_network_v3.7.plan.txt`.**

### Paso 7: terraform apply

```batch
terraform apply .\log_plan\02_network_v3.7.tfplan 2>&1 | tee log_plan\04_network_v3.7.apply.log
```

### Paso 8: Generar y distribuir network_dependencies

```batch
powershell -NoProfile -ExecutionPolicy Bypass -Command "cd C:\gitlab\GISS_iac_oci\ga_ioci0020_iac-oci-network\dependencies; .\network_dependencies.ps1"
```

---

## Módulo 03: Security Services

### Paso 1: Navegar

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0030_iac-oci-security-svc
```

### Paso 2: Crear carpeta log_plan

```batch
if not exist log_plan mkdir log_plan
```

### Paso 3: terraform init

```batch
terraform init 2>&1 | tee log_plan\00_init.log
```

### Paso 4: terraform validate

```batch
terraform validate 2>&1 | tee log_plan\01_validate.log
```

### Paso 5: terraform plan (con foundation + identity + network dependencies)

```batch
terraform plan -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_security_services_v3.7.json -var-file=.\dependencies\foundation_dependencies.auto.tfvars.json -var-file=.\dependencies\identity_dependencies.auto.tfvars.json -var-file=.\dependencies\network_dependencies.auto.tfvars.json -out=.\log_plan\02_security_svc_v3.7.tfplan 2>&1 | tee log_plan\02_security_svc_v3.7.plan.log
```

### Paso 6: terraform show

```batch
terraform show -no-color .\log_plan\02_security_svc_v3.7.tfplan > log_plan\03_security_svc_v3.7.plan.txt
```

**Audita `log_plan\03_security_svc_v3.7.plan.txt`.**

### Paso 7: terraform apply

```batch
terraform apply .\log_plan\02_security_svc_v3.7.tfplan 2>&1 | tee log_plan\04_security_svc_v3.7.apply.log
```

---

## Módulo 04: ExaCS Infrastructure

### Paso 1: Navegar

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0040_iac-oci-exa-infra
```

### Paso 2: Crear carpeta log_plan

```batch
if not exist log_plan mkdir log_plan
```

### Paso 3: terraform init

```batch
terraform init 2>&1 | tee log_plan\00_init.log
```

### Paso 4: terraform validate

```batch
terraform validate 2>&1 | tee log_plan\01_validate.log
```

### Paso 5: terraform plan

```batch
terraform plan -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_exa_infra_v3.7.json -var-file=.\dependencies\foundation_dependencies.auto.tfvars.json -var-file=.\dependencies\identity_dependencies.auto.tfvars.json -var-file=.\dependencies\network_dependencies.auto.tfvars.json -out=.\log_plan\02_exa_infra_v3.7.tfplan 2>&1 | tee log_plan\02_exa_infra_v3.7.plan.log
```

### Paso 6: terraform show

```batch
terraform show -no-color .\log_plan\02_exa_infra_v3.7.tfplan > log_plan\03_exa_infra_v3.7.plan.txt
```

### Paso 7: terraform apply

```batch
terraform apply .\log_plan\02_exa_infra_v3.7.tfplan 2>&1 | tee log_plan\04_exa_infra_v3.7.apply.log
```

---

## Módulo 05: ExaCS Database

### Paso 1: Navegar

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0041_iac-oci-exa-database
```

### Paso 2: Crear carpeta log_plan

```batch
if not exist log_plan mkdir log_plan
```

### Paso 3: terraform init

```batch
terraform init 2>&1 | tee log_plan\00_init.log
```

### Paso 4: terraform validate

```batch
terraform validate 2>&1 | tee log_plan\01_validate.log
```

### Paso 5: terraform plan

```batch
terraform plan -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_exa_database_v3.7.json -var-file=.\dependencies\foundation_dependencies.auto.tfvars.json -var-file=.\dependencies\identity_dependencies.auto.tfvars.json -var-file=.\dependencies\network_dependencies.auto.tfvars.json -out=.\log_plan\02_exa_database_v3.7.tfplan 2>&1 | tee log_plan\02_exa_database_v3.7.plan.log
```

### Paso 6: terraform show

```batch
terraform show -no-color .\log_plan\02_exa_database_v3.7.tfplan > log_plan\03_exa_database_v3.7.plan.txt
```

### Paso 7: terraform apply

```batch
terraform apply .\log_plan\02_exa_database_v3.7.tfplan 2>&1 | tee log_plan\04_exa_database_v3.7.apply.log
```

---

## Módulo 06: Observability Logs

### Paso 1: Navegar

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0050_iac-oci-obs-logs
```

### Paso 2: Crear carpeta log_plan

```batch
if not exist log_plan mkdir log_plan
```

### Paso 3: terraform init

```batch
terraform init 2>&1 | tee log_plan\00_init.log
```

### Paso 4: terraform validate

```batch
terraform validate 2>&1 | tee log_plan\01_validate.log
```

### Paso 5: terraform plan

```batch
terraform plan -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_obs_logs_v3.7.json -var-file=.\dependencies\foundation_dependencies.auto.tfvars.json -var-file=.\dependencies\identity_dependencies.auto.tfvars.json -var-file=.\dependencies\network_dependencies.auto.tfvars.json -out=.\log_plan\02_obs_logs_v3.7.tfplan 2>&1 | tee log_plan\02_obs_logs_v3.7.plan.log
```

### Paso 6: terraform show

```batch
terraform show -no-color .\log_plan\02_obs_logs_v3.7.tfplan > log_plan\03_obs_logs_v3.7.plan.txt
```

### Paso 7: terraform apply

```batch
terraform apply .\log_plan\02_obs_logs_v3.7.tfplan 2>&1 | tee log_plan\04_obs_logs_v3.7.apply.log
```

---

## Módulo 07: Observability Monitor

### Paso 1: Navegar

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0060_iac-oci-obs-monitor
```

### Paso 2: Crear carpeta log_plan

```batch
if not exist log_plan mkdir log_plan
```

### Paso 3: terraform init

```batch
terraform init 2>&1 | tee log_plan\00_init.log
```

### Paso 4: terraform validate

```batch
terraform validate 2>&1 | tee log_plan\01_validate.log
```

### Paso 5: terraform plan

```batch
terraform plan -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_obs_monitor_v3.7.json -var-file=.\dependencies\foundation_dependencies.auto.tfvars.json -var-file=.\dependencies\identity_dependencies.auto.tfvars.json -var-file=.\dependencies\network_dependencies.auto.tfvars.json -out=.\log_plan\02_obs_monitor_v3.7.tfplan 2>&1 | tee log_plan\02_obs_monitor_v3.7.plan.log
```

### Paso 6: terraform show

```batch
terraform show -no-color .\log_plan\02_obs_monitor_v3.7.tfplan > log_plan\03_obs_monitor_v3.7.plan.txt
```

### Paso 7: terraform apply

```batch
terraform apply .\log_plan\02_obs_monitor_v3.7.tfplan 2>&1 | tee log_plan\04_obs_monitor_v3.7.apply.log
```

---

## Módulo 08: Storage

### Paso 1: Navegar

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0070_iac-oci-storage
```

### Paso 2: Crear carpeta log_plan

```batch
if not exist log_plan mkdir log_plan
```

### Paso 3: terraform init

```batch
terraform init 2>&1 | tee log_plan\00_init.log
```

### Paso 4: terraform validate

```batch
terraform validate 2>&1 | tee log_plan\01_validate.log
```

### Paso 5: terraform plan

```batch
terraform plan -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_storage_v3.7.json -var-file=.\dependencies\foundation_dependencies.auto.tfvars.json -var-file=.\dependencies\identity_dependencies.auto.tfvars.json -var-file=.\dependencies\network_dependencies.auto.tfvars.json -out=.\log_plan\02_storage_v3.7.tfplan 2>&1 | tee log_plan\02_storage_v3.7.plan.log
```

### Paso 6: terraform show

```batch
terraform show -no-color .\log_plan\02_storage_v3.7.tfplan > log_plan\03_storage_v3.7.plan.txt
```

### Paso 7: terraform apply

```batch
terraform apply .\log_plan\02_storage_v3.7.tfplan 2>&1 | tee log_plan\04_storage_v3.7.apply.log
```

---

## Post-Ejecución

### Verificación de Logs

Revisa los archivos de log en cada módulo:

```batch
explorer C:\gitlab\GISS_iac_oci\ga_ioci0000_iac-oci-foundation\log_plan
explorer C:\gitlab\GISS_iac_oci\ga_ioci0010_iac-oci-identity\log_plan
explorer C:\gitlab\GISS_iac_oci\ga_ioci0020_iac-oci-network\log_plan
```

### Estado de Terraform

Para verificar el estado de cada módulo:

```batch
cd C:\gitlab\GISS_iac_oci\ga_ioci0000_iac-oci-foundation
terraform state list
terraform state show oci_identity_compartment.main
```

### Rollback (si es necesario)

Si necesitas revertir cambios:

```batch
terraform destroy -var-file=.\oci-credentials.auto.tfvars.json -var-file=.\giss_foundation_v3.7.json
```

---

**Última actualización:** 2026-06-11
**Versión:** 3.7
