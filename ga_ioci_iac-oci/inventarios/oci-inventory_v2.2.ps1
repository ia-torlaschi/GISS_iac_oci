<#
.SYNOPSIS
    Inventario detallado de Oracle Cloud Infrastructure — árbol jerárquico HTML.

.DESCRIPTION
    Versión 2.2 — basada en v2.1. Idéntica en todo excepto la salida HTML:
    en lugar de una tabla plana por tipo, genera un árbol jerárquico desplegable
    que refleja la topología real del tenant:

      Tenant
       └─ IAM & Identidad
            ├─ Usuarios (agrupados por Dominio)
            ├─ Grupos, Policies, Tag Namespaces …
            └─ Aplicaciones de Dominio (OAuth/SAML apps)
       └─ Compartment (recursivo)
            ├─ Networking
            │    ├─ DRG → Attachments, Route Tables, Route Distributions
            │    ├─ VCN → Subnets (con SL/RT enlazadas) · Route Tables · SL · NSG · Gateways · DHCP
            │    ├─ FastConnect / VirtualCircuit
            │    ├─ Public IPs
            │    └─ DNS (Resolvers, Views, Zones)
            ├─ Compute  → Instances (con Volumes)
            ├─ Base de Datos → DbSystem/ADB/ExaCS (con Databases/PDBs/Clusters)
            ├─ Almacenamiento → Buckets, FileSystems/MountTargets
            ├─ Seguridad → Vaults, Bastions
            ├─ Governance → Policies, Tag Namespaces (en este compartment)
            └─ Sub-Compartments (recursivo)

    El HTML incluye búsqueda interactiva, expandir/colapsar todo y badges de estado.

    NOTA: Este script NO modifica oci-inventory_v2.1.ps1; todas las demás salidas
    (JSON, CSV, ASCII) son idénticas a v2.1.

.PARAMETER Limit
    Tamaño de página para la búsqueda global. Default 1000.

.PARAMETER IncludeTypes
    Lista opcional de tipos a enriquecer. Si está vacía, se procesan todos.

.PARAMETER ExcludeTypes
    Lista opcional de tipos a excluir del enrichment.

.PARAMETER NoEnrich
    Omite el enrichment (solo inventario "wide").

.PARAMETER Html
    Genera el reporte HTML árbol jerárquico.

.PARAMETER MaxConcurrent
    Reservado para futura paralelización.

.EXAMPLE
    .\oci-inventory_v2.2.ps1 -Html

.EXAMPLE
    .\oci-inventory_v2.2.ps1 -IncludeTypes instance,vcn,subnet,dbsystem -Html

.NOTES
    Requiere OCI CLI configurado (perfil DEFAULT o variable OCI_CLI_PROFILE).
#>

param(
    [int]$Limit = 1000,
    [string[]]$IncludeTypes = @(),
    [string[]]$ExcludeTypes = @(),
    [switch]$NoEnrich,
    [switch]$Html,
    [int]$MaxConcurrent = 1,
    [switch]$NoSupplement,
    [switch]$SupplementHomeRegionOnly
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

Write-Log INFO "Generando inventario OCI v2.2 (árbol jerárquico HTML)."
Write-Log INFO "Output dir: $OutDir"

# ===========================================================================
# 1. HELPERS GENERALES
# ===========================================================================

function Invoke-OciJson {
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
    foreach ($p in @($prefer,'display-name','name','identifier')) {
        if ($p -and $res.PSObject.Properties.Name -contains $p -and $res.$p) { return $res.$p }
    }
    return ""
}

function Join-NonEmpty([object[]]$values, [string]$sep = "; ") {
    if (-not $values) { return "" }
    return ($values | Where-Object { $_ -ne $null -and "$_" -ne "" }) -join $sep
}

function Add-Region([string[]]$BaseArgs, [string]$Region) {
    if ($Region) { return $BaseArgs + @("--region",$Region) }
    return $BaseArgs
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

Write-Log INFO "Total recursos encontrados (búsqueda global): $($allItems.Count)"

# ===========================================================================
# 2b. SUPLEMENTO — tipos NO indexados de forma fiable por Resource Search
# ===========================================================================
# El servicio "search resource structured-search" no devuelve varios tipos de
# recurso que son críticos para cumplimiento (ENS / CCN-STIC-889A/B):
# Object Storage Buckets, Logging (Log Groups), Service Connector Hub,
# Notifications (ONS Topics), Events Rules, Monitoring Alarms, Budgets y
# Network Firewall. Esta fase los descubre vía sus APIs dedicadas y los
# fusiona (dedup por OCID) en el inventario, conservando el mismo esquema de
# campos que la búsqueda global para que fluyan a TODAS las salidas
# (JSON / CSV / ASCII / árbol HTML) sin cambios adicionales.
#
# Desactivable con -NoSupplement. Acota regiones con -SupplementHomeRegionOnly.

function New-SearchLikeItem {
    param(
        [string]$Type, [string]$Id, [string]$Name, [string]$CompId,
        [string]$State, [string]$TimeCreated, [string]$Region, $Freeform, $Defined
    )
    return [pscustomobject]@{
        'resource-type'   = $Type
        'display-name'    = $Name
        'identifier'      = $Id
        'compartment-id'  = $CompId
        'lifecycle-state' = $State
        'region'          = $Region
        'time-created'    = $TimeCreated
        'freeform-tags'   = $Freeform
        'defined-tags'    = $Defined
        '_source'         = 'supplement'
    }
}

if (-not $NoSupplement) {
    Write-Log INFO "Fase suplemento: descubriendo tipos no indexados por Resource Search."
    $preSupCount = $allItems.Count

    # --- Tenancy OCID (raíz) desde los compartments ya encontrados o config ---
    $supTenancy = ""
    foreach ($it in $allItems) {
        if ("$($it.'compartment-id')" -match '^ocid1\.tenancy\.') { $supTenancy = "$($it.'compartment-id')"; break }
    }
    # (Si no se resolvió el tenancy aquí, se intenta más abajo desde el listado
    #  de compartments en subtree, que incluye el compartment-id raíz.)

    # --- Regiones a barrer ---
    $supRegions = @()
    if ($SupplementHomeRegionOnly) {
        $supRegions = @("")   # cadena vacía => región por defecto del perfil
    } else {
        $rs = Invoke-OciJson -Args @("iam","region-subscription","list","--output","json") -AllowEmpty
        if ($rs -and $rs.data) { $supRegions = @($rs.data | ForEach-Object { $_.'region-name' }) }
        if (-not $supRegions -or $supRegions.Count -eq 0) { $supRegions = @("") }
    }
    Write-Log INFO "Suplemento: regiones a barrer = $([string]::Join(', ', ($supRegions | ForEach-Object { if ($_){$_}else{'(default)'} })))"

    # --- Compartments activos (raíz + subtree) ---
    $supComps = New-Object 'System.Collections.Generic.List[string]'
    $compList = $null
    if ($supTenancy) {
        $compList = Invoke-OciJson -Args @("iam","compartment","list","-c",$supTenancy,"--compartment-id-in-subtree","true","--access-level","ACCESSIBLE","--all","--output","json") -AllowEmpty
    }
    if (-not $compList) {
        $compList = Invoke-OciJson -Args @("iam","compartment","list","--compartment-id-in-subtree","true","--access-level","ACCESSIBLE","--all","--output","json") -AllowEmpty
    }
    if ($compList -and $compList.data) {
        foreach ($c in @($compList.data)) {
            if ($c.'lifecycle-state' -eq 'ACTIVE') { [void]$supComps.Add("$($c.id)") }
            if (-not $supTenancy -and "$($c.'compartment-id')" -match '^ocid1\.tenancy\.') { $supTenancy = "$($c.'compartment-id')" }
        }
    }
    if ($supTenancy -and -not $supComps.Contains($supTenancy)) { [void]$supComps.Add($supTenancy) }
    Write-Log INFO "Suplemento: $($supComps.Count) compartments activos."

    # --- Set de OCIDs ya conocidos (para dedup) ---
    $knownOcids = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($it in $allItems) { [void]$knownOcids.Add("$($it.identifier)") }

    # --- Filtro Include/Exclude (reutiliza la semántica del enrichment) ---
    function Sup-WantType([string]$type) {
        $t = Norm($type)
        if ($ExcludeTypes -and ($ExcludeTypes | ForEach-Object { Norm($_) }) -contains $t) { return $false }
        if ($IncludeTypes -and $IncludeTypes.Count -gt 0) {
            $inc = $IncludeTypes | ForEach-Object { Norm($_) }
            if (-not ($inc -contains $t)) { return $false }
        }
        return $true
    }

    # --- Extrae la lista de elementos de una respuesta CLI (data[] o data.items) ---
    function Sup-Items($obj) {
        if (-not $obj -or -not $obj.data) { return @() }
        if ($obj.data.items) { return @($obj.data.items) }
        if ($obj.data -is [System.Array]) { return @($obj.data) }
        return @($obj.data)
    }

    # --- Primer valor no vacío de una lista de posibles nombres de campo ---
    function Sup-Pick($item, [string[]]$names) {
        foreach ($n in $names) {
            $v = $item.$n
            if ($null -ne $v -and "$v".Trim() -ne "") { return "$v" }
        }
        return ""
    }

    $supAdded = 0

    # Especificaciones: tipos region-scoped barridos por compartment o subtree
    $supSpecs = @(
        @{ Type='LogGroup';              Cmd=@('logging','log-group','list');                       Scope='subtree'; SubtreeFlag='--compartmentidinsubtree';      Id=@('id');       Name=@('display-name') }
        @{ Type='Alarm';                 Cmd=@('monitoring','alarm','list');                         Scope='subtree'; SubtreeFlag='--compartment-id-in-subtree';    Id=@('id');       Name=@('display-name') }
        @{ Type='ServiceConnector';      Cmd=@('sch','service-connector','list');                    Scope='comp';    Id=@('id');       Name=@('display-name') }
        @{ Type='OnsTopic';              Cmd=@('ons','topic','list');                                Scope='comp';    Id=@('topic-id','id'); Name=@('name','display-name') }
        @{ Type='EventRule';             Cmd=@('events','rule','list');                              Scope='comp';    Id=@('id');       Name=@('display-name') }
        @{ Type='NetworkFirewall';       Cmd=@('network-firewall','network-firewall','list');        Scope='comp';    Id=@('id');       Name=@('display-name') }
        @{ Type='NetworkFirewallPolicy'; Cmd=@('network-firewall','network-firewall-policy','list'); Scope='comp';    Id=@('id');       Name=@('display-name') }
        @{ Type='Bucket';                Cmd=@('os','bucket','list');                                Scope='bucket';  Id=@('name');     Name=@('name') }
    )

    function Sup-AddItems($spec, $rawItems, [string]$region) {
        $n = 0
        foreach ($it in @($rawItems)) {
            $id = Sup-Pick $it $spec.Id
            if (-not $id) { continue }
            if ($script:knownOcids.Contains($id)) { continue }
            $name = Sup-Pick $it $spec.Name
            $comp = Sup-Pick $it @('compartment-id')
            $state = Sup-Pick $it @('lifecycle-state')
            $tc    = Sup-Pick $it @('time-created')
            $ff    = $it.'freeform-tags'
            $df    = $it.'defined-tags'
            $regForItem = if ($region) { $region } else { Sup-Pick $it @('region') }
            $newItem = New-SearchLikeItem -Type $spec.Type -Id $id -Name $name -CompId $comp -State $state -TimeCreated $tc -Region $regForItem -Freeform $ff -Defined $df
            [void]$allItems.Add($newItem)
            [void]$script:knownOcids.Add($id)
            $n++
        }
        return $n
    }

    foreach ($region in $supRegions) {
        $regLabel = if ($region) { $region } else { "(default)" }

        # Namespace de Object Storage (por región)
        $supNs = $null

        foreach ($spec in $supSpecs) {
            if (-not (Sup-WantType $spec.Type)) { continue }

            switch ($spec.Scope) {
                'subtree' {
                    if (-not $supTenancy) { continue }
                    $a = @() + $spec.Cmd + @("-c",$supTenancy,$spec.SubtreeFlag,"true","--all","--output","json")
                    $resp = Invoke-OciJson -Args (Add-Region $a $region) -AllowEmpty
                    $added = Sup-AddItems $spec (Sup-Items $resp) $region
                    if ($added -gt 0) { Write-Log INFO "Suplemento [$regLabel] $($spec.Type): +$added" }
                }
                'comp' {
                    $added = 0
                    foreach ($comp in $supComps) {
                        $a = @() + $spec.Cmd + @("-c",$comp,"--all","--output","json")
                        $resp = Invoke-OciJson -Args (Add-Region $a $region) -AllowEmpty
                        $added += Sup-AddItems $spec (Sup-Items $resp) $region
                    }
                    if ($added -gt 0) { Write-Log INFO "Suplemento [$regLabel] $($spec.Type): +$added" }
                }
                'bucket' {
                    if (-not $supNs) {
                        $nsResp = Invoke-OciJson -Args (Add-Region @("os","ns","get","--output","json") $region) -AllowEmpty
                        if ($nsResp -and $nsResp.data) { $supNs = "$($nsResp.data)" }
                    }
                    if (-not $supNs) { continue }
                    $added = 0
                    foreach ($comp in $supComps) {
                        $a = @() + $spec.Cmd + @("-c",$comp,"-ns",$supNs,"--all","--output","json")
                        $resp = Invoke-OciJson -Args (Add-Region $a $region) -AllowEmpty
                        $added += Sup-AddItems $spec (Sup-Items $resp) $region
                    }
                    if ($added -gt 0) { Write-Log INFO "Suplemento [$regLabel] $($spec.Type): +$added" }
                }
            }
        }

        # Budgets: ámbito tenancy, independiente de región (se barre una sola vez)
        if ($region -eq $supRegions[0] -and (Sup-WantType 'Budget') -and $supTenancy) {
            $bResp = Invoke-OciJson -Args @("budgets","budget","budget","list","-c",$supTenancy,"--all","--output","json") -AllowEmpty
            $spec  = @{ Type='Budget'; Id=@('id'); Name=@('display-name') }
            $added = Sup-AddItems $spec (Sup-Items $bResp) ""
            if ($added -gt 0) { Write-Log INFO "Suplemento Budget: +$added" }
        }
    }

    $supAdded = $allItems.Count - $preSupCount
    Write-Log INFO "Fase suplemento completada. Recursos añadidos: $supAdded. Total tras suplemento: $($allItems.Count)"
} else {
    Write-Log INFO "Fase suplemento omitida (-NoSupplement)."
}

$final = [pscustomobject]@{ data = $allItems.ToArray() }
$final | ConvertTo-Json -Depth 30 | Out-File $FullJson -Encoding utf8

$items = $allItems.ToArray()
if ($items.Count -eq 0) {
    Write-Log WARN "No se han devuelto recursos (0). Revisa permisos IAM / TBAC."
    exit 0
}

# ===========================================================================
# 3. ENRICHERS POR TIPO
# ===========================================================================

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
                if ($v.'private-ip')    { $privIps   += $v.'private-ip' }
                if ($v.'public-ip')     { $pubIps    += $v.'public-ip' }
                if ($v.'subnet-id')     { $subnetIds += $v.'subnet-id' }
                if ($v.'hostname-label'){ $hostnames += $v.'hostname-label' }
                if ($v.'mac-address')   { $macs      += $v.'mac-address' }
                if ($v.'nsg-ids')       { $nsgs      += @($v.'nsg-ids') }
            }
        }
    }
    $detail["private_ips"]   = (Join-NonEmpty $privIps ",")
    $detail["public_ips"]    = (Join-NonEmpty $pubIps  ",")
    $detail["subnet_ids"]    = (Join-NonEmpty $subnetIds ",")
    $detail["vnic_ids"]      = (Join-NonEmpty $vnicIds ",")
    $detail["hostnames"]     = (Join-NonEmpty $hostnames ",")
    $detail["mac_addresses"] = (Join-NonEmpty $macs ",")
    $detail["nsg_ids"]       = (Join-NonEmpty ($nsgs | Select-Object -Unique) ",")

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
        cidr_blocks                  = (Join-NonEmpty $v.'cidr-blocks' ",")
        ipv6_cidr_blocks             = (Join-NonEmpty $v.'ipv6-cidr-blocks' ",")
        dns_label                    = $v.'dns-label'
        vcn_domain_name              = $v.'vcn-domain-name'
        default_route_table_id       = $v.'default-route-table-id'
        default_security_list_id     = $v.'default-security-list-id'
        default_dhcp_options_id      = $v.'default-dhcp-options-id'
    }
}

