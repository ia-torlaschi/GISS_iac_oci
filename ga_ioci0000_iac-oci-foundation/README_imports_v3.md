# OCI Landing Zone GISS — Importación declarativa, separación de states y wrappers portables

## Alcance

Este documento describe el procedimiento reproducible utilizado para separar el despliegue monolítico de OCI Landing Zone GISS en repositorios independientes, ampliado con el nuevo patrón de **wrappers PowerShell portables colocados dentro de `dependencies/`** que sustituye al snippet inline usado en v2.

Stacks cubiertos en esta versión:

- `ga_ioci0000_iac-oci-foundation`
- `ga_ioci0010_iac-oci-identity`
- `ga_ioci0020_iac-oci-network`

Stacks pendientes de migrar al mismo patrón (estructura ya preparada en `dependencies/`):

- `ga_ioci0030_iac-oci-security-svc`
- `ga_ioci0040_iac-oci-exa-infra`
- `ga_ioci0041_iac-oci-exa-database`
- `ga_ioci0050_iac-oci-obs-logs`
- `ga_ioci0060_iac-oci-obs-monitor`
- `ga_ioci0070_iac-oci-storage`

El objetivo sigue siendo **armar los states Terraform de cada repositorio mediante imports declarativos**, sin recrear, modificar ni destruir infraestructura ya existente en OCI.

La regla de seguridad aplicada durante todo el proceso es:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

Si un plan muestra `add`, `change` o `destroy`, no se debe aplicar hasta auditar la causa.

---

## Cambios respecto a v2

```text
[+] Wrapper PowerShell portable por stack en dependencies/<stack>_dependencies.ps1
    - usa $PSScriptRoot, valida existencia de inputs, acepta -DepPath / -OutFile
    - sustituye al snippet inline duplicado de v2 (secciones 1.12, 2.3 y 7)
[+] Identity exporta identity_domains_output.json y genera identity_dependencies.auto.tfvars.json
[+] Network  exporta network_output.json        y genera network_dependencies.auto.tfvars.json
[+] Regla simetrica explicita del wrapper: el JSON generado preserva la clave
    interna del *_output.json bajo el envoltorio *_dependency
[+] KB ampliado con casos de wrapper / variables faltantes downstream
[~] Estructuras de repositorio actualizadas para incluir los .ps1
[~] Checklist actualizado con paso "ejecutar wrapper PS"
```

---

## Contexto técnico

La Landing Zone ya existía y había sido validada previamente con el Terraform monolítico v3.6, obteniendo plan sin cambios. Por tanto, la separación en repositorios no se trató como un nuevo despliegue, sino como una **migración controlada del ownership del state**.

Se sustituyó el uso de `terraform import` imperativo recurso a recurso por **bloques declarativos `import {}`**, porque el OCI Landing Zones Orchestrator evalúa módulos completos y puede fallar cuando el state queda parcialmente importado durante una operación secuencial.

El modelo final usa además la funcionalidad oficial de **External Dependencies** del orquestador:

```text
https://github.com/oci-landing-zones/terraform-oci-modules-orchestrator#external-dependencies
```

Cada stack genera, mediante `output_path` y `local_file`, ficheros `<recurso>_output.json` en su carpeta `dependencies/`. Los stacks dependientes los consumen transformados a variables Terraform mediante wrappers `*.auto.tfvars.json`.

---

## Convenciones usadas

### Variables y placeholders

Sustituir los siguientes valores por los reales del entorno:

```text
[TENANCY_OCID]
[OCI_PROFILE]
[REGION]
```

En el caso probado:

```text
[OCI_PROFILE] = DEFAULT
```

### Herramientas usadas

Versiones observadas durante la ejecución:

```text
Terraform: 1.15.x
OCI CLI:   3.81.x
PowerShell: 7.6.x
```

### Versionado del generador de imports

```text
Foundation → Generate-OrchestratorImportBlocks-v3.0.ps1
Identity   → Generate-OrchestratorImportBlocks-v3.1.ps1
Network    → Generate-OrchestratorImportBlocks-v3.2.7.ps1
```

Notas:

- Cada versión es la validada para su stack. No sustituir versiones anteriores ya consolidadas en otros repositorios.
- La versión `v3.2.7` incorpora soporte completo para recursos de networking OCI (`oci_core_*`, `oci_core_drg_*`) y los parámetros `-NoPrecheck` y `-SkipMissing`.
- Las versiones menores intermedias (`v3.2.x`) reflejan iteraciones de corrección durante la POC de Network; solo `v3.2.7` se considera estable.

### Ubicación base esperada

```text
C:\gitlab
├─ terraform-oci-modules-orchestrator
├─ ga_ioci0000_iac-oci-foundation
├─ ga_ioci0010_iac-oci-identity
├─ ga_ioci0020_iac-oci-network
...
```

### Regla simétrica del wrapper

Todos los wrappers `<stack>_dependencies.ps1` aplican la misma transformación:

```text
Input  : dependencies/<recurso>_output.json   con forma { "<key>": { ... } }
Output : dependencies/<stack>_dependencies.auto.tfvars.json
         con forma { "<recurso>_dependency": { "<key>": { ... } } }
```

Concretamente:

```text
compartments_output.json   { "compartments":     {...} }  →  compartments_dependency.compartments
tags_output.json           { "tags":             {...} }  →  tags_dependency.tags
identity_domains_output.json { "identity_domains":{...} } →  identity_domains_dependency.identity_domains
network_output.json        { "network_resources":{...} }  →  network_dependency.network_resources
```

El wrapper **no aplana** el contenido del output: preserva la clave interna tal cual la emite el orquestador. Esta regla es la que define el patrón de acceso desde HCL downstream.

---

