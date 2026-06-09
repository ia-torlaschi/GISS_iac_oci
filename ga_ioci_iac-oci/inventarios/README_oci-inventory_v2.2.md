# OCI Inventory v2.2 — Inventario Jerárquico de Oracle Cloud Infrastructure

Script PowerShell que genera un inventario completo de todos los recursos de un tenant OCI,
con enriquecimiento de metadatos por tipo y salida HTML interactiva con árbol jerárquico desplegable.

---

## Novedades respecto a v2.1

| Aspecto | v2.1 | v2.2 |
|---|---|---|
| Salida HTML | Tabla plana por tipo de recurso | **Árbol jerárquico desplegable** que refleja la topología real del tenant |
| Estructura | Lista | Tenant → IAM → Compartment (recursivo) → Networking / Compute / DB / Almacenamiento / Seguridad / Governance |
| Búsqueda | — | Búsqueda interactiva en tiempo real sobre el árbol |
| Estilos | — | Paleta de marca Accenture (purple `#A100FF`) con badges de estado coloreados |
| Resto de salidas (JSON / CSV / ASCII) | — | **Idénticas a v2.1** |

---

## Suplemento de cobertura (fase 2b)

El inventario base se obtiene de `search resource structured-search` (`query all resources`),
que es rápido y multi-región pero **no indexa de forma fiable varios tipos de recurso**
críticos para cumplimiento (ENS / **CCN-STIC-889A/889B**). Para cerrar ese hueco, el script
ejecuta una **fase de suplemento** que descubre esos tipos vía sus APIs dedicadas y los
**fusiona en el inventario** con el mismo esquema de campos que la búsqueda global, de modo
que aparecen automáticamente en **todas** las salidas (JSON, CSV, ASCII y árbol HTML).

| Tipo añadido | Servicio OCI | API usada | Ámbito | Control ENS asociado |
|---|---|---|---|---|
| `Bucket` | Object Storage | `os bucket list` | por compartment | mp.info.9 / op.exp.10 |
| `LogGroup` (+ `logs`) | Logging | `logging log-group list` | subtree | op.exp.8 / op.exp.10 |
| `ServiceConnector` | Service Connector Hub | `sch service-connector list` | por compartment | op.exp.8/10 |
| `OnsTopic` (+ subs.) | Notifications | `ons topic list` | por compartment | op.mon.2 / mp.s.1 |
| `EventRule` | Events | `events rule list` | por compartment | op.exp.7 |
| `Alarm` | Monitoring | `monitoring alarm list` | subtree | op.mon.2 |
| `Budget` | Budgets | `budgets budget budget list` | tenancy | governance / costes |
| `NetworkFirewall` | Network Firewall | `network-firewall network-firewall list` | por compartment | mp.com.1 |
| `NetworkFirewallPolicy` | Network Firewall | `network-firewall network-firewall-policy list` | por compartment | mp.com.1 |

- Los recursos suplementados se marcan con el campo `_source = supplement` (los de la
  búsqueda global no llevan ese campo).
- La deduplicación es por OCID: si la búsqueda global ya devolvió un recurso, **no** se
  duplica.
- Se respetan `-IncludeTypes` / `-ExcludeTypes` también en esta fase.

---

## Requisitos previos

- **PowerShell 5.1** o superior (Windows PowerShell o PowerShell Core).
- **OCI CLI** instalado y configurado con un perfil válido (`DEFAULT` o variable de entorno `OCI_CLI_PROFILE`).
- Permisos IAM suficientes sobre el tenant:
  - `INSPECT` / `READ` sobre todos los tipos de recurso que se deseen inventariar.
  - Acceso a `search resource structured-search` (permiso `search-resources`).

---

## Parámetros

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `-Limit` | `int` | `1000` | Tamaño de página para la búsqueda global paginada. |
| `-IncludeTypes` | `string[]` | `@()` (todos) | Lista de tipos de recurso a enriquecer (p. ej. `instance`, `vcn`, `dbsystem`). Si se omite, se procesan todos los tipos soportados. |
| `-ExcludeTypes` | `string[]` | `@()` | Lista de tipos a excluir del enrichment. |
| `-NoEnrich` | `switch` | — | Omite el enrichment; genera únicamente el inventario "wide" sin llamadas adicionales a la API. |
| `-Html` | `switch` | — | Genera el reporte HTML con árbol jerárquico interactivo. |
| `-MaxConcurrent` | `int` | `1` | Reservado para futura paralelización (sin efecto en v2.2). |
| `-NoSupplement` | `switch` | — | Desactiva la fase de suplemento (ver sección "Suplemento de cobertura"). Con esta opción el comportamiento es idéntico al original (solo búsqueda global). |
| `-SupplementHomeRegionOnly` | `switch` | — | Limita el suplemento a la región por defecto del perfil. Sin él, el suplemento barre **todas las regiones suscritas** (paridad con la búsqueda global). |

