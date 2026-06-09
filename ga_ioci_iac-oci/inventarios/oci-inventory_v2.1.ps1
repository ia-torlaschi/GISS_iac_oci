<#
.SYNOPSIS
    Inventario detallado de Oracle Cloud Infrastructure con enrichment por tipo de recurso.

.DESCRIPTION
    Versión extendida del inventario basado en 'oci search resource structured-search'.
    Adicionalmente, por cada recurso encontrado, invoca al servicio nativo correspondiente
    (Compute, VirtualNetwork, Database, LoadBalancer, ObjectStorage, etc.) para obtener
    atributos detallados: IPs públicas/privadas, subredes, CIDR, shape, OCPUs/memoria,
    nombres y versiones de bases de datos, tamaños de volúmenes, etc.

    Salidas:
      - inventario_full.json          : JSON consolidado de la búsqueda global
      - inventario_enriched.json      : JSON enriquecido con detalle por recurso
      - inventario_ascii.txt          : Tabla ASCII agrupada por TYPE (vista rápida)
      - resumen_por_tipo.txt          : Conteo por TYPE
      - csv\<type>.csv                : Un CSV por tipo, con columnas específicas
      - inventario_resumen.csv        : CSV plano resumen-enriquecido (best-effort)
      - inventario.html               : (opcional) Reporte HTML navegable

.PARAMETER Limit
    Tamaño de página para la búsqueda global. Default 1000.

.PARAMETER IncludeTypes
    Lista opcional de tipos a enriquecer (case-insensitive). Si está vacía, se procesan todos
    los tipos para los que existe enricher. Ej: -IncludeTypes instance,vcn,subnet

.PARAMETER ExcludeTypes
    Lista opcional de tipos a excluir del enrichment.

.PARAMETER NoEnrich
    Si se especifica, omite el enrichment y produce solo el inventario "wide" (comportamiento
    original).

.PARAMETER Html
    Si se especifica, genera además un reporte HTML.

.PARAMETER MaxConcurrent
    Reservado para futura paralelización. Por ahora el enrichment es secuencial con progress bar.

.EXAMPLE
    .\oci-inventory.ps1

.EXAMPLE
    .\oci-inventory.ps1 -IncludeTypes instance,vcn,subnet,dbsystem -Html

.NOTES
    Requiere OCI CLI configurado (perfil DEFAULT o variable OCI_CLI_PROFILE).
    El usuario IAM debe tener permisos de lectura sobre los servicios consultados.
    En entornos con TBAC, los recursos sin el tag de acceso requerido se omitirán silenciosamente.
#>

param(
    [int]$Limit = 1000,
    [string[]]$IncludeTypes = @(),
    [string[]]$ExcludeTypes = @(),
    [switch]$NoEnrich,
    [switch]$Html,
    [int]$MaxConcurrent = 1
)

$ErrorActionPreference = "Stop"

# ===========================================================================
# 0. SETUP
# ===========================================================================
$QueryText = "query all resources"
$TS        = Get-Date -Format "yyyyMMdd_HHmmss"
$OutDir    = "oci_inventory_$TS"
$CsvDir    = Join-Path $OutDir "csv"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $CsvDir | Out-Null

$FullJson     = Join-Path $OutDir "inventario_full.json"
$EnrichedJson = Join-Path $OutDir "inventario_enriched.json"
$AsciiTxt     = Join-Path $OutDir "inventario_ascii.txt"
$SummaryOut   = Join-Path $OutDir "resumen_por_tipo.txt"
$FlatCsv      = Join-Path $OutDir "inventario_resumen.csv"
$HtmlOut      = Join-Path $OutDir "inventario.html"
$LogFile      = Join-Path $OutDir "inventario.log"

$env:OCI_CLI_PAGER = ""
$env:OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING = "True"

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

Write-Log INFO "Generando inventario OCI (extendido)."
Write-Log INFO "Output dir: $OutDir"

# ===========================================================================
# 1. HELPERS GENERALES
# ===========================================================================

function Invoke-OciJson {
    <#
        Wrapper sobre 'oci' que devuelve PSObject parseado o $null si la llamada falla.
        No aborta el script ante errores individuales; los registra en el log.
    #>
    param(
        [Parameter(Mandatory=$true)][string[]]$Args,
        [switch]$AllowEmpty
    )
    try {
        $raw = (& oci @Args 2>&1 | Out-String)
        if ([string]::IsNullOrWhiteSpace($raw)) {
            if ($AllowEmpty) { return $null }
            Write-Log WARN "OCI CLI devolvió salida vacía para: $($Args -join ' ')"
            return $null
        }
        # Algunas llamadas devuelven texto de error antes del JSON
        $trim = $raw.TrimStart()
        if ($trim -notmatch '^[\{\[]') {
            Write-Log WARN "OCI CLI no devolvió JSON. Cmd: $($Args -join ' '). Inicio: $($trim.Substring(0,[Math]::Min(120,$trim.Length)))"
            return $null
        }
        return $raw | ConvertFrom-Json
    } catch {
        Write-Log ERROR "Excepción invocando OCI CLI: $_  Cmd: $($Args -join ' ')"
        return $null
    }
}

