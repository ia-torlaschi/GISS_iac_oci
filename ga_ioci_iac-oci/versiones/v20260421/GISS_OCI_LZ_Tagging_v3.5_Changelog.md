# GISS OCI Landing Zone — Changelog v3.5
**Proyecto:** OCI Landing Zone — Seguridad Social (GISS)  
**Región:** `eu-madrid-2`  
**Fecha:** 2026-04-20  
**Alcance:** Implementación de estrategia de tagging obligatorio en todos los recursos

---

## Resumen ejecutivo

La versión 3.5 incorpora la estrategia de tagging corporativo sobre los cuatro ficheros de configuración de la Landing Zone. El cambio es **exclusivamente aditivo**: no se ha eliminado ni modificado ningún valor existente. Todo el contenido desplegado en producción permanece intacto.

---

## Ficheros modificados

| Fichero | Versión anterior | Versión nueva |
|---|---|---|
| `giss_governance__v3.3.json` | v3.3 | **v3.5** |
| `giss_iam_v3.4.json` | v3.4 | **v3.5** |
| `giss_network_hub_b_empty_v3.3.json` | v3.3 | **v3.5** |
| `giss_network_hub_b_firewall_v3.3.json` | v3.3 | **v3.5** |

---

## 1. `giss_governance__v3.5.json`

### Cambios
Se añaden dos nuevos namespaces de tags al namespace existente de TBAC, que permanece sin modificaciones.

#### Namespace existente — sin cambios
| Namespace | Tag key | Propósito |
|---|---|---|
| `o-p-om2-tagns-name-001` | `o-p-om2-tag-role-001` | TBAC de roles IAM — **sin cambios** |

#### Namespace nuevo — Governance operativa
**`o-p-om2-tagns-gov-001`**

| Key Terraform | Tag OCI | `is_cost_tracking` | Valores / Validación |
|---|---|---|---|
| `TAG-GOV-TECHNICAL-OWNER-KEY` | `technical-owner` | `false` | Correo corporativo — libre |
| `TAG-GOV-OPERATIONAL-OWNER-KEY` | `operational-owner` | `false` | Correo corporativo — libre |
| `TAG-GOV-DEPARTMENT-KEY` | `department` | **`true`** | Unidad de negocio — libre |
| `TAG-GOV-COST-CENTER-KEY` | `cost-center` | **`true`** | Código de centro de costes — libre |
| `TAG-GOV-APPLICATION-CODE-KEY` | `application-code` | **`true`** | Código de aplicación — libre |
| `TAG-GOV-APPLICATION-NAME-KEY` | `application-name` | `false` | Nombre de aplicación — libre |
| `TAG-GOV-NAME-KEY` | `Name` | **`true`** | Igual al `display_name` del recurso — libre |
| `TAG-GOV-ENVIRONMENT-KEY` | `environment` | **`true`** | ENUM: `dev`, `pre`, `pro`, `int`, `qa`, `cer` |
| `TAG-GOV-IAC-KEY` | `iac` | `false` | ENUM: `terraform`, `manual`, `cli` |
| `TAG-GOV-BUSINESS-CRITICALITY-KEY` | `business-criticality` | `false` | ENUM: `critico`, `alto`, `medio`, `bajo` |

#### Namespace nuevo — Clasificación ENS
**`o-p-om2-tagns-ens-001`**

| Key Terraform | Tag OCI | Dimensión ENS | Valores |
|---|---|---|---|
| `TAG-ENS-AUTHENTICITY-KEY` | `ens-authenticity` | Autenticidad | ENUM: `alto`, `medio`, `bajo` |
| `TAG-ENS-INTEGRITY-KEY` | `ens-integrity` | Integridad | ENUM: `alto`, `medio`, `bajo` |
| `TAG-ENS-AVAILABILITY-KEY` | `ens-availability` | Disponibilidad | ENUM: `alto`, `medio`, `bajo` |
| `TAG-ENS-CONFIDENTIALITY-KEY` | `ens-confidentiality` | Confidencialidad | ENUM: `alto`, `medio`, `bajo` |
| `TAG-ENS-TRACEABILITY-KEY` | `ens-traceability` | Trazabilidad | ENUM: `alto`, `medio`, `bajo` |

---

## 2. `giss_iam_v3.5.json`

### Cambios