---

## Uso

### Inventario completo con HTML

```powershell
.\oci-inventory_v2.2.ps1 -Html
```

### Solo tipos críticos con HTML

```powershell
.\oci-inventory_v2.2.ps1 -IncludeTypes instance,vcn,subnet,dbsystem -Html
```

### Inventario rápido sin enrichment (solo búsqueda global)

```powershell
.\oci-inventory_v2.2.ps1 -NoEnrich
```

### Excluir volúmenes y buckets del enrichment

```powershell
.\oci-inventory_v2.2.ps1 -ExcludeTypes volume,bootvolume,bucket -Html
```

### Inventario sin suplemento (comportamiento original v2.2)

```powershell
.\oci-inventory_v2.2.ps1 -Html -NoSupplement
```

### Suplemento acotado a la región del perfil (tenants multi-región grandes)

```powershell
.\oci-inventory_v2.2.ps1 -Html -SupplementHomeRegionOnly
```

---

## Archivos de salida

Todos los artefactos se generan en una carpeta con timestamp: `oci_inventory_<AAAAMMdd_HHmmss>\`.

| Archivo | Descripción |
|---|---|
| `inventario_full.json` | Resultado crudo de la búsqueda global paginada **+ recursos del suplemento** (sin enriquecer). Los recursos del suplemento llevan `_source: supplement`. |
| `inventario_enriched.json` | Recursos con todos los atributos extra obtenidos por los enrichers. |
| `inventario_resumen.csv` | CSV plano con los campos base de todos los recursos (sin enrichment). |
| `csv\<tipo>.csv` | Un CSV por tipo de recurso con todos los atributos enriquecidos de ese tipo. |
| `inventario_ascii.txt` | Tabla ASCII agrupada por tipo, ordenada por nombre y región. |
| `resumen_por_tipo.txt` | Conteo de recursos por tipo (formato `count\ttipo`). |
| `inventario.html` | Árbol jerárquico interactivo (solo con `-Html`). |
| `inventario.log` | Log de ejecución con timestamps y niveles INFO / WARN / ERROR. |

---

## Tipos de recursos enriquecidos

| Tipo OCI | Atributos extra destacados |
|---|---|
| `instance` | Shape, OCPUs, memoria, AD/FD, IPs privadas/públicas, VNICs, NSGs, boot/block volumes |
| `vcn` | CIDRs IPv4/IPv6, DNS label, RT/SL/DHCP por defecto |
| `subnet` | CIDR, AD, RT enlazada, Security Lists, DNS label, virtual router IP |
| `vnic` | IP privada/pública, subnet, MAC, NSGs, hostname, is-primary |
| `loadbalancer` | Shape, IPs (público/privado), subnets, NSGs, listeners, backend sets, bandwidth |
| `networkloadbalancer` | IP, subnet, NSGs |
| `dbsystem` | Shape, CPUs, nodos, hostname, versión DB, edition, licencia, storage, SCAN, VIPs, databases |
| `autonomousdatabase` | Workload, versión, CPUs, storage, dedicated/free-tier, endpoint privado, NSGs |
| `cloudexadatainfrastructure` | Shape, compute/storage count, storage total/disponible, AD |
| `cloudvmcluster` | Cluster name, hostname, CPUs, GI version, scan, VIPs, NSGs |
| `database` | db_name, db_unique_name, PDB, workload, character set, connection strings |
| `pluggabledatabase` | PDB name, CDB OCID, open_mode, is_restricted |
| `volume` | Size (GB/MB), VPUs/GB, AD, hydrated, KMS key, source type |
| `bootvolume` | Size (GB), VPUs/GB, AD, image ID, KMS key |
| `bucket` | Namespace, tier, public access, versioning, auto-tiering, tamaño aprox. (GB), object count |
| `filesystem` | AD, metered_bytes, KMS key, is_clone_parent |
| `mounttarget` | AD, subnet, NSGs, private IPs, hostname, export set |
| `drg` | Default DRG route tables |
| `internetgateway` | VCN ID, is_enabled |
| `natgateway` | VCN ID, NAT IP, block_traffic |
| `servicegateway` | VCN ID, servicios, RT ID |
| `localpeeringgateway` | VCN ID, peer ID, peering status, CIDR anunciado |
| `routetable` | VCN ID, número de reglas |
| `securitylist` | VCN ID, reglas ingress/egress count |
| `networksecuritygroup` | VCN ID, número de reglas |
| `cluster` (OKE) | Versión Kubernetes, VCN, endpoints público/privado/kubernetes, tipo |
| `vault` | Vault type, crypto/management endpoint, time created |
| `bastion` | Tipo, target subnet/VCN, CIDR allow list, max TTL, DNS proxy, private endpoint IP |
| `compartment` | Parent compartment ID, is_accessible, description |
| `loggroup` | Descripción, nº de logs y nombres de los logs contenidos |
| `serviceconnector` | source kind, target kind, descripción |
| `onstopic` | nº de suscripciones y protocolos de suscripción |
| `eventrule` | is_enabled, condition, descripción |
| `alarm` | namespace, severity, is_enabled, metric compartment, destinos |
| `budget` | amount, reset period, target type, actual/forecasted spend |
| `networkfirewall` | subnet, IPv4, policy ID, availability domain |
| `networkfirewallpolicy` | nº de firewalls asociados |

---

## Estructura del árbol HTML

```
Tenant (OCID)
├── IAM & Identidad
│   ├── Aplicaciones de Dominio (OAuth / SAML apps)
│   ├── Usuarios  (agrupados por Identity Domain)
│   ├── Grupos
│   ├── Policies (nivel tenant)
│   ├── Tag Namespaces
│   └── Tag Defaults
└── Compartment  (recursivo)
    ├── Networking
    │   ├── DRG → Attachments · Route Tables · Route Distributions
    │   ├── VCN → Subnets (con SL y RT enlazadas) · Route Tables · SL · NSG · Gateways · DHCP
    │   ├── FastConnect / VirtualCircuit
    │   ├── Public IPs
    │   └── DNS (Resolvers, Views, Zones)
    ├── Compute → Instances (con Boot/Block Volumes)
    ├── Base de Datos → DbSystem / ADB / ExaCS (con Databases / PDBs / VM Clusters)
    ├── Almacenamiento → Buckets · FileSystems / MountTargets
    ├── Aplicaciones / Servicios → OKE · LB · NLB · API GW · Functions
    ├── Seguridad → Vaults · Bastions · Keys · Secrets · Network Firewall (+ Policy)
    ├── Observabilidad → Log Groups · Service Connectors · Alarms · ONS Topics · Event Rules
    ├── Governance → Policies · Tag Namespaces · Budgets
    └── Sub-Compartments (recursivo, sin DELETED)
