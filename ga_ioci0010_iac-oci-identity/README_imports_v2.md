# OCI Landing Zone GISS — Importación declarativa y separación de states

## Alcance

Este documento describe el procedimiento reproducible utilizado para separar el despliegue monolítico de OCI Landing Zone GISS en repositorios independientes, empezando por:

- `ga_ioci0000_iac-oci-foundation`
- `ga_ioci0010_iac-oci-identity`
- `ga_ioci0020_iac-oci-network`

El objetivo del procedimiento es **armar los states Terraform de cada repositorio mediante imports declarativos**, sin recrear, modificar ni destruir infraestructura ya existente en OCI.

La regla de seguridad aplicada durante todo el proceso es:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

Si un plan muestra `add`, `change` o `destroy`, no se debe aplicar hasta auditar la causa.

---

## Contexto técnico

La Landing Zone ya existía y había sido validada previamente con el Terraform monolítico v3.6, obteniendo plan sin cambios. Por tanto, la separación en repositorios no se trató como un nuevo despliegue, sino como una **migración controlada del ownership del state**.

Se sustituyó el uso de `terraform import` imperativo recurso a recurso por **bloques declarativos `import {}`**, porque el OCI Landing Zones Orchestrator evalúa módulos completos y puede fallar cuando el state queda parcialmente importado durante una operación secuencial.

El modelo final usa además la funcionalidad oficial de **External Dependencies** del orquestador:

```text
https://github.com/oci-landing-zones/terraform-oci-modules-orchestrator#external-dependencies
```

El stack `foundation` genera outputs como:

```text
compartments_output.json
tags_output.json
```

y los stacks dependientes, como `identity` y `network`, los consumen transformados a variables Terraform:

```text
foundation_dependencies.auto.tfvars.json
```

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

El script de generación de import blocks evolucionó en paralelo a los stacks para soportar recursos OCI adicionales y resolver edge cases detectados durante la importación real:

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
│  ├─ compartments_output.json
│  ├─ tags_output.json
│  └─ foundation_dependencies.auto.tfvars.json
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
- `dependencies/` contiene solo outputs y wrappers necesarios para otros stacks.
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
  "_meta": {
    "...": "..."
  },
  "output_path": "./dependencies",
  "tags_configuration": {
    "...": "..."
  },
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

Antes de regenerar import blocks o planes, limpiar artefactos temporales anteriores:

```powershell
Remove-Item .\foundation_imports.auto.tf -ErrorAction SilentlyContinue
Remove-Item .\foundation-import.tfplan -ErrorAction SilentlyContinue
```

---

## 1.6. Generar import blocks declarativos para Foundation

Ejecutar:

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

El fichero `foundation_imports.auto.tf` contiene bloques como:

```hcl
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag_namespace.these["TAGNS-LZ-ROLE-KEY"]
  id = "ocid1.tagnamespace..."
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-LZ-ROLE-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.../tags/o-p-om2-tag-role-001"
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.these["CMP-LANDINGZONE-KEY"]
  id = "ocid1.compartment..."
}
```

---

## 1.7. Validar el plan de import de Foundation

El resultado esperado debe ser exactamente:

```text
Plan: 39 to import, 0 to add, 0 to change, 0 to destroy.
```

No aplicar si aparece:

```text
to add
to change
to destroy
```

Durante la POC apareció inicialmente:

```text
Plan: 39 to import, 0 to add, 20 to change, 0 to destroy.
```

La causa fue `enable_delete = "true"`. Se corrigió cambiándolo a `"false"`.

---

## 1.8. Aplicar el plan de import de Foundation

Aplicar únicamente el plan guardado:

```powershell
terraform apply ".\foundation-import.tfplan"
```

Resultado esperado:

```text
Apply complete! Resources: 39 imported, 0 added, 0 changed, 0 destroyed.
```

Este `apply` no crea infraestructura. Solo materializa en el `tfstate` la asociación entre las direcciones Terraform y los recursos OCI existentes.

---

## 1.9. Validar el state de Foundation

Listar recursos importados:

```powershell
terraform state list
```

Deben verse recursos como:

```text
module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag_namespace.these["TAGNS-LZ-ROLE-KEY"]
module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-LZ-ROLE-KEY"]
module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.these["CMP-LANDINGZONE-KEY"]
module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_2["CMP-LZ-NETWORK-KEY"]
```

---

## 1.10. Validar que Foundation no tiene drift

Ejecutar:

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

