# OCI Landing Zone GISS — División por dominios v3.6

Este paquete contiene la **refactorización organizativa** de los ficheros de configuración Terraform de la Landing Zone GISS, en respuesta a la solicitud interna de  **separar la operación según departamento y responsable funcional** .

A partir de los ficheros monolíticos v3.5, gestionados hasta ahora desde un único repositorio con un único state Terraform, se ha generado una  **división en 9 unidades funcionales independientes** , cada una alineada con un equipo responsable de GISS.

---

## 1. Solicitud de origen

El requisito formulado por GISS fue separar la configuración Terraform en los siguientes bloques operativos:

| Bloque solicitado por GISS                                                        | Naturaleza                                      |
| --------------------------------------------------------------------------------- | ----------------------------------------------- |
| Parte de **organización**(foundation)                                             | Estructura de compartments + estrategia de tags |
| Parte de **seguridad**→ identidad, permisos, etc.                                 | Identity Domain, grupos, políticas IAM          |
| Parte de **red**                                                                  | VCN, DRG, subnets, gateways, routing            |
| Parte de **Exadata**                                                              | Cloud Exadata Infrastructure + bases de datos   |
| **Políticas de seguridad** , Marketplace, CloudGuard                              | Servicios de seguridad activos                  |
| **Logs de la plataforma** , integración Cloud, integración on-prem QRadar         | Logging y SIEM                                  |
| **Monitorización** → enviada a terceros                                           | Métricas y alarmas                              |
| **Almacenamiento** → buckets, etc.                                               | Object Storage, FSS, Block Volume                |

---

## 2. Mapeo solicitud → repositorios

Cada bloque solicitado se materializa en uno o varios repositorios. Solo un caso ha requerido desdoblamiento (Exadata), explicado más abajo.

| Bloque GISS                                   | Repositorio(s) destino      | Equipo responsable           | Origen v3.5                                |
| --------------------------------------------- | --------------------------- | ---------------------------- | ------------------------------------------ |
| Organización (foundation)                     | `00-iac-oci-foundation`     | Cloud IAM admin + Governance | `giss_governance`+`compartments`de IAM     |
| Seguridad: identidad y permisos               | `10-iac-oci-identity`       | Cloud IAM admin              | resto de `giss_iam`                        |
| Red                                           | `20-iac-oci-network`        | Cloud Networking admin       | `giss_network_hub_b_empty`+ delta NFW      |
| Exadata (infraestructura física)              | `40-iac-oci-exa-infra`      | Cloud Infra admin            | nuevo                                      |
| Exadata (bases de datos)                      | `41-iac-oci-exa-database`   | Cloud DB admin               | nuevo                                      |
| Políticas seguridad, Marketplace, CloudGuard  | `30-iac-oci-security-svc`   | Cloud Security admin         | nuevo                                      |
| Logs + integración QRadar                     | `50-iac-oci-obs-logs`       | Cloud Security / SOC         | nuevo                                      |
| Monitorización a terceros                     | `60-iac-oci-obs-monitor`    | Cloud Monitoring admin       | nuevo                                      |
| Almacenamiento                                | `70-iac-oci-storage`        | Cloud Storage admin          | nuevo                                      |

### Por qué Exadata se desdobla en `40` + `41`

Aunque GISS lo formuló como un único bloque, la separación en dos repositorios responde a las políticas IAM ya implementadas en v3.4:

* **`PCY-LZ-PLATFORM-EXACS-INFRA-ADMIN-KEY`** autoriza al grupo `grp-admi-infra-001` con TBAC sobre el tag `o-p-om2-tag-role-exainfra-001`. Este equipo gestiona la infraestructura física Exadata (capacidad reservada, OCPUs, scheduling de patching).
* **`PCY-LZ-PLATFORM-EXACS-DB-ADMIN-KEY`** autoriza al grupo `grp-admi-database-001` con TBAC sobre el tag `o-p-om2-tag-role-exadb-001`. Este equipo gestiona VM clusters, DB homes, databases y PDBs.