# 1. Stack Foundation

## 1.1. Objetivo del stack

El repositorio `ga_ioci0000_iac-oci-foundation` gestiona la base de la Landing Zone:

```text
Tag namespaces
Tag keys
Compartments
```

En la POC se importaron:

```text
3 tag namespaces
16 tag keys
20 compartments
Total: 39 recursos
```

---

## 1.2. Estructura recomendada del repositorio Foundation

```text
ga_ioci0000_iac-oci-foundation/
├─ dependencies/
│  ├─ compartments_output.json                      ← output del orquestador
│  ├─ tags_output.json                              ← output del orquestador
│  ├─ foundation_dependencies.ps1                   ← wrapper portable (v3)
│  └─ foundation_dependencies.auto.tfvars.json      ← generado por el wrapper
│
├─ .terraform/
├─ .terraform.lock.hcl
├─ Generate-OrchestratorImportBlocks-v3.0.ps1
├─ giss_foundation_v3.6.json
├─ foundation_imports.auto.tf
├─ foundation-import.tfplan
├─ main.tf
├─ providers.tf
├─ variables.tf
├─ versions.tf
├─ terraform.tfstate
├─ terraform.tfstate.backup
└─ oci-credentials.auto.tfvars.json
```

Notas:

- `oci-credentials.auto.tfvars.json` no debe copiarse dentro de `dependencies`.
- `dependencies/` contiene solo outputs, el wrapper PS y el `.auto.tfvars.json` consumido por otros stacks.
- Los ficheros `*.tfplan`, `*_imports.auto.tf` y logs son artefactos operativos; en producción deben gestionarse según la política de cada equipo.

---

## 1.3. Validaciones previas

Entrar al repo:

```powershell
cd C:\gitlab\ga_ioci0000_iac-oci-foundation
```

Inicializar Terraform:

```powershell
terraform init
```

Verificar que existe `.terraform`:

```powershell
Test-Path .\.terraform
```

Resultado esperado:

```text
True
```

Validar acceso OCI con el profile configurado:

```powershell
oci iam tenancy get `
  --tenancy-id "[TENANCY_OCID]" `
  --profile "DEFAULT"
```

---

## 1.4. Cambios aplicados al JSON de Foundation

### 1.4.1. Proteger compartments contra eliminación

En `giss_foundation_v3.6.json`, se detectó que existía:

```json
"compartments_configuration": {
  "enable_delete": "true"
}
```

Ese valor provocaba drift durante el import:

```text
Plan: 39 to import, 0 to add, 20 to change, 0 to destroy
```

Los 20 cambios correspondían a:

```hcl
enable_delete = true
```

Para evitar que Terraform pueda intentar borrar compartments ante un `destroy` o una eliminación accidental en código, se cambió a:

```json
"compartments_configuration": {
  "enable_delete": "false"
}
```

Resultado esperado después del cambio:

```text
Plan: 39 to import, 0 to add, 0 to change, 0 to destroy
```

### 1.4.2. Generación de outputs del orquestador

Para que Foundation pueda generar los ficheros de dependencias externas, se añadió `output_path`.

Recomendado:

```json
"output_path": "./dependencies"
```

Ejemplo de estructura:

```json
{
  "_meta": { "...": "..." },
  "output_path": "./dependencies",
  "tags_configuration": { "...": "..." },
  "compartments_configuration": {
    "enable_delete": "false",
    "...": "..."
  }
}
```

Esto permite que el orquestador genere directamente:

```text
dependencies/compartments_output.json
dependencies/tags_output.json
```

Si inicialmente se usó `"output_path": "."`, los ficheros se generan en la raíz del repo y pueden moverse manualmente a `dependencies/`.

---

## 1.5. Limpieza de artefactos temporales antes de regenerar plan

```powershell
Remove-Item .\foundation_imports.auto.tf -ErrorAction SilentlyContinue
Remove-Item .\foundation-import.tfplan   -ErrorAction SilentlyContinue
```

---

## 1.6. Generar import blocks declarativos para Foundation

```powershell
.\Generate-OrchestratorImportBlocks-v3.0.ps1 `
  -ConfigPath ".\giss_foundation_v3.6.json" `
  -TenancyOcid "[TENANCY_OCID]" `
  -Profile "DEFAULT" `
  -VarFiles @(
    ".\oci-credentials.auto.tfvars.json",
    ".\giss_foundation_v3.6.json"
  ) `
  -StackType "foundation" `
  -Mode "Plan"
```

El script debe generar:

```text
foundation_imports.auto.tf
foundation-import.tfplan
```

---

## 1.7. Validar el plan de import de Foundation

Resultado esperado:

```text
Plan: 39 to import, 0 to add, 0 to change, 0 to destroy.
```

Durante la POC apareció inicialmente:

```text
Plan: 39 to import, 0 to add, 20 to change, 0 to destroy.
```

Causa: `enable_delete = "true"`. Corregido en 1.4.1.

---

## 1.8. Aplicar el plan de import de Foundation

```powershell
terraform apply ".\foundation-import.tfplan"
```

Resultado esperado:

```text
Apply complete! Resources: 39 imported, 0 added, 0 changed, 0 destroyed.
```

Este `apply` no crea infraestructura. Solo materializa la asociación entre direcciones Terraform y recursos OCI existentes.

---

## 1.9. Validar el state de Foundation

```powershell
terraform state list
```

Recursos esperados:

```text
module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag_namespace.these["TAGNS-LZ-ROLE-KEY"]
module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-LZ-ROLE-KEY"]
module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.these["CMP-LANDINGZONE-KEY"]
module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_2["CMP-LZ-NETWORK-KEY"]
```

---

## 1.10. Validar que Foundation no tiene drift

