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
  [string]$OutFile  = "foundation_dependencies.auto.tfvars.json"
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