#### 2.1 Compartimentos — `defined_tags` añadidos en todos
Los 15 compartimentos de la jerarquía reciben el bloque completo de 15 tags (10 GOV + 5 ENS). Los compartimentos que ya tenían `defined_tags` TBAC los conservan intactos; los nuevos tags se añaden junto a ellos.

| Compartimento | `environment` auto | TBAC previo |
|---|---|---|
| `o-p-om2-cmp-land-001` | `pro` | — |
| `o-p-om2-cmp-network-001` | `pro` | `network-001` |
| `o-p-om2-cmp-platform-001` | `pro` | — |
| `o-p-om2-cmp-exacs-001` | `pro` | `exa-001` |
| `o-p-om2-cmp-exacsdb-001` | `pro` | `exadb-001` |
| `o-p-om2-cmp-exacsinfra-001` | `pro` | `exainfra-001` |
| `o-p-om2-cmp-logg-001` | `pro` | — |
| `o-p-om2-cmp-devop-001` | `pro` | — |
| `o-p-om2-cmp-cdin-core-001` | `pro` | — |
| `o-p-om2-cmp-cdin-001` (PROD) | `pro` | — |
| `o-p-om2-cmp-cdin-network-001` | `pro` | `network-001` |
| `o-p-om2-cmp-cdin-platform-001` | `pro` | — |
| `o-p-om2-cmp-cdin-projects-001` | `pro` | — |
| `o-p-om2-cmp-cdin-security-001` | `pro` | `security-001` |
| `o-d-om2-cmp-cdin-001` (NPR) | **`dev`** | — |
| `o-d-om2-cmp-cdin-network-001` | **`dev`** | `network-001` |
| `o-d-om2-cmp-cdin-platform-001` | **`dev`** | — |
| `o-d-om2-cmp-cdin-projects-001` | **`dev`** | — |
| `o-d-om2-cmp-cdin-security-001` | **`dev`** | `security-001` |
| `o-p-om2-cmp-security-001` | `pro` | `security-001` |

#### 2.2 Política `PCY-GENERIC-ADMIN-KEY` (`o-p-om2-pcy-gadm-001`)
Se añaden 2 statements al final de la lista existente para que Terraform pueda inspeccionar los nuevos namespaces durante `plan`/`apply`. Los 5 statements originales permanecen sin cambios.

```
allow any-user to inspect tag-namespaces in tenancy where target.tag-namespace.name='o-p-om2-tagns-gov-001'
allow any-user to inspect tag-namespaces in tenancy where target.tag-namespace.name='o-p-om2-tagns-ens-001'
```

> **Nota:** El resto de las 18 políticas y sus statements quedan íntegros. Los 8 grupos de identidad y la `identity_domains_configuration` no reciben modificaciones.

---

## 3. `giss_network_hub_b_empty_v3.5.json`

### Cambios
Se añaden `defined_tags` a todos los recursos de red con soporte nativo en OCI. Ninguna regla de routing, security list, NSG ni configuración de gateway ha sido modificada.

#### Recursos taggeados por categoría

**Categoría `0-shared` — Hub VCN**

| Tipo | Recurso | `environment` |
|---|---|---|
| VCN | `o-p-om2-vcn-hub-001` | `pro` |
| Subnet | `o-p-om2-sub-hubfw-001` | `pro` |
| Subnet | `o-p-om2-sub-hubmgmt-001` | `pro` |
| Subnet | `o-p-om2-sub-hubmon-001` | `pro` |
| Subnet | `o-p-om2-sub-hubdns-001` | `pro` |
| Route Table | `o-p-om2-rtb-hubingress-001` | `pro` |
| Route Table | `o-p-om2-rtb-hubfw-001` | `pro` |
| Route Table | `o-p-om2-rtb-hubnatgw-001` | `pro` |
| Route Table | `o-p-om2-rtb-hubmgmt-001` | `pro` |
| Security List | `o-p-om2-sl-hubfw-001` | `pro` |
| Security List | `o-p-om2-sl-hubmgmt-001` | `pro` |
| NSG | `o-p-om2-nsg-hublb-001` | `pro` |
| NSG | `o-p-om2-nsg-hubfw-001` | `pro` |
| NAT Gateway | `o-p-om2-ngw-hub-001` | `pro` |
| Service Gateway | `o-p-om2-sgw-hub-001` | `pro` |
| DRG | `o-p-om2-drg-hub-001` | `pro` |

**Categoría `1-shared-exacs-pro` — ExaCS Producción**