```powershell
terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_foundation_v3.6.json"
```

Resultado esperado:

```text
No changes. Your infrastructure matches the configuration.
```

---

## 1.11. Generar outputs de Foundation

Con `"output_path": "./dependencies"` en el JSON, ejecutar:

```powershell
terraform apply `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_foundation_v3.6.json"
```

Plan esperado:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Recursos locales esperados:

```text
module.oci_lz_orchestrator.local_file.compartments_output[0]
module.oci_lz_orchestrator.local_file.tags_output[0]
```

No modifica OCI. Después del apply deben existir:

```text
dependencies/compartments_output.json
dependencies/tags_output.json
```

---

## 1.12. Generar wrapper Terraform para dependencias Foundation (v3)

**Cambio respecto a v2**: el snippet inline ha sido empaquetado como script portable colocado en `dependencies/foundation_dependencies.ps1`. Usa `$PSScriptRoot` y resuelve las rutas relativas al propio script, por lo que es ejecutable desde cualquier CWD.

Ejecutar:

```powershell
.\dependencies\foundation_dependencies.ps1
```

o invocando el script directamente:

```powershell
& "C:\gitlab\ga_ioci0000_iac-oci-foundation\dependencies\foundation_dependencies.ps1"
```

Parámetros opcionales:

```powershell
-DepPath  <ruta-alternativa-a-dependencies>
-OutFile  <nombre-alternativo-del-tfvars>
```

Salida esperada:

```text
Generado: <ruta>\dependencies\foundation_dependencies.auto.tfvars.json
```

Estructura generada (regla simétrica):

```json
{
  "compartments_dependency": {
    "compartments": {
      "CMP-LANDINGZONE-KEY": { "id": "ocid1.compartment..." }
    }
  },
  "tags_dependency": {
    "tags": {
      "TAG-GOV-NAME-KEY": { "id": "ocid1.tagdefinition..." }
    }
  }
}
```

Acceso esperado en HCL downstream:

```hcl
var.compartments_dependency.compartments["CMP-LANDINGZONE-KEY"].id
var.tags_dependency.tags["TAG-GOV-NAME-KEY"].id
```

---

## 1.13. Archivos Foundation que se copian a otros repositorios

Para los repositorios dependientes se deben copiar:

```text
dependencies/foundation_dependencies.auto.tfvars.json   ← variable consumida por los stacks downstream
```

Opcionalmente, si se quiere regenerar el wrapper desde el repo consumidor:

```text
dependencies/compartments_output.json
dependencies/tags_output.json
dependencies/foundation_dependencies.ps1
```

Estos son los únicos ficheros Foundation que casi todos los stacks necesitarán.

No copiar:

```text
oci-credentials.auto.tfvars.json
terraform.tfstate
terraform.tfstate.backup
*.tfplan
```

---

# 2. Stack Identity

## 2.1. Objetivo del stack

El repositorio `ga_ioci0010_iac-oci-identity` gestiona:

```text
Identity Domain
Identity Domain Groups
IAM Policies
```

En la POC se importaron:

```text
1 identity domain
8 identity domain groups
18 IAM policies
Total: 27 recursos
```

---

## 2.2. Estructura recomendada del repositorio Identity

```text
ga_ioci0010_iac-oci-identity/
├─ dependencies/
│  ├─ foundation_dependencies.auto.tfvars.json     ← desde Foundation
│  ├─ identity_domains_output.json                 ← output del orquestador (v3)
│  ├─ identity_dependencies.ps1                    ← wrapper portable (v3)
│  └─ identity_dependencies.auto.tfvars.json       ← generado por el wrapper (v3)
│
├─ .terraform/
├─ .terraform.lock.hcl
├─ Generate-OrchestratorImportBlocks-v3.1.ps1
├─ giss_identity_v3.6.json
├─ identity_imports.auto.tf
├─ identity-import.tfplan
├─ main.tf
├─ providers.tf
├─ variables.tf
├─ versions.tf
├─ terraform.tfstate
├─ terraform.tfstate.backup
└─ oci-credentials.auto.tfvars.json
```

---

## 2.3. Preparar dependencias Foundation en Identity

Desde Foundation copiar al repo Identity:

```text
foundation_dependencies.auto.tfvars.json
```

Ubicación recomendada:

```text
ga_ioci0010_iac-oci-identity/dependencies/
```

Si se prefiere regenerar el wrapper de Foundation desde Identity, copiar también `compartments_output.json`, `tags_output.json` y `foundation_dependencies.ps1`, y ejecutarlo:

```powershell
.\dependencies\foundation_dependencies.ps1
```

---

## 2.4. `output_path` en Identity (v3)

A diferencia de v2, en v3 Identity **sí** activa `output_path` porque exporta `identity_domains` para que otros stacks lo consuman.

En `giss_identity_v3.6.json`:

```json
"output_path": "./dependencies"
```

Esto permite que el orquestador, tras el apply, genere:

```text
dependencies/identity_domains_output.json
```

Si la Landing Zone no necesita exponer identity domains a otros stacks, `output_path` puede dejarse desactivado y omitir secciones 2.13–2.15.

---

## 2.5. Validaciones previas de Identity

```powershell
cd C:\gitlab\ga_ioci0010_iac-oci-identity

terraform init

Test-Path .\.terraform
```

Validar que Terraform carga correctamente las dependencies:

```powershell
terraform console `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_identity_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json"
```

Dentro de la consola:

```hcl
var.compartments_dependency.compartments["CMP-LANDINGZONE-KEY"].id
```

Resultado esperado:

```text
"ocid1.compartment..."
```

Salir:

```hcl
exit
```

---

## 2.6. Correcciones aplicadas al script para Identity

