# README — Entorno de Despliegue OCI IaC GISS

**Versión:** 1.1  
**Última revisión:** Abril 2026  
**Proyecto:** OCI Landing Zone — Seguridad Social (GISS)  
**Plataforma:** Windows 11 (equipo corporativo con usuario SILCON)  
**PowerShell requerido:** Windows PowerShell 5.x — **NO usar PowerShell 7.x ni pwsh**

---

## Índice

1. [Qué es este documento](#1-qué-es-este-documento)
2. [Política de tagging OCI](#2-política-de-tagging-oci)
3. [Prerequisitos de acceso y cuenta](#3-prerequisitos-de-acceso-y-cuenta)
4. [Estructura de directorios esperada](#4-estructura-de-directorios-esperada)
5. [Orden de ejecución — resumen](#5-orden-de-ejecución--resumen)
6. [PASO 1 — Creación de directorios base](#6-paso-1--creación-de-directorios-base)
7. [PASO 2 — Variables de entorno y configuración de red](#7-paso-2--variables-de-entorno-y-configuración-de-red)
8. [PASO 3 — Clonación de repositorios](#8-paso-3--clonación-de-repositorios)
9. [PASO 4 — Instalación de OCI CLI](#9-paso-4--instalación-de-oci-cli)
10. [PASO 5 — Configuración de OCI CLI](#10-paso-5--configuración-de-oci-cli)
11. [PASO 6 — Pruebas de conectividad OCI CLI](#11-paso-6--pruebas-de-conectividad-oci-cli)
12. [PASO 7 — Instalación de Terraform](#12-paso-7--instalación-de-terraform)
13. [PASO 8 — Instalación de Python](#13-paso-8--instalación-de-python)
14. [PASO 9 — Creación de oci-credentials.auto.tfvars.json](#14-paso-9--creación-de-oci-credentialsautotfvarsjson)
15. [PASO 10 — Backend GitLab y terraform init](#15-paso-10--backend-gitlab-y-terraform-init)
16. [PASO 11 — terraform plan y apply](#16-paso-11--terraform-plan-y-apply)
17. [Flujo operativo de sesión](#17-flujo-operativo-de-sesión)
18. [Buenas prácticas](#18-buenas-prácticas)
19. [Versiones validadas](#19-versiones-validadas)

---

## 1. Qué es este documento

Este documento describe el procedimiento completo para preparar un equipo Windows 11 corporativo GISS y desplegar una **OCI Landing Zone** mediante Terraform.

El punto de partida es un equipo Windows con usuario SILCON activo, acceso al proxy corporativo (`proxy.seg-social.es:8080`) y conectividad a Internet a través de dicho proxy.

Las herramientas se instalan mediante **winget** (Windows Package Manager), disponible de forma nativa en Windows 11. No se requieren paquetes offline ni scripts adicionales.

El despliegue crea en el tenancy OCI de GISS (`eu-madrid-2`) la estructura de gobernanza, IAM, red y seguridad de la Landing Zone, incluyendo los namespaces de tags definidos en la sección 2.

> **Alcance de este documento:** exclusivamente herramientas y configuración OCI. No cubre instalación de AWS CLI, GCP CLI ni otros proveedores cloud.

---

## 2. Política de tagging OCI

La Landing Zone despliega un namespace de tags en el root del tenancy para el control de acceso basado en tags (TBAC). Los namespaces y tags se definen en `giss_governance__v3.3.json`.

### 2.1 Namespace: Control de Acceso Basado en Tags (TBAC)

| Campo | Valor |
|---|---|
| Namespace | `o-p-om2-tagns-name-001` |
| Descripción | Tag namespace for Tag Based Access Controls of Landing Zone Roles |
| Ámbito | `TENANCY-ROOT` |

| Tag | Descripción | Cost tracking |
|---|---|---|
| `o-p-om2-tag-role-001` | Identifica roles administrativos dentro de la Landing Zone, a través de los compartimentos de red y seguridad | No |

> Este namespace habilita políticas IAM basadas en tags (TBAC), permitiendo controlar el acceso a recursos OCI en función del valor asignado al tag `o-p-om2-tag-role-001`.

---

## 3. Prerequisitos de acceso y cuenta

Antes de iniciar, el operador debe tener activos los siguientes accesos:

- **Usuario SILCON** (formato `99GUXXXX`) asignado al proyecto GISS
- **Cuenta en GitLab corporativo:** `https://gitlab.pro.portal.ss` — el username debe ser el usuario SILCON; gestionar permisos sobre el repositorio `ga/ioci/ga_ioci_iac-oci` con el responsable del proyecto
- **Cuenta OCI** con permisos suficientes en el tenancy GISS — región `eu-madrid-2`
- **winget disponible** — verificar con `winget --version` desde PowerShell; debe devolver versión `1.x` o superior

> Estos accesos deben estar activos **antes** de ejecutar el PASO 1. Sin ellos no es posible completar la instalación ni la clonación de repositorios.

---

## 4. Estructura de directorios esperada

Tras completar todos los pasos, la estructura de trabajo en `C:\` debe ser:

```
C:\
├── Cloud\
│   └── ca.segsocial.eu.goskope.crt          (certificado CA corporativo)
└── gitlab\
    ├── ga_ioci_iac-oci\                      (repositorio principal IaC)
    │   ├── main.tf
    │   ├── providers.tf
    │   ├── versions.tf
    │   ├── variables.tf
    │   ├── oci-credentials.auto.tfvars.json  (a crear en PASO 9 — NO commitear)
    │   ├── giss_governance__v3.3.json
    │   ├── giss_iam_v3.4.json
    │   ├── giss_network_hub_b_empty_v3.3.json
    │   └── giss_network_hub_b_firewall_v3.3.json
    ├── terraform-oci-modules-orchestrator\   (módulo orquestador)
    └── oci-python-sdk\                       (SDK Python OCI — requerido para scripts)
```

---

## 5. Orden de ejecución — resumen

| Paso        | Qué hace                                                 | Método
|-------------|----------------------------------------------------------|-----------------------
| **PASO 1**  | Crear `C:\Cloud` y `C:\gitlab`                           | CMD como administrador
| **PASO 2**  | Variables de entorno de proxy, SSL y configuración git   | PowerShell / CMD
| **PASO 3**  | Clonar repositorios en `C:\gitlab`                       | git (PowerShell 5.x)
| **PASO 4**  | Instalar OCI CLI con winget                              | PowerShell
| **PASO 5**  | Configurar OCI CLI con credenciales del operador         | Consola OCI + PowerShell
| **PASO 6**  | Validar conectividad OCI CLI                             | PowerShell
| **PASO 7**  | Instalar Terraform con winget                            | PowerShell
| **PASO 8**  | Instalar Python con winget                               | PowerShell
| **PASO 9**  | Completar `oci-credentials.auto.tfvars.json`             | Editor de texto
| **PASO 10** | Backend GitLab y `terraform init`                        | PowerShell
| **PASO 11** | Ejecutar `terraform plan` y `terraform apply`            | PowerShell

---

## 6. PASO 1 — Creación de directorios base

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

## 7. PASO 2 — Variables de entorno y configuración de red

### 7.1 Copiar el certificado CA corporativo

> Este archivo se obtiene del SharePoint corporativo o del equipo de microinformática GISS.

El certificado `ca.segsocial.eu.goskope.crt` es necesario para que las herramientas de línea de comandos confíen en el proxy de inspección TLS corporativo (Netskope).

Se encuentra dentro de https://segsocial2020.sharepoint.com/:u:/r/sites/ET99GISS_GA_OTD_CLOUDAWS/Shared%20Documents/General/07.%20Configuraci%C3%B3n%20puesto%20de%20trabajo/Configuracion_EV_Desarrollo/Cloud.zip?csf=1&web=1&e=OUDNk3

Copiarlo en:

```
C:\Cloud\ca.segsocial.eu.goskope.crt
```

### 7.2 Establecer variables de entorno de proxy y SSL

Abrir **CMD como administrador** y ejecutar:

```cmd
setx HTTP_PROXY  "http://proxy.seg-social.es:8080"
setx HTTPS_PROXY "http://proxy.seg-social.es:8080"
setx NO_PROXY    "localhost,10.*,127.*,192.168.*,gitlab.pro.portal.ss,metadata.google.internal,*.googleapis.com,api.giss.int.portal.ss,*.portal.ss,*.seg-social.ss"
setx SSL_CERT_FILE "C:\Cloud\ca.segsocial.eu.goskope.crt"
```

> **Nota:** `setx` persiste la variable para futuras sesiones pero no la activa en la sesión actual. Cerrar y reabrir CMD/PowerShell tras ejecutar estos comandos.

### 7.3 Verificar las variables en Windows 11

**Método gráfico:**

1. `Win + R` → `sysdm.cpl` → Enter
2. Pestaña **Opciones avanzadas** → **Variables de entorno...**
3. Verificar en **Variables de usuario** que las siguientes variables existen con el valor correcto:

| Variable | Valor esperado |
|---|---|
| `HTTP_PROXY` | `http://proxy.seg-social.es:8080` |
| `HTTPS_PROXY` | `http://proxy.seg-social.es:8080` |
| `NO_PROXY` | (valor completo según sección 7.2) |
| `SSL_CERT_FILE` | `C:\Cloud\ca.segsocial.eu.goskope.crt` |

**Verificación rápida desde PowerShell:**

```powershell
echo $env:HTTP_PROXY
echo $env:HTTPS_PROXY
echo $env:NO_PROXY
echo $env:SSL_CERT_FILE
```

Todos deben devolver el valor esperado antes de continuar.

### 7.4 Configuración de git para el proxy corporativo

```powershell
git config --global http.sslVerify false
```

---

## 8. PASO 3 — Clonación de repositorios

Abrir **Windows PowerShell 5.x** (NO PowerShell 7.x) y ejecutar:

```powershell
cd C:\gitlab

# Repositorio principal de IaC (GitLab corporativo)
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci_iac-oci.git

# Módulo orquestador de Terraform para OCI (GitHub)
git clone https://github.com/oci-landing-zones/terraform-oci-modules-orchestrator.git

# SDK Python de OCI — requerido para scripts de automatización y auditoría
git clone https://github.com/oracle/oci-python-sdk.git
```

Verificar que los repositorios se clonaron correctamente:

```powershell
Test-Path C:\gitlab\ga_ioci_iac-oci
Test-Path C:\gitlab\terraform-oci-modules-orchestrator
Test-Path C:\gitlab\oci-python-sdk
```

Los tres deben devolver `True`.

---

## 9. PASO 4 — Instalación de OCI CLI

### 9.1 Instalar con winget

Abrir **Windows PowerShell** y ejecutar:

```powershell
winget search oci
winget install --id Oracle.OCI-CLI --exact
```

> winget instalará la última versión disponible en su catálogo. La versión validada para este proyecto es la **3.76.0** o superior. Si la versión instalada difiere, verificar con el equipo de arquitectura antes de continuar.

### 9.2 Cerrar y reabrir PowerShell

Cerrar la sesión actual y abrir una nueva **Windows PowerShell 5.x** para que el PATH se actualice con la ruta de instalación de OCI CLI.

### 9.3 Validar la instalación

```powershell
oci --version
```

Salida esperada: `3.76.0` o superior compatible.

---

## 10. PASO 5 — Configuración de OCI CLI

Crear el directorio `.oci` local:

```powershell
New-Item -ItemType Directory -Force -Path C:\Users\$env:USERNAME\.oci
```

### 10.1 Acceder a la consola OCI y obtener los OCIDs

Abrir navegador y acceder a:

```
https://cloud.oracle.eu/?region=eu-madrid-2
```

Seleccionar el tenancy **seguridadsocial** e iniciar sesión con credenciales corporativas.

**Tenancy OCID:**
- Menú perfil (esquina superior derecha) → nombre del tenancy → campo **OCID** → **Copiar**
- Formato: `ocid1.tenancy.oc1..xxxxxxxx`

**User OCID:**
- Menú perfil → **Mi perfil** → campo **OCID** → **Copiar**
- Formato: `ocid1.user.oc1..xxxxxxxx`

> Guardar ambos OCIDs en un bloc de notas temporal — se necesitarán en varios pasos posteriores.

### 10.2 Generar el par de claves API

**Nomenclatura de claves:** `[USUARIO_SILCON]_GISS_priv.pem` / `[USUARIO_SILCON]_GISS_pub.pem`

1. Consola OCI → **Mi perfil** → **Claves de API** → **Agregar clave de API**
2. Seleccionar **Generar par de claves**
3. Descargar la **clave privada** (`.pem`) y guardarla en:
   ```
   C:\Users\[USUARIO_SILCON]\.oci\[USUARIO_SILCON]_GISS_priv.pem
   ```
4. Descargar la **clave pública** como respaldo (opcional)
5. Hacer clic en **Agregar** y copiar el **Fingerprint** que aparece en la confirmación
   - Formato: `xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx`
   - ⚠️ **El fingerprint no puede recuperarse después — guardarlo en ese momento**
6. ⚠️ **Copiar todos los datos que aparecen en el resumen de la consola OCI a un bloc de notas** ⚠️

### 10.3 Gestionar permisos del directorio .oci

**La CLI de OCI no funcionará si la clave privada es accesible por otros usuarios en la máquina.** Antes de ejecutar `oci setup config`:

1. Clic derecho sobre la carpeta `.oci` → **Propiedades** → pestaña **Seguridad** → **Opciones avanzadas**
2. Clic en **Deshabilitar herencia** → seleccionar **"Convertir los permisos heredados en permisos explícitos"**
3. Eliminar todos los usuarios y grupos excepto tu usuario actual y `SYSTEM`
4. Tu usuario debe tener **Control total**
5. Asegurarse de que `Usuarios` y `Todos` no tienen permisos

Repetir el mismo proceso para cada archivo dentro de la carpeta `.oci` tras ejecutar `oci setup config`.

### 10.4 Ejecutar oci setup config

Abrir **Windows PowerShell 5.x**:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
oci setup config
```

Respuestas al asistente interactivo:

| Pregunta del asistente              | Valor a introducir |
|-------------------------------------|--------------------|
| Location for config                 | Enter (acepta `C:\Users\[USUARIO_SILCON]\.oci\config`)
| User OCID                           | OCID obtenido en 10.1
| Tenancy OCID                        | OCID obtenido en 10.1
| Region                              | Seleccionar `eu-madrid-2` en el listado numérico (39)
| Generate new API key pair?          | `n` (ya se generó en la consola OCI en 10.2)
| Location of API Signing private key | `C:\Users\[USUARIO_SILCON]\.oci\[USUARIO_SILCON]_GISS_priv.pem`
| Fingerprint                         | Fingerprint obtenido en 10.2

> Tras ejecutar `oci setup config`, **repetir la revisión de permisos** sobre los archivos creados dentro de `.oci` (especialmente `config` y el `.pem`).

### 10.5 Verificar el fichero config generado

```powershell
Get-Content C:\Users\$env:USERNAME\.oci\config
```

Estructura esperada:

```ini
[DEFAULT]
user=ocid1.user.oc1..xxxxxxxx
fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
tenancy=ocid1.tenancy.oc1..xxxxxxxx
region=eu-madrid-2
key_file=C:\Users\[USUARIO_SILCON]\.oci\[USUARIO_SILCON]_GISS_priv.pem
```

---

## 11. PASO 6 — Pruebas de conectividad OCI CLI

Ejecutar desde **Windows PowerShell**:

```powershell
oci iam region list
oci iam availability-domain list --region eu-madrid-2
oci identity-domains group get --endpoint  https://idcs-e0138a37daa84b4aacdb004b63eb5d75.eu-madrid-idcs-2.identity.oci.oraclecloud.eu --group-id 1f2d6edbbdba48de93f4fedd4c65173d
```

Los comandos deben devolver respuesta JSON con datos reales sin errores.

> **Si alguno de los comandos de validación falla, NO continuar.** Revisar la configuración OCI antes de avanzar.

---

## 12. PASO 7 — Instalación de Terraform

### 12.1 Instalar con winget

```powershell
winget search Terraform
winget install --id Hashicorp.Terraform --exact
```

> winget instalará la última versión estable disponible. La versión validada para este proyecto es **v1.14.7** o superior. Si la versión instalada es diferente, evaluar compatibilidad con el equipo de arquitectura antes de continuar — no actualizar Terraform sin validación previa en entorno de pruebas.

### 12.2 Cerrar y reabrir PowerShell

Cerrar la sesión actual y abrir una nueva **Windows PowerShell 5.x** para que el PATH se actualice.

### 12.3 Validar versión de Terraform

```powershell
terraform version
```

Salida esperada:

```
Terraform v1.14.7 (o superior)
on windows_amd64
```

Si la versión no coincide con la validada, no continuar hasta alinearlo con el equipo.

---

## 13. PASO 8 — Instalación de Python

Python es requerido para la ejecución de los scripts del SDK de OCI (`oci-python-sdk`). OCI CLI incluye su propio entorno Python — esta instalación es independiente y necesaria para los scripts de automatización y auditoría del proyecto.

```powershell
winget search python
winget install --id Python.Python.3.14 --exact
```

Cerrar la sesión actual y abrir una nueva **Windows PowerShell 5.x** para que el PATH se actualice.

Verificar tras reabrir PowerShell:

```powershell
python --version
pip --version
```

Ambos comandos deben responder con versión. Si `pip` no se reconoce:

```powershell
python -m ensurepip --upgrade
```

---

## 14. PASO 9 — Creación de oci-credentials.auto.tfvars.json

Crear el archivo dentro del repositorio con un editor de texto (Notepad, VS Code):

```
C:\gitlab\ga_ioci_iac-oci\oci-credentials.auto.tfvars.json
```

Estructura válida (usar los mismos valores que en `oci setup config`):

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
- `private_key_path` usa barras `/` aunque sea Windows — requerido por el provider OCI
- `private_key_password` debe ser `null` si la clave no tiene passphrase
- Los valores deben ser idénticos a los usados en `oci setup config`
- ⚠️ **Este archivo contiene credenciales — NUNCA commitear al repositorio**

### 14.1 Verificar que el archivo está en .gitignore

```powershell
Select-String -Path "C:\gitlab\ga_ioci_iac-oci\.gitignore" -Pattern "auto.tfvars"
```

Si no devuelve resultado, añadir manualmente al `.gitignore`:

```
*.auto.tfvars.json
*.pem
```

---

## 15. PASO 10 — Backend GitLab y terraform init

El estado de Terraform se almacena en el backend HTTP de GitLab corporativo (`gitlab.pro.portal.ss`). `terraform init -reconfigure` conecta con el backend remoto y descarga el estado actual antes de cualquier operación.

### 15.1 Ejecutar terraform init

```powershell
cd C:\gitlab\ga_ioci_iac-oci
terraform init -reconfigure
```

El flag `-reconfigure` fuerza la reinicialización completa del directorio `.terraform`, descartando cualquier estado previo de caché local. Usarlo siempre que la red de GISS lo permita — especialmente tras cambios de backend, actualización de módulos o problemas de inicialización anteriores.

Si todo está correcto:
- Se conecta al backend GitLab y verifica el estado remoto
- Se resuelven los módulos (referencia relativa `../terraform-oci-modules-orchestrator`)
- Se descargan los providers desde el registry público de Terraform
- Se genera o valida `.terraform.lock.hcl`

### 15.2 Validaciones post-init

```powershell
terraform fmt -check
terraform validate
```

Ambos comandos deben completarse sin errores antes de continuar con el `plan`.

---

## 16. PASO 11 — terraform plan y apply

> **Revisar siempre el output completo del `terraform plan` antes de confirmar el `apply`.** El uso de `-out` garantiza que el `apply` ejecuta exactamente el plan revisado, sin posibilidad de drift entre plan y ejecución.

### 16.1 Despliegue sin OCI Network Firewall

```powershell
terraform plan `
  -var-file .\oci-credentials.auto.tfvars.json `
  -var-file .\giss_governance__v3.3.json `
  -var-file .\giss_iam_v3.4.json `
  -var-file .\giss_network_hub_b_empty_v3.3.json `
  -out tfplan.out

terraform apply tfplan.out
```

### 16.2 Despliegue con OCI Network Firewall

```powershell
terraform plan `
  -var-file .\oci-credentials.auto.tfvars.json `
  -var-file .\giss_governance__v3.3.json `
  -var-file .\giss_iam_v3.4.json `
  -var-file .\giss_network_hub_b_firewall_v3.3.json `
  -out tfplan.out

terraform apply tfplan.out
```

### 16.3 Destrucción del entorno

Sin OCI Network Firewall:

```powershell
terraform destroy `
  -var-file .\oci-credentials.auto.tfvars.json `
  -var-file .\giss_governance__v3.3.json `
  -var-file .\giss_iam_v3.4.json `
  -var-file .\giss_network_hub_b_empty_v3.3.json
```

Con OCI Network Firewall:

```powershell
terraform destroy `
  -var-file .\oci-credentials.auto.tfvars.json `
  -var-file .\giss_governance__v3.3.json `
  -var-file .\giss_iam_v3.4.json `
  -var-file .\giss_network_hub_b_firewall_v3.3.json
```

---

## 17. Flujo operativo de sesión

Al inicio de cada sesión de trabajo, ejecutar siempre este bloque de verificación antes de cualquier operación Terraform:

```powershell
# 1. Posicionarse en el directorio de trabajo
cd C:\gitlab\ga_ioci_iac-oci

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

## 18. Buenas prácticas

- Completar la verificación del flujo operativo de sesión (sección 17) antes de cualquier `plan` o `apply`
- Usar siempre `C:\gitlab\ga_ioci_iac-oci` como directorio de trabajo
- No borrar `.terraform.lock.hcl` salvo cambio aprobado de versión de provider
- Mantener `oci setup config` y `oci-credentials.auto.tfvars.json` siempre alineados entre sí
- Nunca commitear `oci-credentials.auto.tfvars.json` ni archivos `.pem` al repositorio
- Usar siempre `terraform plan -out=tfplan.out` y `terraform apply tfplan.out` — garantiza que el apply ejecuta exactamente el plan revisado
- No asumir que dos entornos son iguales solo porque el root del repositorio coincide

---

## 19. Versiones validadas

| Componente          | Versión validada |
|---------------------|------------------|
| Terraform           | v1.14.7 windows_amd64
| OCI CLI             | 3.76.0
| Provider oracle/oci | ~> 8.5.0
| Python              | 3.14.x
| Windows PowerShell  | 5.x (NO usar 7.x)
| Sistema operativo   | Windows 11 (Entorno Virtual GISS)

---

> **Disclaimer técnico:** estas instrucciones se basan en el procedimiento validado en entorno limpio Windows 11 con usuario SILCON GISS. Las versiones de herramientas están fijadas a las validadas — no actualizar Terraform, OCI CLI ni el provider sin validación previa en entorno no productivo. Considerar siempre las políticas internas de la organización, los requisitos de seguridad corporativos y los procesos de gestión del cambio vigentes.