El orquestador no expone necesariamente estos datos mediante `terraform output`. En la POC, al ejecutar:

```powershell
terraform output
```

se obtuvo:

```text
Warning: No outputs found
```

La generación correcta se hizo mediante `output_path`.

Con `"output_path": "./dependencies"` en el JSON, ejecutar:

```powershell
terraform apply `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_foundation_v3.6.json"
```

El plan esperado para esta operación solo debe crear ficheros locales:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Recursos locales esperados:

```text
module.oci_lz_orchestrator.local_file.compartments_output[0]
module.oci_lz_orchestrator.local_file.tags_output[0]
```

No modifica OCI.

Después del apply deben existir:

```text
dependencies/compartments_output.json
dependencies/tags_output.json
```

Verificar:

```powershell
dir .\dependencies | Sort-Object LastWriteTime -Descending
```

---

## 1.12. Generar wrapper Terraform para dependencias Foundation

Los outputs originales tienen esta forma:

```json
{
  "compartments": {
    "CMP-LANDINGZONE-KEY": {
      "id": "ocid1.compartment..."
    }
  }
}
```

y:

```json
{
  "tags": {
    "TAG-GOV-NAME-KEY": {
      "id": "ocid1.tagdefinition..."
    }
  }
}
```

El orquestador, al recibir variables, espera esta forma:

```json
{
  "compartments_dependency": {
    "compartments": {
      "CMP-LANDINGZONE-KEY": {
        "id": "ocid1.compartment..."
      }
    }
  },
  "tags_dependency": {
    "tags": {
      "TAG-GOV-NAME-KEY": {
        "id": "ocid1.tagdefinition..."
      }
    }
  }
}
```

Generar el wrapper:

```powershell
$depPath = ".\dependencies"

$comp = Get-Content "$depPath\compartments_output.json" -Raw | ConvertFrom-Json
$tags = Get-Content "$depPath\tags_output.json" -Raw | ConvertFrom-Json

$vars = [ordered]@{
  compartments_dependency = @{
    compartments = $comp.compartments
  }
  tags_dependency = @{
    tags = $tags.tags
  }
}

$vars | ConvertTo-Json -Depth 30 |
  Set-Content "$depPath\foundation_dependencies.auto.tfvars.json" -Encoding utf8
```

Validar:

```powershell
Get-Content .\dependencies\foundation_dependencies.auto.tfvars.json
```

Debe contener:

```json
{
  "compartments_dependency": {
    "compartments": {
      "...": {
        "id": "..."
      }
    }
  },
  "tags_dependency": {
    "tags": {
      "...": {
        "id": "..."
      }
    }
  }
}
```

---

## 1.13. Archivos Foundation que se copian a otros repositorios

Para los repositorios dependientes se deben copiar:

```text
dependencies/compartments_output.json
dependencies/tags_output.json
dependencies/foundation_dependencies.auto.tfvars.json
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
│  ├─ compartments_output.json
│  ├─ tags_output.json
│  └─ foundation_dependencies.auto.tfvars.json
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
compartments_output.json
tags_output.json
foundation_dependencies.auto.tfvars.json
```

Ubicación recomendada:

```text
ga_ioci0010_iac-oci-identity/dependencies/
```

Verificar:

```powershell
cd C:\gitlab\ga_ioci0010_iac-oci-identity

dir .\dependencies | Sort-Object LastWriteTime -Descending
```

Debe mostrar:

```text
compartments_output.json
tags_output.json
foundation_dependencies.auto.tfvars.json
```

Si no existe el wrapper, se puede regenerar desde Identity:

```powershell
$depPath = ".\dependencies"

$comp = Get-Content "$depPath\compartments_output.json" -Raw | ConvertFrom-Json
$tags = Get-Content "$depPath\tags_output.json" -Raw | ConvertFrom-Json

$vars = [ordered]@{
  compartments_dependency = @{
    compartments = $comp.compartments
  }
  tags_dependency = @{
    tags = $tags.tags
  }
}

$vars | ConvertTo-Json -Depth 30 |
  Set-Content "$depPath\foundation_dependencies.auto.tfvars.json" -Encoding utf8