function Norm([object]$v) {
    if ($null -eq $v) { return "" }
    return ([string]$v).Trim().ToLowerInvariant()
}

function Format-Cell([string]$value, [int]$width) {
    if ($null -eq $value) { $value = "" }
    $value = [string]$value
    if ($value.Length -gt $width) { return ($value.Substring(0, $width-3) + "...") }
    return $value.PadRight($width)
}

function Get-FreeformOrDefined($res, [string]$prefer) {
    # Devuelve el nombre canónico priorizando display-name, fallback a name/identifier
    foreach ($p in @($prefer,'display-name','name','identifier')) {
        if ($p -and $res.PSObject.Properties.Name -contains $p -and $res.$p) { return $res.$p }
    }
    return ""
}

function Join-NonEmpty([object[]]$values, [string]$sep = "; ") {
    if (-not $values) { return "" }
    return ($values | Where-Object { $_ -ne $null -and "$_" -ne "" }) -join $sep
}

# ===========================================================================
# 2. BÚSQUEDA GLOBAL (paginada)
# ===========================================================================

$allItems = New-Object 'System.Collections.Generic.List[object]'
$page     = $null

do {
    $args = @(
        "search","resource","structured-search",
        "--query-text",$QueryText,
        "--limit","$Limit",
        "--output","json"
    )
    if ($page) { $args += @("--page",$page) }

    $obj = Invoke-OciJson -Args $args
    if (-not $obj) {
        Write-Log ERROR "Fallo en la búsqueda global. Abortando."
        exit 1
    }

    if ($obj.data -and $obj.data.items) {
        foreach ($r in @($obj.data.items)) { [void]$allItems.Add($r) }
    } elseif ($obj.data -is [System.Array]) {
        foreach ($r in @($obj.data)) { [void]$allItems.Add($r) }
    }
    $page = $obj.'opc-next-page'
} while ($page)

Write-Log INFO "Total recursos encontrados: $($allItems.Count)"

$final = [pscustomobject]@{ data = $allItems.ToArray() }
$final | ConvertTo-Json -Depth 30 | Out-File $FullJson -Encoding utf8

$items = $allItems.ToArray()
if ($items.Count -eq 0) {
    Write-Log WARN "No se han devuelto recursos (0). Revisa permisos IAM / TBAC."
    exit 0
}

# ===========================================================================
# 3. ENRICHERS POR TIPO
#    Cada función recibe el objeto base (resource-type, identifier, region,
#    compartment-id, display-name, lifecycle-state) y devuelve un hashtable con
#    campos adicionales. Si falla, devuelve hashtable vacío.
#
#    IMPORTANTE: el OCID viene en la propiedad 'identifier'.
# ===========================================================================

function Add-Region([string[]]$BaseArgs, [string]$Region) {
    # NOTA: NO usar $args como nombre de parámetro: es una variable automática
    # reservada de PowerShell y en funciones no-advanced devuelve $null.
    if ($Region) { return $BaseArgs + @("--region",$Region) }
    return $BaseArgs
}

# ---------- COMPUTE INSTANCE ----------
function Get-InstanceDetail($r) {
    $ocid   = $r.identifier
    $region = $r.region
    $detail = @{}

    $inst = Invoke-OciJson -Args (Add-Region @("compute","instance","get","--instance-id",$ocid,"--output","json") $region)
    if (-not $inst -or -not $inst.data) { return $detail }
    $d = $inst.data

    $detail["shape"]               = $d.shape
    $detail["ocpus"]               = $d.'shape-config'.ocpus
    $detail["memory_gb"]           = $d.'shape-config'.'memory-in-gbs'
    $detail["availability_domain"] = $d.'availability-domain'
    $detail["fault_domain"]        = $d.'fault-domain'
    $detail["image_id"]            = $d.'image-id'
    $detail["time_created"]        = $d.'time-created'
    $detail["compartment_id"]      = $d.'compartment-id'

    # VNICs → IPs
    $vnicAtt = Invoke-OciJson -Args (Add-Region @("compute","vnic-attachment","list","--instance-id",$ocid,"--all","--output","json") $region)
    $privIps = @(); $pubIps = @(); $subnetIds = @(); $vnicIds = @(); $hostnames = @(); $macs = @(); $nsgs = @()

    if ($vnicAtt -and $vnicAtt.data) {
        foreach ($att in @($vnicAtt.data)) {
            $vnicId = $att.'vnic-id'
            if (-not $vnicId) { continue }
            $vnic = Invoke-OciJson -Args (Add-Region @("network","vnic","get","--vnic-id",$vnicId,"--output","json") $region)
            if ($vnic -and $vnic.data) {
                $v = $vnic.data
                $vnicIds   += $vnicId
                if ($v.'private-ip')   { $privIps   += $v.'private-ip' }
                if ($v.'public-ip')    { $pubIps    += $v.'public-ip' }
                if ($v.'subnet-id')    { $subnetIds += $v.'subnet-id' }
                if ($v.'hostname-label'){$hostnames += $v.'hostname-label' }
                if ($v.'mac-address')  { $macs      += $v.'mac-address' }
                if ($v.'nsg-ids')      { $nsgs      += @($v.'nsg-ids') }
            }
        }
    }
    $detail["private_ips"] = (Join-NonEmpty $privIps ",")
    $detail["public_ips"]  = (Join-NonEmpty $pubIps  ",")
    $detail["subnet_ids"]  = (Join-NonEmpty $subnetIds ",")
    $detail["vnic_ids"]    = (Join-NonEmpty $vnicIds ",")
    $detail["hostnames"]   = (Join-NonEmpty $hostnames ",")
    $detail["mac_addresses"] = (Join-NonEmpty $macs ",")
    $detail["nsg_ids"]     = (Join-NonEmpty ($nsgs | Select-Object -Unique) ",")

    # Volúmenes adjuntos (block + boot)
    $boot = Invoke-OciJson -Args (Add-Region @("compute","boot-volume-attachment","list",
        "--availability-domain",$d.'availability-domain',
        "--compartment-id",$d.'compartment-id',
        "--instance-id",$ocid,"--all","--output","json") $region)
    if ($boot -and $boot.data) {
        $detail["boot_volume_ids"] = (Join-NonEmpty ($boot.data | ForEach-Object { $_.'boot-volume-id' }) ",")
    }
    $blk = Invoke-OciJson -Args (Add-Region @("compute","volume-attachment","list",
        "--compartment-id",$d.'compartment-id',
        "--instance-id",$ocid,"--all","--output","json") $region)
    if ($blk -and $blk.data) {
        $detail["block_volume_ids"] = (Join-NonEmpty ($blk.data | ForEach-Object { $_.'volume-id' }) ",")
    }

    return $detail
}