# ---------- SUBNET ----------
function Get-SubnetDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","subnet","get","--subnet-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $s = $d.data
    return @{
        cidr_block                = $s.'cidr-block'
        ipv6_cidr_block           = $s.'ipv6-cidr-block'
        vcn_id                    = $s.'vcn-id'
        availability_domain       = $s.'availability-domain'
        prohibit_public_ip        = $s.'prohibit-public-ip-on-vnic'
        prohibit_internet_ingress = $s.'prohibit-internet-ingress'
        route_table_id            = $s.'route-table-id'
        dhcp_options_id           = $s.'dhcp-options-id'
        security_list_ids         = (Join-NonEmpty $s.'security-list-ids' ",")
        dns_label                 = $s.'dns-label'
        subnet_domain_name        = $s.'subnet-domain-name'
        virtual_router_ip         = $s.'virtual-router-ip'
        virtual_router_mac        = $s.'virtual-router-mac'
    }
}

# ---------- VNIC ----------
function Get-VnicDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","vnic","get","--vnic-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $v = $d.data
    return @{
        private_ip             = $v.'private-ip'
        public_ip              = $v.'public-ip'
        subnet_id              = $v.'subnet-id'
        mac_address            = $v.'mac-address'
        nsg_ids                = (Join-NonEmpty $v.'nsg-ids' ",")
        hostname_label         = $v.'hostname-label'
        is_primary             = $v.'is-primary'
        skip_source_dest_check = $v.'skip-source-dest-check'
    }
}

# ---------- LOAD BALANCER ----------
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
        shape_name         = $l.'shape-name'
        is_private         = $l.'is-private'
        ip_addresses       = (Join-NonEmpty $ips ",")
        subnet_ids         = (Join-NonEmpty $l.'subnet-ids' ",")
        nsg_ids            = (Join-NonEmpty $l.'network-security-group-ids' ",")
        listeners          = (Join-NonEmpty ($l.listeners.PSObject.Properties.Name) ",")
        backend_sets       = (Join-NonEmpty ($l.'backend-sets'.PSObject.Properties.Name) ",")
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
        is_private   = $n.'is-private'
        ip_addresses = (Join-NonEmpty $ips ",")
        subnet_id    = $n.'subnet-id'
        nsg_ids      = (Join-NonEmpty $n.'network-security-group-ids' ",")
    }
}

