<#
.SYNOPSIS
  Genera foundation_dependencies.auto.tfvars.json a partir de los outputs del stack foundation.

.DESCRIPTION
  Wrapper que combina compartments_output.json y tags_output.json (exportados desde
  el stack ga_ioci0000_iac-oci-foundation) en el formato consumido por los stacks
  consumidores (identity, network, etc.) como auto.tfvars.json.

  Estructura generada:
    {
      "compartments_dependency": { "compartments": { ... } },
      "tags_dependency":         { "tags":         { ... } }
    }

  Rutas resueltas relativamente al directorio del script (.\), por lo que puede
  ejecutarse desde cualquier ubicacion.

.NOTES
  Stack origen : ga_ioci0000_iac-oci-foundation
  Consumido por: ga_ioci0010_iac-oci-identity (y resto de stacks downstream)
#>

[CmdletBinding()]
param(
  [string]$DepPath  = $PSScriptRoot,
  [string]$OutFile  = "foundation_dependencies.auto.tfvars.json",
  [bool]$DistributeDownstream = $true
)

$ErrorActionPreference = "Stop"

$compartmentsFile = Join-Path $DepPath "compartments_output.json"
$tagsFile         = Join-Path $DepPath "tags_output.json"
$outPath          = Join-Path $DepPath $OutFile

foreach ($f in @($compartmentsFile, $tagsFile)) {
  if (-not (Test-Path $f)) {
    throw "No se encontro el fichero requerido: $f"
  }
}

$comp = Get-Content $compartmentsFile -Raw | ConvertFrom-Json
$tags = Get-Content $tagsFile         -Raw | ConvertFrom-Json

$vars = [ordered]@{
  compartments_dependency = [ordered]@{
    compartments = $comp.compartments
  }
  tags_dependency = [ordered]@{
    tags = $tags.tags
  }
}

$vars |
  ConvertTo-Json -Depth 30 |
  Set-Content -Path $outPath -Encoding utf8

Write-Host "Generado: $outPath"

if ($DistributeDownstream) {
  $moduleRoot = Split-Path $DepPath -Parent
  $workspaceRoot = Split-Path $moduleRoot -Parent
  $targets = @(
    "ga_ioci0010_iac-oci-identity",
    "ga_ioci0020_iac-oci-network",
    "ga_ioci0030_iac-oci-security-svc",
    "ga_ioci0040_iac-oci-exa-infra",
    "ga_ioci0041_iac-oci-exa-database",
    "ga_ioci0050_iac-oci-obs-logs",
    "ga_ioci0060_iac-oci-obs-monitor",
    "ga_ioci0070_iac-oci-storage"
  )

  foreach ($target in $targets) {
    $targetDepDir = Join-Path (Join-Path $workspaceRoot $target) "dependencies"
    if (-not (Test-Path $targetDepDir)) {
      Write-Warning "No existe dependencies en modulo destino: $targetDepDir"
      continue
    }

    $targetPath = Join-Path $targetDepDir $OutFile
    Copy-Item -Path $outPath -Destination $targetPath -Force
    Write-Host "Distribuido: $targetPath"
  }
}