```

### Funcionalidades interactivas del HTML

- **Búsqueda en tiempo real**: filtra el árbol completo al escribir (mínimo 2 caracteres); expande automáticamente los nodos que contienen coincidencias.
- **Expandir / Colapsar todo**: botones en la barra superior.
- **Badges de estado**: `ACTIVE/AVAILABLE/RUNNING` en verde, `DELETING/TERMINATED/FAILED` en rojo, resto en ámbar.
- **Tabla de atributos** expandible por cada recurso con todos los metadatos enriquecidos.

---

## Notas de operación

- El script **no modifica ni elimina** ningún recurso de OCI; todas las llamadas son de solo lectura (`GET` / `LIST`).
- Los recursos con `lifecycle_state = DELETED` se **excluyen** del árbol HTML (compartments y recursos).
- La variable de entorno `OCI_CLI_PAGER` se fija a vacío para evitar paginación interactiva durante la ejecución.
- Errores en enrichers individuales se registran en el log como `WARN` y no detienen la ejecución; el recurso se incluye sin atributos extra.
- El enrichment puede generar **cientos o miles de llamadas** a la API OCI dependiendo del tamaño del tenant. Para tenants grandes se recomienda usar `-IncludeTypes` para limitar el alcance o `-NoEnrich` para una pasada rápida.
- La **fase de suplemento** añade llamadas adicionales proporcionales a `nº regiones suscritas × nº compartments × nº tipos suplementados`. En tenants multi-región grandes use `-SupplementHomeRegionOnly` para acotarla, o `-NoSupplement` para desactivarla por completo. Todas las llamadas siguen siendo de solo lectura (`list` / `get`).
- Los recursos descubiertos por el suplemento llevan el campo `_source = supplement`; permite distinguir en el JSON/CSV qué recursos vinieron de la búsqueda global y cuáles de las APIs dedicadas.

---

## Variables de entorno utilizadas

| Variable | Uso |
|---|---|
| `OCI_CLI_PROFILE` | Perfil OCI CLI alternativo al `DEFAULT`. |
| `OCI_CLI_PAGER` | Forzado a vacío para deshabilitar paginación interactiva. |
| `OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING` | Silencia advertencias de permisos de archivo de configuración. |