# ---------- DB SYSTEM ----------
function Get-DbSystemDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","system","get","--db-system-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $s = $d.data
    $detail = @{
        shape                = $s.shape
        cpu_core_count       = $s.'cpu-core-count'
        node_count           = $s.'node-count'
        hostname             = $s.hostname
        domain               = $s.domain
        db_version           = $s.version
        database_edition     = $s.'database-edition'
        license_model        = $s.'license-model'
        data_storage_size_gb = $s.'data-storage-size-in-gbs'
        reco_storage_size_gb = $s.'reco-storage-size-in-gb'
        storage_management   = $s.'db-system-options'.'storage-management'
        subnet_id            = $s.'subnet-id'
        backup_subnet_id     = $s.'backup-subnet-id'
        nsg_ids              = (Join-NonEmpty $s.'nsg-ids' ",")
        backup_nsg_ids       = (Join-NonEmpty $s.'backup-network-nsg-ids' ",")
        listener_port        = $s.'listener-port'
        scan_dns_name        = $s.'scan-dns-name'
        scan_ip_ids          = (Join-NonEmpty $s.'scan-ip-ids' ",")
        vip_ids              = (Join-NonEmpty $s.'vip-ids' ",")
        cluster_name         = $s.'cluster-name'
        availability_domain  = $s.'availability-domain'
    }
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
        db_name                  = $a.'db-name'
        db_workload              = $a.'db-workload'
        db_version               = $a.'db-version'
        cpu_core_count           = $a.'cpu-core-count'
        compute_count            = $a.'compute-count'
        compute_model            = $a.'compute-model'
        data_storage_tb          = $a.'data-storage-size-in-tbs'
        data_storage_gb          = $a.'data-storage-size-in-gbs'
        is_free_tier             = $a.'is-free-tier'
        is_dedicated             = $a.'is-dedicated'
        is_mtls_required         = $a.'is-mtls-connection-required'
        license_model            = $a.'license-model'
        infrastructure_type      = $a.'infrastructure-type'
        whitelisted_ips          = (Join-NonEmpty $a.'whitelisted-ips' ",")
        private_endpoint         = $a.'private-endpoint'
        private_endpoint_ip      = $a.'private-endpoint-ip'
        private_endpoint_label   = $a.'private-endpoint-label'
        subnet_id                = $a.'subnet-id'
        nsg_ids                  = (Join-NonEmpty $a.'nsg-ids' ",")
    }
}

# ---------- CLOUD EXADATA INFRASTRUCTURE ----------
function Get-CloudExaInfraDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","cloud-exa-infra","get","--cloud-exa-infra-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $e = $d.data
    return @{
        shape                      = $e.shape
        compute_count              = $e.'compute-count'
        storage_count              = $e.'storage-count'
        total_storage_size_gb      = $e.'total-storage-size-in-gbs'
        available_storage_size_gb  = $e.'available-storage-size-in-gbs'
        availability_domain        = $e.'availability-domain'
    }
}

# ---------- CLOUD VM CLUSTER ----------
function Get-CloudVmClusterDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","cloud-vm-cluster","get","--cloud-vm-cluster-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $c = $d.data
    return @{
        cluster_name           = $c.'cluster-name'
        hostname               = $c.hostname
        domain                 = $c.domain
        cpu_core_count         = $c.'cpu-core-count'
        ocpu_count             = $c.'ocpu-count'
        memory_gb              = $c.'memory-size-in-gbs'
        data_storage_tb        = $c.'data-storage-size-in-tbs'
        node_count             = $c.'node-count'
        gi_version             = $c.'gi-version'
        system_version         = $c.'system-version'
        license_model          = $c.'license-model'
        cloud_exa_infra_id     = $c.'cloud-exadata-infrastructure-id'
        subnet_id              = $c.'subnet-id'
        backup_subnet_id       = $c.'backup-subnet-id'
        nsg_ids                = (Join-NonEmpty $c.'nsg-ids' ",")
        scan_dns_name          = $c.'scan-dns-name'
        scan_ip_ids            = (Join-NonEmpty $c.'scan-ip-ids' ",")
        vip_ids                = (Join-NonEmpty $c.'vip-ids' ",")
    }
}

# ---------- DATABASE ----------
function Get-DatabaseDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("db","database","get","--database-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $x = $d.data
    return @{
        db_name              = $x.'db-name'
        db_unique_name       = $x.'db-unique-name'
        pdb_name             = $x.'pdb-name'
        db_workload          = $x.'db-workload'
        character_set        = $x.'character-set'
        ncharacter_set       = $x.'ncharacter-set'
        db_home_id           = $x.'db-home-id'
        db_system_id         = $x.'db-system-id'
        vm_cluster_id        = $x.'vm-cluster-id'
        connection_strings   = $x.'connection-strings'.'cdb-default'
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
        size_gb             = $v.'size-in-gbs'
        size_mb             = $v.'size-in-mbs'
        vpus_per_gb         = $v.'vpus-per-gb'
        availability_domain = $v.'availability-domain'
        is_hydrated         = $v.'is-hydrated'
        kms_key_id          = $v.'kms-key-id'
        source_type         = $v.'source-details'.type
    }
}

# ---------- BOOT VOLUME ----------
function Get-BootVolumeDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("bv","boot-volume","get","--boot-volume-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $v = $d.data
    return @{
        size_gb             = $v.'size-in-gbs'
        vpus_per_gb         = $v.'vpus-per-gb'
        availability_domain = $v.'availability-domain'
        image_id            = $v.'image-id'
        kms_key_id          = $v.'kms-key-id'
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
        namespace             = $b.namespace
        storage_tier          = $b.'storage-tier'
        public_access_type    = $b.'public-access-type'
        versioning            = $b.versioning
        object_events_enabled = $b.'object-events-enabled'
        replication_enabled   = $b.'replication-enabled'
        kms_key_id            = $b.'kms-key-id'
        auto_tiering          = $b.'auto-tiering'
        approximate_size_gb   = if ($b.'approximate-size') { [math]::Round($b.'approximate-size' / 1GB, 2) } else { $null }
        approximate_count     = $b.'approximate-count'
    }
}

# ---------- FILE SYSTEM ----------
function Get-FsDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("fs","file-system","get","--file-system-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $f = $d.data
    return @{
        availability_domain = $f.'availability-domain'
        metered_bytes       = $f.'metered-bytes'
        kms_key_id          = $f.'kms-key-id'
        is_clone_parent     = $f.'is-clone-parent'
    }
}

# ---------- MOUNT TARGET ----------
function Get-MountTargetDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("fs","mount-target","get","--mount-target-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    $m = $d.data
    return @{
        availability_domain = $m.'availability-domain'
        subnet_id           = $m.'subnet-id'
        nsg_ids             = (Join-NonEmpty $m.'nsg-ids' ",")
        private_ip_ids      = (Join-NonEmpty $m.'private-ip-ids' ",")
        hostname_label      = $m.'hostname-label'
        export_set_id       = $m.'export-set-id'
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

# ---------- GATEWAYS ----------
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
        vcn_id         = $d.data.'vcn-id'
        services       = (Join-NonEmpty ($d.data.services | ForEach-Object { $_.'service-name' }) ",")
        route_table_id = $d.data.'route-table-id'
    }
}
function Get-LpgDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network","local-peering-gateway","get","--local-peering-gateway-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        vcn_id               = $d.data.'vcn-id'
        peer_id              = $d.data.'peer-id'
        peering_status       = $d.data.'peering-status'
        peer_advertised_cidr = $d.data.'peer-advertised-cidr'
        route_table_id       = $d.data.'route-table-id'
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
        vcn_id        = $d.data.'vcn-id'
        ingress_count = ($d.data.'ingress-security-rules' | Measure-Object).Count
        egress_count  = ($d.data.'egress-security-rules'  | Measure-Object).Count
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
        type                = $c.type
    }
}

# ---------- VAULT ----------
function Get-VaultDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("kms","management","vault","get","--vault-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        vault_type          = $d.data.'vault-type'
        crypto_endpoint     = $d.data.'crypto-endpoint'
        management_endpoint = $d.data.'management-endpoint'
        time_created        = $d.data.'time-created'
    }
}

# ---------- BASTION ----------
function Get-BastionDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("bastion","bastion","get","--bastion-id",$r.identifier,"--output","json") $r.region)
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        bastion_type            = $d.data.'bastion-type'
        target_subnet_id        = $d.data.'target-subnet-id'
        target_vcn_id           = $d.data.'target-vcn-id'
        client_cidr_allow_list  = (Join-NonEmpty $d.data.'client-cidr-block-allow-list' ",")
        max_session_ttl_seconds = $d.data.'max-session-ttl-in-seconds'
        dns_proxy_status        = $d.data.'dns-proxy-status'
        private_endpoint_ip     = $d.data.'private-endpoint-ip-address'
    }
}

# ---------- COMPARTMENT ----------
function Get-CompartmentDetail($r) {
    $d = Invoke-OciJson -Args @("iam","compartment","get","--compartment-id",$r.identifier,"--output","json")
    if (-not $d -or -not $d.data) { return @{} }
    return @{
        parent_compartment_id = $d.data.'compartment-id'
        is_accessible         = $d.data.'is-accessible'
        description           = $d.data.description
    }
}

# ---------- OBSERVABILIDAD / SEGURIDAD (tipos del suplemento) ----------

function Get-LogGroupDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("logging","log-group","get","--log-group-id",$r.identifier,"--output","json") $r.region) -AllowEmpty
    $detail = @{}
    if ($d -and $d.data) { $detail.description = $d.data.description }
    # Logs contenidos en el grupo
    $logs = Invoke-OciJson -Args (Add-Region @("logging","log","list","--log-group-id",$r.identifier,"--all","--output","json") $r.region) -AllowEmpty
    if ($logs -and $logs.data) {
        $arr = @($logs.data)
        $detail.logs_count = $arr.Count
        $detail.logs       = (Join-NonEmpty ($arr | ForEach-Object { $_.'display-name' }) ", ")
    }
    return $detail
}

function Get-ServiceConnectorDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("sch","service-connector","get","--service-connector-id",$r.identifier,"--output","json") $r.region) -AllowEmpty
    if (-not $d -or -not $d.data) { return @{} }
    $s = $d.data
    return @{
        source_kind = $s.source.kind
        target_kind = $s.target.kind
        description = $s.description
    }
}

function Get-OnsTopicDetail($r) {
    $subs = Invoke-OciJson -Args (Add-Region @("ons","subscription","list","-c",$r.'compartment-id',"--topic-id",$r.identifier,"--all","--output","json") $r.region) -AllowEmpty
    $detail = @{}
    if ($subs -and $subs.data) {
        $arr = @($subs.data)
        $detail.subscriptions_count    = $arr.Count
        $detail.subscription_protocols = (Join-NonEmpty ($arr | ForEach-Object { $_.protocol } | Sort-Object -Unique) ", ")
    }
    return $detail
}