Durante la POC se detectaron dos problemas de parsing en PowerShell con propiedades de OCI CLI.

### 2.6.1. Corrección en Identity Domains

OCI CLI devuelve algunas propiedades con guiones (`display-name`, `lifecycle-state`) y no siempre en camelCase. La función `Get-IdentityDomainByDisplayName` debe usar acceso seguro:

```powershell
$match = $items | Where-Object {
  $dn = $_.'display-name'
  if ($null -eq $dn -and $_.PSObject.Properties.Name -contains 'displayName') { $dn = $_.displayName }
  $ls = $_.'lifecycle-state'
  ($dn -ieq $DisplayName) -and ($ls -ne "DELETED")
} | Select-Object -First 1
```

### 2.6.2. Corrección en Identity Domain Groups

La función `Get-IdentityDomainGroupId` debe usar acceso seguro:

```powershell
$match = $items | Where-Object {
  $dn = $null
  if ($_.PSObject.Properties.Name -contains 'displayName')    { $dn = $_.displayName }
  elseif ($_.PSObject.Properties.Name -contains 'display_name') { $dn = $_.display_name }
  elseif ($_.PSObject.Properties.Name -contains 'display-name') { $dn = $_.'display-name' }

  $deleteInProgress = $false
  if ($_.PSObject.Properties.Name -contains 'deleteInProgress')   { $deleteInProgress = $_.deleteInProgress }
  elseif ($_.PSObject.Properties.Name -contains 'delete-in-progress') { $deleteInProgress = $_.'delete-in-progress' }

  ($dn -ieq $DisplayName) -and ($deleteInProgress -ne $true)
} | Select-Object -First 1
```

---

## 2.7. Por qué se usa `-NoPrecheck` en Identity

El precheck original ejecuta:

```powershell
terraform plan -refresh=false -input=false -lock=false -detailed-exitcode
```

En Identity ese precheck puede fallar antes del import con:

```text
var.compartments_dependency is empty map of object
```

El plan real sí funciona cuando recibe el wrapper correcto. Por tanto, para Identity se ejecuta el script con `-NoPrecheck`.

El criterio seguro sigue siendo el plan real guardado:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

---

## 2.8. Limpiar artefactos temporales antes del import de Identity

```powershell
Remove-Item .\identity_imports.auto.tf -ErrorAction SilentlyContinue
Remove-Item .\identity-import.tfplan   -ErrorAction SilentlyContinue
```

---

## 2.9. Generar import blocks declarativos para Identity

```powershell
.\Generate-OrchestratorImportBlocks-v3.1.ps1 `
  -ConfigPath ".\giss_identity_v3.6.json" `
  -TenancyOcid "[TENANCY_OCID]" `
  -Profile "DEFAULT" `
  -VarFiles @(
    ".\oci-credentials.auto.tfvars.json",
    ".\giss_identity_v3.6.json",
    ".\dependencies\foundation_dependencies.auto.tfvars.json"
  ) `
  -DependencyFiles @(
    ".\dependencies\compartments_output.json",
    ".\dependencies\tags_output.json"
  ) `
  -StackType "identity" `
  -Mode "Plan" `
  -NoPrecheck
```

Genera:

```text
identity_imports.auto.tf
identity-import.tfplan
```

---

## 2.10. Validar plan de import de Identity

Resultado esperado:

```text
Plan: 27 to import, 0 to add, 0 to change, 0 to destroy.
```

Casuística observada durante la POC:

- **Caso 1** — dependencies no existentes → copiar desde Foundation a `dependencies/`.
- **Caso 2** — wrapper incorrecto (`var.compartments_dependency is empty map of object`) → regenerar con `foundation_dependencies.ps1`.
- **Caso 3** — parser `displayName` inexistente → aplicar correcciones de 2.6.

---

## 2.11. Aplicar el plan de import de Identity

```powershell
terraform apply ".\identity-import.tfplan"
```

Resultado esperado:

```text
Apply complete! Resources: 27 imported, 0 added, 0 changed, 0 destroyed.
```

---

## 2.12. Validar que Identity no tiene drift

```powershell
terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_identity_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json"
```

Resultado esperado:

```text
No changes. Your infrastructure matches the configuration.
```

con un warning upstream relacionado con `ETag` (ver 2.14).

---

## 2.13. Generación de outputs de Identity (v3)

Tras el import, ejecutar un apply normal para materializar los outputs declarados por `output_path`:

```powershell
terraform apply `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_identity_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json"
```

Plan esperado para esta operación:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Recurso esperado:

```text
module.oci_lz_orchestrator.local_file.identity_domains_output[0]
```

Después del apply debe existir:

```text
dependencies/identity_domains_output.json
```

Forma esperada:

```json
{
  "identity_domains": {
    "COMMON-DOMAIN": { "id": "ocid1.domain..." }
  }
}
```

---

## 2.14. Generar wrapper Terraform para dependencias Identity (v3)

Ejecutar el wrapper portable:

```powershell
.\dependencies\identity_dependencies.ps1
```

Genera `dependencies/identity_dependencies.auto.tfvars.json` con estructura:

```json
{
  "identity_domains_dependency": {
    "identity_domains": {
      "COMMON-DOMAIN": { "id": "ocid1.domain..." }
    }
  }
}
```

Acceso esperado en HCL downstream:

```hcl
var.identity_domains_dependency.identity_domains["COMMON-DOMAIN"].id
```

Notas:

- La variable `identity_domains_dependency` aún no está declarada en los `variables.tf` de los stacks downstream (0030–0070). Cuando un stack la consuma deberá añadirse:

  ```hcl
  variable "identity_domains_dependency" {
    type    = any
    default = null
  }
  ```

- Y propagarla al módulo orquestador en `main.tf`:

  ```hcl
  identity_domains_dependency = var.identity_domains_dependency
  ```

---

## 2.15. Warning conocido de `ETag`

Puede aparecer:

```text
Warning: Deprecated value used