| Tipo | Recurso | `environment` |
|---|---|---|
| VCN | `o-p-om2-vcn-exacspro-001` | `pro` |
| Subnet | `o-p-om2-sub-exacsprocli-001` | `pro` |
| Subnet | `o-p-om2-sub-exacsprobck-001` | `pro` |
| Route Table | `o-p-om2-rtb-exacs-procli-001` | `pro` |
| Route Table | `o-p-om2-rtb-exacs-procbck-001` | `pro` |
| Security List | `o-p-om2-sl-exacs-procli-001` | `pro` |
| Security List | `o-p-om2-sl-exacs-probkc-001` | `pro` |
| Service Gateway | `o-p-om2-sgw-exacs-pro-001` | `pro` |

**Categoría `2-shared-exacs-nonpro` — ExaCS No Producción**

| Tipo | Recurso | `environment` |
|---|---|---|
| VCN | `o-d-om2-vcn-exacsnpr-001` | **`dev`** |
| Subnet | `o-d-om2-sub-exacs-nprcli-001` | **`dev`** |
| Subnet | `o-d-om2-sub-exacs-nprbck-001` | **`dev`** |
| Route Table | `o-d-om2-rtb-exacs-nprcli-001` | **`dev`** |
| Route Table | `o-d-om2-rtb-exacs-nprbck-001` | **`dev`** |
| Security List | `o-d-om2-sl-exacs-nprcli-001` | **`dev`** |
| Security List | `o-d-om2-sl-exacs-nprbck-001` | **`dev`** |
| Service Gateway | `o-d-om2-sgw-exacs-npr-001` | **`dev`** |

---

## 4. `giss_network_hub_b_firewall_v3.5.json`

### Cambios
Idéntico al fichero `empty` en cuanto a recursos de red. Se añaden adicionalmente tags a los recursos exclusivos de este fichero.

#### Recursos adicionales taggeados

| Tipo | Recurso | `environment` |
|---|---|---|
| NFW Policy | `o-p-om2-nfw-policy-001` | `pro` |
| NFW Instance | `o-p-om2-nfw-hub-001` | `pro` |

> Los sub-objetos internos de la política (services, service_lists, applications, address_lists, url_lists, security_rules) no soportan `defined_tags` de forma independiente en OCI y no han sido modificados.

---

## Automatización de tags

Los siguientes tags se resuelven automáticamente durante el `terraform apply` sin intervención manual:

| Tag | Valor automático | Criterio |
|---|---|---|
| `iac` | `terraform` | Fijo en todos los recursos |
| `environment` | `pro` / `dev` | Derivado del prefijo del nombre: `o-p-` → `pro`, `o-d-` → `dev` |
| `Name` | Igual al `display_name` del recurso | Tomado directamente del campo de nomenclatura |

---

## Tags pendientes de relleno manual (`__FILL__`)

Los siguientes tags requieren valores específicos por compartimento o workload y deben ser completados antes del `terraform apply`:

- `technical-owner`
- `operational-owner`
- `department`
- `cost-center`
- `application-code`
- `application-name`
- `business-criticality`
- `ens-authenticity`
- `ens-integrity`
- `ens-availability`
- `ens-confidentiality`
- `ens-traceability`

Busca globalmente `__FILL__` en cada fichero para localizar todos los campos pendientes.

| Fichero | Campos `__FILL__` |
|---|---|
| `giss_governance__v3.5.json` | 0 |
| `giss_iam_v3.5.json` | 240 |
| `giss_network_hub_b_empty_v3.5.json` | 384 |
| `giss_network_hub_b_firewall_v3.5.json` | 408 |

---

## Orden de despliegue recomendado

```
1. terraform apply -var-file giss_governance__v3.5.json       ← primero: crea los namespaces y tag keys
2. terraform apply -var-file giss_iam_v3.5.json               ← segundo: aplica tags a compartimentos y actualiza policies
3. terraform apply -var-file giss_network_hub_b_empty_v3.5.json   ← tercero (entorno sin firewall)
   o
   terraform apply -var-file giss_network_hub_b_firewall_v3.5.json ← tercero (entorno con firewall)
```

> Los namespaces y tag keys deben existir en el tenancy **antes** de que Terraform intente asignar `defined_tags` en los recursos de IAM y red. Si se aplica en un solo `apply`, el orquestador resuelve las dependencias automáticamente.

---