function Get-EventRuleDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("events","rule","get","--rule-id",$r.identifier,"--output","json") $r.region) -AllowEmpty
    if (-not $d -or -not $d.data) { return @{} }
    $e = $d.data
    return @{
        is_enabled  = $e.'is-enabled'
        condition   = $e.condition
        description = $e.description
    }
}

function Get-AlarmDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("monitoring","alarm","get","--alarm-id",$r.identifier,"--output","json") $r.region) -AllowEmpty
    if (-not $d -or -not $d.data) { return @{} }
    $a = $d.data
    return @{
        namespace            = $a.namespace
        severity             = $a.severity
        is_enabled           = $a.'is-enabled'
        metric_compartment   = $a.'metric-compartment-id'
        destinations         = (Join-NonEmpty $a.destinations ", ")
    }
}

function Get-BudgetDetail($r) {
    $d = Invoke-OciJson -Args @("budgets","budget","budget","get","--budget-id",$r.identifier,"--output","json") -AllowEmpty
    if (-not $d -or -not $d.data) { return @{} }
    $b = $d.data
    return @{
        amount             = $b.amount
        reset_period       = $b.'reset-period'
        target_type        = $b.'target-type'
        actual_spend       = $b.'actual-spend'
        forecasted_spend   = $b.'forecasted-spend'
    }
}

function Get-NetworkFirewallDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network-firewall","network-firewall","get","--network-firewall-id",$r.identifier,"--output","json") $r.region) -AllowEmpty
    if (-not $d -or -not $d.data) { return @{} }
    $f = $d.data
    return @{
        subnet_id              = $f.'subnet-id'
        ipv4_address           = $f.'ipv4-address'
        network_firewall_policy_id = $f.'network-firewall-policy-id'
        availability_domain    = (Join-NonEmpty $f.'availability-domain' ", ")
    }
}

function Get-NetworkFirewallPolicyDetail($r) {
    $d = Invoke-OciJson -Args (Add-Region @("network-firewall","network-firewall-policy","get","--network-firewall-policy-id",$r.identifier,"--output","json") $r.region) -AllowEmpty
    if (-not $d -or -not $d.data) { return @{} }
    return @{ attached_firewalls = (Join-NonEmpty $d.data.'attached-network-firewall-count' ", ") }
}

# ===========================================================================
# 4. DISPATCHER
# ===========================================================================

$EnricherMap = @{
    "instance"                   = ${function:Get-InstanceDetail}
    "vcn"                        = ${function:Get-VcnDetail}
    "subnet"                     = ${function:Get-SubnetDetail}
    "vnic"                       = ${function:Get-VnicDetail}
    "loadbalancer"               = ${function:Get-LoadBalancerDetail}
    "networkloadbalancer"        = ${function:Get-NlbDetail}
    "dbsystem"                   = ${function:Get-DbSystemDetail}
    "autonomousdatabase"         = ${function:Get-AdbDetail}
    "cloudexadatainfrastructure" = ${function:Get-CloudExaInfraDetail}
    "cloudvmcluster"             = ${function:Get-CloudVmClusterDetail}
    "database"                   = ${function:Get-DatabaseDetail}
    "pluggabledatabase"          = ${function:Get-PdbDetail}
    "volume"                     = ${function:Get-BlockVolumeDetail}
    "bootvolume"                 = ${function:Get-BootVolumeDetail}
    "bucket"                     = ${function:Get-BucketDetail}
    "filesystem"                 = ${function:Get-FsDetail}
    "mounttarget"                = ${function:Get-MountTargetDetail}
    "drg"                        = ${function:Get-DrgDetail}
    "internetgateway"            = ${function:Get-IgwDetail}
    "natgateway"                 = ${function:Get-NatDetail}
    "servicegateway"             = ${function:Get-SgwDetail}
    "localpeeringgateway"        = ${function:Get-LpgDetail}
    "routetable"                 = ${function:Get-RouteTableDetail}
    "securitylist"               = ${function:Get-SecurityListDetail}
    "networksecuritygroup"       = ${function:Get-NsgDetail}
    "cluster"                    = ${function:Get-OkeClusterDetail}
    "vault"                      = ${function:Get-VaultDetail}
    "bastion"                    = ${function:Get-BastionDetail}
    "compartment"                = ${function:Get-CompartmentDetail}
    "loggroup"                   = ${function:Get-LogGroupDetail}
    "serviceconnector"           = ${function:Get-ServiceConnectorDetail}
    "onstopic"                   = ${function:Get-OnsTopicDetail}
    "eventrule"                  = ${function:Get-EventRuleDetail}
    "alarm"                      = ${function:Get-AlarmDetail}
    "budget"                     = ${function:Get-BudgetDetail}
    "networkfirewall"            = ${function:Get-NetworkFirewallDetail}
    "networkfirewallpolicy"      = ${function:Get-NetworkFirewallPolicyDetail}
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
    $type  = Norm($r.'resource-type')
    $extra = @{}

    if (ShouldEnrich $type) {
        try {
            $fn    = $EnricherMap[$type]
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
        resource_type   = $r.'resource-type'
        display_name    = $r.'display-name'
        region          = $r.region
        lifecycle_state = $r.'lifecycle-state'
        compartment_id  = $r.'compartment-id'
        ocid            = $r.identifier
        time_created    = $r.'time-created'
        freeform_tags   = ($r.'freeform-tags' | ConvertTo-Json -Compress -Depth 5)
        defined_tags    = ($r.'defined-tags'  | ConvertTo-Json -Compress -Depth 5)
    }
    foreach ($k in $extra.Keys) { $merged[$k] = $extra[$k] }
    [void]$enriched.Add([pscustomobject]$merged)

    if ($i % 25 -eq 0 -or $i -eq $total) {
        Write-Progress -Activity "Enriqueciendo recursos" -Status "$i / $total (ok=$ok skip=$skip fail=$fail)" -PercentComplete (($i/$total)*100)
    }
}
Write-Progress -Activity "Enriqueciendo recursos" -Completed
Write-Log INFO "Enrichment finalizado. ok=$ok skip=$skip fail=$fail"

[pscustomobject]@{ generated_at = (Get-Date).ToString("o"); count = $enriched.Count; data = $enriched.ToArray() } |
    ConvertTo-Json -Depth 30 | Out-File $EnrichedJson -Encoding utf8

# ===========================================================================
# 6. RESUMEN POR TIPO + ASCII
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
    $hdr  = "|"
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
            $row  += " " + (Format-Cell $value $col.Width) + " |"
        }
        $null = $sb.AppendLine($row)
    }
    $null = $sb.AppendLine($line)
}
$sb.ToString() | Out-File $AsciiTxt -Encoding utf8

# ===========================================================================
# 7. CSV ENRIQUECIDO POR TIPO
# ===========================================================================

$byType = $enriched | Group-Object -Property resource_type
foreach ($g in $byType) {
    $typeSafe = ($g.Name -replace '[^a-zA-Z0-9\-_]', '_')
    if (-not $typeSafe) { $typeSafe = "untyped" }
    $csvPath = Join-Path $CsvDir "$typeSafe.csv"
    $cols    = New-Object System.Collections.Generic.List[string]
    foreach ($obj in $g.Group) {
        foreach ($p in $obj.PSObject.Properties.Name) {
            if (-not $cols.Contains($p)) { [void]$cols.Add($p) }
        }
    }
    $g.Group | Select-Object $cols | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
}

$enriched | Select-Object resource_type,display_name,region,lifecycle_state,compartment_id,ocid,time_created |
    Export-Csv -Path $FlatCsv -NoTypeInformation -Encoding utf8