The deprecation originates from:
module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["..."].ETag

Deprecated resource attribute "ETag" used.
```

Causa: el submódulo upstream de policies exporta el recurso completo, lo que arrastra atributos deprecated del provider OCI como `ETag`.

```text
No genera drift.
No modifica infraestructura.
No afecta imports.
No afecta state.
```

No se recomienda modificar `.terraform/modules/...` porque se regenera con `terraform init` y rompe reproducibilidad.

---

# 3. Stack Network

## 3.1. Objetivo del stack

El repositorio `ga_ioci0020_iac-oci-network` gestiona:

```text
VCNs, Subnets, Route Tables, Route Table Attachments,
Security Lists, NSGs, NSG Rules,
Service Gateways, NAT Gateways,
DRGs, DRG Attachments, DRG Route Tables, DRG Route Distributions, DRG Route Rules
```

Resultado final validado:

```text
56 recursos importados
0 cambios reales en OCI
0 drift final
```

---

## 3.2. Estructura recomendada del repositorio Network

```text
ga_ioci0020_iac-oci-network/
├─ dependencies/
│  ├─ foundation_dependencies.auto.tfvars.json     ← desde Foundation
│  ├─ identity_dependencies.auto.tfvars.json       ← desde Identity (si aplica)
│  ├─ network_output.json                          ← output del orquestador
│  ├─ network_dependencies.ps1                     ← wrapper portable (v3)
│  └─ network_dependencies.auto.tfvars.json        ← generado por el wrapper (v3)
│
├─ migration/
│  ├─ Generate-OrchestratorImportBlocks-v3.2.7.ps1
│  ├─ network-discovery.tfplan
│  ├─ network-discovery.json
│  ├─ network_imports.auto.tf
│  ├─ network-import.tfplan
│  └─ logs...
│
├─ .terraform/
├─ .terraform.lock.hcl
├─ giss_network_base_v3.6.json
├─ giss_network_nfw_addon_v3.6.json
├─ main.tf
├─ providers.tf
├─ variables.tf
├─ versions.tf
├─ terraform.tfstate
└─ oci-credentials.auto.tfvars.json
```

---

## 3.3. Dependencias requeridas

El stack Network consume outputs del stack Foundation (y, opcionalmente, Identity).

Copiar desde Foundation:

```text
foundation_dependencies.auto.tfvars.json
```

Copiar desde Identity (si se usa):

```text
identity_dependencies.auto.tfvars.json
```

Validar:

```powershell
dir .\dependencies
```

---

## 3.4. Generar discovery plan

```powershell
cd C:\gitlab\ga_ioci0020_iac-oci-network

terraform init

terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_network_base_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json" `
  -out ".\migration\network-discovery.tfplan"
```

Resultado esperado inicial:

```text
Plan: 58 to add, 0 to change, 0 to destroy
```

Esto **NO** debe aplicarse. Solo se usa para generar el tfplan de discovery.

---

## 3.5. Generar JSON del discovery plan

```powershell
terraform show -json .\migration\network-discovery.tfplan |
  Out-File .\migration\network-discovery.json -Encoding utf8

Test-Path .\migration\network-discovery.json
```

---

## 3.6. Generar import blocks declarativos

```powershell
.\migration\Generate-OrchestratorImportBlocks-v3.2.7.ps1 `
  -ConfigPath ".\giss_network_base_v3.6.json" `
  -DiscoveryPlanJson ".\migration\network-discovery.json" `
  -TenancyOcid "[TENANCY_OCID]" `
  -Profile "DEFAULT" `
  -VarFiles @(
    ".\oci-credentials.auto.tfvars.json",
    ".\giss_network_base_v3.6.json",
    ".\dependencies\foundation_dependencies.auto.tfvars.json"
  ) `
  -DependencyFiles @(
    ".\dependencies\compartments_output.json",
    ".\dependencies\tags_output.json"
  ) `
  -StackType "network" `
  -Mode "Plan" `
  -NoPrecheck `
  -SkipMissing