```

---

## 2.4. Nota sobre `output_path` en Identity

`output_path` no es obligatorio en Identity para el import ni para la operación normal.

En `giss_identity_v3.6.json` puede dejarse deshabilitado. Se recomienda documentarlo dentro de `_meta.notes`:

```json
"Este stack no requiere output_path para operación normal. Se utiliza únicamente en escenarios donde identity exporta dependencias consumidas por otros stacks."
```

Activar `output_path` solo si otro stack necesita consumir outputs de Identity, como Identity Domains, grupos o policies.

---

## 2.5. Validaciones previas de Identity

Entrar al repo:

```powershell
cd C:\gitlab\ga_ioci0010_iac-oci-identity
```

Inicializar Terraform:

```powershell
terraform init
```

Verificar:

```powershell
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
var.compartments_dependency["compartments"]["CMP-LANDINGZONE-KEY"].id
```

o, si Terraform interpreta el objeto con sintaxis de atributo:

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

Problema:

```text
The property 'displayName' cannot be found on this object.
```

Causa:

OCI CLI devuelve algunas propiedades con guiones, por ejemplo:

```text
display-name
lifecycle-state
```

y no siempre:

```text
displayName
```

La función `Get-IdentityDomainByDisplayName` debe usar acceso seguro:

```powershell
$match = $items | Where-Object {
  $dn = $_.'display-name'
  if ($null -eq $dn -and $_.PSObject.Properties.Name -contains 'displayName') { $dn = $_.displayName }
  $ls = $_.'lifecycle-state'
  ($dn -ieq $DisplayName) -and ($ls -ne "DELETED")
} | Select-Object -First 1
```

### 2.6.2. Corrección en Identity Domain Groups

Problema:

```text
The property 'displayName' cannot be found on this object.
```

La función `Get-IdentityDomainGroupId` debe usar acceso seguro:

```powershell
$match = $items | Where-Object {
  $dn = $null

  if ($_.PSObject.Properties.Name -contains 'displayName') {
    $dn = $_.displayName
  }
  elseif ($_.PSObject.Properties.Name -contains 'display_name') {
    $dn = $_.display_name
  }
  elseif ($_.PSObject.Properties.Name -contains 'display-name') {
    $dn = $_.'display-name'
  }

  $deleteInProgress = $false
  if ($_.PSObject.Properties.Name -contains 'deleteInProgress') {
    $deleteInProgress = $_.deleteInProgress
  }
  elseif ($_.PSObject.Properties.Name -contains 'delete-in-progress') {
    $deleteInProgress = $_.'delete-in-progress'
  }

  ($dn -ieq $DisplayName) -and ($deleteInProgress -ne $true)
} | Select-Object -First 1
```

---

## 2.7. Por qué se usa `-NoPrecheck` en Identity

El precheck original ejecutaba:

```powershell
terraform plan -refresh=false -input=false -lock=false -detailed-exitcode
```

En Identity ese precheck puede fallar antes del import con:

```text
var.compartments_dependency is empty map of object
```

El plan real sí funciona cuando recibe el wrapper correcto:

```text
foundation_dependencies.auto.tfvars.json
```

Por tanto, para Identity se ejecuta el script con:

```powershell
-NoPrecheck
```

El criterio seguro sigue siendo el plan real guardado:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

---

## 2.8. Limpiar artefactos temporales antes del import de Identity

```powershell
Remove-Item .\identity_imports.auto.tf -ErrorAction SilentlyContinue
Remove-Item .\identity-import.tfplan -ErrorAction SilentlyContinue
```

---

## 2.9. Generar import blocks declarativos para Identity

Ejecutar:

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

El script debe generar:

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

No aplicar si aparece:

```text
to add
to change
to destroy
```

Durante la POC se detectaron varias causas de error antes de llegar al plan limpio:

### Caso 1: dependencies no existentes

Síntoma:

```text
No existe dependency file: .\compartments_output.json
```

Solución:

Copiar desde Foundation a `dependencies/`.

### Caso 2: dependencies sin wrapper correcto

Síntoma:

```text
var.compartments_dependency is empty map of object
```

Formato incorrecto:

```json
{
  "compartments_dependency": {
    "CMP-LANDINGZONE-KEY": {
      "id": "ocid1.compartment..."
    }
  }
}
```

Formato correcto:

```json
{
  "compartments_dependency": {
    "compartments": {
      "CMP-LANDINGZONE-KEY": {
        "id": "ocid1.compartment..."
      }
    }
  }
}
```

### Caso 3: parser de Identity Domains o Groups

Síntoma:

```text
The property 'displayName' cannot be found on this object.
```

Solución:

Aplicar las correcciones descritas en la sección 2.6.

---

## 2.11. Aplicar el plan de import de Identity

Aplicar únicamente el plan guardado:

```powershell
terraform apply ".\identity-import.tfplan"
```

Resultado esperado:

```text
Apply complete! Resources: 27 imported, 0 added, 0 changed, 0 destroyed.
```

---

## 2.12. Validar state de Identity

```powershell
terraform state list
```

Deben aparecer recursos como:

```text
module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domain.these["COMMON-DOMAIN"]
module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["GRP-AUDITORS-ADMIN-KEY"]
module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-AUDITING-ADMIN-KEY"]
```

---

## 2.13. Validar que Identity no tiene drift

Ejecutar:

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

Durante la POC el resultado final fue:

```text
No changes.
```

con un warning upstream del módulo de policies relacionado con `ETag`.

---

## 2.14. Warning conocido de `ETag`

Puede aparecer:

```text
Warning: Deprecated value used