# ---------- VCN ----------
function Get-VcnDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","vcn","get","--vcn-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $v = $d.data
    return @{
        cidr_blocks       = (Join-NonEmpty $v.'cidr-blocks' ",")
        ipv6_cidr_blocks  = (Join-NonEmpty $v.'ipv6-cidr-blocks' ",")
        dns_label         = $v.'dns-label'
        vcn_domain_name   = $v.'vcn-domain-name'
        default_route_table_id    = $v.'default-route-table-id'
        default_security_list_id  = $v.'default-security-list-id'
        default_dhcp_options_id   = $v.'default-dhcp-options-id'
    }
}

# ---------- SUBNET ----------
function Get-SubnetDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","subnet","get","--subnet-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $s = $d.data
    return @{
        cidr_block             = $s.'cidr-block'
        ipv6_cidr_block        = $s.'ipv6-cidr-block'
        vcn_id                 = $s.'vcn-id'
        availability_domain    = $s.'availability-domain'
        prohibit_public_ip     = $s.'prohibit-public-ip-on-vnic'
        prohibit_internet_ingress = $s.'prohibit-internet-ingress'
        route_table_id         = $s.'route-table-id'
        dhcp_options_id        = $s.'dhcp-options-id'
        security_list_ids      = (Join-NonEmpty $s.'security-list-ids' ",")
        dns_label              = $s.'dns-label'
        subnet_domain_name     = $s.'subnet-domain-name'
        virtual_router_ip      = $s.'virtual-router-ip'
        virtual_router_mac     = $s.'virtual-router-mac'
    }
}

# ---------- VNIC ----------
function Get-VnicDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","vnic","get","--vnic-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $v = $d.data
    return @{
        private_ip   = $v.'private-ip'
        public_ip    = $v.'public-ip'
        subnet_id    = $v.'subnet-id'
        mac_address  = $v.'mac-address'
        nsg_ids      = (Join-NonEmpty $v.'nsg-ids' ",")
        hostname_label = $v.'hostname-label'
        is_primary   = $v.'is-primary'
        skip_source_dest_check = $v.'skip-source-dest-check'
    }
}

# ---------- LOAD BALANCER (LBaaS) ----------
function Get-LoadBalancerDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("lb","load-balancer","get","--load-balancer-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $l = $d.data
    $ips = @()
    if ($l.'ip-addresses') {
        foreach ($ip in @($l.'ip-addresses')) {
            $kind = if ($ip.'is-public') { "public" } else { "private" }
            $ips += ("{0}({1})" -f $ip.'ip-address',$kind)
        }
    }
    return @{
        shape_name        = $l.'shape-name'
        is_private        = $l.'is-private'
        ip_addresses      = (Join-NonEmpty $ips ",")
        subnet_ids        = (Join-NonEmpty $l.'subnet-ids' ",")
        nsg_ids           = (Join-NonEmpty $l.'network-security-group-ids' ",")
        listeners         = (Join-NonEmpty ($l.listeners.PSObject.Properties.Name) ",")
        backend_sets      = (Join-NonEmpty ($l.'backend-sets'.PSObject.Properties.Name) ",")
        min_bandwidth_mbps = $l.'shape-details'.'minimum-bandwidth-in-mbps'
        max_bandwidth_mbps = $l.'shape-details'.'maximum-bandwidth-in-mbps'
    }
}

# ---------- NETWORK LOAD BALANCER ----------
function Get-NlbDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("nlb","network-load-balancer","get","--network-load-balancer-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $n = $d.data
    $ips = @()
    if ($n.'ip-addresses') {
        foreach ($ip in @($n.'ip-addresses')) {
            $kind = if ($ip.'is-public') { "public" } else { "private" }
            $ips += ("{0}({1})" -f $ip.'ip-address',$kind)
        }
    }
    return @{
        is_private    = $n.'is-private'
        ip_addresses  = (Join-NonEmpty $ips ",")
        subnet_id     = $n.'subnet-id'
        nsg_ids       = (Join-NonEmpty $n.'network-security-group-ids' ",")
    }
}

