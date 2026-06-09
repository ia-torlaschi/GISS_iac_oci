param(
    [int]$Limit = 1000
)

$ErrorActionPreference = "Stop"

$QueryText = "query all resources"
$TS = Get-Date -Format "yyyyMMdd_HHmmss"
$OutDir = "oci_inventory_$TS"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$FullJson   = Join-Path $OutDir "inventario_full.json"
$AsciiTxt   = Join-Path $OutDir "inventario_ascii.txt"
$CsvOut     = Join-Path $OutDir "inventario_por_tipo.csv"
$SummaryOut = Join-Path $OutDir "resumen_por_tipo.txt"

$env:OCI_CLI_PAGER = ""
$env:OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING = "True"

Write-Host "[INFO] Generando inventario OCI..."
Write-Host "[INFO] Output dir: $OutDir"

# ---------------------------
# PAGINACIÓN MANUAL
# ---------------------------
$allItems = New-Object 'System.Collections.Generic.List[object]'
$page = $null

do {
    $args = @(
        "search","resource","structured-search",
        "--query-text",$QueryText,
        "--limit","$Limit",
        "--output","json"
    )
    if ($page) { $args += @("--page",$page) }

    $jsonText = (& oci @args | Out-String)

    if ($jsonText.TrimStart() -notmatch '^\{') {
        Write-Host "[ERROR] OCI CLI no devolvió JSON válido. Primeras líneas:"
        Write-Host ($jsonText.Split("`n") | Select-Object -First 12 | Out-String)
        exit 1
    }

    $obj = $jsonText | ConvertFrom-Json

    # Estructura típica: data.items
    if ($obj.data -and $obj.data.items) {
        foreach ($r in @($obj.data.items)) { [void]$allItems.Add($r) }
    }
    # Fallback: algunas salidas pueden traer data como array directo
    elseif ($obj.data -is [System.Array]) {
        foreach ($r in @($obj.data)) { [void]$allItems.Add($r) }
    }

    $page = $obj.'opc-next-page'
} while ($page)

Write-Host "[INFO] Total recursos encontrados: $($allItems.Count)"

# Guardar JSON consolidado
$final = [pscustomobject]@{ data = $allItems.ToArray() }
$final | ConvertTo-Json -Depth 30 | Out-File $FullJson -Encoding utf8

# ---------------------------
# Helpers
# ---------------------------
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

# ✅ Conversión segura a array (FIX del error)
$items = $allItems.ToArray()

if ($items.Count -eq 0) {
    Write-Host "[WARN] No se han devuelto recursos (0). Revisa permisos IAM."
    exit 0
}

# ---------------------------
# AGRUPAR POR TYPE NORMALIZADO
# ---------------------------
$groups = $items |
    Group-Object -Property { Norm($_.'resource-type') } |
    Sort-Object Name

# Resumen por tipo
$groups |
    Sort-Object Count -Descending |
    ForEach-Object {
        $typeDisplay = ($_.Group | Select-Object -First 1).'resource-type'
        if (-not $typeDisplay) { $typeDisplay = "(sin-type)" }
        "{0}`t{1}" -f $_.Count, $typeDisplay
    } | Out-File $SummaryOut -Encoding utf8

# ---------------------------
# TABLA ASCII POR SECCIONES
# ---------------------------
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

# ---------------------------
# CSV ORDENADO (TYPE + NAME + REGION)
# ---------------------------
$sortedAll = $items | Sort-Object `
    @{E={ Norm($_.'resource-type') }}, `
    @{E={ Norm($_.'display-name') }}, `
    @{E={ Norm($_.region) }}

$sortedAll | Select-Object `
    @{N="resource_type";E={$_. 'resource-type'}}, `
    @{N="display_name";E={$_. 'display-name'}}, `
    @{N="region";E={$_.region}}, `
    @{N="lifecycle_state";E={$_. 'lifecycle-state'}}, `
    @{N="compartment_id";E={$_. 'compartment-id'}}, `
    @{N="ocid";E={$_.identifier}} |
    Export-Csv $CsvOut -NoTypeInformation -Encoding utf8

Write-Host ""
Write-Host "[OK] Inventario generado:"
Write-Host " - $SummaryOut"
Write-Host " - $AsciiTxt   (ASCII agrupado por TYPE)"
Write-Host " - $CsvOut"
Write-Host " - $FullJson"