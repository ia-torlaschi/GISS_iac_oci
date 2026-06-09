# README — Entorno de Despliegue OCI IaC GISS
**Versión:** 0.2  
**Última revisión:** 2025  
**Proyecto:** OCI Landing Zone — Seguridad Social (GISS)  
**Plataforma:** Windows 11
**PowerShell requerido:** Windows PowerShell 5.x (NO usar PowerShell 7.x)

---

## Índice

1. [Qué es este paquete](#1-qué-es-este-paquete)
2. [Prerequisitos de acceso y cuenta](#2-prerequisitos-de-acceso-y-cuenta)
3. [Estructura de directorios esperada](#3-estructura-de-directorios-esperada)
4. [Orden de ejecución — resumen](#4-orden-de-ejecución--resumen)
5. [PASO 1 — Creación de directorios y copia de archivos desde SharePoint](#5-paso-1--creación-de-directorios-y-copia-de-archivos-desde-sharepoint)
6. [PASO 2 — Variables de entorno](#6-paso-2--variables-de-entorno)
7. [PASO 3 — Instalación de herramientas base: AWS CLI y GCP CLI](#7-paso-3--instalación-de-herramientas-base-aws-cli-y-gcp-cli)
8. [PASO 4 — Clonación de repositorios](#8-paso-4--clonación-de-repositorios)
9. [PASO 5 — Extracción del paquete giss_oci_despliegue.7z](#9-paso-5--extracción-del-paquete-giss_oci_despliegue7z)
10. [PASO 6 — Instalación offline de OCI CLI](#10-paso-6--instalación-offline-de-oci-cli)
11. [PASO 7 — Instalación de Terraform](#11-paso-7--instalación-de-terraform)
12. [PASO 8 — Configuración de OCI CLI](#12-paso-8--configuración-de-oci-cli)
13. [PASO 9 — Pruebas de conectividad OCI CLI](#13-paso-9--pruebas-de-conectividad-oci-cli)
14. [PASO 10 — Creación de oci-credentials.auto.tfvars.json](#14-paso-10--creación-de-oci-credentialsautotfvarsjson)
15. [PASO 11 — Validación del módulo orquestador](#15-paso-11--validación-del-módulo-orquestador)
16. [PASO 12 — Configuración del mirror de Terraform](#16-paso-12--configuración-del-mirror-de-terraform)
17. [PASO 13 — terraform init](#17-paso-13--terraform-init)
18. [PASO 14 — terraform plan y apply](#18-paso-14--terraform-plan-y-apply)
19. [Flujo operativo de sesión](#19-flujo-operativo-de-sesión)
20. [Troubleshooting](#20-troubleshooting)
21. [Buenas prácticas](#21-buenas-prácticas)
22. [Versiones validadas](#22-versiones-validadas)

---

## 1. Qué es este paquete

Este documento describe el procedimiento completo para preparar un equipo Windows corporativo GISS y desplegar una **OCI Landing Zone** mediante Terraform, sin requerir acceso a Internet durante el despliegue.

El punto de partida es un equipo Windows con usuario SILCON activo y acceso al SharePoint corporativo. A partir de ahí, este documento guía todos los pasos en orden secuencial hasta el `terraform apply`.

---

## 2. Prerequisitos de acceso y cuenta

Antes de iniciar, el operador debe tener activos los siguientes accesos:

- **Usuario SILCON** (formato `99GUXXXX`) asignado al proyecto GISS
- **Cuenta en GitLab corporativo:** solicitar acceso en `https://gitlab.pro.portal.ss/users/sign_up` — el username debe ser el usuario SILCON; la confirmación llega por email corporativo GISS. Gestionar permisos sobre el repositorio `ga/ioci/ga_ioci_iac-oci` con el responsable del proyecto
- **Perfil de navegación avanzado** en el equipo: abrir PASS a microinformática para asignación y para añadir el usuario al grupo `99GISS.Netskope_SUITE_Amazon_GISS` del directorio activo
- **Permisos en Nexus/Jenkins** del centro de desarrollo correspondiente (CDINSS, CDTGSS, Gerencia Adjunta…) — ver procedimiento en el portal DevOps
- **Cuenta OCI** con permisos de administrador en el tenancy GISS (región `eu-madrid-2`)

> Estos accesos deben estar activos **antes** de ejecutar el PASO 1. Sin ellos no es posible completar la descarga ni la clonación de repositorios.

---

## 3. Estructura de directorios esperada

Tras completar todos los pasos, la estructura de `C:\` debe ser:

```
C:\
├── Cloud\
│   ├── ca.segsocial.eu.goskope.crt              (del Cloud.zip de SharePoint)
│   ├── InstalaCloud_1.bat                        (del Cloud.zip de SharePoint)
│   ├── InstalaCloud_2.bat                        (del Cloud.zip de SharePoint)
│   ├── InstalaCloud_3.bat                        (del Cloud.zip de SharePoint)
│   ├── oci-cli-3.76.0-Windows-Server-2019-Offline.zip   (del OCI.zip de SharePoint)
│   ├── terraform_1.14.7_windows_amd64.zip        (del OCI.zip de SharePoint)
│   ├── giss_oci_despliegue.7z                    (del OCI.zip de SharePoint)
│   └── Terraform\
│       └── terraform.exe                         (extraído en PASO 7)
└── gitlab\
    ├── ga_ioci_iac-oci\
    │   ├── .terraform\                           (extraído del .7z en PASO 5)
    │   ├── .terraform_mirror\                    (extraído del .7z en PASO 5)
    │   │   └── registry.terraform.io\oracle\oci\ (extraído del .7z en PASO 5)
    │   ├── .terraformrc-local                    (extraído del .7z en PASO 5)
    │   ├── .terraform.lock.hcl                   (extraído del .7z en PASO 5)
    │   ├── terraform.tfstate                     (extraído del .7z en PASO 5)
    │   ├── terraform.tfstate.backup              (extraído del .7z en PASO 5)
    │   ├── main.tf                               (del git clone en PASO 4)
    │   ├── providers.tf                          (del git clone en PASO 4)
    │   ├── versions.tf                           (del git clone en PASO 4)
    │   ├── variables.tf                          (del git clone en PASO 4)
    │   ├── oci-credentials.auto.tfvars.json      (a rellenar en PASO 10)
    │   ├── giss_governance__v3.3.json            (del git clone en PASO 4)
    │   ├── giss_iam_v3.4.json                    (del git clone en PASO 4)
    │   ├── giss_network_hub_b_empty_v3.3.json    (del git clone en PASO 4)
    │   └── giss_network_hub_b_firewall_v3.3.json (del git clone en PASO 4)
    ├── terraform-oci-modules-orchestrator\       (del git clone en PASO 4)
    │   └── providers.tf                          (crítico: debe declarar oracle/oci)
    └── oci-python-sdk\                           (del git clone en PASO 4, opcional)
```

---

## 4. Orden de ejecución — resumen

| Paso | Qué hace | Quién lo hace |
|---|---|---|
| **PASO 1** | Crear `C:\Cloud` y `C:\gitlab`. Descargar y copiar archivos desde SharePoint | Operador (manual) |
| **PASO 2** | Ejecutar `InstalaCloud_1.bat` — establece variables de entorno | Script |
| **PASO 3** | Ejecutar `InstalaCloud_2.bat` e `InstalaCloud_3.bat` — AWS CLI, GCP CLI, Python, PATH | Scripts |
| **PASO 4** | Clonar los tres repositorios en `C:\gitlab` | Operador (git) |
| **PASO 5** | Extraer `giss_oci_despliegue.7z` en `C:\gitlab\ga_ioci_iac-oci\` | Operador (7-Zip) |
| **PASO 6** | Instalar OCI CLI offline con `-AcceptAllDefaults` | Operador (PowerShell) |
| **PASO 7** | Extraer `terraform.exe` en `C:\Cloud\Terraform` y añadir al PATH | Operador (PowerShell) |
| **PASO 8** | Configurar OCI CLI con credenciales del operador (`oci setup config`) | Operador (consola OCI + PowerShell) |
| **PASO 9** | Validar conectividad OCI CLI | Operador (PowerShell) |
| **PASO 10** | Completar `oci-credentials.auto.tfvars.json` | Operador (editor de texto) |
| **PASO 11** | Validar `providers.tf` del módulo orquestador | Operador (PowerShell) |
| **PASO 12** | Establecer variable `TF_CLI_CONFIG_FILE` para el mirror | Operador (PowerShell) |
| **PASO 13** | Ejecutar `terraform init -reconfigure` | Operador (PowerShell) |
| **PASO 14** | Ejecutar `terraform plan` y `terraform apply` | Operador (PowerShell) |

---

## 5. PASO 1 — Creación de directorios y copia de archivos desde SharePoint

Este es el punto de entrada absoluto. Ningún script ni herramienta puede ejecutarse sin completar este paso primero.

### 5.1 Crear los directorios base

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

### 5.2 Descargar los archivos desde SharePoint

Acceder al SharePoint corporativo GISS y navegar a la biblioteca:

```
Configuracion_EV_Desarrollo
 ( https://segsocial2020.sharepoint.com/:f:/r/sites/ET99GISS_GA_OTD_CLOUDAWS/Shared%20Documents/General/07.%20Configuraci%C3%B3n%20puesto%20de%20trabajo/Configuracion_EV_Desarrollo?csf=1&web=1&e=jG40Zr )
```

Descargar los siguientes tres elementos:

| Elemento a descargar | Contenido | Destino local |
|---|---|---|
| `Cloud.zip` | Scripts `InstalaCloud_1/2/3.bat`, certificado CA, herramientas base | Descomprimir en `C:\Cloud\` |
| `Configuracion_EV_Infra-cloud_Developer_V0.1.docx` | Manual de referencia del entorno de desarrollo cloud | Guardar en `C:\Cloud\` |
| `OCI.zip` | `oci-cli-3.76.0-Windows-Server-2019-Offline.zip`, `terraform_1.14.7_windows_amd64.zip`, `giss_oci_despliegue.7z` | Descomprimir en `C:\Cloud\` |
| `README_DESPLIEGUE_v0.2.md` | Paso a paso Despliegue OCI-CLI Repositorio| Guardar en `C:\Cloud\` |

### 5.3 Descomprimir Cloud.zip en C:\Cloud

1. Clic derecho sobre `Cloud.zip` → **Extraer todo...** (o con 7-Zip: **Extraer aquí**)
2. Destino: `C:\Cloud\`
3. Verificar que quedan los archivos:

```powershell
Test-Path C:\Cloud\InstalaCloud_1.bat
Test-Path C:\Cloud\InstalaCloud_2.bat
Test-Path C:\Cloud\InstalaCloud_3.bat
Test-Path C:\Cloud\ca.segsocial.eu.goskope.crt
```

Todos deben devolver `True`.

### 5.4 Descomprimir OCI.zip en C:\Cloud

1. Clic derecho sobre `OCI.zip` → **Extraer todo...** (o con 7-Zip: **Extraer aquí**)
2. Destino: `C:\Cloud\`
3. Verificar que quedan los archivos:

```powershell
Test-Path "C:\Cloud\oci-cli-3.76.0-Windows-Server-2019-Offline.zip"
Test-Path C:\Cloud\terraform_1.14.7_windows_amd64.zip
Test-Path C:\Cloud\giss_oci_despliegue.7z
```

Todos deben devolver `True`.

### 5.5 Estado final de C:\Cloud al terminar este paso

```powershell
Get-ChildItem C:\Cloud
```

Deben aparecer al menos:
- `AWSCLIV2.msi`
- `ca.segsocial.eu.goskope.crt`
- `Configuracion_EV_Infra-cloud_Developer_V0.1.docx`
- `giss_oci_despliegue.7z`
- `google-clod-sdk-zip`
- `InstalaCloud_1.bat`
- `InstalaCloud_2.bat`
- `InstalaCloud_3.bat`
- `oci-cli-3.76.0-Windows-Server-2019-Offline.zip`
- `README_DESPLIEGUE_v0.2.MD`
- `terraform_1.11.4_windows_386.zip`
- `terraform_1.14.7_windows_amd64.zip`
- `vs-settings-default.json`

> No continuar al PASO 2 hasta que todos estos archivos estén presentes.

---

## 6. PASO 2 — Variables de entorno

`InstalaCloud_1.bat` establece algunas variables de entorno necesarias para que las herramientas cloud funcionen en el entorno corporativo (proxy, certificados, perfil AWS).

### 6.1 Ejecutar el script

Abrir **CMD como administrador** y ejecutar:

```cmd
C:\Cloud\InstalaCloud_1.bat
```

Al finalizar, **cerrar completamente CMD** y volver a abrirlo como administrador antes de continuar.

### 6.2 Variables

| Variable | Valor |
|---|---|
| `SSL_CERT_FILE` | `C:\Cloud\ca.segsocial.eu.goskope.crt` |
| `AWS_CA_BUNDLE` | `C:\Cloud\ca.segsocial.eu.goskope.crt` |
| `CURL_CA_BUNDLE` | `C:\Cloud\ca.segsocial.eu.goskope.crt` | (Crear amanualmente)
| `AWS_PROFILE` | `giss-aft` |
| `HTTP_PROXY` | `http://proxy.seg-social.es:8080` |
| `HTTPS_PROXY` | `http://proxy.seg-social.es:8080` |
| `NO_PROXY` | `localhost,10.*,127.*,192.168.*,gitlab.pro.portal.ss,metadata.google.internal,*.googleapis.com,api.giss.int.portal.ss,*.portal.ss,*.seg-social.ss` |
| `OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING` | `True` | (Crear amanualmente)

### 6.3 Verificar las variables en Windows 11

**Método 1 — Interfaz gráfica:**

1. Pulsar `Win + R` → escribir `sysdm.cpl` → Enter
2. Pestaña **Opciones avanzadas** → botón **Variables de entorno...**
3. Se abren dos secciones:
   - **Variables de usuario** (parte superior): aplican solo al usuario actual
   - **Variables del sistema** (parte inferior): aplican a todos los usuarios
4. Localizar cada variable de la tabla anterior y verificar que el valor coincide exactamente, caso contrario crearlas


**Verificación rápida de la sesión activa:**

```powershell
echo $env:SSL_CERT_FILE
echo $env:AWS_CA_BUNDLE
echo $env:CURL_CA_BUNDLE
echo $env:AWS_PROFILE
echo $env:HTTP_PROXY
echo $env:HTTPS_PROXY
echo $env:NO_PROXY
echo $env:OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING
```

> `$env:VARIABLE` muestra el valor activo en la sesión actual. `GetEnvironmentVariable(..., "User")` consulta el valor persistido en el registro, independientemente de si la sesión lo ha recargado.

git config --global http.sslVerify false
---

## 7. PASO 3 — Instalación de herramientas base: AWS CLI y GCP CLI

Ejecutar los scripts en orden. Cerrar y reabrir CMD como administrador entre cada uno.

### 7.1 InstalaCloud_2.bat — AWS CLI y GCP CLI

```cmd
C:\Cloud\InstalaCloud_2.bat
```

Durante la ejecución aparecerán preguntas interactivas — responder **N** + Enter a todas.

Instala: AWS CLI v2 de forma silenciosa y GCP CLI desde el SDK incluido en `Cloud.zip`.

Cerrar CMD al terminar.

### 7.2 InstalaCloud_3.bat — PATH, Python y AWS SSO

Reabrir CMD como administrador y ejecutar:

```cmd
C:\Cloud\InstalaCloud_3.bat
```

Realiza: añadir GCP SDK y Terraform al PATH del usuario, instalar Python 3 con Chocolatey, configurar el proxy para `gcloud`, copiar la configuración base de VS Code y configurar AWS SSO. Durante la configuración de AWS SSO se solicitarán parámetros — rellenar con los valores proporcionados por el equipo.

Cerrar CMD al terminar.

---

## 8. PASO 4 — Clonación de repositorios

Abrir **Windows PowerShell** (NO PowerShell 7.x) y ejecutar:

```powershell
cd C:\gitlab

# Repositorio principal de IaC (GitLab corporativo)
git clone https://gitlab.pro.portal.ss/ga/ioci/ga_ioci_iac-oci.git

# Módulo orquestador de Terraform para OCI (GitHub)
git clone https://github.com/oci-landing-zones/terraform-oci-modules-orchestrator.git

# SDK Python de OCI — opcional, no requerido para Terraform
git clone https://github.com/oracle/oci-python-sdk.git
```

Verificar que los repositorios se clonaron correctamente:

```powershell
Test-Path C:\gitlab\ga_ioci_iac-oci
Test-Path C:\gitlab\terraform-oci-modules-orchestrator
```

Ambos deben devolver `True`.

> Para el repositorio GitLab corporativo se requiere cuenta activa con permisos sobre `ga/ioci/ga_ioci_iac-oci`. Para los repos de GitHub, si no hay salida a Internet disponible en el equipo, solicitar copia local o mirror autorizado al equipo de arquitectura.

---

## 9. PASO 5 — Extracción del paquete giss_oci_despliegue.7z

El archivo `giss_oci_despliegue.7z` contiene directamente los artefactos de Terraform en su raíz, sin estructura de carpetas intermedia:

```
.terraform\
.terraform_mirror\
terraform.tfstate
terraform.tfstate.backup
```

El destino de extracción debe ser la carpeta del repositorio ya clonado `C:\gitlab\ga_ioci_iac-oci\`.

### 9.1 Extraer con 7-Zip

1. Abrir el Explorador de archivos y navegar a `C:\Cloud`
2. Clic derecho sobre `giss_oci_despliegue.7z` → **7-Zip** → **Extraer archivos...**
3. En el campo **Extraer en**, escribir exactamente:
   ```
   C:\gitlab\ga_ioci_iac-oci\
   ```
4. Hacer clic en **Aceptar**

### 9.2 Verificar la extracción

```powershell
Test-Path C:\gitlab\ga_ioci_iac-oci\.terraform_mirror
Test-Path C:\gitlab\ga_ioci_iac-oci\.terraformrc-local
Test-Path C:\gitlab\ga_ioci_iac-oci\terraform.tfstate
```

Los tres deben devolver `True`.

> **Atención:** si se extrae en `C:\gitlab\` en lugar de `C:\gitlab\ga_ioci_iac-oci\`, los artefactos quedan en el nivel incorrecto y Terraform no los encontrará. Verificar siempre la ruta destino antes de extraer.

---

## 10. PASO 6 — Instalación offline de OCI CLI

El instalador offline incluye un script PowerShell que acepta `-AcceptAllDefaults` para instalación completamente desatendida, sin preguntas interactivas.

Documentación oficial de referencia:
- Instalación offline: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/climanualinst.htm
- API Signing Key: https://docs.oracle.com/es-ww/iaas/Content/API/Concepts/apisigningkey.htm

### 10.1 Extraer el instalador

Abrir **Windows PowerShell** y ejecutar:

```powershell
# Crear directorio de trabajo para la extracción
New-Item -ItemType Directory -Force -Path C:\Cloud\oci-cli-offline

# Extraer el ZIP del instalador offline
Expand-Archive -Path "C:\Cloud\oci-cli-3.76.0-Windows-Server-2019-Offline.zip" `
               -DestinationPath "C:\Cloud\oci-cli-offline" -Force
```

### 10.2 Localizar el script de instalación

```powershell
Get-ChildItem -Path C:\Cloud\oci-cli-offline -Recurse -Filter "install.ps1" | Select-Object FullName
```

El resultado mostrará la ruta completa, por ejemplo:
```
C:\Cloud\oci-cli-offline\oci-cli-3.76.0\install.ps1
```

#############################################
winget search python 

winget search oci
#############################################

Anotar esa ruta — se usa en el siguiente paso.

### 10.3 Ejecutar la instalación desatendida

```powershell
# Permitir ejecución de scripts en esta sesión (no modifica la política global del sistema)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Ejecutar el instalador aceptando todos los valores por defecto
C:\Cloud\oci-cli-offline\oci-cli-3.76.0\install.ps1 -AcceptAllDefaults
```

> Sustituir `oci-cli-3.76.0` por el nombre de directorio real que devolvió el paso 10.2 si difiere.

El parámetro `-AcceptAllDefaults` acepta automáticamente: ruta de instalación, actualización de PATH, instalación de dependencias Python y todas las demás preguntas del instalador.

### 10.4 Cerrar y reabrir Windows PowerShell

Cerrar la sesión actual de PowerShell y abrir una nueva para que el PATH se actualice con la ruta de OCI CLI.

### 10.5 Validar la instalación

```powershell
oci --version
```

Salida esperada: `3.76.0` o similar. Si el comando no se reconoce, ver troubleshooting 20.3.

---

## 11. PASO 7 — Instalación de Terraform

### 11.1 Extraer terraform.exe

```powershell
# Extraer terraform.exe desde el ZIP a C:\Cloud\Terraform
# tar está disponible de forma nativa en Windows 10/11 y Server 2019+
tar -xf C:\Cloud\terraform_1.14.7_windows_amd64.zip -C C:\Cloud\Terraform terraform.exe
```

Verificar:
```powershell
Test-Path C:\Cloud\Terraform\terraform.exe
```

### 11.2 Añadir C:\Cloud\Terraform al PATH del usuario

```powershell
# Leer el PATH actual del usuario
$currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")

# Añadir C:\Cloud\Terraform solo si no está ya presente
if ($currentPath -notlike "*C:\Cloud\Terraform*") {
    $newPath = $currentPath + ";C:\Cloud\Terraform"
    [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "[OK] C:\Cloud\Terraform añadido al PATH de usuario."
} else {
    Write-Host "[OK] C:\Cloud\Terraform ya estaba en el PATH."
}

# Activar en la sesión actual sin necesidad de reabrir PowerShell
$env:PATH = $env:PATH + ";C:\Cloud\Terraform"
```

### 11.3 Validar versión de Terraform

```powershell
terraform version
```

Salida esperada:
```
Terraform v1.14.7
on windows_amd64
```

Si la versión no coincide con `v1.14.7`, no continuar hasta corregirla.

---

## 12. PASO 8 — Configuración de OCI CLI

### 12.1 Acceder a la consola OCI y obtener los OCIDs

Abrir navegador y acceder a `https://cloud.oracle.com`. Seleccionar el tenancy **GISS** e iniciar sesión con credenciales corporativas. Región: `eu-madrid-2`.

**Tenancy OCID:**
- Menú perfil (esquina superior derecha) → nombre del tenancy → campo **OCID** → **Copiar**
- Formato: `ocid1.tenancy.oc1..xxxxxxxx`

**User OCID:**
- Menú perfil → **Mi perfil** → campo **OCID** → **Copiar**
- Formato: `ocid1.user.oc1..xxxxxxxx`

### 12.2 Generar el par de claves API

Crear el directorio `.oci` si no existe:
```powershell
New-Item -ItemType Directory -Force -Path C:\Users\$env:USERNAME\.oci
```
Nomenclatura de claves: `[usuario]_GISS_priv.pem` / `[usuario]_GISS_pub.pem`

1. Consola OCI → **Mi perfil** → **Claves de API** → **Agregar clave de API**
2. Seleccionar **Generar par de claves**
3. Descargar la **clave privada** (`.pem`) y guardarla en:
   ```
   C:\Users\[usuario]\.oci\[usuario]_GISS_priv.pem
   ```
4. Descargar la **clave pública** (opcional, como respaldo)
5. Hacer clic en **Agregar** y copiar el **Fingerprint** que aparece en la confirmación
   - Formato: `xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx`
   - **El fingerprint no puede recuperarse después — guardarlo en ese momento**
6. Copiar todos los datos que aparecen en la consola de OCI en un notepad

### 12.3 Ejecutar oci setup config

Abrir **Windows PowerShell** (NO PowerShell 7.x):

**Verificar SIEMPRE que los permisos y el propietario de C:\Users\$env:USERNAME\.oci y sus archivos, sean solamente a nuestro usuario y sin herencias**
**La CLI de OCI no funcionará si la clave privada es accesible por otros usuarios en la máquina.**

1. Hcer clic derecho sobre la carpeta .oci completa (y liego cada uno de sus archivos internos) y selecciona Propiedades.
2. Ve a la pestaña Seguridad y haz clic en Opciones avanzadas.
3. Haz clic en Deshabilitar herencia y selecciona "Convertir los permisos heredados en permisos explícitos".
4. Elimina todos los usuarios y grupos excepto tu usuario actual y SYSTEM. Tu usuario debe tener de control total.
5. Asegúrate de que los grupos como "Usuarios" o "Todos" no tengan permisos. 
6. Volver a revisar luego de "oci setup config".

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
oci setup config
```

Respuestas al asistente:

| Pregunta del asistente | Valor a introducir |
|---|---|
| Location for config | Enter (acepta `C:\Users\[usuario]\.oci\config`) |
| User OCID | OCID obtenido en 12.1 |
| Tenancy OCID | OCID obtenido en 12.1 |
| Region | `eu-madrid-2` | (acá deben ver los números que indica la lsita de regiones e ingresar el de eu-madrid-2)
| Generate new API key pair? | `n` (ya se generó en la consola OCI) |
| Location of API Signing private key | `C:\Users\[usuario]\.oci\[usuario]_GISS_priv.pem` |
| Fingerprint | Fingerprint obtenido en 12.2 |

### 12.4 Verificar el fichero config generado

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
key_file=C:\Users\[usuario]\.oci\[usuario]_GISS_priv.pem
```

---

## 13. PASO 9 — Pruebas de conectividad OCI CLI

Ejecutar desde Windows PowerShell:

```powershell
oci --version
oci iam region list
oci iam availability-domain list --region eu-madrid-2
```

Los dos últimos comandos deben devolver respuesta JSON con datos.

> **Si alguno falla, NO continuar.** Revisar la sección 20.4 de troubleshooting antes de avanzar.

---

## 14. PASO 10 — Creación de oci-credentials.auto.tfvars.json

Generar el archivo dentro del repositorio ga_ioci_iac-oci, con un editor de texto (Notepad, VS Code) y completar con los mismos datos usados en `oci setup config`:

```
C:\gitlab\ga_ioci_iac-oci\oci-credentials.auto.tfvars.json
```

Estructura válida:
```json
{
  "fingerprint": "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx",
  "private_key_path": "C:/Users/[usuario]/.oci/[usuario]_GISS_priv.pem",
  "tenancy_ocid": "ocid1.tenancy.oc1...",
  "user_ocid": "ocid1.user.oc1...",
  "home_region": "eu-madrid-2",
  "region": "eu-madrid-2",
  "private_key_password": null
}
```

Notas:
- `private_key_path` usa barras `/` aunque sea Windows — se requiere ese formato
- `private_key_password` en `null` si la clave no tiene passphrase
- los valores deben ser idénticos a los usados en `oci setup config`
- **no commitear este archivo con credenciales reales al repositorio** (debe estar siempre en .gitignore)

---

## 15. PASO 11 — Validación del módulo orquestador

El archivo crítico es:
```
C:\gitlab\terraform-oci-modules-orchestrator\providers.tf
```

Debe contener al final exactamente:
```hcl
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}
```
 **no commitear este archivo al repositorio y en caso de refreacar el repositorio, volver a modificarlo**

Verificar desde PowerShell:
```powershell
Select-String -Path "C:\gitlab\terraform-oci-modules-orchestrator\providers.tf" -Pattern "oracle/oci"
```

Si la línea no aparece o el `source` es `hashicorp/oci`, corregir el archivo antes de continuar.

Sin esta declaración, Terraform resuelve el provider como `hashicorp/oci` y `terraform init` falla con `Provider type mismatch`. Esta incidencia ha sido detectada anteriormente — el repositorio principal puede ser idéntico entre entornos y aún así fallar si el orquestador local difiere.

---

## 16. PASO 12 — Configuración del mirror de Terraform

### 16.1 Verificar contenido de .terraformrc-local

El archivo `C:\gitlab\ga_ioci_iac-oci\.terraformrc-local` (incluido en el `.7z`) debe contener:

```hcl
provider_installation {
  filesystem_mirror {
    path    = "C:/gitlab/ga_ioci_iac-oci/.terraform_mirror"
    include = ["registry.terraform.io/hashicorp/*", "registry.terraform.io/oracle/oci"]
  }
  direct {
    exclude = ["registry.terraform.io/hashicorp/*", "registry.terraform.io/Oracle/oci"]
  }
}
```

Notas críticas:
- Usar `oracle/oci` en **minúsculas** — `Oracle/oci` no funciona
- Las rutas usan barras `/` aunque sea Windows

Verificar:
```powershell
Get-Content C:\gitlab\ga_ioci_iac-oci\.terraformrc-local
```

### 16.2 Establecer la variable TF_CLI_CONFIG_FILE

Para establecerla de forma permanente (persiste en futuras sesiones):

```powershell
[System.Environment]::SetEnvironmentVariable(
    "TF_CLI_CONFIG_FILE",
    "C:\gitlab\ga_ioci_iac-oci\.terraformrc-local",
    "User"
)
```

Para activarla también en la sesión actual sin necesidad de reabrir PowerShell:

```powershell
$env:TF_CLI_CONFIG_FILE="C:\gitlab\ga_ioci_iac-oci\.terraformrc-local"
```

Verificar valor persistido:
```powershell
[System.Environment]::GetEnvironmentVariable("TF_CLI_CONFIG_FILE", "User")
```

Verificar valor activo en la sesión:
```powershell
echo $env:TF_CLI_CONFIG_FILE
```

Ambos deben devolver: `C:\gitlab\ga_ioci_iac-oci\.terraformrc-local`

---






## 17. PASO 13 — terraform init

```powershell
cd C:\gitlab\ga_ioci_iac-oci
$env:TF_CLI_CONFIG_FILE="C:\gitlab\ga_ioci_iac-oci\.terraformrc-local"
terraform init -reconfigure
```

Si todo está correcto:
- Se inicializa el backend
- Se resuelven los módulos (referencia relativa `../terraform-oci-modules-orchestrator`)
- Se instalan los providers desde el mirror local sin salida a Internet
- Se genera o valida `.terraform.lock.hcl`

Validaciones post-init:
```powershell
terraform fmt -check
terraform validate
```

---

## 18. PASO 14 — terraform plan y apply

### 18.1 Despliegue sin OCI Network Firewall

```powershell
terraform plan -var-file .\oci-credentials.auto.tfvars.json `
               -var-file .\giss_governance__v3.3.json `
               -var-file .\giss_iam_v3.4.json `
               -var-file .\giss_network_hub_b_empty_v3.3.json

terraform apply -var-file .\oci-credentials.auto.tfvars.json `
                -var-file .\giss_governance__v3.3.json `
                -var-file .\giss_iam_v3.4.json `
                -var-file .\giss_network_hub_b_empty_v3.3.json
```

### 18.2 Despliegue con OCI Network Firewall

```powershell
terraform plan -var-file .\oci-credentials.auto.tfvars.json `
               -var-file .\giss_governance__v3.3.json `
               -var-file .\giss_iam_v3.4.json `
               -var-file .\giss_network_hub_b_firewall_v3.3.json

terraform apply -var-file .\oci-credentials.auto.tfvars.json `
                -var-file .\giss_governance__v3.3.json `
                -var-file .\giss_iam_v3.4.json `
                -var-file .\giss_network_hub_b_firewall_v3.3.json
```

### 18.3 Destrucción del entorno

Sin firewall:
```powershell
terraform destroy -var-file .\oci-credentials.auto.tfvars.json `
                  -var-file .\giss_governance__v3.3.json `
                  -var-file .\giss_iam_v3.4.json `
                  -var-file .\giss_network_hub_b_empty_v3.3.json
```

Con OCI NFW:
```powershell
terraform destroy -var-file .\oci-credentials.auto.tfvars.json `
                  -var-file .\giss_governance__v3.3.json `
                  -var-file .\giss_iam_v3.4.json `
                  -var-file .\giss_network_hub_b_firewall_v3.3.json
```

---

## 19. Flujo operativo de sesión

Al inicio de cada sesión de trabajo, ejecutar siempre este bloque de verificación antes de cualquier operación Terraform:

```powershell
cd C:\gitlab\ga_ioci_iac-oci
$env:TF_CLI_CONFIG_FILE="C:\gitlab\ga_ioci_iac-oci\.terraformrc-local"

# Verificar versiones
terraform version
oci --version

# Verificar conectividad OCI
oci iam region list
oci iam availability-domain list --region eu-madrid-2

# Verificar variable mirror activa
echo $env:TF_CLI_CONFIG_FILE

# Inicializar y validar
terraform init -reconfigure
terraform fmt -check
terraform validate
```

Todos los comandos deben responder correctamente antes de ejecutar `plan` o `apply`.

---

## 20. Troubleshooting

### 20.1 Error: Provider type mismatch

**Síntoma:** `terraform init` falla con referencias cruzadas entre `hashicorp/oci` y `oracle/oci`.

**Causa:** `providers.tf` del módulo orquestador no declara explícitamente `oracle/oci`.

**Solución:** verificar y corregir `C:\gitlab\terraform-oci-modules-orchestrator\providers.tf` con el bloque indicado en el paso 15. Volver a ejecutar `terraform init -reconfigure`.

### 20.2 Terraform no usa el mirror

**Síntoma:** `terraform init` intenta descargar providers desde Internet o falla con error de red.

**Verificación:**
```powershell
echo $env:TF_CLI_CONFIG_FILE
```
Debe mostrar `C:\gitlab\ga_ioci_iac-oci\.terraformrc-local`. Si está vacío:
```powershell
$env:TF_CLI_CONFIG_FILE="C:\gitlab\ga_ioci_iac-oci\.terraformrc-local"
```

Verificar también que `.terraformrc-local` usa `oracle/oci` en minúsculas y rutas con `/`.

### 20.3 OCI CLI instalado pero no responde

**Causa:** PATH no actualizado en la sesión actual.

**Solución:** cerrar y reabrir Windows PowerShell. Si persiste:
```powershell
[System.Environment]::GetEnvironmentVariable("PATH", "User")
```
Verificar que la ruta de instalación de OCI CLI está presente.

### 20.4 OCI CLI responde pero las consultas IAM fallan

Verificar en orden:
- `tenancy_ocid` en `oci-credentials.auto.tfvars.json`
- `user_ocid` en `oci-credentials.auto.tfvars.json`
- `fingerprint` — debe coincidir exactamente con la API key registrada en OCI
- Ruta del fichero `.pem` y que existe con permisos de lectura
- Región configurada en `oci setup config` (debe ser `eu-madrid-2`)
- Coherencia entre `oci setup config` y `oci-credentials.auto.tfvars.json`

### 20.5 Error al extraer el .7z

- Verificar integridad del archivo (comparar hash SHA256 con el proporcionado por el equipo)
- Verificar espacio suficiente en `C:\` (el mirror puede ocupar varios GB)
- Verificar que el destino de extracción es `C:\gitlab\ga_ioci_iac-oci\` — no `C:\gitlab\`

### 20.6 Restricción de PowerShell / error de permisos .oci

No usar PowerShell 7.x con OCI CLI. Usar siempre Windows PowerShell 5.x:
```powershell
$PSVersionTable.PSVersion
```
El `Major` debe ser `5`.

Para errores de permisos del directorio `.oci`, verificar:
```powershell
echo $env:OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING
```
Debe devolver `True`. Si no:
```powershell
$env:OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING="True"
```



---

## 21. Buenas prácticas

- Completar el PASO 1 íntegramente antes de ejecutar cualquier script
- Usar siempre `C:\gitlab\ga_ioci_iac-oci` como directorio de trabajo
- Establecer `TF_CLI_CONFIG_FILE` al inicio de cada sesión de PowerShell
- No borrar `.terraform.lock.hcl` salvo cambio aprobado de versión de provider
- No modificar `terraform-oci-modules-orchestrator\providers.tf` sin coordinar con el equipo
- Mantener `oci setup config` y `oci-credentials.auto.tfvars.json` siempre alineados
- No commitear credenciales ni el fichero `.pem` al repositorio
- Ante cualquier error inesperado, revisar el mirror antes de escalar al equipo de red
- Fijar Terraform en `v1.14.7` — no actualizar sin validación previa en entorno de pruebas
- Hacer siempre `terraform plan` antes de `terraform apply` y revisar el output completo
- No asumir que dos entornos son iguales solo porque el root del repositorio coincide

---

## 22. Versiones validadas

| Componente | Versión validada |
|---|---|
| Terraform | v1.14.7 windows_amd64 |
| OCI CLI | 3.76.0 |
| Provider oracle/oci | >= 5.0.0 |
| Windows PowerShell | 5.x (no usar 7.x) |
| Sistema operativo | Windows Server 2019 / Windows 10-11 |

---