# ===========================================================================
# 8. HTML — ÁRBOL JERÁRQUICO (v2.2)
# ===========================================================================
if ($Html) {

    # -----------------------------------------------------------------------
    # 8a. Construir índices
    # -----------------------------------------------------------------------
    $tIdx_ByOcid       = @{}   # ocid          -> enriched resource
    $tIdx_ByType       = @{}   # resource_type -> [list]
    $tIdx_ByComp       = @{}   # compartment_id -> [list]
    $tIdx_ByVcn        = @{}   # vcn_id         -> [list]
    $tIdx_CompMap      = @{}   # compartment ocid -> enriched compartment
    $tIdx_DomainByUser = @{}   # user ocid -> domain display name

    foreach ($r in $enriched) {
        $o = "$($r.ocid)"
        if ($o) { $tIdx_ByOcid[$o] = $r }

        $t = "$($r.resource_type)"
        if (-not $tIdx_ByType.ContainsKey($t)) {
            $tIdx_ByType[$t] = [System.Collections.Generic.List[object]]::new()
        }
        [void]$tIdx_ByType[$t].Add($r)

        $c = "$($r.compartment_id)"
        if (-not $tIdx_ByComp.ContainsKey($c)) {
            $tIdx_ByComp[$c] = [System.Collections.Generic.List[object]]::new()
        }
        [void]$tIdx_ByComp[$c].Add($r)

        $v = "$($r.vcn_id)"
        if ($v -and $v -ne "") {
            if (-not $tIdx_ByVcn.ContainsKey($v)) {
                $tIdx_ByVcn[$v] = [System.Collections.Generic.List[object]]::new()
            }
            [void]$tIdx_ByVcn[$v].Add($r)
        }

        if ($t -eq "Compartment" -and $o) { $tIdx_CompMap[$o] = $r }
    }

    # Domain info para Users (desde items raw que tienen identity-context)
    foreach ($fi in $items) {
        if ($fi.'resource-type' -eq 'User') {
            $ic = $fi.'identity-context'
            if ($ic -and $ic.domainDisplayName) {
                $tIdx_DomainByUser["$($fi.identifier)"] = $ic.domainDisplayName
            }
        }
    }

    # Tenancy OCID
    $tIdx_TenancyOcid = ""
    foreach ($r in $enriched) {
        if ($r.compartment_id -match '^ocid1\.tenancy\.') {
            $tIdx_TenancyOcid = "$($r.compartment_id)"
            break
        }
    }
    if (-not $tIdx_TenancyOcid) {
        foreach ($c in $tIdx_CompMap.Values) {
            if ($c.compartment_id -match '^ocid1\.tenancy\.') {
                $tIdx_TenancyOcid = "$($c.compartment_id)"
                break
            }
        }
    }

    # -----------------------------------------------------------------------
    # 8b. Funciones helper HTML
    # -----------------------------------------------------------------------

    function TH_Esc([string]$s) {
        if (-not $s) { return "" }
        return $s.Replace("&","&amp;").Replace("<","&lt;").Replace(">","&gt;").Replace('"',"&quot;")
    }

    function TH_Badge([string]$state) {
        if (-not $state -or $state.Trim() -eq "") { return "" }
        $cls = switch -Regex ($state.ToUpper()) {
            "^(ACTIVE|AVAILABLE|RUNNING|ATTACHED|CREATED|PROVISIONED|ENABLED|PENDINGPROVIDER)$" { "bk" }
            "^(DELET|TERMINAT|INACTIVE|FAILED)"                                                   { "be" }
            default                                                                               { "bw" }
        }
        return "<span class='b $cls'>$(TH_Esc $state)</span>"
    }

    function TH_AttrRows($r, [string[]]$extraSkip = @()) {
        $skip = @('resource_type','display_name','freeform_tags','defined_tags') + $extraSkip
        $rows = New-Object System.Text.StringBuilder
        foreach ($p in $r.PSObject.Properties.Name) {
            if ($skip -contains $p) { continue }
            $v = "$($r.$p)"
            if (-not $v -or $v.Trim() -eq "") { continue }
            $null = $rows.Append("<tr><td class='ak'>$(TH_Esc $p)</td><td>$(TH_Esc $v)</td></tr>")
        }
        $s = $rows.ToString()
        if (-not $s) { return "" }
        return "<table class='at'>$s</table>"
    }

    function TH_LeafNode($r, [string]$icon = "&#128196;") {
        $nm  = TH_Esc "$($r.display_name)"
        $tp  = TH_Esc "$($r.resource_type)"
        $st  = TH_Badge "$($r.lifecycle_state)"
        $oid = TH_Esc "$($r.ocid)"
        $at  = TH_AttrRows $r
        $chi = if ($at) { "<div class='chi'>$at</div>" } else { "" }
        return "<details class='rs'><summary>$icon <b>$nm</b> <em class='rt'>$tp</em> $st<span class='oid'>$oid</span></summary>$chi</details>"
    }

    function TH_CatSection([string]$title, [string]$icon, $resources, [string]$extraCls = "") {
        if (-not $resources) { return "" }
        $arr = @($resources)
        if ($arr.Count -eq 0) { return "" }
        $inner = New-Object System.Text.StringBuilder
        foreach ($r in $arr) { $null = $inner.Append((TH_LeafNode $r $icon)) }
        return "<details class='cat $extraCls'><summary>$icon $title <span class='cnt'>$($arr.Count)</span></summary><div class='chi'>$($inner.ToString())</div></details>"
    }

    # -----------------------------------------------------------------------
    # 8c. Árbol de VCN
    # -----------------------------------------------------------------------

    function TH_VcnTree($vcn) {
        $vOcid = "$($vcn.ocid)"
        $nm    = TH_Esc "$($vcn.display_name)"
        $cidr  = TH_Esc "$($vcn.cidr_blocks)"
        $st    = TH_Badge "$($vcn.lifecycle_state)"
        $at    = TH_AttrRows $vcn

        $vcnRes = if ($tIdx_ByVcn.ContainsKey($vOcid)) { @($tIdx_ByVcn[$vOcid]) } else { @() }
        $inner  = New-Object System.Text.StringBuilder
        if ($at) { $null = $inner.Append("<div class='chi'>$at</div>") }

        # Subnets
        $subnets = @($vcnRes | Where-Object { $_.resource_type -eq "Subnet" } | Sort-Object display_name)
        foreach ($sn in $subnets) {
            $snNm   = TH_Esc "$($sn.display_name)"
            $snCidr = TH_Esc "$($sn.cidr_block)"
            $snSt   = TH_Badge "$($sn.lifecycle_state)"
            $snAt   = TH_AttrRows $sn
            $snIn   = New-Object System.Text.StringBuilder
            if ($snAt) { $null = $snIn.Append("<div class='chi'>$snAt</div>") }

            # Security Lists enlazadas
            if ($sn.security_list_ids -and "$($sn.security_list_ids)" -ne "") {
                $slIds  = ("$($sn.security_list_ids)" -split ",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                $slRefs = @($slIds | ForEach-Object { if ($tIdx_ByOcid.ContainsKey($_)) { $tIdx_ByOcid[$_] } } | Where-Object { $_ -ne $null })
                if ($slRefs.Count -gt 0) { $null = $snIn.Append((TH_CatSection "Security Lists" "&#128737;" $slRefs)) }
            }
            # Route Table enlazada
            if ($sn.route_table_id -and "$($sn.route_table_id)" -ne "") {
                $rtId = "$($sn.route_table_id)".Trim()
                if ($tIdx_ByOcid.ContainsKey($rtId)) {
                    $null = $snIn.Append((TH_CatSection "Route Table" "&#128506;" @($tIdx_ByOcid[$rtId])))
                }
            }
            $null = $inner.Append("<details class='sn'><summary>&#128225; <b>$snNm</b> <span class='cidr'>$snCidr</span> $snSt</summary>$($snIn.ToString())</details>")
        }

        # Route Tables (standalone en esta VCN)
        $rts = @($vcnRes | Where-Object { $_.resource_type -eq "RouteTable" } | Sort-Object display_name)
        if ($rts.Count -gt 0) { $null = $inner.Append((TH_CatSection "Route Tables" "&#128506;" $rts)) }

        # Security Lists (standalone)
        $sls = @($vcnRes | Where-Object { $_.resource_type -eq "SecurityList" } | Sort-Object display_name)
        if ($sls.Count -gt 0) { $null = $inner.Append((TH_CatSection "Security Lists" "&#128737;" $sls)) }

        # NSG
        $nsgs = @($vcnRes | Where-Object { $_.resource_type -eq "NetworkSecurityGroup" } | Sort-Object display_name)
        if ($nsgs.Count -gt 0) { $null = $inner.Append((TH_CatSection "NSG" "&#128274;" $nsgs)) }

        # Gateways
        $gwTypes = @("InternetGateway","NatGateway","ServiceGateway","LocalPeeringGateway")
        $gws = @($vcnRes | Where-Object { $_.resource_type -in $gwTypes } | Sort-Object resource_type,display_name)
        if ($gws.Count -gt 0) { $null = $inner.Append((TH_CatSection "Gateways" "&#128682;" $gws)) }

        # DHCP Options
        $dhcps = @($vcnRes | Where-Object { $_.resource_type -eq "DHCPOptions" } | Sort-Object display_name)
        if ($dhcps.Count -gt 0) { $null = $inner.Append((TH_CatSection "DHCP Options" "&#9881;" $dhcps)) }

        return "<details class='vcn'><summary>&#128376; <b>$nm</b> <span class='cidr'>$cidr</span> $st</summary>$($inner.ToString())</details>"
    }

    # -----------------------------------------------------------------------
    # 8d. Contenido de compartment
    # -----------------------------------------------------------------------

    function TH_CompContent([string]$compOcid) {
        $allRes = if ($tIdx_ByComp.ContainsKey($compOcid)) { @($tIdx_ByComp[$compOcid]) } else { @() }
        $allRes = @($allRes | Where-Object { $_.resource_type -ne "Compartment" })
        if ($allRes.Count -eq 0) { return "" }
        $html = New-Object System.Text.StringBuilder

        # ---- Networking ----
        $netTypes = @("Vcn","Subnet","RouteTable","SecurityList","NetworkSecurityGroup",
                      "Drg","DrgAttachment","DrgRouteTable","DrgRouteDistribution",
                      "InternetGateway","NatGateway","ServiceGateway","LocalPeeringGateway",
                      "DHCPOptions","VirtualCircuit","PublicIp",
                      "DnsResolver","DnsView","CustomerDnsZone")
        $netRes = @($allRes | Where-Object { $_.resource_type -in $netTypes })
        if ($netRes.Count -gt 0) {
            $nI = New-Object System.Text.StringBuilder

            # DRGs
            $drgs = @($netRes | Where-Object { $_.resource_type -eq "Drg" } | Sort-Object display_name)
            foreach ($drg in $drgs) {
                $dNm = TH_Esc "$($drg.display_name)"
                $dSt = TH_Badge "$($drg.lifecycle_state)"
                $dAt = TH_AttrRows $drg
                $dI  = New-Object System.Text.StringBuilder
                if ($dAt) { $null = $dI.Append("<div class='chi'>$dAt</div>") }
                $drgAtts = @($netRes | Where-Object { $_.resource_type -eq "DrgAttachment" })
                $drgRTs  = @($netRes | Where-Object { $_.resource_type -eq "DrgRouteTable" })
                $drgRDs  = @($netRes | Where-Object { $_.resource_type -eq "DrgRouteDistribution" })
                if ($drgAtts.Count -gt 0) { $null = $dI.Append((TH_CatSection "Attachments"       "&#128279;" $drgAtts)) }
                if ($drgRTs.Count  -gt 0) { $null = $dI.Append((TH_CatSection "Route Tables"      "&#128506;" $drgRTs))  }
                if ($drgRDs.Count  -gt 0) { $null = $dI.Append((TH_CatSection "Route Distributions" "&#128228;" $drgRDs)) }
                $null = $nI.Append("<details class='drg'><summary>&#128268; <b>$dNm</b> [DRG] $dSt</summary>$($dI.ToString())</details>")
            }

            # VCNs
            $vcns = @($netRes | Where-Object { $_.resource_type -eq "Vcn" } | Sort-Object display_name)
            foreach ($vcn in $vcns) { $null = $nI.Append((TH_VcnTree $vcn)) }

            # FastConnect / VirtualCircuit
            $vcs = @($netRes | Where-Object { $_.resource_type -eq "VirtualCircuit" })
            if ($vcs.Count -gt 0) { $null = $nI.Append((TH_CatSection "FastConnect" "&#9889;" $vcs)) }

            # Public IPs
            $pips = @($netRes | Where-Object { $_.resource_type -eq "PublicIp" })
            if ($pips.Count -gt 0) { $null = $nI.Append((TH_CatSection "Public IPs" "&#127757;" $pips)) }

            # DNS
            $dnsRes = @($netRes | Where-Object { $_.resource_type -in @("DnsResolver","DnsView","CustomerDnsZone") } | Sort-Object resource_type,display_name)
            if ($dnsRes.Count -gt 0) { $null = $nI.Append((TH_CatSection "DNS" "&#128269;" $dnsRes)) }

            $null = $html.Append("<details class='cat net'><summary>&#127760; Networking <span class='cnt'>$($netRes.Count)</span></summary><div class='chi'>$($nI.ToString())</div></details>")
        }

        # ---- Compute ----
        $computeTypes = @("Instance","BootVolume","Volume","Image","BootVolumeBackup","VolumeBackup","VolumeGroup")
        $computeRes   = @($allRes | Where-Object { $_.resource_type -in $computeTypes })
        if ($computeRes.Count -gt 0) {
            $cI = New-Object System.Text.StringBuilder
            $instances = @($computeRes | Where-Object { $_.resource_type -eq "Instance" } | Sort-Object display_name)
            foreach ($inst in $instances) {
                $iNm = TH_Esc "$($inst.display_name)"
                $iSh = TH_Esc "$($inst.shape)"
                $iSt = TH_Badge "$($inst.lifecycle_state)"
                $iAt = TH_AttrRows $inst
                $iI  = New-Object System.Text.StringBuilder
                if ($iAt) { $null = $iI.Append("<div class='chi'>$iAt</div>") }
                if ($inst.boot_volume_ids -and "$($inst.boot_volume_ids)" -ne "") {
                    $bvList = @(("$($inst.boot_volume_ids)" -split ",") | ForEach-Object { $id = $_.Trim(); if ($tIdx_ByOcid.ContainsKey($id)) { $tIdx_ByOcid[$id] } } | Where-Object { $_ })
                    if ($bvList.Count -gt 0) { $null = $iI.Append((TH_CatSection "Boot Volume" "&#128190;" $bvList)) }
                }
                if ($inst.block_volume_ids -and "$($inst.block_volume_ids)" -ne "") {
                    $blkList = @(("$($inst.block_volume_ids)" -split ",") | ForEach-Object { $id = $_.Trim(); if ($tIdx_ByOcid.ContainsKey($id)) { $tIdx_ByOcid[$id] } } | Where-Object { $_ })
                    if ($blkList.Count -gt 0) { $null = $iI.Append((TH_CatSection "Block Volumes" "&#128191;" $blkList)) }
                }
                $null = $cI.Append("<details class='rs'><summary>&#128187; <b>$iNm</b> <em class='rt'>Instance</em> <span class='shape'>$iSh</span> $iSt</summary>$($iI.ToString())</details>")
            }
            $stVols = @($computeRes | Where-Object { $_.resource_type -in @("BootVolume","Volume") })
            if ($stVols.Count -gt 0) { $null = $cI.Append((TH_CatSection "Volumes" "&#128190;" $stVols)) }
            $null = $html.Append("<details class='cat cmp'><summary>&#128187; Compute <span class='cnt'>$($computeRes.Count)</span></summary><div class='chi'>$($cI.ToString())</div></details>")
        }

        # ---- Base de Datos ----
        $dbTypes = @("DbSystem","AutonomousDatabase","CloudExadataInfrastructure","CloudVmCluster","Database","PluggableDatabase","DbHome","DbNode")
        $dbRes   = @($allRes | Where-Object { $_.resource_type -in $dbTypes })
        if ($dbRes.Count -gt 0) {
            $dI = New-Object System.Text.StringBuilder
            # DB Systems
            $dbSystems = @($dbRes | Where-Object { $_.resource_type -eq "DbSystem" } | Sort-Object display_name)
            foreach ($dbs in $dbSystems) {
                $dbsNm = TH_Esc "$($dbs.display_name)"
                $dbsSh = TH_Esc "$($dbs.shape)"
                $dbsSt = TH_Badge "$($dbs.lifecycle_state)"
                $dbsAt = TH_AttrRows $dbs
                $dbsI  = New-Object System.Text.StringBuilder
                if ($dbsAt) { $null = $dbsI.Append("<div class='chi'>$dbsAt</div>") }
                $databases = @($dbRes | Where-Object { $_.resource_type -eq "Database" -and "$($_.db_system_id)" -eq "$($dbs.ocid)" })
                foreach ($db in $databases) {
                    $dbNm = TH_Esc "$($db.display_name)"
                    $dbSt = TH_Badge "$($db.lifecycle_state)"
                    $dbAt = TH_AttrRows $db
                    $dbI2 = New-Object System.Text.StringBuilder
                    if ($dbAt) { $null = $dbI2.Append("<div class='chi'>$dbAt</div>") }
                    $pdbs = @($dbRes | Where-Object { $_.resource_type -eq "PluggableDatabase" -and "$($_.container_db_id)" -eq "$($db.ocid)" })
                    if ($pdbs.Count -gt 0) { $null = $dbI2.Append((TH_CatSection "PDBs" "&#128230;" $pdbs)) }
                    $null = $dbsI.Append("<details class='rs'><summary>&#128202; <b>$dbNm</b> [DB] $dbSt</summary>$($dbI2.ToString())</details>")
                }
                $null = $dI.Append("<details class='rs'><summary>&#128220; <b>$dbsNm</b> <em class='rt'>DbSystem</em> <span class='shape'>$dbsSh</span> $dbsSt</summary>$($dbsI.ToString())</details>")
            }
            # ADB
            $adbs = @($dbRes | Where-Object { $_.resource_type -eq "AutonomousDatabase" } | Sort-Object display_name)
            if ($adbs.Count -gt 0) { $null = $dI.Append((TH_CatSection "Autonomous Database" "&#9729;" $adbs)) }
            # ExaCS Infra → VM Clusters
            $exas = @($dbRes | Where-Object { $_.resource_type -eq "CloudExadataInfrastructure" } | Sort-Object display_name)
            foreach ($exa in $exas) {
                $exaNm = TH_Esc "$($exa.display_name)"
                $exaSt = TH_Badge "$($exa.lifecycle_state)"
                $exaAt = TH_AttrRows $exa
                $exaI  = New-Object System.Text.StringBuilder
                if ($exaAt) { $null = $exaI.Append("<div class='chi'>$exaAt</div>") }
                $clusters = @($dbRes | Where-Object { $_.resource_type -eq "CloudVmCluster" -and "$($_.cloud_exa_infra_id)" -eq "$($exa.ocid)" })
                foreach ($cl in $clusters) {
                    $clNm = TH_Esc "$($cl.display_name)"
                    $clSt = TH_Badge "$($cl.lifecycle_state)"
                    $clAt = TH_AttrRows $cl
                    $clChi = if ($clAt) { "<div class='chi'>$clAt</div>" } else { "" }
                    $null = $exaI.Append("<details class='rs'><summary>&#127959; <b>$clNm</b> [VM Cluster] $clSt</summary>$clChi</details>")
                }
                $null = $dI.Append("<details class='rs'><summary>&#9889; <b>$exaNm</b> [ExaCS Infra] $exaSt</summary>$($exaI.ToString())</details>")
            }
            $null = $html.Append("<details class='cat db'><summary>&#128220; Base de Datos <span class='cnt'>$($dbRes.Count)</span></summary><div class='chi'>$($dI.ToString())</div></details>")
        }

        # ---- Almacenamiento ----
        $storTypes = @("Bucket","FileSystem","MountTarget","ExportSet","Export")
        $storRes   = @($allRes | Where-Object { $_.resource_type -in $storTypes })
        if ($storRes.Count -gt 0) {
            $sI = New-Object System.Text.StringBuilder
            $fss = @($storRes | Where-Object { $_.resource_type -eq "FileSystem" } | Sort-Object display_name)
            foreach ($fs in $fss) {
                $fsNm = TH_Esc "$($fs.display_name)"
                $fsSt = TH_Badge "$($fs.lifecycle_state)"
                $fsAt = TH_AttrRows $fs
                $fsI  = if ($fsAt) { "<div class='chi'>$fsAt</div>" } else { "" }
                $mts  = @($storRes | Where-Object { $_.resource_type -eq "MountTarget" })
                $mtsH = if ($mts.Count -gt 0) { TH_CatSection "Mount Targets" "&#128204;" $mts } else { "" }
                $null = $sI.Append("<details class='rs'><summary>&#128193; <b>$fsNm</b> [FileSystem] $fsSt</summary>$fsI$mtsH</details>")
            }
            $buckets = @($storRes | Where-Object { $_.resource_type -eq "Bucket" } | Sort-Object display_name)
            if ($buckets.Count -gt 0) { $null = $sI.Append((TH_CatSection "Object Storage" "&#128165;" $buckets)) }
            $null = $html.Append("<details class='cat stor'><summary>&#128190; Almacenamiento <span class='cnt'>$($storRes.Count)</span></summary><div class='chi'>$($sI.ToString())</div></details>")
        }

        # ---- Aplicaciones / Servicios ----
        $appTypes = @("Cluster","LoadBalancer","NetworkLoadBalancer","ApiGateway","FunctionsApplication")
        $appRes   = @($allRes | Where-Object { $_.resource_type -in $appTypes })
        if ($appRes.Count -gt 0) { $null = $html.Append((TH_CatSection "Aplicaciones / Servicios" "&#9881;" $appRes)) }

        # ---- Seguridad ----
        $secTypes = @("Vault","Bastion","Key","Secret","NetworkFirewall","NetworkFirewallPolicy")
        $secRes   = @($allRes | Where-Object { $_.resource_type -in $secTypes })
        if ($secRes.Count -gt 0) { $null = $html.Append((TH_CatSection "Seguridad" "&#128274;" $secRes)) }

        # ---- Observabilidad (Logging / Monitorización / Notificaciones) ----
        $obsTypes = @("LogGroup","Log","ServiceConnector","Alarm","OnsTopic","OnsSubscription","EventRule")
        $obsRes   = @($allRes | Where-Object { $_.resource_type -in $obsTypes } | Sort-Object resource_type,display_name)
        if ($obsRes.Count -gt 0) { $null = $html.Append((TH_CatSection "Observabilidad" "&#128202;" $obsRes)) }

        # ---- Governance ----
        $govTypes = @("Policy","TagNamespace","TagDefault","Budget")
        $govRes   = @($allRes | Where-Object { $_.resource_type -in $govTypes })
        if ($govRes.Count -gt 0) { $null = $html.Append((TH_CatSection "Governance" "&#128203;" $govRes)) }

        # ---- Otros (no categorizados) ----
        $handledTypes = $netTypes + $computeTypes + $dbTypes + $storTypes + $appTypes + $secTypes + $obsTypes + $govTypes + @("Compartment")
        $otherRes = @($allRes | Where-Object { $_.resource_type -notin $handledTypes })
        if ($otherRes.Count -gt 0) { $null = $html.Append((TH_CatSection "Otros" "&#128230;" $otherRes)) }

        return $html.ToString()
    }

    # -----------------------------------------------------------------------
    # 8e. Compartment recursivo
    # -----------------------------------------------------------------------

    function TH_RenderComp([string]$compOcid, [string]$compName, [string]$lifecycle, [string]$description) {
        $st   = TH_Badge $lifecycle
        $desc = if ($description) { "<span class='cdesc'>$(TH_Esc $description)</span>" } else { "" }
        $inner = New-Object System.Text.StringBuilder

        # Recursos de este compartment
        $null = $inner.Append((TH_CompContent $compOcid))

        # Sub-compartments (recursivo, excluye DELETED)
        $subComps = @($tIdx_CompMap.Values |
            Where-Object { "$($_.compartment_id)" -eq $compOcid -and $_.lifecycle_state -ne "DELETED" } |
            Sort-Object display_name)
        foreach ($sub in $subComps) {
            $null = $inner.Append((TH_RenderComp "$($sub.ocid)" "$($sub.display_name)" "$($sub.lifecycle_state)" "$($sub.description)"))
        }

        return "<details class='cmp'><summary>&#128230; <b>$(TH_Esc $compName)</b> $st $desc</summary><div class='chi'>$($inner.ToString())</div></details>"
    }

    # -----------------------------------------------------------------------
    # 8f. Sección IAM (recursos a nivel de tenancy)
    # -----------------------------------------------------------------------

    function TH_RenderIAM() {
        $tenantRes = if ($tIdx_ByComp.ContainsKey($tIdx_TenancyOcid)) { @($tIdx_ByComp[$tIdx_TenancyOcid]) } else { @() }
        $tenantRes = @($tenantRes | Where-Object { $_.resource_type -ne "Compartment" })
        if ($tenantRes.Count -eq 0) { return "" }
        $iI = New-Object System.Text.StringBuilder

        # Aplicaciones de Dominio (OAuth/SAML)
        $apps = @($tenantRes | Where-Object { $_.resource_type -eq "App" } | Sort-Object display_name)
        if ($apps.Count -gt 0) { $null = $iI.Append((TH_CatSection "Aplicaciones de Dominio" "&#128640;" $apps)) }

        # Usuarios agrupados por dominio
        $users = @($tenantRes | Where-Object { $_.resource_type -eq "User" } | Sort-Object display_name)
        if ($users.Count -gt 0) {
            $byDomain = @{}
            foreach ($u in $users) {
                $dn = if ($tIdx_DomainByUser.ContainsKey("$($u.ocid)")) { $tIdx_DomainByUser["$($u.ocid)"] } else { "(sin dominio)" }
                if (-not $byDomain.ContainsKey($dn)) { $byDomain[$dn] = @() }
                $byDomain[$dn] += $u
            }
            $uI = New-Object System.Text.StringBuilder
            foreach ($dn in ($byDomain.Keys | Sort-Object)) {
                $domUsers = @($byDomain[$dn])
                $duH = New-Object System.Text.StringBuilder
                foreach ($u in $domUsers) { $null = $duH.Append((TH_LeafNode $u "&#128100;")) }
                $null = $uI.Append("<details class='dom'><summary>&#127760; <b>$(TH_Esc $dn)</b> <span class='cnt'>$($domUsers.Count)</span></summary><div class='chi'>$($duH.ToString())</div></details>")
            }
            $null = $iI.Append("<details class='cat iam'><summary>&#128100; Usuarios <span class='cnt'>$($users.Count)</span></summary><div class='chi'>$($uI.ToString())</div></details>")
        }

        # Grupos
        $groups = @($tenantRes | Where-Object { $_.resource_type -eq "Group" } | Sort-Object display_name)
        if ($groups.Count -gt 0) { $null = $iI.Append((TH_CatSection "Grupos" "&#128101;" $groups)) }

        # Policies (nivel tenant)
        $policies = @($tenantRes | Where-Object { $_.resource_type -eq "Policy" } | Sort-Object display_name)
        if ($policies.Count -gt 0) { $null = $iI.Append((TH_CatSection "Policies (Tenant)" "&#128203;" $policies)) }

        # Tag Namespaces
        $tagns = @($tenantRes | Where-Object { $_.resource_type -eq "TagNamespace" } | Sort-Object display_name)
        if ($tagns.Count -gt 0) { $null = $iI.Append((TH_CatSection "Tag Namespaces" "&#127991;" $tagns)) }

        # Tag Defaults
        $tagd = @($tenantRes | Where-Object { $_.resource_type -eq "TagDefault" } | Sort-Object display_name)
        if ($tagd.Count -gt 0) { $null = $iI.Append((TH_CatSection "Tag Defaults" "&#127991;" $tagd)) }

        # Otros a nivel tenant
        $iamHandled = @("App","User","Group","Policy","TagNamespace","TagDefault","Compartment")
        $otherT = @($tenantRes | Where-Object { $_.resource_type -notin $iamHandled })
        if ($otherT.Count -gt 0) { $null = $iI.Append((TH_CatSection "Otros (Tenant)" "&#128230;" $otherT)) }

        return "<details class='cat iam-root' open><summary>&#128273; IAM &amp; Identidad <span class='cnt'>$($tenantRes.Count)</span></summary><div class='chi'>$($iI.ToString())</div></details>"
    }

    # -----------------------------------------------------------------------
    # 8g. Construir árbol principal
    # -----------------------------------------------------------------------

    $treeContent = New-Object System.Text.StringBuilder

    # Sección IAM
    $null = $treeContent.Append((TH_RenderIAM))

    # Compartments raíz (hijos directos del tenancy, sin DELETED)
    $rootComps = @($tIdx_CompMap.Values |
        Where-Object { "$($_.compartment_id)" -eq $tIdx_TenancyOcid -and $_.lifecycle_state -ne "DELETED" } |
        Sort-Object display_name)
    foreach ($rc in $rootComps) {
        $null = $treeContent.Append((TH_RenderComp "$($rc.ocid)" "$($rc.display_name)" "$($rc.lifecycle_state)" "$($rc.description)"))
    }

    # -----------------------------------------------------------------------
    # 8h. Ensamblado del HTML final
    # -----------------------------------------------------------------------

    $htmlPage = @"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OCI Inventory &gt; $TS</title>
<style>
/* ═══════════════════════════════════════════════════
   Accenture Brand Palette
   Primary:  #A100FF  (Accenture Purple)
   Black:    #000000
   Grays:    #1A1A1A · #333 · #666 · #999 · #E6E6E6 · #F2F2F2
   Purples:  #7500C0 · #5C0097 · #E5CCFF · #F0E6FF · #F7F2FF
   Status:   #00A36C (green) · #D92B2B (red) · #E06C00 (amber)
════════════════════════════════════════════════════ */
:root {
  --ap:   #A100FF;   /* Accenture Purple — brand primary */
  --ap-d: #7500C0;   /* Dark purple */
  --ap-dd:#5C0097;   /* Deeper purple */
  --ap-l: #E5CCFF;   /* Light purple */
  --ap-xl:#F0E6FF;   /* Extra-light purple */
  --ap-bg:#F7F2FF;   /* Surface purple tint */
  --blk:  #000000;
  --g1:   #1A1A1A;
  --g2:   #333333;
  --g3:   #666666;
  --g4:   #999999;
  --g5:   #CCCCCC;
  --g6:   #E6E6E6;
  --g7:   #F2F2F2;
  --white:#FFFFFF;
  --ok:   #007A53;   /* Status: active/ok */
  --ok-bg:#E6F5EF;
  --err:  #D92B2B;   /* Status: error */
  --err-bg:#FDECEA;
  --warn: #E06C00;   /* Status: warning */
  --warn-bg:#FEF3E6;
}
* { box-sizing:border-box; margin:0; padding:0 }
body {
  font:13.5px/1.5 "Segoe UI","Helvetica Neue",Arial,sans-serif;
  background:var(--g7); color:var(--g1)
}

/* ══ Toolbar ══ */
.tb {
  background:var(--ap); color:var(--white);
  padding:0 20px; height:52px;
  display:flex; align-items:center; gap:12px;
  position:sticky; top:0; z-index:100;
  box-shadow:0 2px 8px rgba(161,0,255,.35)
}
.tb-logo {
  font-size:1.45em; font-weight:900; letter-spacing:-1px;
  line-height:1; margin-right:4px; color:var(--white)
}
.tb-logo span { color:var(--blk); background:var(--white); padding:0 3px; border-radius:2px }
.tb-sep { width:1px; height:24px; background:rgba(255,255,255,.35); flex-shrink:0 }
.tb h1 { font-size:.95em; font-weight:600; white-space:nowrap; letter-spacing:.2px }
#srch {
  flex:1; max-width:300px; padding:6px 14px; border-radius:2px;
  border:none; font-size:13px; outline:none;
  background:rgba(255,255,255,.18); color:var(--white);
}
#srch::placeholder { color:rgba(255,255,255,.65) }
#srch:focus { background:rgba(255,255,255,.28) }
.btn {
  padding:5px 14px; border-radius:2px; border:1px solid rgba(255,255,255,.5);
  cursor:pointer; background:transparent; color:var(--white);
  font-size:12px; font-weight:600; white-space:nowrap; letter-spacing:.3px;
  transition:background .12s
}
.btn:hover { background:rgba(255,255,255,.18) }
.meta { margin-left:auto; font-size:.76em; color:rgba(255,255,255,.75); white-space:nowrap }

/* ══ Tree container ══ */
.tree { padding:14px 18px 60px; max-width:1400px }
details { margin:2px 0 }
summary {
  list-style:none; cursor:pointer; padding:5px 10px; border-radius:2px;
  display:flex; align-items:baseline; gap:6px; flex-wrap:wrap; user-select:none
}
summary::-webkit-details-marker { display:none }
summary::before {
  content:"▶"; font-size:.6em; color:var(--g4);
  transition:transform .12s; min-width:10px; display:inline-block; flex-shrink:0
}
details[open] > summary::before { transform:rotate(90deg) }
summary:hover { background:var(--ap-xl) }

/* ══ Tenant ══ */
details.tenant > summary {
  background:var(--blk); color:var(--white); border-radius:2px;
  font-size:1.05em; font-weight:700; padding:10px 16px;
  letter-spacing:.3px
}
details.tenant > summary::before { color:var(--ap) }
details.tenant > summary:hover   { background:var(--g1) }

/* ══ Compartments ══ */
details.cmp > summary {
  background:var(--white); border-left:3px solid var(--ap);
  font-weight:700; padding:6px 12px; color:var(--g1)
}
details.cmp > summary:hover { background:var(--ap-bg) }

/* ══ Category sections ══ */
details.cat > summary {
  background:var(--ap-bg); border-left:3px solid var(--ap-d);
  font-weight:600; padding:5px 10px
}
details.cat.net   > summary { background:#EEF2FF; border-color:#3730A3 }
details.cat.db    > summary { background:#FFF0F3; border-color:#B91C1C }
details.cat.cmp   > summary { background:#F0FDF4; border-color:#15803D }
details.cat.stor  > summary { background:#FDF4FF; border-color:var(--ap-d) }
details.cat.iam   > summary,
details.cat.iam-root > summary {
  background:var(--blk); color:var(--white); border-left:3px solid var(--ap)
}
details.cat.iam   > summary::before,
details.cat.iam-root > summary::before { color:var(--ap) }
details.cat.iam   > summary:hover,
details.cat.iam-root > summary:hover { background:var(--g1) }

/* ══ VCN ══ */
details.vcn > summary {
  background:var(--ap-xl); border-left:3px solid var(--ap);
  font-weight:600; padding:5px 10px
}
details.vcn > summary:hover { background:var(--ap-l) }

/* ══ Subnet ══ */
details.sn > summary {
  background:#FAF5FF; border-left:3px solid var(--ap-d); padding:4px 10px
}
details.sn > summary:hover { background:var(--ap-xl) }

/* ══ DRG ══ */
details.drg > summary {
  background:#FFFBEB; border-left:3px solid #D97706;
  padding:5px 10px; font-weight:600
}
details.drg > summary:hover { background:#FEF3C7 }

/* ══ Identity Domain ══ */
details.dom > summary {
  background:var(--ap-bg); border-left:2px solid var(--ap-l); padding:4px 10px
}
details.dom > summary:hover { background:var(--ap-xl) }

/* ══ Resource leaf ══ */
details.rs > summary {
  background:var(--white); border-left:2px solid var(--g6);
  padding:3px 10px; font-size:.91em
}
details.rs > summary:hover { background:var(--ap-bg) }

/* ══ Children indent ══ */
.chi { padding-left:18px; border-left:1px dashed var(--ap-l); margin:2px 0 2px 12px }

/* ══ Status badges ══ */
.b  { border-radius:2px; padding:1px 8px; font-size:.72em; font-weight:700;
      margin-left:4px; letter-spacing:.4px; text-transform:uppercase }
.bk { background:var(--ok-bg);   color:var(--ok)  }
.be { background:var(--err-bg);  color:var(--err) }
.bw { background:var(--warn-bg); color:var(--warn)}

/* ══ Count pill ══ */
.cnt { background:var(--ap-l); color:var(--ap-dd); border-radius:10px;
       padding:0 8px; font-size:.76em; font-weight:700;
       margin-left:auto; flex-shrink:0 }
details.cat.iam-root .cnt,
details.cat.iam      .cnt { background:var(--ap); color:var(--white) }

/* ══ Inline metadata ══ */
.rt    { color:var(--g4); font-size:.82em; font-style:italic }
.oid   { font-family:"Consolas","Courier New",monospace; font-size:.66em; color:var(--g5);
         margin-left:5px; overflow:hidden; text-overflow:ellipsis; max-width:280px;
         display:inline-block; white-space:nowrap; vertical-align:middle }
.cidr  { color:var(--g3); font-size:.82em; font-family:"Consolas","Courier New",monospace }
.shape { color:var(--g4); font-size:.82em }
.cdesc { color:var(--g4); font-size:.81em; font-style:italic; margin-left:6px }

/* ══ Attribute table ══ */
.at { border-collapse:collapse; font-size:11.5px; margin:6px 0; width:100%; max-width:880px }
.at td { border:1px solid var(--g6); padding:3px 8px; vertical-align:top }
.at .ak { background:var(--g7); font-weight:600; white-space:nowrap; width:160px;
          color:var(--g2); border-right:2px solid var(--ap-l) }

/* ══ Search ══ */
.hide { display:none !important }

/* ══ Scrollbar (Chromium) ══ */
::-webkit-scrollbar { width:6px; height:6px }
::-webkit-scrollbar-track { background:var(--g7) }
::-webkit-scrollbar-thumb { background:var(--ap-l); border-radius:3px }
::-webkit-scrollbar-thumb:hover { background:var(--ap-d) }
</style>
</head>
<body>

<div class="tb">
  <div class="tb-logo">&gt;</div>
  <div class="tb-sep"></div>
  <h1>OCI Inventory Tree</h1>
  <input id="srch" type="text" placeholder="&#128269; Buscar recursos..." oninput="doSearch(this.value)">
  <button class="btn" onclick="setAll(true)">&#9660; Expandir todo</button>
  <button class="btn" onclick="setAll(false)">&#9654; Colapsar todo</button>
  <span class="meta">
    $TS &nbsp;&middot;&nbsp;
    $($enriched.Count) recursos &nbsp;&middot;&nbsp;
    enriquecidos: $ok &nbsp;&middot;&nbsp;
    omitidos: $skip &nbsp;&middot;&nbsp;
    fallidos: $fail
  </span>
</div>

<div class="tree" id="tree">
<details class="tenant" open>
<summary>&#127968; Tenant <span style="color:var(--ap);font-size:.72em;margin-left:10px;font-weight:400;letter-spacing:.2px">$tIdx_TenancyOcid</span></summary>
<div class="chi">
$($treeContent.ToString())
</div>
</details>
</div>

<script>
function setAll(open) {
  document.querySelectorAll('#tree details').forEach(function(d){ d.open = open; });
  if (!open) { document.querySelector('#tree details.tenant').open = true; }
}

function doSearch(q) {
  var tree = document.getElementById('tree');
  if (!q || q.length < 2) {
    tree.querySelectorAll('.hide').forEach(function(e){ e.classList.remove('hide'); });
    return;
  }
  var lq = q.toLowerCase();
  var all = Array.from(tree.querySelectorAll('details'));
  // Hide everything first
  all.forEach(function(d){ d.classList.add('hide'); });
  // Find matches and reveal them plus all ancestors
  all.forEach(function(d) {
    var txt = d.textContent ? d.textContent.toLowerCase() : '';
    if (txt.indexOf(lq) !== -1) {
      var el = d;
      while (el && el.id !== 'tree') {
        if (el.tagName === 'DETAILS') {
          el.classList.remove('hide');
          el.open = true;
        }
        el = el.parentElement;
      }
    }
  });
}
</script>
</body>
</html>
"@

    $htmlPage | Out-File $HtmlOut -Encoding utf8
    Write-Log INFO "HTML árbol jerárquico generado: $HtmlOut"
}

# ===========================================================================
# 9. RESUMEN FINAL
# ===========================================================================
Write-Log INFO ""
Write-Log INFO "[OK] Inventario v2.2 generado:"
Write-Log INFO " - $SummaryOut"
Write-Log INFO " - $AsciiTxt"
Write-Log INFO " - $FullJson"
Write-Log INFO " - $EnrichedJson"
Write-Log INFO " - $FlatCsv"
Write-Log INFO " - csv\<type>.csv  (un fichero por tipo, en $CsvDir)"
if ($Html) { Write-Log INFO " - $HtmlOut  (árbol jerárquico interactivo)" }
Write-Log INFO " - $LogFile"