Si se mantuviese un solo repositorio Exadata,  **un DBA con permisos para crear una nueva PDB también podría disparar `terraform apply` sobre la infraestructura física** , cosa que las políticas TBAC ya impiden a nivel OCI. Mantener el aislamiento también a nivel de quién ejecuta Terraform conserva esa disciplina.

---

## 3. Estructura

| #  | Carpeta                      | Repositorio destino      | Origen v3.5               | Estado                        |
| -- | ---------------------------- | ------------------------ | ------------------------- | ----------------------------- |
| 00 | `00-iac-oci-foundation/`     | `iac-oci-foundation`     | governance + compartments | Listo (refactor de existente) |
| 10 | `10-iac-oci-identity/`       | `iac-oci-identity`       | resto de IAM              | Listo (refactor de existente) |
| 20 | `20-iac-oci-network/`        | `iac-oci-network`        | network empty + delta NFW | Listo (refactor de existente) |
| 30 | `30-iac-oci-security-svc/`   | `iac-oci-security-svc`   | nuevo                     | Esqueleto                     |
| 40 | `40-iac-oci-exa-infra/`      | `iac-oci-exa-infra`      | nuevo                     | Esqueleto                     |
| 41 | `41-iac-oci-exa-database/`   | `iac-oci-exa-database`   | nuevo                     | Esqueleto                     |
| 50 | `50-iac-oci-obs-logs/`       | `iac-oci-obs-logs`       | nuevo                     | Esqueleto                     |
| 60 | `60-iac-oci-obs-monitor/`    | `iac-oci-obs-monitor`    | nuevo                     | Esqueleto                     |
| 70 | `70-iac-oci-storage/`        | `iac-oci-storage`        | nuevo                     | Esqueleto                     |

```
ga_ioci_iac-oci/
│
│   README.md
│
├── 00-iac-oci-foundation/        ← organización: tags + compartments -> (refactor de existente)
│       giss_foundation_v3.6.json
│
├── 10-iac-oci-identity/          ← seguridad (identidad y permisos) -> (refactor de existente)
│       giss_identity_v3.6.json
│
├── 20-iac-oci-network/           ← red (incluye NFW como overlay) -> (refactor de existente)
│       giss_network_base_v3.6.json
│       giss_network_nfw_addon_v3.6.json
│
├── 30-iac-oci-security-svc/      ← políticas seguridad, Marketplace, CloudGuard -> (Esqueleto vacío)
│       giss_security_services_v3.6.json
│
├── 40-iac-oci-exa-infra/         ← Exadata: infraestructura física -> (Esqueleto vacío)
│       giss_exa_infra_v3.6.json
│ 
├── 41-iac-oci-exa-database/      ← Exadata: capa de bases de datos -> (Esqueleto vacío)
│       giss_exa_database_v3.6.json
│
├── 50-iac-oci-obs-logs/          ← logs + integración QRadar on-prem -> (Esqueleto vacío)
│       giss_obs_logs_v3.6.json
│ 
├── 60-iac-oci-obs-monitor/       ← monitorización a terceros -> (Esqueleto vacío)
│       giss_obs_monitor_v3.6.json
│
└── 70-iac-oci-storage/           ← almacenamiento (buckets, FSS, BV) -> (Esqueleto vacío)
        giss_storage_v3.6.json

```
---

## 4. Dependencias y orden de despliegue

Los repositorios se organizan en cinco capas según sus dependencias. Ningún repositorio puede aplicarse antes de que sus dependencias inferiores estén operativas.

| Capa | Repositorios                                          | Depende de     |
| ---- | ----------------------------------------------------- | -------------- |
| 0    | `00-foundation`                                       | —              |
| 1    | `10-identity`,`70-storage`                            | 00             |
| 2    | `20-network`,`30-security-svc`,`60-obs-monitor`       | 00, 10         |
| 3    | `40-exa-infra`,`50-obs-logs`                          | 00, 10, 20     |
| 4    | `41-exa-database`                                     | 00, 10, 20, 40 |

