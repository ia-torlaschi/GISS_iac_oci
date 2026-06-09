# CHANGELOG — OCI Landing Zone GISS

**Proyecto:** OCI Landing Zone — Seguridad Social (GISS)
**Región:** `eu-madrid-2` — España Central (Madrid)
**Plataforma:** Oracle Cloud Infrastructure · Terraform · oracle/oci provider ~> 8.5.0
**Repositorios (desde v3.6):** ver tabla en sección [3.6](#36--2026-05) — antes de v3.6: `ga/ioci/ga_ioci_iac-oci` (monolito)

---

> Todas las versiones siguen el formato [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
> Hasta v3.5 los ficheros se versionaban como `giss_<módulo>_v<X>.<Y>.json` dentro de un único repositorio.
> Desde v3.6 cada stack vive en su propio repositorio Git con un único fichero `giss_<stack>_v3.6.json` (más overlays opcionales).

---

## [3.7] - 2026-06-09

> **Normalizacion de versionado 3.7 por stack.** Se copia la base v3.6 a archivos v3.7 en todos los stacks. Los cambios funcionales se concentran en identity, network, obs-logs y obs-monitor; el resto queda como copia 1:1 sin cambios funcionales respecto a v3.6.

### Added - Archivos de configuracion v3.7

- Se generan los archivos giss_*_v3.7.json para los 9 stacks del modelo multi-repo.
- El repositorio agregador ga_ioci_iac-oci incorpora el set completo de ficheros v3.7 para trazabilidad centralizada.

### Changed - Cambios funcionales aplicados en v3.7

- **Identity (giss_identity_v3.7.json)**:
  - Se habilita allow_signing_cert_public_access: true en COMMON-DOMAIN para coherencia con el dominio desplegado.
- **Network (giss_network_base_v3.7.json)**:
  - Se incorpora fast_connect_virtual_circuits con dos circuitos privados existentes:
    - o-p-om2-fas-connect-001
    - o-p-om2-fas-connect-002
  - Se mantienen mapeos BGP y proveedor (provider_service_id) segun inventario OCI.
- **Obs Logs (giss_obs_logs_v3.7.json)**:
  - Evoluciona de esqueleto a READY_FOR_DEPLOYMENT.
  - Se implementan logging_configuration y service_connectors_configuration para flujo de auditoria a streaming SIEM.
- **Obs Monitor (giss_obs_monitor_v3.7.json)**:
  - Evoluciona de esqueleto a READY_FOR_DEPLOYMENT.
  - Se implementan alarms_configuration, events_configuration y home_region_events_configuration.

### Fixed - Coherencia de metadatos y validacion

- _meta.version actualizado a 3.7 en los archivos v3.7 de stacks con cambios funcionales.
- JSON v3.7 validado sintacticamente (ConvertFrom-Json) en identidad, red, obs-logs y obs-monitor.

### Notes

- Los archivos v3.6 se preservan como baseline restaurada.
- Los ficheros de maqueta v3.6 de observabilidad se ajustaron solo para validez JSON, sin impacto funcional y sin entrada en plan/apply.

---
## [3.6] — 2026-05

> **Split del Terraform monolítico en 9 repositorios independientes con states separados.** Cambio estructural mayor: cada dominio funcional pasa a tener su propio repositorio, su propio state remoto y su propio ciclo de despliegue. La migración se ejecuta mediante **imports declarativos `import {}`** sobre la infraestructura ya existente: **sin recrear, modificar ni destruir nada** en OCI. Tres stacks quedan operativos (foundation, identity, network); seis quedan como esqueletos a implementar en sucesivas iteraciones.

### Changed — Arquitectura del repositorio

- **De monorepo a multi-repo.** El repositorio único `ga/ioci/ga_ioci_iac-oci` se descompone en 9 repositorios independientes, cada uno con su propio state remoto en el backend HTTP de GitLab corporativo:

  | #  | Repositorio GitLab                                  | Contenido                                                | Origen v3.5                                   | Estado     |
  | -- | --------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------- | ---------- |
  | 00 | `ga_ioci0000_iac-oci-foundation`                  | Tag namespaces (TBAC + GOV + ENS) + jerarquía compartments | `giss_governance_v3.5.json` + `iam_v3.5.json` (compartments) | Operativo  |
  | 10 | `ga_ioci0010_iac-oci-identity`                    | Identity Domain + grupos nativos + 18 políticas IAM        | `giss_iam_v3.5.json` (resto)                | Operativo  |
  | 20 | `ga_ioci0020_iac-oci-network`                     | VCN Hub + spokes ExaCS PRO/NPR + DRG + gateways + NFW overlay | `giss_network_hub_b_empty_v3.5.json` + delta NFW | Operativo  |
  | 30 | `ga_ioci0030_iac-oci-security-svc`                | Cloud Guard, VSS, Bastion, Marketplace, WAF              | Nuevo                                         | Esqueleto  |
  | 40 | `ga_ioci0040_iac-oci-exa-infra`                   | Cloud Exadata Infrastructure + scheduling                | Nuevo                                         | Esqueleto  |
  | 41 | `ga_ioci0041_iac-oci-exa-database`                | VM Clusters + DB Homes + Databases + PDBs + Data Safe    | Nuevo                                         | Esqueleto  |
  | 50 | `ga_ioci0050_iac-oci-obs-logs`                    | Log Groups + Service Connector Hub + Streaming a QRadar  | Nuevo                                         | Esqueleto  |
  | 60 | `ga_ioci0060_iac-oci-obs-monitor`                 | Alarms + ONS Topics + conector a monitorización externa  | Nuevo                                         | Esqueleto  |
  | 70 | `ga_ioci0070_iac-oci-storage`                     | Object Storage buckets + FSS + Block Volume groups       | Nuevo                                         | Esqueleto  |

- **Orden de despliegue preservado entre stacks** (campo `deploy_order` en cada `_meta`): 1 foundation → 2 identity → 3 network → 4 security-svc / storage → 5 exa-infra / obs-logs / obs-monitor → 6 exa-database.

### Added — Patrón de External Dependencies del orquestador

- Se adopta el patrón oficial de **External Dependencies** del [OCI Landing Zones Orchestrator](https://github.com/oci-landing-zones/terraform-oci-modules-orchestrator#external-dependencies) para resolver la dependencia entre stacks sin compartir state.
- El stack `foundation` genera, mediante `output_path: "./dependencies"`, los ficheros:
  ```text
  dependencies/compartments_output.json
  dependencies/tags_output.json
  ```
- Los stacks dependientes (`identity`, `network`, …) consumen un wrapper:
  ```text
  dependencies/foundation_dependencies.auto.tfvars.json
  ```
  que envuelve los outputs en las claves `compartments_dependency.compartments` y `tags_dependency.tags` esperadas por el orquestador.

### Added — Migración mediante imports declarativos

- Se sustituye `terraform import` imperativo por **bloques `import {}` declarativos** generados por script PowerShell, porque el orquestador evalúa módulos completos y puede fallar con states parcialmente importados.
- Versiones del generador validadas por stack (no sustituir versiones consolidadas):

  | Stack       | Script                                              |
  | ----------- | --------------------------------------------------- |
  | Foundation  | `Generate-OrchestratorImportBlocks-v3.0.ps1`      |
  | Identity    | `Generate-OrchestratorImportBlocks-v3.1.ps1`      |
  | Network     | `Generate-OrchestratorImportBlocks-v3.2.7.ps1`    |

- La versión `v3.2.7` incorpora soporte completo para recursos `oci_core_*` / `oci_core_drg_*` y los flags `-NoPrecheck` / `-SkipMissing`.
- Regla de seguridad aplicada en todo el procedimiento: `N to import, 0 to add, 0 to change, 0 to destroy` (con excepción documentada de 2 add en Network — ver más abajo).

### Added — Nuevos ficheros de configuración v3.6

- `giss_foundation_v3.6.json` — refactor de v3.5 governance + compartments.
- `giss_identity_v3.6.json` — refactor del resto de IAM de v3.5.
- `giss_network_base_v3.6.json` — refactor de `giss_network_hub_b_empty_v3.5.json`.
- `giss_network_nfw_addon_v3.6.json` — **overlay opcional**. `file_role: OVERLAY_NFW`, `status: REFERENCE_ONLY_NOT_DEPLOYED`. Mantiene la política NFW (`o-p-om2-nfw-policy-001`) y la instancia (`o-p-om2-nfw-hub-001`) como referencia tras la decisión de v3.4. Reactivación requiere rediseño de routing east-west, política NFW con reglas L7 reales y validación de coste con CSM Oracle.
- Esqueletos `_meta`-only con `status: SKELETON_PENDING_IMPLEMENTATION` y `todo_resources` documentado para:
  - `giss_security_services_v3.6.json` (Cloud Guard, VSS, Bastion, Marketplace, WAF)
  - `giss_exa_infra_v3.6.json` (CEI, scheduling policies/windows)
  - `giss_exa_database_v3.6.json` (VM Clusters, DB Homes, Databases, PDBs, backups, Data Safe)
  - `giss_obs_logs_v3.6.json` (Log Groups, Service Connector Hub, Streaming a QRadar)
  - `giss_obs_monitor_v3.6.json` (Alarms, ONS Topics, conector externo)
  - `giss_storage_v3.6.json` (Object Storage, FSS, Block Volume groups)

### Fixed — `giss_foundation_v3.6.json`

- **`compartments_configuration.enable_delete`**: `"true"` → `"false"`.
  El valor anterior provocaba drift durante el import:
  ```text
  Plan: 39 to import, 0 to add, 20 to change, 0 to destroy
  ```
  Los 20 cambios correspondían al atributo `enable_delete` en cada compartment. Resultado esperado tras la corrección:
  ```text
  Plan: 39 to import, 0 to add, 0 to change, 0 to destroy
  ```
  Beneficio colateral: previene `destroy` accidental de compartments.

### Added — `giss_foundation_v3.6.json`

- Campo `output_path: "./dependencies"` para que el orquestador escriba directamente los outputs consumidos por stacks downstream.

### Resultado final validado (POC)

- Imports ejecutados sin drift en los 3 stacks operativos:
  ```text
  Foundation:  39 recursos importados — 0 add, 0 change, 0 destroy
  Identity:    27 recursos importados — 0 add, 0 change, 0 destroy
  Network:     56 recursos importados — 2 add, 0 change, 0 destroy
  ```
- Los **2 add de Network** corresponden a recursos `local_file` y `time_sleep` generados por el propio orquestador (escritura de outputs y sincronización). **No tienen impacto en OCI.**
- Validación final de drift en los 3 stacks:
  ```text
  Foundation → terraform plan: No changes. Your infrastructure matches the configuration.
  Identity   → terraform plan: No changes. Your infrastructure matches the configuration.
  Network    → terraform plan: No changes. Your infrastructure matches the configuration.
  ```

### Warnings residuales aceptados (upstream Oracle)

| Stack    | Warning                                                | Impacto                                                         | Decisión                          |
| -------- | ------------------------------------------------------ | --------------------------------------------------------------- | --------------------------------- |
| Identity | `Deprecated resource attribute "ETag"`                | Sin drift, sin recreación, sin cambios pendientes               | Aceptado hasta corrección upstream |
| Network  | `Deprecated resource attribute "route_rules[...].cidr_block"` | Sin drift, sin recreación, sin cambios pendientes               | Aceptado hasta corrección upstream |

No modificar `.terraform/modules/` ni módulos descargados.

### Changed — Versiones de herramientas

- Terraform: `1.14.7` → `1.15.x`
- OCI CLI: `3.76.0` → `3.81.x`
- PowerShell: `Windows PowerShell 5.x` → `PowerShell 7.6.x` (el procedimiento de import se validó en PS 7.x; los pasos de setup workstation siguen siendo compatibles con ambos).
- Provider `oracle/oci`: `~> 8.5.0` (sin cambio).

### Known Issues (heredados de v3.5, sin resolver en v3.6)

- `o-p-om2-sl-exacs-probkc-001` — typo en nombre del Security List backup ExaCS PRO (`probkc` en lugar de `probck`). Corregir en próxima versión del stack `20-network` con rename.
- `o-p-om2-drgrt-hub-001b` — trailing `b` residual en nombre de DRG route table Hub.
- Descripción de `PCY-NETWORK-ADMIN-KEY` aún referencia el grupo antiguo `o-p-om2-grp-neta-001` (solo cosmético; los statements son correctos desde v3.4).
- Tags con valores pendientes marcados como `__FILL__` siguen presentes en los ficheros migrados. Buscar globalmente `__FILL__` antes del `terraform apply` en cada stack.
- `PCY-COST-ADMIN-KEY` y `PCY-BILLING-VIEWER-KEY` contienen OCID literal del tenancy `usage-report`. Considerar parametrización vía variable del stack en versión futura.

---

## [3.5] — 2026-04-20

> **Estrategia de tagging corporativo.** Cambio exclusivamente aditivo: no se ha eliminado ni modificado ningún valor existente. Todo el contenido desplegado permanece intacto.

### Added — `giss_governance_v3.5.json`

- **Namespace `o-p-om2-tagns-gov-001`** — Governance operativa y control de costes. 10 tag keys nuevas, alineadas con la estrategia de tagging corporativo de GISS aplicada en AWS y GCP:

  | Tag OCI                  | `is_cost_tracking` | Validación                                                                                      |
  | ------------------------ | -------------------- | ------------------------------------------------------------------------------------------------ |
  | `technical-owner`      | `false`            | Libre (correo corporativo)                                                                       |
  | `operational-owner`    | `false`            | Libre (correo corporativo)                                                                       |
  | `department`           | **`true`**   | Libre                                                                                            |
  | `cost-center`          | **`true`**   | Libre                                                                                            |
  | `application-code`     | **`true`**   | Libre                                                                                            |
  | `application-name`     | `false`            | Libre                                                                                            |
  | `name`                 | **`true`**   | Libre — se iguala al `display_name` del recurso para control de costes por recurso individual |
  | `environment`          | **`true`**   | ENUM:`dev`, `pre`, `pro`, `int`, `qa`, `cer`                                         |
  | `iac`                  | `false`            | ENUM:`terraform`, `manual`, `cli`                                                          |
  | `business-criticality` | `false`            | ENUM:`critico`, `alto`, `medio`, `bajo`                                                  |

- **Namespace `o-p-om2-tagns-ens-001`** — Clasificación ENS (Esquema Nacional de Seguridad).
  5 tag keys nuevas, todas con validador ENUM `alto` / `medio` / `bajo`:

  | Tag OCI                 | Dimensión ENS   |
  | ----------------------- | ---------------- |
  | `ens-authenticity`    | Autenticidad     |
  | `ens-integrity`       | Integridad       |
  | `ens-availability`    | Disponibilidad   |
  | `ens-confidentiality` | Confidencialidad |
  | `ens-traceability`    | Trazabilidad     |

### Added — `giss_iam_v3.5.json`

- **`defined_tags` GOV + ENS** aplicados a los 20 compartimentos de la jerarquía.
  Los compartimentos con prefijo `o-p-` reciben `environment = pro`; los `o-d-` reciben `environment = dev`.
  Los compartimentos que ya tenían `defined_tags` TBAC los conservan intactos.
- **`PCY-GENERIC-ADMIN-KEY`** — 2 statements adicionales para inspección de los nuevos namespaces durante `plan`/`apply`:

  ```
  allow any-user to inspect tag-namespaces in tenancy where target.tag-namespace.name='o-p-om2-tagns-gov-001'
  allow any-user to inspect tag-namespaces in tenancy where target.tag-namespace.name='o-p-om2-tagns-ens-001'
  ```

### Added — `giss_network_hub_b_empty_v3.5.json`

- **`defined_tags` GOV + ENS** aplicados a todos los recursos de red con soporte nativo en OCI: VCNs, Subnets, Route Tables, Security Lists, NSGs, NAT Gateway, Service Gateways, DRG.
  - 16 recursos Hub (`environment = pro`)
  - 8 recursos ExaCS PRO (`environment = pro`)
  - 8 recursos ExaCS NPR (`environment = dev`)

### Added — `giss_network_hub_b_firewall_v3.5.json`

- Idéntico al `_empty` en recursos de red. Adicionalmente:
  - `defined_tags` GOV + ENS en NFW Policy `o-p-om2-nfw-policy-001` (`environment = pro`)
  - `defined_tags` GOV + ENS en NFW Instance `o-p-om2-nfw-hub-001` (`environment = pro`)

### Notes

- Tags con valores pendientes marcados como `__FILL__`: 240 en IAM, 384 en network empty, 408 en network firewall. Buscar globalmente `__FILL__` antes del `terraform apply`.
- Tags resueltos automáticamente sin intervención manual: `iac = terraform`, `environment` (derivado del prefijo del nombre), `name` (igual al `display_name`).
- **Orden de despliegue recomendado:** governance → IAM → network. Los namespaces deben existir antes de que Terraform asigne `defined_tags` en recursos downstream.

### Known Issues (heredados, sin resolver en esta versión)

- `o-p-om2-sl-exacs-probkc-001` — typo en nombre del Security List backup ExaCS PRO (`probkc` en lugar de `probck`). Corregir en próxima versión con rename.
- `o-p-om2-drgrt-hub-001b` — trailing `b` residual en nombre de DRG route table Hub.
- Descripción de `PCY-NETWORK-ADMIN-KEY` aún referencia el grupo antiguo `o-p-om2-grp-neta-001` (solo cosmético; los statements son correctos desde v3.4).

---

## [3.4] — 2026-03

> **Federación Microsoft Entra ID completada.** Políticas actualizadas para doble autorización (grupo nativo OCI + grupo federado `99GISS.*`). Nuevas políticas para roles post-federación. El firewall se retira del despliegue activo por decisión de costes; el fichero `_firewall` se mantiene actualizado en paralelo.

### Fixed — `giss_iam_v3.4.json`

- **Corrección definitiva de grupos inexistentes en políticas** (error arrastrado desde v3.2 sin corregir en v3.3):

  - `PCY-GENERIC-ADMIN-KEY`: `o-p-om2-grp-seca-001` → `o-p-om2-grp-admi-security-001`
  - `PCY-GENERIC-ADMIN-KEY`: `o-p-om2-grp-neta-001` → `o-p-om2-grp-admi-network-001`
  - `PCY-NETWORK-ADMIN-KEY` (26 statements): `o-p-om2-grp-neta-001` → `o-p-om2-grp-admi-network-001`
- **`PCY-LZ-PLATFORM-EXACS-GENERIC-ADMIN-KEY`** — eliminados 2 statements duplicados (`manage alarms` y `manage metrics` aparecían dos veces).
- **`PCY-COST-ADMIN-KEY`** — OCID del tenancy `usage-report` actualizado al valor correcto del tenancy GISS.

### Changed — `giss_iam_v3.4.json`

- **Integración de grupos federados Entra ID** en políticas existentes (doble autorización nativo + federado):

  | Política                                   | Grupo nativo OCI                                  | Grupo federado añadido           |
  | ------------------------------------------- | ------------------------------------------------- | --------------------------------- |
  | `PCY-GENERIC-ADMIN-KEY`                   | `o-p-om2-grp-admi-security-001`                 | `99GISS.Cloud_Security_admin`   |
  | `PCY-GENERIC-ADMIN-KEY`                   | `o-p-om2-grp-admi-network-001`                  | `99GISS.Cloud_Networking_admin` |
  | `PCY-NETWORK-ADMIN-KEY`                   | `o-p-om2-grp-admi-network-001`                  | `99GISS.Cloud_Networking_admin` |
  | `PCY-SECURITY-ADMIN-KEY`                  | `o-p-om2-grp-admi-security-001`                 | `99GISS.Cloud_Security_admin`   |
  | `PCY-LZ-PLATFORM-EXACS-GENERIC-ADMIN-KEY` | `o-p-om2-grp-admi-infra-001` + `database-001` | `99GISS.Cloud_DB_admin`         |
  | `PCY-LZ-PLATFORM-EXACS-DB-ADMIN-KEY`      | `o-p-om2-grp-admi-database-001`                 | `99GISS.Cloud_DB_admin`         |

- **`PCY-COST-ADMIN-KEY`** — grupos con acceso a usage-report ampliados: añadidos `Administrators`, `99GISS.Cloud_Billing_admin` y `99GISS.ORACLE_Administradores`.

### Added — `giss_iam_v3.4.json`

- **7 nuevas políticas** para roles de acceso federado post-federación Entra ID:

  | Nombre OCI                      | Clave                         | Grupo(s)                                                               | Alcance                                                |
  | ------------------------------- | ----------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------ |
  | `o-p-om2-pcy-tenantadmin-001` | `PCY-TENANCY-ADMIN-001-KEY` | `99GISS.ORACLE_Administradores`, `Cloud_Admin`, `Cloud_DB_admin` | `manage all-resources in tenancy`                    |
  | `o-p-om2-pcy-billv-001`       | `PCY-BILLING-VIEWER-KEY`    | `99GISS.Cloud_Billing_viewer`                                        | `read usage-budgets/reports in tenancy`              |
  | `o-p-om2-pcy-viewer-001`      | `PCY-VIEWER-KEY`            | `99GISS.Cloud_Viewer`                                                | `inspect all-resources in tenancy`                   |
  | `o-p-om2-pcy-monit-001`       | `PCY-MONITORING-KEY`        | `99GISS.Cloud_Monitoring_admin`                                      | metrics, alarms, logging, serviceconnectors, ons en LZ |
  | `o-p-om2-pcy-stora-001`       | `PCY-STORAGE-KEY`           | `99GISS.Cloud_Storage_admin`                                         | object/file/block storage en LZ (sin delete)           |
  | `o-p-om2-pcy-osadm-001`       | `PCY-OS-ADMIN-KEY`          | `99GISS.Cloud_OS_admin`                                              | instance-family, volumes, agent en LZ                  |
  | `o-p-om2-pcy-mktpl-001`       | `PCY-MARKETPLACE-KEY`       | `99GISS.Cloud_MarketplaceSuscriber`                                  | app-catalog-listing/subscriptions en tenancy           |

### Changed — `giss_network_hub_b_firewall_v3.4.json`

- Fichero mantenido actualizado en paralelo. **OCI Network Firewall retirado del despliegue activo** por decisión de optimización de costes. El despliegue activo continúa con `giss_network_hub_b_empty`.

### Style — `giss_iam_v3.4.json`

- Reformateado completo del JSON: eliminado el alineado con espacios en todas las claves (sin impacto funcional).

---

## [3.3] — 2026-02

> **Corrección de nomenclatura y CIDRs.** Primera prueba de OCI Network Firewall (fichero `_firewall` introducido).

### Fixed — `giss_iam_v3.3.json`

- **Prefijo de entorno corregido** en 5 compartimentos CDINSS Non-Production: `o-np-om2-` → `o-d-om2-`, alineando con la convención de nomenclatura `{env}-{tier}-{region}-{tipo}-{nombre}-{seq}`:
  - `o-d-om2-cmp-cdin-001`
  - `o-d-om2-cmp-cdin-network-001`
  - `o-d-om2-cmp-cdin-platform-001`
  - `o-d-om2-cmp-cdin-projects-001`
  - `o-d-om2-cmp-cdin-security-001`

### Fixed — `giss_network_hub_b_empty_v3.3.json`

- **13 CIDRs de template reemplazados por CIDRs reales GISS** en Security Lists y NSGs:

  - `10.0.0.0/21` → `10.197.128.0/23` (Hub CIDR real) en ICMP ingress rules de Hub MGMT, ExaCS PRO CLI/BCK, ExaCS NPR CLI/BCK.
  - `10.0.2.123/32` (regla Bastion marcada como `EXAMPLE:`) → `10.197.128.32/27` (subred de gestión Hub real).
  - `10.0.0.0/24` (IPs de template LB en NSG Hub FW) → `10.197.128.0/27` (subred FW Hub real).
- **8 recursos ExaCS NPR renombrados**: prefijo `o-np-` → `o-d-` en VCN, Subnets, Route Tables, Security Lists y Service Gateway NPR.

### Added — `giss_network_hub_b_firewall_v3.3.json` *(fichero nuevo)*

- Primera versión del fichero de configuración con OCI Network Firewall para pruebas. Política inicial `o-p-om2-nfw-policy-001` con:
  - Servicios TCP: HTTP (80) y HTTPS (443).
  - Aplicación ICMP: echo (type 8, code 0).
  - 4 address lists: público (`0.0.0.0/0`), PRO (`10.197.132.0/23`), NPR (`10.197.134.0/23`), spokes (ambas).
  - 2 URL lists: `*.oracle.com` y `*.google.com`.
  - 1 security rule `o-p-om2-nfw-alloweastwest-001`: ALLOW spoke→spoke (inspección este-oeste).
  - Instancia NFW: `o-p-om2-nfw-hub-001`, IP fija `10.197.128.10`, subred FW Hub.

### Known Issues (presentes desde v3.2, sin resolver en v3.3)

- `o-p-om2-sl-exacs-probkc-001` — typo en nombre Security List backup ExaCS PRO (`bkc` en lugar de `bck`).
- `o-p-om2-drgrt-hub-001b` — trailing `b` en nombre de DRG route table Hub.
- DRG attachments de ExaCS PRO y NPR sin `drg_route_table_key` asignada.
- `PCY-GENERIC-ADMIN-KEY` y `PCY-NETWORK-ADMIN-KEY` — grupos `seca-001` / `neta-001` (inexistentes) aún presentes; corrección diferida a v3.4.

---

## [3.2] — 2026-02

> **Despliegue inicial con Oracle Support.** Baseline de la Landing Zone sin firewall. Varios errores de nomenclatura identificados en el proceso de despliegue.

### Added — `giss_governance_v3.2.json`

- Namespace de tags `o-p-om2-tagns-name-001` con tag key `o-p-om2-tag-role-001` para TBAC (Tag-Based Access Control) de roles IAM. `is_cost_tracking: false`.

### Added — `giss_iam_v3.2.json`

- Identity Domain `o-p-om2-id-common-001` (`license_type: free`). Default Domain reservado para cuentas break-glass.
- 8 grupos de administración en el domain común: `auditors`, `costs`, `iam`, `network`, `security`, `globalserv`, `infra`, `database`.
- Jerarquía de compartimentos bajo `o-p-om2-cmp-land-001`:
  - Shared: `network`, `platform` (con hijos `exacs`, `exacsdb`, `exacsinfra`, `logg`, `devop`), `security`.
  - CDINSS: `cdin-core-001` con entornos PRO (`o-p-om2-cmp-cdin-*`) y NPR (`o-np-om2-cmp-cdin-*` ⚠️).
- 9 políticas IAM: auditing, costs, generic, iam, network-admin, security-admin, globalserv, services, exacs-generic, exacs-db, exacs-infra.
- TBAC habilitado en compartimentos: `network-001`, `exacs-001`, `exacsdb-001`, `exacsinfra-001`, `security-001`, `cdin-network-001`, `cdin-security-001`.

### Added — `giss_network_hub_b_empty_v3.2.json`

- Topología hub-and-spoke completamente privada (sin Internet Gateway):
  - **VCN Hub** `o-p-om2-vcn-hub-001` (`10.197.128.0/23`) con 4 subredes `/27`: FW, MGMT, MON, DNS.
  - **VCN ExaCS PRO** `o-p-om2-vcn-exacspro-001` (`10.197.132.0/23`) con subredes Client y Backup.
  - **VCN ExaCS NPR** `o-np-om2-vcn-exacsnpr-001` (`10.197.134.0/23`) con subredes Client y Backup ⚠️.
- DRG `o-p-om2-drg-hub-001` con attachments a las 3 VCNs y ruta estática spoke→hub.
- Gateways: NAT GW y Service GW en Hub; Service GW en ExaCS PRO y NPR.
- Security Lists con reglas ICMP y egress total. NSGs en Hub (LB y FW).

---