```

Genera:

```text
network_imports.auto.tf
network-import.tfplan
```

---

## 3.7. Recursos soportados por el import generator (v3.2.7)

```text
oci_core_vcn
oci_core_subnet
oci_core_route_table
oci_core_route_table_attachment
oci_core_security_list
oci_core_default_security_list
oci_core_network_security_group
oci_core_network_security_group_security_rule
oci_core_nat_gateway
oci_core_service_gateway
oci_core_drg
oci_core_drg_attachment
oci_core_drg_route_distribution
oci_core_drg_route_table
oci_core_drg_route_table_route_rule
```

Además contempla estructuras futuras del overlay OCI Network Firewall (NFW), aunque no estén desplegadas.

---

## 3.8. Problemas encontrados y correcciones aplicadas

### 3.8.1. Route Table Attachments

OCI provider requiere import IDs con formato:

```text
[subnet_ocid]/[route_table_ocid]
```

### 3.8.2. Default Security Lists

No descubribles por display_name; se resuelven vía:

```text
VCN -> default-security-list-id
```

usando `oci network vcn get --output json`.

### 3.8.3. DRG Attachments

La resolución correcta se hizo mediante `display-name` y no por VCN únicamente.

### 3.8.4. DRG Route Rules

OCI no expone OCIDs individuales para route rules. Terraform utiliza import IDs compuestos:

```text
[drg_route_table_ocid]/[route_rule_id]
```

---

## 3.9. Resultado final del import

```text
Apply complete! Resources: 56 imported, 2 added, 0 changed, 0 destroyed.
```

Los 2 recursos añadidos:

```text
module.oci_lz_orchestrator.local_file.network_output[0]
module.oci_lz_orchestrator.module.oci_lz_network[0].time_sleep.wait_for_dns_resolver
```

No modifican OCI.

---

## 3.10. Validación final sin drift

```powershell
terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_network_base_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json"
```

Resultado esperado:

```text
No changes. Your infrastructure matches the configuration.
```

---

## 3.11. Generación de outputs del stack Network

El stack genera:

```text
dependencies/network_output.json
```

Forma esperada (clave interna `network_resources` que el wrapper preserva):

```json
{
  "network_resources": {
    "vcns":                    { "VCN-...":     { "id": "..." } },
    "subnets":                 { "SN-...":      { "id": "..." } },
    "network_security_groups": { "NSG-...":     { "id": "..." } },
    "drg_attachments":         { "DRGATT-...":  { "id": "..." } },
    "drg_route_tables":        { "DRGRT-...":   { "id": "..." } },
    "dynamic_routing_gateways":{ "DRG-...":     { "id": "..." } }
  }
}
```

---

## 3.12. Generar wrapper Terraform para dependencias Network (v3)

Ejecutar el wrapper portable:

```powershell
.\dependencies\network_dependencies.ps1
```

Genera `dependencies/network_dependencies.auto.tfvars.json` con estructura:

```json
{
  "network_dependency": {
    "network_resources": {
      "vcns":                    { "VCN-VLL-LZ-HUB-KEY": { "id": "..." } },
      "subnets":                 { "SN-VLL-LZ-HUB-DNS":  { "id": "..." } },
      "network_security_groups": { "NSG-...":            { "id": "..." } },
      "drg_attachments":         { "DRGATT-...":         { "id": "..." } },
      "drg_route_tables":        { "DRGRT-...":          { "id": "..." } },
      "dynamic_routing_gateways":{ "DRG-...":            { "id": "..." } }
    }
  }
}
```

Acceso esperado en HCL downstream:

```hcl
var.network_dependency.network_resources.vcns["VCN-VLL-LZ-HUB-KEY"].id
var.network_dependency.network_resources.subnets["SN-VLL-LZ-HUB-DNS"].id
```

La variable `network_dependency` ya está declarada en los `variables.tf` de todos los stacks downstream y propagada al módulo orquestador (`main.tf`, línea 48).

---

## 3.13. Overlay OCI Network Firewall (NFW)

`giss_network_nfw_addon_v3.6.json` **NO** forma parte del despliegue activo.

```text
REFERENCE_ONLY_NOT_DEPLOYED
```

Razón: optimización de costes. Se conserva como referencia arquitectónica, baseline de reactivación y validación de diseño Hub-and-Spoke. Actualmente NO debe incluirse en `terraform plan`, `terraform apply` ni pipelines CI/CD.

---

## 3.14. Warnings conocidos

```text
Deprecated resource attribute "route_rules[...].cidr_block" used.
```

Origen: módulo upstream `terraform-oci-modules-networking`. Sin drift, sin modificación de OCI, sin afectación a imports. No modificar `.terraform/modules`; esperar corrección oficial upstream.

---

## 3.15. Checklist operativo final — Network

```text
[ ] terraform init ejecutado
[ ] network-discovery.tfplan generado
[ ] network-discovery.json generado
[ ] imports declarativos generados
[ ] DRG attachments correctamente resueltos
[ ] default security lists importadas
[ ] route_table_attachment IDs corregidos
[ ] DRG route rules importadas
[ ] terraform apply ejecutado
[ ] terraform plan final = No changes
[ ] network_output.json generado
[ ] network_dependencies.auto.tfvars.json generado via wrapper PS
[ ] overlay NFW documentado como NO desplegado
```

---

# 4. Stacks downstream (0030 – 0070)

## 4.1. Estado actual

Los repositorios:

```text
ga_ioci0030_iac-oci-security-svc
ga_ioci0040_iac-oci-exa-infra
ga_ioci0041_iac-oci-exa-database
ga_ioci0050_iac-oci-obs-logs
ga_ioci0060_iac-oci-obs-monitor
ga_ioci0070_iac-oci-storage
```

ya tienen la carpeta `dependencies/` preparada con los outputs de Foundation y, en algunos casos, `identity_domains_output.json`. Pendiente:

```text
- Copiar foundation_dependencies.auto.tfvars.json desde Foundation (ya presente en todos)
- Copiar identity_dependencies.auto.tfvars.json desde Identity (cuando consuman identity domains)
- Copiar network_dependencies.auto.tfvars.json desde Network (cuando consuman networking)
- Declarar variables faltantes (identity_domains_dependency) en variables.tf
- Ejecutar el procedimiento de imports declarativos del mismo modo que Foundation/Identity/Network
```

## 4.2. Patrón reproducible

```text
1. Copiar dependencies necesarias desde el stack proveedor
2. Si el stack expone outputs propios, copiar el wrapper *.ps1 desde el stack actualizado y ejecutarlo
3. Generar import blocks declarativos con el script correspondiente
4. Validar plan: N to import, 0 to add, 0 to change, 0 to destroy
5. Aplicar plan guardado
6. Validar plan final sin drift: No changes
7. Generar y validar outputs del stack si los stacks dependientes los requieren
```

---

# 5. Artefactos temporales generados durante la migración

## 5.1. Artefactos por stack

### Foundation

```text
foundation_imports.auto.tf           ← bloques import declarativos; descartar tras apply
foundation-import.tfplan             ← plan binario de import; descartar tras apply
```

### Identity

```text
identity_imports.auto.tf             ← bloques import declarativos; descartar tras apply
identity-import.tfplan               ← plan binario de import; descartar tras apply
```

### Network

```text
migration/network-discovery.tfplan   ← plan de discovery; NO aplicar, solo convertir a JSON
migration/network-discovery.json     ← JSON del discovery plan; input del script de imports
migration/network_imports.auto.tf    ← bloques import declarativos; descartar tras apply
migration/network-import.tfplan      ← plan binario de import; descartar tras apply
migration/network-import-plan.txt    ← salida legible del plan (si se genera)
```

### Logs del generador

```text
generate_import_blocks_*.log         ← logs de ejecución del script PowerShell
```

## 5.2. Política de gestión recomendada

```text
- No commitear *.tfplan en Git (binarios Terraform, no son reproducibles ni legibles).
- No commitear *_imports.auto.tf tras completar el apply (ya no tienen función operativa).
- Los ficheros de discovery (network-discovery.*) pueden conservarse en migration/ como
  referencia histórica si el equipo lo decide, pero no son operativos.