El orden topológico es estricto: el grafo es una DAG sin ciclos.

---

## 5. Convenciones aplicadas

### Bloque `_meta` en cada fichero

Todo fichero JSON entregado lleva un bloque `_meta` al inicio que documenta:

* **`repository`** : nombre del repositorio destino
* **`stack_id`** : identificador numérico (00–70)
* **`responsible_team`** : equipo Entra ID/OCI responsable
* **`depends_on`** : lista de stacks de los que depende
* **`deploy_order`** : orden topológico de despliegue
* **`source_v3_5`** : trazabilidad exacta del origen
* **`todo_resources`** (en esqueletos): recursos OCI pendientes de implementar
* **`iam_dependencies`** : políticas IAM ya existentes que autorizan al equipo
* **`integration_notes`** : observaciones técnicas relevantes

Este bloque es ignorado por Terraform (genera un warning informativo silenciable con `-compact-warnings`) y sirve exclusivamente como metadato documental embebido en el propio fichero.

### Comunicación entre repositorios

Los repositorios consumidores referencian recursos producidos por otros mediante  **data sources OCI por nombre o tag** , aprovechando la rigurosa convención de naming GISS (prefijos `o-p-`, `o-d-`, sufijos por tipología y secuencia).

Esto significa que:

* Cada repositorio mantiene su Terraform state aislado.
* Ningún equipo necesita acceso al state de otro repositorio.
* La convención de naming actúa como contrato auto-documentado entre stacks.

### Tagging GOV+ENS preservado

El esquema de tagging triple implantado en v3.5 (TBAC + governance + ENS, 16 tag keys en total) se preserva íntegramente y se centraliza en `00-foundation`. Los `defined_tags` aplicados a cada recurso viajan junto al recurso al repositorio destino, sin alteración.

### Federación Entra ID preservada

La doble autorización nativa OCI + grupos federados Entra ID `99GISS.*` introducida en v3.4 se mantiene en todas las políticas del repositorio `10-identity`, sin cambios.

---

## 6. Validación realizada sobre la división

Antes de la entrega se ha ejecutado una  **doble verificación de integridad** :

### 6.1. Auditoría estructural

Diff recursivo profundo de los 4 ficheros v3.5 originales contra el conjunto v3.6 reconstituido:

* 0 pérdidas
* 0 invenciones (más allá de los `_meta` documentales)
* 0 transformaciones de valor
* 0 tipos no coincidentes

### 6.2. Plan operativo

Ejecución de `terraform plan` sobre el state real desplegado en OCI utilizando los nuevos JSON v3.6:

```
No changes. Your infrastructure matches the configuration.
Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```

Sin errores, sin warnings, sin drift. La división v3.6 produce el mismo grafo de recursos que la configuración v3.5 ya aplicada.

---

## 7. Lo que NO se ha tocado

La división es  **estrictamente reorganizativa** . Ningún valor se ha modificado.

* Los placeholders `__FILL__` se mantienen tal cual estaban en v3.5. Resolverlos sigue siendo responsabilidad del equipo de cada dominio antes del primer `terraform apply` de su repositorio.
* Los **issues conocidos heredados** no se corrigen en este split y quedan como primera tarea de cada repositorio:
  * Typo `probkc` (debería ser `probck`) en `o-p-om2-sl-exacs-probkc-001` → repositorio `20-network`
  * Trailing `b` residual en `o-p-om2-drgrt-hub-001b` → repositorio `20-network`
  * Descripción de `PCY-NETWORK-ADMIN-KEY` referencia el grupo antiguo `o-p-om2-grp-neta-001` → repositorio `10-identity`
* El fichero **NFW** (`giss_network_nfw_addon_v3.6.json`) está marcado como `REFERENCE_ONLY_NOT_DEPLOYED`, coherente con la decisión de v3.4 de retirarlo del despliegue activo por optimización de costes. Su reactivación requiere rediseño del routing east-west, política con reglas L7 reales y validación de coste con Oracle CSM.