# ---------- DB SYSTEM (Base Database / VM DB) ----------
function Get-DbSystemDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","system","get","--db-system-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $s = $d.data
    $detail = @{
        shape               = $s.shape
        cpu_core_count      = $s.'cpu-core-count'
        node_count          = $s.'node-count'
        hostname            = $s.hostname
        domain              = $s.domain
        db_version          = $s.version
        database_edition    = $s.'database-edition'
        license_model       = $s.'license-model'
        data_storage_size_gb = $s.'data-storage-size-in-gbs'
        reco_storage_size_gb = $s.'reco-storage-size-in-gb'
        storage_management  = $s.'db-system-options'.'storage-management'
        subnet_id           = $s.'subnet-id'
        backup_subnet_id    = $s.'backup-subnet-id'
        nsg_ids             = (Join-NonEmpty $s.'nsg-ids' ",")
        backup_nsg_ids      = (Join-NonEmpty $s.'backup-network-nsg-ids' ",")
        listener_port       = $s.'listener-port'
        scan_dns_name       = $s.'scan-dns-name'
        scan_ip_ids         = (Join-NonEmpty $s.'scan-ip-ids' ",")
        vip_ids             = (Join-NonEmpty $s.'vip-ids' ",")
        cluster_name        = $s.'cluster-name'
        availability_domain = $s.'availability-domain'
    }
    # Nombres de DB (db-home → database)
    $dbHomes = Invoke-OciJson -Args (Add-Region @("db","db-home","list",
        "--compartment-id",$s.'compartment-id',
        "--db-system-id",$r.identifier,
        "--all","--output","json") $r.region)
    $dbNames = @()
    if ($dbHomes -and $dbHomes.data) {
        foreach ($h in @($dbHomes.data)) {
            $dbs = Invoke-OciJson -Args (Add-Region @("db","database","list",
                "--compartment-id",$s.'compartment-id',
                "--db-home-id",$h.id,
                "--all","--output","json") $r.region)
            if ($dbs -and $dbs.data) {
                foreach ($db in @($dbs.data)) {
                    $dbNames += ("{0}/{1}" -f $db.'db-name', $db.'db-unique-name')
                }
            }
        }
    }
    $detail["databases"] = (Join-NonEmpty $dbNames ",")
    return $detail
}

# ---------- AUTONOMOUS DATABASE ----------
function Get-AdbDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","autonomous-database","get","--autonomous-database-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $a = $d.data
    return @{
        db_name              = $a.'db-name'
        db_workload          = $a.'db-workload'
        db_version           = $a.'db-version'
        cpu_core_count       = $a.'cpu-core-count'
        compute_count        = $a.'compute-count'
        compute_model        = $a.'compute-model'
        data_storage_tb      = $a.'data-storage-size-in-tbs'
        data_storage_gb      = $a.'data-storage-size-in-gbs'
        is_free_tier         = $a.'is-free-tier'
        is_dedicated         = $a.'is-dedicated'
        is_mtls_required     = $a.'is-mtls-connection-required'
        license_model        = $a.'license-model'
        infrastructure_type  = $a.'infrastructure-type'
        whitelisted_ips      = (Join-NonEmpty $a.'whitelisted-ips' ",")
        private_endpoint     = $a.'private-endpoint'
        private_endpoint_ip  = $a.'private-endpoint-ip'
        private_endpoint_label = $a.'private-endpoint-label'
        subnet_id            = $a.'subnet-id'
        nsg_ids              = (Join-NonEmpty $a.'nsg-ids' ",")
        connection_strings   = ($a.'connection-strings'.profiles | ForEach-Object { $_.'display-name' }) -join ","
    }
}

# ---------- CLOUD EXADATA INFRASTRUCTURE (ExaCS) ----------
function Get-CloudExaInfraDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","cloud-exa-infra","get","--cloud-exa-infra-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $e = $d.data
    return @{
        shape                       = $e.shape
        compute_count               = $e.'compute-count'
        storage_count               = $e.'storage-count'
        total_storage_size_gb       = $e.'total-storage-size-in-gbs'
        available_storage_size_gb   = $e.'available-storage-size-in-gbs'
        availability_domain         = $e.'availability-domain'
        cluster_placement_group_id  = $e.'cluster-placement-group-id'
        customer_contacts           = (Join-NonEmpty ($e.'customer-contacts' | ForEach-Object { $_.email }) ",")
        maintenance_window          = ($e.'maintenance-window' | ConvertTo-Json -Compress -Depth 5)
    }
}