- Los logs del generador pueden archivarse para auditoría o eliminarse tras validación.
```

Excluir mediante `.gitignore`:

```text
*.tfplan
*_imports.auto.tf
generate_import_blocks_*.log
```

## 5.3. Ficheros que sí deben persistir

```text
dependencies/compartments_output.json                  ← output operativo de Foundation
dependencies/tags_output.json                          ← output operativo de Foundation
dependencies/foundation_dependencies.ps1               ← wrapper portable Foundation
dependencies/foundation_dependencies.auto.tfvars.json  ← wrapper para stacks dependientes
dependencies/identity_domains_output.json              ← output operativo de Identity
dependencies/identity_dependencies.ps1                 ← wrapper portable Identity
dependencies/identity_dependencies.auto.tfvars.json    ← wrapper para stacks dependientes
dependencies/network_output.json                       ← output operativo de Network
dependencies/network_dependencies.ps1                  ← wrapper portable Network
dependencies/network_dependencies.auto.tfvars.json     ← wrapper para stacks dependientes
terraform.tfstate                                      ← state activo del stack
terraform.tfstate.backup                               ← backup automático del state
```

---

# 6. KB de problemas encontrados

## KB-001 — `terraform import` imperativo rompe con state parcial

Síntoma:

```text
Invalid index
oci_identity_tag_namespace.these is object with 1 attribute
```

o:

```text
var.compartments_dependency is empty map of object
```

Causa: el orquestador evalúa colecciones completas aunque solo se esté importando un recurso individual.

Solución: usar `import {}` declarativo en bloque y generar un plan completo.

---

## KB-002 — `terraform apply` del plan de import no crea infraestructura

`terraform apply ".\foundation-import.tfplan"` no crea recursos si el plan dice `N to import, 0 to add, 0 to change, 0 to destroy`. Solo escribe en el state la relación entre recursos OCI existentes y direcciones Terraform.

---

## KB-003 — `terraform output` no muestra outputs

Síntoma: `Warning: No outputs found`.

Causa: el root module del repo no define outputs Terraform. El orquestador genera dependency files mediante `output_path` y recursos `local_file`.

Solución: añadir en el JSON `"output_path": "./dependencies"` y ejecutar `terraform apply` para materializar `local_file.*_output[0]`.

---

## KB-004 — Formato incorrecto de dependencies

Síntoma: `var.compartments_dependency is empty map of object`.

Causa: se generó un wrapper plano sin preservar la clave interna del `*_output.json`.

Solución: regenerar el `*_dependencies.auto.tfvars.json` con el wrapper PS correspondiente (`foundation_dependencies.ps1`, `identity_dependencies.ps1`, `network_dependencies.ps1`). La regla simétrica garantiza el formato correcto.

---

## KB-005 — `enable_delete` generaba cambios en compartments

Síntoma:

```text
Plan: 39 to import, 0 to add, 20 to change, 0 to destroy
```

Causa: `"enable_delete": "true"` en el JSON de Foundation.

Solución: cambiar a `"enable_delete": "false"`.

---

## KB-006 — PowerShell no soporta `Select-String -Recurse`

Solución:

```powershell
Get-ChildItem -Recurse -Include *.tf,*.json |
Select-String -Pattern "enable_delete","output_path","compartments_dependency"
```

---

## KB-007 — Ordenar directorio por fecha en PowerShell

```powershell
dir | Sort-Object LastWriteTime -Descending
```

Con columnas reducidas:

```powershell
Get-ChildItem |
Sort-Object LastWriteTime -Descending |
Select-Object LastWriteTime, Name
```

---

## KB-008 — No copiar credenciales como dependency

No colocar dentro de `dependencies/`:

```text
oci-credentials.auto.tfvars.json
```

Debe permanecer en la raíz del repo o gestionarse por mecanismo seguro del runner.

---

## KB-009 — Variable `identity_domains_dependency` no declarada en downstream (v3)

Síntoma al pasar `identity_dependencies.auto.tfvars.json` a un stack 0030–0070:

```text
An input variable with the name "identity_domains_dependency" has not been declared.
```

Causa: la variable no existe aún en los `variables.tf` de los stacks downstream.

Solución: añadir en `variables.tf` del stack consumidor:

```hcl
variable "identity_domains_dependency" {
  type    = any
  default = null
}
```

y propagarla al módulo en `main.tf`:

```hcl
identity_domains_dependency = var.identity_domains_dependency
```

---

## KB-010 — Wrapper PS no encuentra `*_output.json` (v3)

Síntoma:

```text
No se encontro el fichero requerido: <ruta>\dependencies\<recurso>_output.json
```

Causa: aún no se ha ejecutado el `terraform apply` que genera los `local_file.*_output[0]` del orquestador, o se intentó ejecutar el wrapper desde un repo dependiente sin haber copiado primero el output.

Solución:

```text
- Foundation : ejecutar `terraform apply` con output_path configurado.
- Identity   : idem, generando identity_domains_output.json.
- Network    : idem, generando network_output.json.
- Downstream : copiar el *_output.json desde el repo proveedor antes de ejecutar el wrapper.
```

---

# 7. Checklist operativo

## Foundation

```text
[ ] terraform init ejecutado
[ ] giss_foundation_v3.6.json con enable_delete = "false"
[ ] giss_foundation_v3.6.json con output_path = "./dependencies"
[ ] Plan de import: 39 to import, 0 add, 0 change, 0 destroy
[ ] terraform apply foundation-import.tfplan ejecutado
[ ] terraform plan final: No changes
[ ] compartments_output.json generado
[ ] tags_output.json generado
[ ] foundation_dependencies.auto.tfvars.json generado vía wrapper PS
```

## Identity

```text
[ ] foundation_dependencies.auto.tfvars.json copiado desde Foundation
[ ] Script con parser seguro para Identity Domains y Groups
[ ] Import script ejecutado con -NoPrecheck
[ ] Plan de import: 27 to import, 0 add, 0 change, 0 destroy
[ ] terraform apply identity-import.tfplan ejecutado
[ ] terraform plan final: No changes
[ ] giss_identity_v3.6.json con output_path = "./dependencies"
[ ] identity_domains_output.json generado
[ ] identity_dependencies.auto.tfvars.json generado vía wrapper PS
[ ] Warning ETag documentado como upstream known warning
```

## Network

```text
[ ] foundation_dependencies.auto.tfvars.json copiado desde Foundation
[ ] (Opcional) identity_dependencies.auto.tfvars.json copiado desde Identity
[ ] terraform init ejecutado
[ ] network-discovery.tfplan generado (NO aplicar)
[ ] network-discovery.json generado
[ ] Import script ejecutado con -NoPrecheck -SkipMissing
[ ] DRG attachments resueltos por display-name
[ ] Default security lists resueltas vía VCN
[ ] Route table attachment IDs con formato subnet/routetable
[ ] DRG route rules con IDs compuestos drgroutetable/rule_id
[ ] Plan de import: 56 to import, 2 add, 0 change, 0 destroy
[ ] terraform apply network-import.tfplan ejecutado
[ ] terraform plan final: No changes
[ ] network_output.json generado
[ ] network_dependencies.auto.tfvars.json generado vía wrapper PS
[ ] overlay NFW documentado como REFERENCE_ONLY_NOT_DEPLOYED
[ ] Warning cidr_block deprecation documentado como upstream known warning
```

## Downstream (0030–0070)

```text
[ ] foundation_dependencies.auto.tfvars.json copiado desde Foundation
[ ] identity_dependencies.auto.tfvars.json copiado desde Identity (si aplica)
[ ] network_dependencies.auto.tfvars.json copiado desde Network (si aplica)
[ ] variables.tf actualizado con identity_domains_dependency (si aplica)
[ ] main.tf propaga identity_domains_dependency al orquestador (si aplica)
[ ] Procedimiento estándar de imports declarativos completado
```

---

# 8. Comandos rápidos finales

## Foundation final plan

```powershell
cd C:\gitlab\ga_ioci0000_iac-oci-foundation

terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_foundation_v3.6.json"
```

## Identity final plan

```powershell
cd C:\gitlab\ga_ioci0010_iac-oci-identity

terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_identity_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json"
```

## Network final plan

```powershell
cd C:\gitlab\ga_ioci0020_iac-oci-network

terraform plan `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_network_base_v3.6.json" `
  -var-file ".\dependencies\foundation_dependencies.auto.tfvars.json"
```

## Regenerar dependencies (wrappers v3)

```powershell
# Foundation
& "C:\gitlab\ga_ioci0000_iac-oci-foundation\dependencies\foundation_dependencies.ps1"

# Identity
& "C:\gitlab\ga_ioci0010_iac-oci-identity\dependencies\identity_dependencies.ps1"

# Network
& "C:\gitlab\ga_ioci0020_iac-oci-network\dependencies\network_dependencies.ps1"
```

---

# 9. Estado final alcanzado y validado

## 9.1. Recursos importados por stack

```text
Foundation:
  39 recursos importados, 0 add, 0 change, 0 destroy

Identity:
  27 recursos importados, 0 add, 0 change, 0 destroy

Network:
  56 recursos importados, 2 add (local_file + time_sleep, sin impacto en OCI), 0 change, 0 destroy
```

## 9.2. Validación final de drift

```text
Foundation → terraform plan: No changes.
Identity   → terraform plan: No changes.
Network    → terraform plan: No changes.
```

## 9.3. Warnings residuales aceptados

```text
Origen:   terraform-oci-modules-orchestrator / OCI provider / módulos upstream Oracle

Warning:  Deprecated resource attribute "ETag"
Stack:    Identity
Impacto:  Sin drift. Sin recreación. Sin cambios pendientes. No bloqueante.

Warning:  Deprecated resource attribute "route_rules[...].cidr_block"
Stack:    Network
Impacto:  Sin drift. Sin recreación. Sin cambios pendientes. No bloqueante.

Decisión: Warnings aceptados hasta corrección oficial upstream Oracle.
          No modificar .terraform/modules ni módulos descargados.
```

## 9.4. Pendiente

```text
- Replicar el patrón en 0030 a 0070 cuando se prioricen.
- Añadir variable identity_domains_dependency a downstream/variables.tf cuando se consuma.
- Evaluar si futuros stacks deben publicar a su vez sus propios *_output.json + wrapper PS.
```
