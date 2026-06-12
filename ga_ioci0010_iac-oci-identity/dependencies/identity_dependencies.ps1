<#
.SYNOPSIS
  Genera identity_dependencies.auto.tfvars.json a partir de los outputs del stack identity.

.DESCRIPTION
  Wrapper que transforma identity_domains_output.json (exportado desde el stack
  ga_ioci0010_iac-oci-identity) al formato auto.tfvars.json consumido por los
  stacks downstream (network, security-svc, etc.).

  Estructura generada:
    {
      "identity_domains_dependency": { "identity_domains": { ... } }
    }

  Rutas resueltas relativamente al directorio del script (.\), por lo que puede
  ejecutarse desde cualquier ubicacion.

.NOTES
  Stack origen : ga_ioci0010_iac-oci-identity
  Consumido por: stacks downstream que referencian identity_domains_dependency
#>

[CmdletBinding()]
param(
  [string]$DepPath = $PSScriptRoot,
  [string]$OutFile = "identity_dependencies.auto.tfvars.json",
  [bool]$DistributeDownstream = $true
)

$ErrorActionPreference = "Stop"

$identityDomainsFile = Join-Path $DepPath "identity_domains_output.json"
$outPath             = Join-Path $DepPath $OutFile

if (-not (Test-Path $identityDomainsFile)) {
  throw "No se encontro el fichero requerido: $identityDomainsFile"
}

$idDomains = Get-Content $identityDomainsFile -Raw | ConvertFrom-Json

$vars = [ordered]@{
  identity_domains_dependency = [ordered]@{
    identity_domains = $idDomains.identity_domains
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