# ---------- CLOUD VM CLUSTER (ExaCS) ----------
function Get-CloudVmClusterDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","cloud-vm-cluster","get","--cloud-vm-cluster-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $c = $d.data
    return @{
        cluster_name              = $c.'cluster-name'
        hostname                  = $c.hostname
        domain                    = $c.domain
        cpu_core_count            = $c.'cpu-core-count'
        ocpu_count                = $c.'ocpu-count'
        memory_gb                 = $c.'memory-size-in-gbs'
        data_storage_tb           = $c.'data-storage-size-in-tbs'
        node_count                = $c.'node-count'
        gi_version                = $c.'gi-version'
        system_version            = $c.'system-version'
        time_zone                 = $c.'time-zone'
        license_model             = $c.'license-model'
        cloud_exa_infra_id        = $c.'cloud-exadata-infrastructure-id'
        subnet_id                 = $c.'subnet-id'
        backup_subnet_id          = $c.'backup-subnet-id'
        nsg_ids                   = (Join-NonEmpty $c.'nsg-ids' ",")
        backup_nsg_ids            = (Join-NonEmpty $c.'backup-network-nsg-ids' ",")
        scan_dns_name             = $c.'scan-dns-name'
        scan_listener_port_tcp    = $c.'scan-listener-port-tcp'
        scan_listener_port_tcp_ssl= $c.'scan-listener-port-tcp-ssl'
        scan_ip_ids               = (Join-NonEmpty $c.'scan-ip-ids' ",")
        vip_ids                   = (Join-NonEmpty $c.'vip-ids' ",")
    }
}

# ---------- DATABASE (en DB System / ExaCS) ----------
function Get-DatabaseDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","database","get","--database-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $x = $d.data
    return @{
        db_name           = $x.'db-name'
        db_unique_name    = $x.'db-unique-name'
        pdb_name          = $x.'pdb-name'
        db_workload       = $x.'db-workload'
        character_set     = $x.'character-set'
        ncharacter_set    = $x.'ncharacter-set'
        db_home_id        = $x.'db-home-id'
        db_system_id      = $x.'db-system-id'
        vm_cluster_id     = $x.'vm-cluster-id'
        connection_strings_cdb = $x.'connection-strings'.'cdb-default'
    }
}

# ---------- PLUGGABLE DATABASE ----------
function Get-PdbDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","pluggable-database","get","--pluggable-database-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $p = $d.data
    return @{
        pdb_name        = $p.'pdb-name'
        container_db_id = $p.'container-database-id'
        open_mode       = $p.'open-mode'
        is_restricted   = $p.'is-restricted'
    }
}

# ---------- BLOCK VOLUME ----------
function Get-BlockVolumeDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("bv","volume","get","--volume-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $v = $d.data
    return @{
        size_gb              = $v.'size-in-gbs'
        size_mb              = $v.'size-in-mbs'
        vpus_per_gb          = $v.'vpus-per-gb'
        availability_domain  = $v.'availability-domain'
        is_hydrated          = $v.'is-hydrated'
        kms_key_id           = $v.'kms-key-id'
        source_type          = $v.'source-details'.type
    }
}

# ---------- BOOT VOLUME ----------
function Get-BootVolumeDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("bv","boot-volume","get","--boot-volume-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $v = $d.data
    return @{
        size_gb              = $v.'size-in-gbs'
        vpus_per_gb          = $v.'vpus-per-gb'
        availability_domain  = $v.'availability-domain'
        image_id             = $v.'image-id'
        kms_key_id           = $v.'kms-key-id'
    }
}

# ---------- OBJECT STORAGE BUCKET ----------
function Get-BucketDetail($r) {
    $ns = Invoke-OciJson -Args (Add-Region @("os","ns","get","--output","json") $r.region)
    if (-not $ns -or -not $ns.data) { return @{} }
    $d = Invoke-OciJson -Args (Add-Region @("os","bucket","get","--namespace-name",$ns.data,"--bucket-name",$r.'display-name',"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $b = $d.data
    return @{
        namespace            = $b.namespace
        storage_tier         = $b.'storage-tier'
        public_access_type   = $b.'public-access-type'
        versioning           = $b.versioning
        object_events_enabled= $b.'object-events-enabled'
        replication_enabled  = $b.'replication-enabled'
        kms_key_id           = $b.'kms-key-id'
        auto_tiering         = $b.'auto-tiering'
        approximate_size_gb  = if ($b.'approximate-size') { [math]::Round($b.'approximate-size' / 1GB, 2) } else { $null }
        approximate_count    = $b.'approximate-count'
    }
}

# ---------- FILE SYSTEM ----------
function Get-FsDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("fs","file-system","get","--file-system-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $f = $d.data
    return @{
        availability_domain  = $f.'availability-domain'
        metered_bytes        = $f.'metered-bytes'
        kms_key_id           = $f.'kms-key-id'
        is_clone_parent      = $f.'is-clone-parent'
    }
}

# ---------- MOUNT TARGET ----------
function Get-MountTargetDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("fs","mount-target","get","--mount-target-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $m = $d.data
    return @{
        availability_domain  = $m.'availability-domain'
        subnet_id            = $m.'subnet-id'
        nsg_ids              = (Join-NonEmpty $m.'nsg-ids' ",")
        private_ip_ids       = (Join-NonEmpty $m.'private-ip-ids' ",")
        hostname_label       = $m.'hostname-label'
        export_set_id        = $m.'export-set-id'
    }
}

# ---------- DRG ----------
function Get-DrgDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","drg","get","--drg-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $g = $d.data
    return @{
        default_drg_route_tables = ($g.'default-drg-route-tables' | ConvertTo-Json -Compress -Depth 4)
    }
}

# ---------- INTERNET / NAT / SERVICE / LOCAL PEERING GATEWAYS ----------
function Get-IgwDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","internet-gateway","get","--ig-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{ vcn_id = $d.data.'vcn-id'; is_enabled = $d.data.'is-enabled' }
}
function Get-NatDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","nat-gateway","get","--nat-gateway-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{ vcn_id = $d.data.'vcn-id'; nat_ip = $d.data.'nat-ip'; block_traffic = $d.data.'block-traffic' }
}
function Get-SgwDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","service-gateway","get","--service-gateway-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        vcn_id    = $d.data.'vcn-id'
        services  = (Join-NonEmpty ($d.data.services | ForEach-Object { $_.'service-name' }) ",")
        route_table_id = $d.data.'route-table-id'
    }
}
function Get-LpgDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","local-peering-gateway","get","--local-peering-gateway-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        vcn_id          = $d.data.'vcn-id'
        peer_id         = $d.data.'peer-id'
        peering_status  = $d.data.'peering-status'
        peer_advertised_cidr = $d.data.'peer-advertised-cidr'
        route_table_id  = $d.data.'route-table-id'
    }
}

