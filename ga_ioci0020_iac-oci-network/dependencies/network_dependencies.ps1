<#
.SYNOPSIS
  Genera network_dependencies.auto.tfvars.json a partir de los outputs del stack network.

.DESCRIPTION
  Wrapper que transforma network_output.json (exportado desde el stack
  ga_ioci0020_iac-oci-network) al formato auto.tfvars.json consumido por los
  stacks downstream (security-svc, exa-infra, exa-database, obs-*, storage, etc.).

  Estructura generada (misma logica simetrica que foundation_dependencies.ps1 e
  identity_dependencies.ps1: se preserva la clave interna del *_output.json bajo
  el envoltorio *_dependency):
    {
      "network_dependency": { "network_resources": { ... } }
    }

  Rutas resueltas relativamente al directorio del script (.\), por lo que puede
  ejecutarse desde cualquier ubicacion.

.NOTES
  Stack origen : ga_ioci0020_iac-oci-network
  Consumido por: stacks downstream que referencian network_dependency
#>

[CmdletBinding()]
param(
  [string]$DepPath = $PSScriptRoot,
  [string]$OutFile = "network_dependencies.auto.tfvars.json"
)

$ErrorActionPreference = "Stop"

$networkFile = Join-Path $DepPath "network_output.json"
$outPath     = Join-Path $DepPath $OutFile

if (-not (Test-Path $networkFile)) {
  throw "No se encontro el fichero requerido: $networkFile"
}

$net = Get-Content $networkFile -Raw | ConvertFrom-Json

$vars = [ordered]@{
  network_dependency = [ordered]@{
    network_resources = $net.network_resources
  }
}

$vars |
  ConvertTo-Json -Depth 30 |
  Set-Content -Path $outPath -Encoding utf8

Write-Host "Generado: $outPath"