The deprecation originates from:
module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["..."].ETag

Deprecated resource attribute "ETag" used.
```

Causa:

El submódulo upstream de policies exporta el recurso completo:

```hcl
output "policies" {
  value = local.enable_output ? oci_identity_policy.these : null
}
```

Al exportar el recurso completo, Terraform evalúa también atributos deprecated del provider OCI, como `ETag`.

Decisión tomada:

```text
No se modifica el orquestador ni módulos descargados.
Se mantiene el warning como known upstream warning hasta corrección oficial de Oracle.
```

Impacto:

```text
No genera drift.
No modifica infraestructura.
No afecta imports.
No afecta state.
```

No se recomienda modificar:

```text
.terraform/modules/...
```

porque se regenera con `terraform init` y rompe reproducibilidad.

---

# 3. Stack Network

## 3.1. Objetivo del stack

El repositorio `ga_ioci0020_iac-oci-network` gestiona:

```text
VCNs
Subnets
Route Tables
Route Table Attachments
Security Lists
NSGs
NSG Rules
Service Gateways
NAT Gateways
DRGs
DRG Attachments
DRG Route Tables
DRG Route Distributions
DRG Route Rules
```

El objetivo de la migración fue separar el networking del monolito v3.6 y construir un state Terraform consistente mediante imports declarativos sin recrear infraestructura OCI existente.

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
│  ├─ compartments_output.json
│  ├─ tags_output.json
│  ├─ foundation_dependencies.auto.tfvars.json
│  └─ network_output.json
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

El stack Network consume outputs del stack Foundation.

Copiar desde Foundation:

```text
dependencies/compartments_output.json
dependencies/tags_output.json
dependencies/foundation_dependencies.auto.tfvars.json
```

Validar:

```powershell
dir .\dependencies
```

---

## 3.4. Generar discovery plan

Antes de generar imports declarativos es obligatorio crear el discovery plan Terraform.

Entrar al repositorio:

```powershell
cd C:\gitlab\ga_ioci0020_iac-oci-network
```

Inicializar:

```powershell
terraform init
```

Generar el plan:

```powershell
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

Esto NO debe aplicarse. El objetivo es únicamente generar el tfplan de discovery.

---

## 3.5. Generar JSON del discovery plan

Convertir el tfplan a JSON:

```powershell
terraform show -json .\migration\network-discovery.tfplan |
  Out-File .\migration\network-discovery.json -Encoding utf8
```

Validar:

```powershell
Test-Path .\migration\network-discovery.json
```

Resultado esperado:

```text
True
```

---

## 3.6. Generar import blocks declarativos

Ejecutar:

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

El script genera:

```text
network_imports.auto.tf
network-import.tfplan
```

---

## 3.7. Recursos soportados por el import generator

La versión `v3.2.7` soporta:

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

Además contempla estructuras futuras del overlay:

```text
OCI Network Firewall (NFW)
```

aunque no estén desplegadas actualmente.

---

## 3.8. Problemas encontrados y correcciones aplicadas

### 3.8.1. Route Table Attachments

OCI provider requiere import IDs con formato:

```text
[subnet_ocid]/[route_table_ocid]
```

No funciona:

```text
/ocid1.routetable...
```

La versión final del script construye correctamente:

```text
ocid1.subnet.../ocid1.routetable...
```

---

### 3.8.2. Default Security Lists

Las default security lists NO se pueden descubrir directamente por display_name.

Fue necesario resolverlas vía:

```text
VCN -> default-security-list-id
```

usando:

```powershell
oci network vcn get --output json
```

---

### 3.8.3. DRG Attachments

La resolución correcta se hizo mediante:

```text
display-name
```

y no por VCN únicamente.

Caso validado:

```text
o-p-om2-drgatt-hub-001
o-p-om2-drgatt-exap-001
o-p-om2-drgatt-exad-001
```

---

### 3.8.4. DRG Route Rules

OCI no expone OCIDs individuales para route rules.

Terraform utiliza import IDs compuestos:

```text
[drg_route_table_ocid]/[route_rule_id]
```

Ejemplo validado:

```text
ocid1.drgroutetable.../5554
```

---

## 3.9. Resultado final del import

Resultado validado:

```text
Apply complete! Resources: 56 imported, 2 added, 0 changed, 0 destroyed.
```

Los 2 recursos añadidos fueron únicamente:

```text
module.oci_lz_orchestrator.local_file.network_output[0]
module.oci_lz_orchestrator.module.oci_lz_network[0].time_sleep.wait_for_dns_resolver
```

Impacto:

```text
No modifican OCI.
No generan drift.
No crean networking real.
```

---

## 3.10. Validación final sin drift

Ejecutar:

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

Este resultado confirma que:

```text
- El state quedó alineado con OCI
- No existe drift
- Todos los imports fueron consistentes
- El repositorio quedó listo para operación normal
```

---

## 3.11. Generación de outputs del stack Network

El stack genera:

```text
dependencies/network_output.json
```

Validar:

```powershell
dir .\dependencies
```

Resultado esperado:

```text
network_output.json
```

---

## 3.12. Overlay OCI Network Firewall (NFW)

El fichero:

```text
giss_network_nfw_addon_v3.6.json
```

NO forma parte del despliegue activo.

Estado actual:

```text
REFERENCE_ONLY_NOT_DEPLOYED
```

Razón:

```text
Optimización de costes.
```

El overlay se conserva únicamente como:

```text
- referencia arquitectónica
- baseline de futuras reactivaciones
- validación de diseño Hub-and-Spoke
```

Actualmente NO debe incluirse en:

```text
terraform plan
terraform apply
pipelines CI/CD
```

La reactivación requiere:

```text
- Rediseño east-west routing
- Revisión de políticas L7 reales
- Validación de coste OCI
```

---

## 3.13. Warnings conocidos

Puede aparecer:

```text
Deprecated resource attribute "route_rules[...].cidr_block" used.
```

Origen:

```text
terraform-oci-modules-networking upstream module
```

Impacto:

```text
No genera drift.
No modifica OCI.
No afecta imports.
```

Decisión tomada:

```text
No modificar módulos descargados en .terraform/modules.
Esperar corrección oficial upstream.
```

---

## 3.14. Checklist operativo final — Network

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
[ ] overlay NFW documentado como NO desplegado
```

---

# 4. Artefactos temporales generados durante la migración

Durante la ejecución de cada stack se generan ficheros auxiliares que no forman parte del estado operativo permanente. Deben excluirse de commits, pipelines CI/CD y entregas de handover.

## 4.1. Artefactos por stack

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

## 4.2. Política de gestión recomendada

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

## 4.3. Ficheros que sí deben persistir

```text
dependencies/compartments_output.json                  ← output operativo de Foundation
dependencies/tags_output.json                          ← output operativo de Foundation
dependencies/foundation_dependencies.auto.tfvars.json  ← wrapper para stacks dependientes
dependencies/network_output.json                       ← output operativo de Network
terraform.tfstate                                      ← state activo del stack
terraform.tfstate.backup                               ← backup automático del state
```

---

# 5. KB de problemas encontrados

## KB-001 — `terraform import` imperativo rompe con state parcial

### Síntoma

```text
Invalid index
oci_identity_tag_namespace.these is object with 1 attribute
```

o:

```text
var.compartments_dependency is empty map of object
```

### Causa

El orquestador evalúa colecciones completas aunque solo se esté importando un recurso individual.

### Solución

Usar `import {}` declarativo en bloque y generar un plan completo:

```text
foundation_imports.auto.tf
identity_imports.auto.tf
```

---

## KB-002 — `terraform apply` del plan de import no crea infraestructura

### Aclaración

El comando:

```powershell
terraform apply ".\foundation-import.tfplan"
```

o:

```powershell
terraform apply ".\identity-import.tfplan"
```

no crea recursos si el plan dice:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

Solo escribe en el state la relación entre recursos OCI existentes y direcciones Terraform.

---

## KB-003 — `terraform output` no muestra outputs

### Síntoma

```text
Warning: No outputs found
```

### Causa

El root module del repo no define outputs Terraform. El orquestador genera dependency files mediante `output_path` y recursos `local_file`.

### Solución

Añadir en el JSON:

```json
"output_path": "./dependencies"
```

y ejecutar:

```powershell
terraform apply `
  -var-file ".\oci-credentials.auto.tfvars.json" `
  -var-file ".\giss_foundation_v3.6.json"