# ---------- ROUTE TABLE / SECURITY LIST / NSG ----------
function Get-RouteTableDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","route-table","get","--rt-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        vcn_id     = $d.data.'vcn-id'
        rule_count = ($d.data.'route-rules' | Measure-Object).Count
    }
}
function Get-SecurityListDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","security-list","get","--security-list-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        vcn_id          = $d.data.'vcn-id'
        ingress_count   = ($d.data.'ingress-security-rules' | Measure-Object).Count
        egress_count    = ($d.data.'egress-security-rules' | Measure-Object).Count
    }
}
function Get-NsgDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","nsg","get","--nsg-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $rules = Invoke-OciJson -Args (Add-Region @("network","nsg","rules","list","--nsg-id",$r.identifier,"--all","--output","json") $r.region)
    $count = if ($rules -and $rules.data) { ($rules.data | Measure-Object).Count } else { 0 }
    return @{
        vcn_id     = $d.data.'vcn-id'
        rule_count = $count
    }
}

# ---------- OKE CLUSTER ----------
function Get-OkeClusterDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("ce","cluster","get","--cluster-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $c = $d.data
    return @{
        kubernetes_version  = $c.'kubernetes-version'
        vcn_id              = $c.'vcn-id'
        endpoint_public     = $c.endpoints.'public-endpoint'
        endpoint_private    = $c.endpoints.'private-endpoint'
        endpoint_kubernetes = $c.endpoints.kubernetes
        cluster_pod_network = ($c.'cluster-pod-network-options' | ForEach-Object { $_.'cni-type' }) -join ","
        type                = $c.type
    }
}

# ---------- VAULT (KMS) ----------
function Get-VaultDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("kms","management","vault","get","--vault-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        vault_type             = $d.data.'vault-type'
        crypto_endpoint        = $d.data.'crypto-endpoint'
        management_endpoint    = $d.data.'management-endpoint'
        time_created           = $d.data.'time-created'
    }
}

# ---------- BASTION ----------
function Get-BastionDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("bastion","bastion","get","--bastion-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        bastion_type             = $d.data.'bastion-type'
        target_subnet_id         = $d.data.'target-subnet-id'
        target_vcn_id            = $d.data.'target-vcn-id'
        client_cidr_allow_list   = (Join-NonEmpty $d.data.'client-cidr-block-allow-list' ",")
        max_session_ttl_seconds  = $d.data.'max-session-ttl-in-seconds'
        dns_proxy_status         = $d.data.'dns-proxy-status'
        private_endpoint_ip      = $d.data.'private-endpoint-ip-address'
    }
}

# ---------- COMPARTMENT ----------
function Get-CompartmentDetail($r) {
    $d = Invoke-OciJson -Args @("iam","compartment","get","--compartment-id",$r.identifier,"--output","json")
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        parent_compartment_id  = $d.data.'compartment-id'
        is_accessible          = $d.data.'is-accessible'
        description            = $d.data.description
    }
}

# ===========================================================================
# 4. DISPATCHER
# ===========================================================================

