# README — OCI Landing Zone GISS — Multi-repo (v3.6+)

**Versión:** 2.0  
**Última revisión:** Mayo 2026  
**Proyecto:** OCI Landing Zone — Seguridad Social (GISS)  
**Región:** `eu-madrid-2` — España Central (Madrid)  
**Plataforma de operador:** Windows 11 corporativo (usuario SILCON)  
**Estructura desde v3.6:** 9 repositorios independientes con states separados

---

## Índice

1. [Qué es este documento](#1-qué-es-este-documento)
2. [Arquitectura multi-repo v3.6](#2-arquitectura-multi-repo-v36)
3. [Mapa de repositorios y contenido por stack](#3-mapa-de-repositorios-y-contenido-por-stack)
4. [Política de tagging OCI](#4-política-de-tagging-oci)
5. [Prerequisitos de acceso y cuenta](#5-prerequisitos-de-acceso-y-cuenta)
6. [Estructura de directorios esperada](#6-estructura-de-directorios-esperada)
7. [Orden de ejecución y dependencias entre stacks](#7-orden-de-ejecución-y-dependencias-entre-stacks)
8. [PASO 1 — Creación de directorios base](#8-paso-1--creación-de-directorios-base)
9. [PASO 2 — Variables de entorno y configuración de red](#9-paso-2--variables-de-entorno-y-configuración-de-red)
10. [PASO 3 — Clonación de repositorios](#10-paso-3--clonación-de-repositorios)
11. [PASO 4 — Instalación de OCI CLI](#11-paso-4--instalación-de-oci-cli)
12. [PASO 5 — Configuración de OCI CLI](#12-paso-5--configuración-de-oci-cli)
13. [PASO 6 — Pruebas de conectividad OCI CLI](#13-paso-6--pruebas-de-conectividad-oci-cli)
14. [PASO 7 — Instalación de Terraform](#14-paso-7--instalación-de-terraform)
15. [PASO 8 — Instalación de Python](#15-paso-8--instalación-de-python)
16. [PASO 9 — Credenciales por stack](#16-paso-9--credenciales-por-stack)
17. [PASO 10 — Backend GitLab y terraform init por stack](#17-paso-10--backend-gitlab-y-terraform-init-por-stack)
18. [PASO 11 — terraform plan y apply por stack](#18-paso-11--terraform-plan-y-apply-por-stack)
19. [Importación declarativa de stacks ya desplegados](#19-importación-declarativa-de-stacks-ya-desplegados)
20. [Flujo operativo de sesión](#20-flujo-operativo-de-sesión)
21. [Buenas prácticas](#21-buenas-prácticas)
22. [Versiones validadas](#22-versiones-validadas)
23. [Disclaimer técnico](#23-disclaimer-técnico)

---

## 1. Qué es este documento

Este README describe **toda la Landing Zone OCI de GISS desde v3.6**, en su nueva forma de **9 repositorios independientes con states Terraform separados**. Es un documento maestro: vale como referencia única para operar cualquiera de los repositorios.

Cubre:

- la arquitectura multi-repo y las dependencias entre stacks,
- el contenido funcional de cada repositorio,
- el procedimiento completo de preparación del puesto Windows 11 corporativo GISS,
- el ciclo `init` / `plan` / `apply` por stack,
- el patrón de importación declarativa para los stacks que ya estaban desplegados antes del split.

El punto de partida es un equipo Windows con usuario SILCON activo, acceso al proxy corporativo (`proxy.seg-social.es:8080`) y conectividad a Internet a través de dicho proxy. Las herramientas se instalan mediante **winget** (Windows Package Manager).

El despliegue activo se realiza en el tenancy OCI de GISS, región `eu-madrid-2`.

> **Alcance:** exclusivamente herramientas y configuración OCI. No cubre instalación de AWS CLI, GCP CLI ni otros proveedores cloud.

---

## 2. Arquitectura multi-repo v3.6

Desde la versión 3.6, el Terraform monolítico se ha descompuesto en **9 repositorios independientes**, cada uno con:

- su propio fichero `giss_<stack>_v3.6.json` con la configuración del orquestador,
- su propio state remoto en el backend HTTP de GitLab corporativo,
- su propio ciclo de despliegue (`init` / `plan` / `apply`),
- dependencias resueltas mediante el patrón oficial **External Dependencies** del [OCI Landing Zones Orchestrator](https://github.com/oci-landing-zones/terraform-oci-modules-orchestrator#external-dependencies).

El stack `foundation` genera, vía `output_path: "./dependencies"`, los ficheros que los stacks downstream consumen como variables Terraform:

```text
dependencies/compartments_output.json
dependencies/tags_output.json
dependencies/foundation_dependencies.auto.tfvars.json
```

**Beneficios de la separación de states:**

- blast radius limitado por dominio funcional,
- ciclos de despliegue independientes (red, IAM, observabilidad… avanzan a ritmos distintos),
- ownership claro por equipo (networking, IAM, DBA, security, etc.),
- pipelines CI/CD por repositorio.

---

## 3. Mapa de repositorios y contenido por stack

### 3.1. Tabla maestra

| #  | Repositorio GitLab                                  | Owner                                  | Estado v3.6 | Depende de                |
| -- | --------------------------------------------------- | -------------------------------------- | ----------- | ------------------------- |
| 00 | `ga_ioci0000_iac-oci-foundation`                  | Cloud IAM admin + Cloud Governance     | Operativo   | —                         |
| 10 | `ga_ioci0010_iac-oci-identity`                    | Cloud IAM admin                        | Operativo   | 00                        |
| 20 | `ga_ioci0020_iac-oci-network`                     | Cloud Networking admin                 | Operativo   | 00                        |
| 30 | `ga_ioci0030_iac-oci-security-svc`                | Cloud Security admin                   | Esqueleto   | 00, 10                    |
| 40 | `ga_ioci0040_iac-oci-exa-infra`                   | Cloud Infra admin                      | Esqueleto   | 00, 10, 20                |
| 41 | `ga_ioci0041_iac-oci-exa-database`                | Cloud DB admin                         | Esqueleto   | 00, 10, 20, 40            |
| 50 | `ga_ioci0050_iac-oci-obs-logs`                    | Cloud Security admin / SOC             | Esqueleto   | 00, 10, 20                |
| 60 | `ga_ioci0060_iac-oci-obs-monitor`                 | Cloud Monitoring admin                 | Esqueleto   | 00, 10                    |
| 70 | `ga_ioci0070_iac-oci-storage`                     | Cloud Storage admin                    | Esqueleto   | 00, 10                    |

### 3.2. Contenido funcional por stack

**`00-foundation` (Operativo)** — Base de toda la Landing Zone. Contiene los tres tag namespaces (TBAC `o-p-om2-tagns-name-001`, Governance `o-p-om2-tagns-gov-001`, ENS `o-p-om2-tagns-ens-001`) con sus 16 tag keys, y la jerarquía completa de 20 compartments bajo `o-p-om2-cmp-land-001`. Todos los demás stacks dependen de este. **Genera dependencies para downstream.**

**`10-identity` (Operativo)** — Identity Domain `o-p-om2-id-common-001` (license=free), 8 grupos nativos OCI y 18 políticas IAM, incluyendo TBAC y federación Entra ID con grupos `99GISS.*`. Las políticas referencian compartments por nombre (no por OCID), preservando independencia del state de foundation.

**`20-network` (Operativo)** — Topología hub-and-spoke completamente privada (sin Internet Gateway). VCN Hub `o-p-om2-vcn-hub-001` (`10.197.128.0/23`), spokes ExaCS PRO (`10.197.132.0/23`) y NPR (`10.197.134.0/23`) interconectadas vía DRG. NAT GW y Service GWs en Hub; Service GW en cada spoke. Egress a Internet solo desde Hub. Incluye **overlay opcional NFW** (`giss_network_nfw_addon_v3.6.json`) como `REFERENCE_ONLY_NOT_DEPLOYED` tras la decisión de v3.4.

**`30-security-svc` (Esqueleto)** — Servicios de seguridad activos: Cloud Guard (targets + recipes configuration/activity/threat), Vulnerability Scanning Service (VSS), OCI Bastion gestionado, suscripciones Marketplace para imágenes endurecidas, y WAF policies para cuando exista exposición pública.

**`40-exa-infra` (Esqueleto)** — Infraestructura física Exadata: Cloud Exadata Infrastructure (CEI), scheduling policies y scheduling windows de mantenimiento. Asignado al compartment `o-p-om2-cmp-exacsinfra-001` con TBAC `o-p-om2-tag-role-exainfra-001`.

**`41-exa-database` (Esqueleto)** — Capa de bases de datos sobre Exadata: VM Clusters, DB Homes, Databases, PDBs, backup destinations a buckets del stack 70 y registro en Data Safe. Asignado al compartment `o-p-om2-cmp-exacsdb-001` con TBAC `o-p-om2-tag-role-exadb-001`.

**`50-obs-logs` (Esqueleto)** — Logging centralizado e integración con QRadar on-prem. Log Groups en `o-p-om2-cmp-logg-001`, captura de Audit + VCN flow logs + ExaCS logs, exportación vía Service Connector Hub a Streaming/Object Storage para consumo por QRadar a través de red privada GISS (FastConnect/IPSec). Retención alineada con `business-criticality` y `ens-traceability`.

**`60-obs-monitor` (Esqueleto)** — Monitorización con destino a sistema de terceros. Alarms sobre métricas estándar de ExaCS/VCN/NAT, ONS Topics y subscriptions tipo webhook o Service Connector Hub → Stream → consumer externo. La política `PCY-MONITORING-KEY` ya existe en `10-identity`.

**`70-storage` (Esqueleto)** — Almacenamiento gestionado: buckets Object Storage (backups ExaCS en exacsdb, intercambio aplicacional en cdin-projects, archivado de logs en logg con lifecycle Archive), File Storage Service, Block Volume groups y lifecycle policies. La política `PCY-STORAGE-KEY` autoriza al grupo `Cloud_Storage_admin` **sin permiso de DELETE** (break-glass o approval explícito).

### 3.3. Estructura de ficheros por repositorio

Todos los repositorios siguen la misma estructura mínima:

```text
ga_ioci00NN_iac-oci-<stack>/
├─ dependencies/                          (solo en stacks dependientes)
│  └─ foundation_dependencies.auto.tfvars.json
├─ giss_<stack>_v3.6.json                 (configuración del orquestador)
├─ main.tf
├─ providers.tf
├─ variables.tf
├─ versions.tf
├─ oci-credentials.auto.tfvars.json       (a crear localmente — NO commitear)
├─ .terraform.lock.hcl
├─ .terraform/                            (generado por terraform init)
├─ terraform.tfstate / .backup            (gestionado por backend remoto en producción)
└─ <stack>_imports.auto.tf                (solo durante import inicial)
```

El stack `foundation` añade además:

```text
dependencies/
├─ compartments_output.json               (output del orquestador)
├─ tags_output.json                       (output del orquestador)
└─ foundation_dependencies.auto.tfvars.json  (wrapper para downstream)
```

---

## 4. Política de tagging OCI

La política de tagging es **idéntica para todos los stacks** y se despliega íntegramente desde `00-foundation`. Los tag namespaces deben existir antes de que cualquier stack downstream asigne `defined_tags` a sus recursos.

### 4.1. Namespace TBAC — `o-p-om2-tagns-name-001`

| Namespace                  | Tag key                  | Propósito                |
| -------------------------- | ------------------------ | ------------------------ |
| `o-p-om2-tagns-name-001` | `o-p-om2-tag-role-001` | TBAC de roles IAM        |

> Habilita políticas IAM basadas en tags, permitiendo controlar el acceso a recursos OCI en función del valor asignado al tag `o-p-om2-tag-role-001`.

### 4.2. Namespace Governance — `o-p-om2-tagns-gov-001`

| Key Terraform                       | Tag OCI                  | `is_cost_tracking` | Valores / Validación                                          |
| ----------------------------------- | ------------------------ | -------------------- | -------------------------------------------------------------- |
| `TAG-GOV-TECHNICAL-OWNER-KEY`     | `technical-owner`      | `false`            | Correo corporativo — libre                                    |
| `TAG-GOV-OPERATIONAL-OWNER-KEY`   | `operational-owner`    | `false`            | Correo corporativo — libre                                    |
| `TAG-GOV-DEPARTMENT-KEY`          | `department`           | **`true`**   | Unidad de negocio — libre                                     |
| `TAG-GOV-COST-CENTER-KEY`         | `cost-center`          | **`true`**   | Código de centro de costes — libre                            |
| `TAG-GOV-APPLICATION-CODE-KEY`    | `application-code`     | **`true`**   | Código de aplicación — libre                                  |
| `TAG-GOV-APPLICATION-NAME-KEY`    | `application-name`     | `false`            | Nombre de aplicación — libre                                  |
| `TAG-GOV-NAME-KEY`                | `name`                 | **`true`**   | Igual al `display_name` del recurso — libre                |
| `TAG-GOV-ENVIRONMENT-KEY`         | `environment`          | **`true`**   | ENUM: `dev`, `pre`, `pro`, `int`, `qa`, `cer` |
| `TAG-GOV-IAC-KEY`                 | `iac`                  | `false`            | ENUM: `terraform`, `manual`, `cli`                       |
| `TAG-GOV-BUSINESS-CRITICALITY-KEY` | `business-criticality` | `false`            | ENUM: `critico`, `alto`, `medio`, `bajo`             |

### 4.3. Namespace Clasificación ENS — `o-p-om2-tagns-ens-001`

| Key Terraform                  | Tag OCI                 | Dimensión ENS   | Valores                              |
| ------------------------------ | ----------------------- | ---------------- | ------------------------------------ |
| `TAG-ENS-AUTHENTICITY-KEY`   | `ens-authenticity`    | Autenticidad     | ENUM: `alto`, `medio`, `bajo` |
| `TAG-ENS-INTEGRITY-KEY`      | `ens-integrity`       | Integridad       | ENUM: `alto`, `medio`, `bajo` |
| `TAG-ENS-AVAILABILITY-KEY`   | `ens-availability`    | Disponibilidad   | ENUM: `alto`, `medio`, `bajo` |
| `TAG-ENS-CONFIDENTIALITY-KEY` | `ens-confidentiality` | Confidencialidad | ENUM: `alto`, `medio`, `bajo` |
| `TAG-ENS-TRACEABILITY-KEY`   | `ens-traceability`    | Trazabilidad     | ENUM: `alto`, `medio`, `bajo` |

> **Antes de cualquier `terraform apply`** buscar globalmente `__FILL__` en los ficheros de configuración. Son valores de tag pendientes de completar por el responsable funcional del recurso.

---

## 5. Prerequisitos de acceso y cuenta

Antes de iniciar, el operador debe tener activos los siguientes accesos:

- **Usuario SILCON** (formato `99GUXXXX`) asignado al proyecto GISS.
- **Cuenta en GitLab corporativo** `https://gitlab.pro.portal.ss` — el username debe ser el usuario SILCON. Gestionar permisos sobre los repositorios `ga/ioci/ga_ioci00NN_*` con el responsable del proyecto.
- **Cuenta OCI** con permisos suficientes en el tenancy GISS — región `eu-madrid-2`.
- **winget disponible** — verificar con `winget --version` desde PowerShell; debe devolver versión `1.x` o superior.

> Estos accesos deben estar activos **antes** de ejecutar el PASO 1. Sin ellos no es posible completar la instalación ni la clonación de repositorios.

---

## 6. Estructura de directorios esperada

Tras completar todos los pasos, la estructura de trabajo en `C:\` debe ser:

```text
C:\
├── Cloud\
│   └── ca.segsocial.eu.goskope.crt                       (certificado CA corporativo)
└── gitlab\
    ├── terraform-oci-modules-orchestrator\               (módulo orquestador — submódulo común)
    ├── oci-python-sdk\                                   (SDK Python — requerido para scripts)
    ├── ga_ioci0000_iac-oci-foundation\
    │   ├── giss_foundation_v3.6.json
    │   ├── dependencies\
    │   │   ├── compartments_output.json
    │   │   ├── tags_output.json
    │   │   └── foundation_dependencies.auto.tfvars.json
    │   └── ... (main.tf, providers.tf, etc.)
    ├── ga_ioci0010_iac-oci-identity\
    │   ├── giss_identity_v3.6.json
    │   └── dependencies\
    │       └── foundation_dependencies.auto.tfvars.json  (copiado desde foundation)
    ├── ga_ioci0020_iac-oci-network\
    │   ├── giss_network_base_v3.6.json
    │   ├── giss_network_nfw_addon_v3.6.json              (overlay opcional)
    │   └── dependencies\
    │       └── foundation_dependencies.auto.tfvars.json  (copiado desde foundation)
    ├── ga_ioci0030_iac-oci-security-svc\
    ├── ga_ioci0040_iac-oci-exa-infra\
    ├── ga_ioci0041_iac-oci-exa-database\
    ├── ga_ioci0050_iac-oci-obs-logs\
    ├── ga_ioci0060_iac-oci-obs-monitor\
    └── ga_ioci0070_iac-oci-storage\
```

El fichero `oci-credentials.auto.tfvars.json` debe existir en la **raíz de cada repositorio** y **nunca** dentro de `dependencies/`, ni commitearse al repositorio.

---

## 7. Orden de ejecución y dependencias entre stacks

### 7.1. Orden global de despliegue

```text
1. foundation         (00)   →  base de tags y compartments
2. identity           (10)   →  domain, grupos y políticas IAM
3. network            (20)   →  VCN Hub + spokes + DRG
4. security-svc (30) / storage (70)
5. exa-infra (40) / obs-logs (50) / obs-monitor (60)
6. exa-database (41)         →  requiere infra Exadata previa
```

### 7.2. Resumen multi-repo

| Paso        | Qué hace                                                          | Ámbito              |
| ----------- | ----------------------------------------------------------------- | ------------------- |
| **PASO 1**  | Crear `C:\Cloud` y `C:\gitlab`                                    | Workstation         |
| **PASO 2**  | Variables de entorno de proxy, SSL y configuración git            | Workstation         |
| **PASO 3**  | Clonar los 9 repositorios + orquestador + SDK en `C:\gitlab`      | Workstation         |
| **PASO 4**  | Instalar OCI CLI con winget                                       | Workstation         |
| **PASO 5**  | Configurar OCI CLI con credenciales del operador                  | Workstation         |
| **PASO 6**  | Validar conectividad OCI CLI                                      | Workstation         |
| **PASO 7**  | Instalar Terraform con winget                                     | Workstation         |
| **PASO 8**  | Instalar Python con winget                                        | Workstation         |
| **PASO 9**  | Crear `oci-credentials.auto.tfvars.json` en cada repositorio      | Por stack           |
| **PASO 10** | Backend GitLab y `terraform init` en cada stack                   | Por stack           |
| **PASO 11** | Ejecutar `terraform plan` y `terraform apply` en cada stack       | Por stack, en orden |

> Para stacks **ya desplegados antes del split** (foundation, identity, network) ver sección 19 — importación declarativa.

---

## 8. PASO 1 — Creación de directorios base

Abrir **CMD como administrador** (`Win + R` → `cmd` → Ctrl+Shift+Enter) y ejecutar:

```cmd
mkdir C:\Cloud
mkdir C:\gitlab
```

Verificar:

```cmd
dir C:\Cloud
dir C:\gitlab
```

Ambos directorios deben existir y estar vacíos antes de continuar.

---

## 9. PASO 2 — Variables de entorno y configuración de red

### 9.1. Copiar el certificado CA corporativo

El certificado `ca.segsocial.eu.goskope.crt` es necesario para que las herramientas de línea de comandos confíen en el proxy de inspección TLS corporativo (Netskope).

Se obtiene del SharePoint corporativo:

```
https://segsocial2020.sharepoint.com/:u:/r/sites/ET99GISS_GA_OTD_CLOUDAWS/Shared%20Documents/General/07.%20Configuraci%C3%B3n%20puesto%20de%20trabajo/Configuracion_EV_Desarrollo/Cloud.zip
```

Copiarlo en:

```
C:\Cloud\ca.segsocial.eu.goskope.crt
```

### 9.2. Establecer variables de entorno de proxy y SSL

Abrir **CMD como administrador** y ejecutar:

```cmd
setx HTTP_PROXY  "http://proxy.seg-social.es:8080"
setx HTTPS_PROXY "http://proxy.seg-social.es:8080"
setx NO_PROXY    "localhost,10.*,127.*,192.168.*,gitlab.pro.portal.ss,metadata.google.internal,*.googleapis.com,api.giss.int.portal.ss,*.portal.ss,*.seg-social.ss"
setx SSL_CERT_FILE "C:\Cloud\ca.segsocial.eu.goskope.crt"
setx OCI_DEFAULT_CERTS_PATH "C:\Cloud\ca.segsocial.eu.goskope.crt"
```

> **Nota:** `setx` persiste la variable para futuras sesiones pero no la activa en la sesión actual. Cerrar y reabrir CMD/PowerShell tras ejecutar estos comandos.

### 9.3. Verificar las variables en Windows 11

**Método gráfico:**

1. `Win + R` → `sysdm.cpl` → Enter
2. Pestaña **Opciones avanzadas** → **Variables de entorno…**
3. Confirmar `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, `SSL_CERT_FILE`, `OCI_DEFAULT_CERTS_PATH`.

**Método PowerShell:**

```powershell
[Environment]::GetEnvironmentVariable("HTTP_PROXY","User")
[Environment]::GetEnvironmentVariable("HTTPS_PROXY","User")
[Environment]::GetEnvironmentVariable("NO_PROXY","User")
[Environment]::GetEnvironmentVariable("SSL_CERT_FILE","User")
```

---

## 10. PASO 3 — Clonación de repositorios

Desde **PowerShell** (5.x o 7.x), posicionarse en `C:\gitlab` y clonar los 9 repositorios + el orquestador + el SDK:

```powershell
cd C:\gitlab


# Repositorio principal de IaC (GitLab corporativo monolítico)
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci_iac-oci.git

# Módulo orquestador de Terraform para OCI (GitHub)
git clone https://github.com/oci-landing-zones/terraform-oci-modules-orchestrator.git

# SDK Python de OCI — requerido para scripts de automatización y auditoría
git clone https://github.com/oracle/oci-python-sdk.git

# Stacks operativos
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci0000_iac-oci-foundation.git
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci0010_iac-oci-identity.git
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci0020_iac-oci-network.git

# Stacks esqueleto (pendientes de implementación)
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci0030_iac-oci-security-svc.git
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci0040_iac-oci-exa-infra.git
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci0041_iac-oci-exa-database.git
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci0050_iac-oci-obs-logs.git
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci0060_iac-oci-obs-monitor.git
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci0070_iac-oci-storage.git
```

---

## 11. PASO 4 — Instalación de OCI CLI

Desde **PowerShell**:

```powershell
winget search OracleCloudInfrastructureCLI
winget install --id Oracle.OracleCloudInfrastructureCLI --exact
```

Cerrar la sesión actual y abrir una nueva PowerShell para que el PATH se actualice. Verificar:

```powershell
oci --version
```

---

## 12. PASO 5 — Configuración de OCI CLI

Generar par de claves API en la consola OCI (perfil del operador → **API Keys** → **Add API Key**) y descargar la `.pem` privada.

Ejecutar:

```powershell
oci setup config
```

Proporcionar:

- Ubicación del fichero de config (por defecto `C:\Users\[USUARIO_SILCON]\.oci\config`).
- `user_ocid` del operador.
- `tenancy_ocid` de GISS.
- Región: `eu-madrid-2`.
- Path a la clave privada `.pem`.
- `fingerprint` que muestra la consola OCI.

---

## 13. PASO 6 — Pruebas de conectividad OCI CLI

```powershell
oci iam region list
oci iam availability-domain list --region eu-madrid-2
```

Ambos comandos deben devolver respuesta JSON sin errores TLS ni de autenticación.

---

## 14. PASO 7 — Instalación de Terraform

```powershell
winget search Hashicorp.Terraform
winget install --id Hashicorp.Terraform --exact
```

Reabrir PowerShell y verificar:

```powershell
terraform version
```

Debe responder `Terraform v1.15.x` o la versión validada vigente (ver sección 22).

---

## 15. PASO 8 — Instalación de Python

```powershell
winget search python
winget install --id Python.Python.3.14 --exact
```

Reabrir PowerShell y verificar:

```powershell
python --version
pip --version
```

Si `pip` no se reconoce:

```powershell
python -m ensurepip --upgrade
```

---

## 16. PASO 9 — Credenciales por stack

En **cada** repositorio clonado, crear el archivo:

```
C:\gitlab\<repositorio>\oci-credentials.auto.tfvars.json
```

Con la estructura:

```json
{
  "fingerprint": "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx",
  "private_key_path": "C:/Users/[USUARIO_SILCON]/.oci/[USUARIO_SILCON]_GISS_priv.pem",
  "tenancy_ocid": "ocid1.tenancy.oc1...",
  "user_ocid": "ocid1.user.oc1...",
  "home_region": "eu-madrid-2",
  "region": "eu-madrid-2",
  "private_key_password": null
}
```

**Notas críticas:**

- `private_key_path` usa barras `/` aunque sea Windows — requerido por el provider OCI.
- `private_key_password` debe ser `null` si la clave no tiene passphrase.
- Los valores deben ser idénticos a los usados en `oci setup config`.
- ⚠️ **Este archivo contiene credenciales — NUNCA commitear al repositorio.**
- ⚠️ **NO copiar este fichero dentro de `dependencies/`** — debe permanecer en la raíz del repo.

Verificar `.gitignore` en cada repo:

```powershell
Select-String -Path ".\.gitignore" -Pattern "auto.tfvars"
```

Si no devuelve resultado, añadir manualmente:

```
*.auto.tfvars.json
*.pem
```

---

## 17. PASO 10 — Backend GitLab y terraform init por stack

El state de cada stack se almacena en el backend HTTP del propio repositorio GitLab corporativo. Ejecutar en cada repo:

```powershell
cd C:\gitlab\<repositorio>
terraform init -reconfigure
```

El flag `-reconfigure` fuerza la reinicialización completa del directorio `.terraform`, descartando cualquier estado previo de caché local.

Validaciones post-init:

```powershell
terraform fmt -check
terraform validate
```

Ambos comandos deben completarse sin errores antes de continuar con el `plan`.

---

## 18. PASO 11 — terraform plan y apply por stack

> **Revisar siempre el output completo del `terraform plan` antes de confirmar el `apply`.** El uso de `-out` garantiza que el `apply` ejecuta exactamente el plan revisado, sin posibilidad de drift entre plan y ejecución.

### 18.1. Foundation (00)

```powershell
cd C:\gitlab\ga_ioci0000_iac-oci-foundation

terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_foundation_v3.6.json" `
  -out tfplan.out

terraform apply tfplan.out
```

Tras el primer apply, foundation genera en `./dependencies/`:

```text
compartments_output.json
tags_output.json
```

Regenerar el wrapper para stacks downstream:

```powershell
$depPath = ".\dependencies"

$comp = Get-Content "$depPath\compartments_output.json" -Raw | ConvertFrom-Json
$tags = Get-Content "$depPath\tags_output.json" -Raw | ConvertFrom-Json

$vars = [ordered]@{
  compartments_dependency = @{ compartments = $comp.compartments }
  tags_dependency         = @{ tags         = $tags.tags         }
}

$vars | ConvertTo-Json -Depth 30 |
  Set-Content "$depPath\foundation_dependencies.auto.tfvars.json" -Encoding utf8
```

Copiar `foundation_dependencies.auto.tfvars.json` a `dependencies\` de cada stack downstream.

### 18.2. Identity (10)

```powershell
cd C:\gitlab\ga_ioci0010_iac-oci-identity

terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_identity_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json" `
  -out tfplan.out

terraform apply tfplan.out
```

### 18.3. Network (20) — sin NFW (despliegue activo)

```powershell
cd C:\gitlab\ga_ioci0020_iac-oci-network

terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_network_base_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json" `
  -out tfplan.out

terraform apply tfplan.out
```

### 18.4. Network (20) — con overlay NFW (no recomendado por coste)

> El overlay NFW está marcado como `REFERENCE_ONLY_NOT_DEPLOYED` desde v3.4 por decisión de optimización de costes. Su reactivación requiere rediseño de routing east-west, política NFW con reglas L7 reales y validación de coste con CSM Oracle.

```powershell
cd C:\gitlab\ga_ioci0020_iac-oci-network

terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_network_base_v3.6.json" `
  -var-file ".\giss_network_nfw_addon_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json" `
  -out tfplan.out

terraform apply tfplan.out
```

### 18.5. Stacks esqueleto (30, 40, 41, 50, 60, 70)

Patrón equivalente, sustituyendo el fichero del stack:

```powershell
cd C:\gitlab\ga_ioci00NN_iac-oci-<stack>

terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_<stack>_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json" `
  -out tfplan.out

terraform apply tfplan.out
```

> Los esqueletos solo contienen `_meta` y `todo_resources` — requieren implementación previa antes de generar plan con cambios.

### 18.6. Destrucción

Mismo patrón sustituyendo `plan` por `destroy`. **El stack `foundation` tiene `enable_delete = "false"`**: los compartments no pueden borrarse vía Terraform sin cambiar manualmente ese flag, lo cual es **intencional** para prevenir destrucción accidental.

---

## 19. Importación declarativa de stacks ya desplegados

Los stacks `foundation`, `identity` y `network` ya estaban desplegados en OCI antes del split. Su migración al nuevo modelo de states separados se ha realizado mediante **bloques `import {}` declarativos** generados por script PowerShell, **sin recrear ni modificar infraestructura existente**.

### 19.1. Regla de seguridad

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

Si un plan muestra `add`, `change` o `destroy`, **no aplicar** hasta auditar la causa.

> Excepción documentada en Network: aparecen **2 add** correspondientes a recursos `local_file` y `time_sleep` generados por el propio orquestador (escritura de outputs y sincronización). No tienen impacto en OCI.

### 19.2. Versiones del generador validadas por stack

| Stack       | Script                                              |
| ----------- | --------------------------------------------------- |
| Foundation  | `Generate-OrchestratorImportBlocks-v3.0.ps1`      |
| Identity    | `Generate-OrchestratorImportBlocks-v3.1.ps1`      |
| Network     | `Generate-OrchestratorImportBlocks-v3.2.7.ps1`    |

No sustituir versiones anteriores ya consolidadas. `v3.2.7` incorpora soporte completo para `oci_core_*` / `oci_core_drg_*` y los flags `-NoPrecheck` / `-SkipMissing`.

### 19.3. Estado final validado tras la importación

```text
Foundation:  39 recursos importados — 0 add, 0 change, 0 destroy
Identity:    27 recursos importados — 0 add, 0 change, 0 destroy
Network:     56 recursos importados — 2 add, 0 change, 0 destroy
```

Validación de drift en los tres stacks: `No changes. Your infrastructure matches the configuration.`

### 19.4. Warnings residuales aceptados (upstream Oracle)

| Stack    | Warning                                                          | Impacto                         |
| -------- | ---------------------------------------------------------------- | ------------------------------- |
| Identity | `Deprecated resource attribute "ETag"`                          | Sin drift. No bloqueante.       |
| Network  | `Deprecated resource attribute "route_rules[...].cidr_block"`   | Sin drift. No bloqueante.       |

Aceptados hasta corrección oficial upstream. **No modificar `.terraform/modules/` ni módulos descargados.**

> Para el procedimiento detallado de importación stack a stack ver el documento `README_imports_v2.md` en cada repositorio.

---

## 20. Flujo operativo de sesión

Al inicio de cada sesión de trabajo, ejecutar este bloque de verificación antes de cualquier operación Terraform:

```powershell
# 1. Posicionarse en el directorio del stack
cd C:\gitlab\ga_ioci00NN_iac-oci-<stack>

# 2. Verificar versiones de herramientas
terraform version
oci --version
python --version

# 3. Verificar conectividad OCI
oci iam region list
oci iam availability-domain list --region eu-madrid-2

# 4. Inicializar y validar
terraform init -reconfigure
terraform fmt -check
terraform validate
```

Todos los comandos deben responder correctamente antes de ejecutar `plan` o `apply`.

---

## 21. Buenas prácticas

- Completar la verificación del flujo operativo de sesión (sección 20) antes de cualquier `plan` o `apply`.
- Trabajar siempre dentro de `C:\gitlab\ga_ioci00NN_iac-oci-<stack>` — un único stack por sesión de terminal.
- No borrar `.terraform.lock.hcl` salvo cambio aprobado de versión de provider.
- Mantener `oci setup config` y `oci-credentials.auto.tfvars.json` siempre alineados entre sí, en **todos** los repositorios.
- **Nunca commitear** `oci-credentials.auto.tfvars.json` ni archivos `.pem`.
- **Nunca copiar** `oci-credentials.auto.tfvars.json` dentro de `dependencies/`.
- Usar siempre `terraform plan -out=tfplan.out` y `terraform apply tfplan.out` — garantiza que el apply ejecuta exactamente el plan revisado.
- En stacks con dependencies externas, **regenerar `foundation_dependencies.auto.tfvars.json`** tras cualquier cambio en `foundation` antes de planificar downstream.
- Buscar `__FILL__` antes de cada `apply` y resolver con el responsable funcional del recurso.
- No asumir que dos entornos son iguales solo porque el root del repositorio coincide — el state remoto es la fuente de verdad.
- Respetar el orden de despliegue: foundation → identity → network → resto.
- Para stacks ya en producción, validar siempre `0 to add, 0 to change, 0 to destroy` antes de aplicar (con las excepciones documentadas en sección 19).

---

## 22. Versiones validadas

| Componente              | Versión validada                  |
| ----------------------- | --------------------------------- |
| Terraform               | v1.15.x windows_amd64             |
| OCI CLI                 | 3.81.x                            |
| Provider `oracle/oci` | ~> 8.5.0                          |
| Python                  | 3.14.x                            |
| PowerShell              | 7.6.x (procedimiento de import)  |
| Windows PowerShell      | 5.x (compatible para setup básico) |
| Sistema operativo       | Windows 11 (Entorno Virtual GISS) |

> El procedimiento de **importación declarativa** (sección 19) se validó con PowerShell 7.6.x. Los pasos 1–11 de setup workstation son compatibles tanto con Windows PowerShell 5.x como con PowerShell 7.x.

---

## 23. Disclaimer técnico

Estas instrucciones se basan en el procedimiento validado en entorno limpio Windows 11 con usuario SILCON GISS y en la POC de split multi-repo ejecutada sobre la Landing Zone GISS en `eu-madrid-2`. Las versiones de herramientas están fijadas a las validadas — no actualizar Terraform, OCI CLI ni el provider sin validación previa en entorno no productivo.

Toda recomendación, script o cambio debe ser revisado y validado por un arquitecto o especialista Oracle certificado antes de aplicarse en entornos productivos. Considerar siempre las políticas internas de la organización, los requisitos de seguridad corporativos (ENS, RGPD, ISO 27001) y los procesos de gestión del cambio vigentes.