```

---

## KB-004 — Formato incorrecto de dependencies

### Síntoma

```text
var.compartments_dependency is empty map of object
```

### Causa

Se generó:

```json
"compartments_dependency": {
  "CMP-LANDINGZONE-KEY": {
    "id": "ocid1..."
  }
}
```

pero el orquestador espera:

```json
"compartments_dependency": {
  "compartments": {
    "CMP-LANDINGZONE-KEY": {
      "id": "ocid1..."
    }
  }
}
```

### Solución

Regenerar `foundation_dependencies.auto.tfvars.json` con el wrapper correcto.

---

## KB-005 — `enable_delete` generaba cambios en compartments

### Síntoma

```text
Plan: 39 to import, 0 to add, 20 to change, 0 to destroy
```

### Causa

El JSON tenía:

```json
"enable_delete": "true"
```

### Solución

Cambiar a:

```json
"enable_delete": "false"
```

---

## KB-006 — PowerShell no soporta `Select-String -Recurse`

### Síntoma

```text
A parameter cannot be found that matches parameter name 'Recurse'
```

### Solución

Usar:

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

Ese fichero debe permanecer en la raíz del repo o gestionarse por mecanismo seguro del runner.

---

# 6. Checklist operativo

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
[ ] foundation_dependencies.auto.tfvars.json generado
```

## Identity

```text
[ ] dependencies copiadas desde Foundation
[ ] foundation_dependencies.auto.tfvars.json validado
[ ] Script con parser seguro para Identity Domains y Groups
[ ] Import script ejecutado con -NoPrecheck
[ ] Plan de import: 27 to import, 0 add, 0 change, 0 destroy
[ ] terraform apply identity-import.tfplan ejecutado
[ ] terraform plan final: No changes
[ ] Warning ETag documentado como upstream known warning
```

## Network

```text
[ ] dependencies copiadas desde Foundation
[ ] foundation_dependencies.auto.tfvars.json validado
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
[ ] overlay NFW documentado como REFERENCE_ONLY_NOT_DEPLOYED
[ ] Warning cidr_block deprecation documentado como upstream known warning
```

---

# 7. Comandos rápidos finales

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

## Regenerar Foundation dependencies

```powershell
cd C:\gitlab\ga_ioci0000_iac-oci-foundation

$depPath = ".\dependencies"

$comp = Get-Content "$depPath\compartments_output.json" -Raw | ConvertFrom-Json
$tags = Get-Content "$depPath\tags_output.json" -Raw | ConvertFrom-Json

$vars = [ordered]@{
  compartments_dependency = @{
    compartments = $comp.compartments
  }
  tags_dependency = @{
    tags = $tags.tags
  }
}

$vars | ConvertTo-Json -Depth 30 |
  Set-Content "$depPath\foundation_dependencies.auto.tfvars.json" -Encoding utf8
```

---

# 8. Estado final alcanzado y validado

## 8.1. Recursos importados por stack

```text
Foundation:
  39 recursos importados
  0 add
  0 change
  0 destroy

Identity:
  27 recursos importados
  0 add
  0 change
  0 destroy

Network:
  56 recursos importados
  2 add (local_file y time_sleep — sin impacto en OCI)
  0 change
  0 destroy
```

## 8.2. Validación final de drift

```text
Foundation → terraform plan: No changes. Your infrastructure matches the configuration.
Identity   → terraform plan: No changes. Your infrastructure matches the configuration.
Network    → terraform plan: No changes. Your infrastructure matches the configuration.
```

Ningún stack tiene drift tras la importación. Los tres repositorios quedaron listos para operación normal y CI/CD.

## 8.3. Warnings residuales aceptados

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

## 8.4. Patrón reproducible para siguientes stacks

El procedimiento queda listo para repetirse en los siguientes repositorios siguiendo el mismo patrón:

```text
1. Copiar dependencies necesarias desde el stack proveedor
2. Generar wrapper .auto.tfvars.json si aplica
3. Generar import blocks declarativos con el script correspondiente
4. Validar plan: N to import, 0 to add, 0 to change, 0 to destroy
5. Aplicar plan guardado
6. Validar plan final sin drift: No changes
7. Generar y validar outputs del stack si los stacks dependientes los requieren
```