$EnricherMap = @{
    "instance"                       = ${function:Get-InstanceDetail}
    "vcn"                            = ${function:Get-VcnDetail}
    "subnet"                         = ${function:Get-SubnetDetail}
    "vnic"                           = ${function:Get-VnicDetail}
    "loadbalancer"                   = ${function:Get-LoadBalancerDetail}
    "networkloadbalancer"            = ${function:Get-NlbDetail}
    "dbsystem"                       = ${function:Get-DbSystemDetail}
    "autonomousdatabase"             = ${function:Get-AdbDetail}
    "cloudexadatainfrastructure"     = ${function:Get-CloudExaInfraDetail}
    "cloudvmcluster"                 = ${function:Get-CloudVmClusterDetail}
    "database"                       = ${function:Get-DatabaseDetail}
    "pluggabledatabase"              = ${function:Get-PdbDetail}
    "volume"                         = ${function:Get-BlockVolumeDetail}
    "bootvolume"                     = ${function:Get-BootVolumeDetail}
    "bucket"                         = ${function:Get-BucketDetail}
    "filesystem"                     = ${function:Get-FsDetail}
    "mounttarget"                    = ${function:Get-MountTargetDetail}
    "drg"                            = ${function:Get-DrgDetail}
    "internetgateway"                = ${function:Get-IgwDetail}
    "natgateway"                     = ${function:Get-NatDetail}
    "servicegateway"                 = ${function:Get-SgwDetail}
    "localpeeringgateway"            = ${function:Get-LpgDetail}
    "routetable"                     = ${function:Get-RouteTableDetail}
    "securitylist"                   = ${function:Get-SecurityListDetail}
    "networksecuritygroup"           = ${function:Get-NsgDetail}
    "cluster"                        = ${function:Get-OkeClusterDetail}
    "vault"                          = ${function:Get-VaultDetail}
    "bastion"                        = ${function:Get-BastionDetail}
    "compartment"                    = ${function:Get-CompartmentDetail}
}

function ShouldEnrich([string]$type) {
    if ($NoEnrich) { return $false }
    $t = Norm($type)
    if ($ExcludeTypes -and ($ExcludeTypes | ForEach-Object { Norm($_) }) -contains $t) { return $false }
    if ($IncludeTypes -and $IncludeTypes.Count -gt 0) {
        $inc = $IncludeTypes | ForEach-Object { Norm($_) }
        if (-not ($inc -contains $t)) { return $false }
    }
    return $EnricherMap.ContainsKey($t)
}

# ===========================================================================
# 5. ENRICHMENT LOOP
# ===========================================================================

$enriched = New-Object 'System.Collections.Generic.List[object]'
$total    = $items.Count
$i        = 0
$ok       = 0
$skip     = 0
$fail     = 0

foreach ($r in $items) {
    $i++
    $type = Norm($r.'resource-type')
    $extra = @{}

    if (ShouldEnrich $type) {
        try {
            $fn = $EnricherMap[$type]
            $extra = & $fn $r
            if (-not $extra) { $extra = @{} }
            $ok++
        } catch {
            Write-Log WARN "Enricher fallo en $type / $($r.identifier): $_"
            $fail++
        }
    } else {
        $skip++
    }

    $merged = [ordered]@{
        resource_type    = $r.'resource-type'
        display_name     = $r.'display-name'
        region           = $r.region
        lifecycle_state  = $r.'lifecycle-state'
        compartment_id   = $r.'compartment-id'
        ocid             = $r.identifier
        time_created     = $r.'time-created'
        freeform_tags    = ($r.'freeform-tags' | ConvertTo-Json -Compress -Depth 5)
        defined_tags     = ($r.'defined-tags'  | ConvertTo-Json -Compress -Depth 5)
    }
    foreach ($k in $extra.Keys) { $merged[$k] = $extra[$k] }
    [void]$enriched.Add([pscustomobject]$merged)

    if ($i % 25 -eq 0 -or $i -eq $total) {
        Write-Progress -Activity "Enriqueciendo recursos" -Status "$i / $total (ok=$ok skip=$skip fail=$fail)" -PercentComplete (($i/$total)*100)
    }
}
Write-Progress -Activity "Enriqueciendo recursos" -Completed
Write-Log INFO "Enrichment finalizado. ok=$ok skip=$skip fail=$fail"

# JSON enriquecido
[pscustomobject]@{ generated_at = (Get-Date).ToString("o"); count = $enriched.Count; data = $enriched.ToArray() } |
    ConvertTo-Json -Depth 30 | Out-File $EnrichedJson -Encoding utf8

# ===========================================================================
# 6. RESUMEN POR TIPO + ASCII (compatible con la salida original)
# ===========================================================================

$groups = $items |
    Group-Object -Property { Norm($_.'resource-type') } |
    Sort-Object Name

$groups |
    Sort-Object Count -Descending |
    ForEach-Object {
        $typeDisplay = ($_.Group | Select-Object -First 1).'resource-type'
        if (-not $typeDisplay) { $typeDisplay = "(sin-type)" }
        "{0}`t{1}" -f $_.Count, $typeDisplay
    } | Out-File $SummaryOut -Encoding utf8

$columns = @(
    @{ Name="TYPE";   Width=28; Expr={ param($x) [string]$x.'resource-type' } },
    @{ Name="NAME";   Width=40; Expr={ param($x) [string]$x.'display-name' } },
    @{ Name="REGION"; Width=15; Expr={ param($x) [string]$x.region } },
    @{ Name="STATE";  Width=12; Expr={ param($x) [string]$x.'lifecycle-state' } }
)

$line = "+"
foreach ($col in $columns) { $line += ("-" * ($col.Width + 2)) + "+" }

$sb = New-Object System.Text.StringBuilder
foreach ($g in $groups) {
    $typeTitle = ($g.Group | Select-Object -First 1).'resource-type'
    if (-not $typeTitle) { $typeTitle = "(sin-type)" }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("######################### TYPE: $typeTitle  (count=$($g.Count)) #########################")
    $null = $sb.AppendLine($line)
    $hdr = "|"
    foreach ($col in $columns) { $hdr += " " + (Format-Cell $col.Name $col.Width) + " |" }
    $null = $sb.AppendLine($hdr)
    $null = $sb.AppendLine($line)

    $sortedInType = $g.Group | Sort-Object `
        @{E={ Norm($_.'display-name') }}, `
        @{E={ Norm($_.region) }}

    foreach ($r in $sortedInType) {
        $row = "|"
        foreach ($col in $columns) {
            $value = & $col.Expr $r
            $row += " " + (Format-Cell $value $col.Width) + " |"
        }
        $null = $sb.AppendLine($row)
    }
    $null = $sb.AppendLine($line)
}
$sb.ToString() | Out-File $AsciiTxt -Encoding utf8

# ===========================================================================
# 7. CSV ENRIQUECIDO POR TIPO
#    Cada tipo recibe su propio CSV con todas las columnas comunes + las
#    específicas del enricher. Esto evita el problema de "columnas dispersas"
#    de un único CSV plano.
# ===========================================================================

$byType = $enriched | Group-Object -Property resource_type
foreach ($g in $byType) {
    $typeSafe = ($g.Name -replace '[^a-zA-Z0-9\-_]', '_')
    if (-not $typeSafe) { $typeSafe = "untyped" }
    $csvPath  = Join-Path $CsvDir "$typeSafe.csv"
    # Calcular unión de columnas para este tipo
    $cols = New-Object System.Collections.Generic.List[string]
    foreach ($obj in $g.Group) {
        foreach ($p in $obj.PSObject.Properties.Name) {
            if (-not $cols.Contains($p)) { [void]$cols.Add($p) }
        }
    }
    $g.Group | Select-Object $cols | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
}

# CSV plano resumen (columnas comunes)
$enriched | Select-Object resource_type,display_name,region,lifecycle_state,compartment_id,ocid,time_created |
    Export-Csv -Path $FlatCsv -NoTypeInformation -Encoding utf8

# ===========================================================================
# 8. HTML (opcional)
# ===========================================================================
if ($Html) {
    $htmlHead = @"
<!doctype html>
<html><head><meta charset="utf-8"><title>OCI Inventory $TS</title>
<style>
 body{font-family:Segoe UI,Arial,sans-serif;margin:20px;background:#fafafa;color:#222}
 h1{margin-bottom:0}
 .meta{color:#666;margin-bottom:20px}
 details{background:#fff;border:1px solid #ddd;border-radius:6px;margin:10px 0;padding:6px 12px}
 summary{cursor:pointer;font-weight:600}
 table{border-collapse:collapse;width:100%;margin-top:8px;font-size:12px}
 th,td{border:1px solid #ddd;padding:4px 6px;text-align:left;vertical-align:top}
 th{background:#f0f0f0;position:sticky;top:0}
 tr:nth-child(even){background:#fafbfc}
 .pill{display:inline-block;padding:1px 8px;border-radius:10px;background:#eef;color:#225;font-size:11px}
</style></head><body>
<h1>OCI Inventory</h1>
<div class="meta">Generado: $TS &middot; Recursos: $($items.Count) &middot; Enriquecidos: $ok &middot; Omitidos: $skip &middot; Fallidos: $fail</div>
"@

    $htmlBody = New-Object System.Text.StringBuilder
    foreach ($g in ($enriched | Group-Object -Property resource_type | Sort-Object Name)) {
        $null = $htmlBody.AppendLine("<details><summary>$($g.Name) <span class='pill'>$($g.Count)</span></summary>")
        $cols = New-Object System.Collections.Generic.List[string]
        foreach ($obj in $g.Group) {
            foreach ($p in $obj.PSObject.Properties.Name) {
                if (-not $cols.Contains($p)) { [void]$cols.Add($p) }
            }
        }
        $null = $htmlBody.Append("<table><thead><tr>")
        foreach ($c in $cols) { $null = $htmlBody.Append("<th>$c</th>") }
        $null = $htmlBody.AppendLine("</tr></thead><tbody>")
        foreach ($obj in $g.Group) {
            $null = $htmlBody.Append("<tr>")
            foreach ($c in $cols) {
                $v = $obj.$c
                if ($null -eq $v) { $v = "" }
                $v = [System.Web.HttpUtility]::HtmlEncode("$v")
                $null = $htmlBody.Append("<td>$v</td>")
            }
            $null = $htmlBody.AppendLine("</tr>")
        }
        $null = $htmlBody.AppendLine("</tbody></table></details>")
    }
    Add-Type -AssemblyName System.Web
    ($htmlHead + $htmlBody.ToString() + "</body></html>") | Out-File $HtmlOut -Encoding utf8
}

# ===========================================================================
# 9. RESUMEN FINAL
# ===========================================================================
Write-Log INFO ""
Write-Log INFO "[OK] Inventario generado:"
Write-Log INFO " - $SummaryOut"
Write-Log INFO " - $AsciiTxt"
Write-Log INFO " - $FullJson"
Write-Log INFO " - $EnrichedJson"
Write-Log INFO " - $FlatCsv"
Write-Log INFO " - csv\<type>.csv  (un fichero por tipo, en $CsvDir)"
if ($Html) { Write-Log INFO " - $HtmlOut" }
Write-Log INFO " - $LogFile"
