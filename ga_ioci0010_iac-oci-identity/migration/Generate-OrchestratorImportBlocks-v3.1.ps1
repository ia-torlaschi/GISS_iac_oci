<#
.SYNOPSIS
  Genera bloques declarativos Terraform import{} para stacks del OCI Landing Zones Orchestrator.

.DESCRIPTION
  Version universal base para evitar el problema de "state parcial" al usar `terraform import`
  recurso a recurso con modulos que calculan locals sobre colecciones completas.

  Para foundation soporta:
    - oci_identity_tag_namespace
    - oci_identity_tag
    - oci_identity_compartment

  Para identity soporta:
    - oci_identity_domain
    - oci_identity_domains_group
    - oci_identity_policy
    - dependency files del orquestador, especialmente compartments_output.json

  La salida es un fichero .auto.tf temporal con bloques import{}.
  Por defecto NO ejecuta terraform apply. Solo genera el fichero y, opcionalmente,
  ejecuta terraform plan.

  Patron seguro:
    1. Generate
    2. Plan
    3. Revisar que el plan indica solo imports y 0 add/change/destroy
    4. Aplicar manualmente el plan guardado
    5. Borrar el fichero imports.auto.tf

.NOTES
  Revision: Torlaschi Consulting / OCI Architect Professional
  Version: 3.1
  Fecha: 08/05/2026

  Cambios v3.0 auditados:
    - Se abandona `terraform import` imperativo para evitar evaluacion con state parcial.
    - Se generan import blocks declarativos en lote.
    - Se mantiene discovery OCI por CLI.
    - Se omiten direcciones ya presentes en el state.
    - Se separan fases Generate / Plan para evitar apply accidental.
    - Base extensible por ResourceSpec para otros dominios/stacks.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$ConfigPath,

  [Parameter(Mandatory=$true)]
  [string]$TenancyOcid,

  [string]$Profile = "DEFAULT",

  [string[]]$VarFiles = @(),

  [ValidateSet("foundation","identity")]
  [string]$StackType = "foundation",

  [string[]]$DependencyFiles = @(),

  [ValidateSet("Generate","Plan")]
  [string]$Mode = "Generate",

  [string]$OutputImportFile = "",

  [string]$PlanOut = "",

  [switch]$IncludeAlreadyManaged,

  [switch]$NoPrecheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:LogFile = ".\generate_import_blocks_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss")

function Write-Log {
  param(
    [ValidateSet("INFO","OK","WARN","ERROR","DRY")]
    [string]$Level,
    [string]$Message
  )
  $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
  Write-Host $line
  Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
}

function Invoke-Native {
  param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [Parameter(Mandatory=$true)][string[]]$Arguments,
    [switch]$AllowFailure
  )
  $old = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $out = & $FilePath @Arguments 2>&1
    $code = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $old
  }

  $text = ""
  if ($null -ne $out) { $text = ($out | Out-String) }

  if (($code -ne 0) -and (-not $AllowFailure)) {
    throw "Command failed. File=$FilePath ExitCode=$code Args=$($Arguments -join ' ') Output=$text"
  }

  [pscustomobject]@{
    ExitCode = $code
    Output   = $text
  }
}

function Invoke-Oci {
  param([string[]]$Arguments)
  $args = @("--profile", $Profile) + $Arguments
  return Invoke-Native -FilePath "oci" -Arguments $args
}

function Invoke-Terraform {
  param([string[]]$Arguments, [switch]$AllowFailure)
  return Invoke-Native -FilePath "terraform" -Arguments $Arguments -AllowFailure:$AllowFailure
}

function Get-Json {
  param([string]$Path)
  $raw = Get-Content -Path $Path -Raw -Encoding UTF8
  return $raw | ConvertFrom-Json -Depth 100
}

function Get-PropNames {
  param($Object)
  if ($null -eq $Object) { return @() }
  return @($Object.PSObject.Properties.Name)
}

function Get-PropValue {
  param($Object, [string]$Name)
  return $Object.PSObject.Properties[$Name].Value
}

function ConvertTo-HclString {
  param([string]$Value)
  return '"' + ($Value -replace '\\','\\' -replace '"','\"') + '"'
}

function Get-ExistingStateAddresses {
  $result = Invoke-Terraform -Arguments @("state","list") -AllowFailure
  if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Output)) {
    return @{}
  }

  $map = @{}
  foreach ($line in ($result.Output -split "`r?`n")) {
    $trim = $line.Trim()
    if (-not [string]::IsNullOrWhiteSpace($trim)) {
      $map[$trim] = $true
    }
  }
  return $map
}

function Get-TagNamespaceOcid {
  param([string]$Name)

  $res = Invoke-Oci -Arguments @(
    "iam","tag-namespace","list",
    "--compartment-id", $TenancyOcid,
    "--include-subcompartments", "false",
    "--all",
    "--output", "json"
  )

  $json = $res.Output | ConvertFrom-Json -Depth 50
  $items = @($json.data)

  $visible = @()
  foreach ($i in $items) {
    $visible += ("{0}[{1}]" -f $i.name, $i.'lifecycle-state')
  }
  Write-Log INFO ("Tag namespaces visibles: " + ($visible -join ", "))

  $match = $items | Where-Object {
    $_.name -ieq $Name -and $_.'lifecycle-state' -ne "DELETED"
  } | Select-Object -First 1

  if ($null -eq $match) {
    throw "No encontrado Tag Namespace '$Name' en root tenancy."
  }
  return $match.id
}

function Get-CompartmentOcidByNameAndParent {
  param(
    [string]$Name,
    [string]$ParentOcid
  )

  $res = Invoke-Oci -Arguments @(
    "iam","compartment","list",
    "--compartment-id", $ParentOcid,
    "--compartment-id-in-subtree", "false",
    "--access-level", "ANY",
    "--all",
    "--output", "json"
  )

  $json = $res.Output | ConvertFrom-Json -Depth 50
  $items = @($json.data)

  $match = $items | Where-Object {
    $_.name -ieq $Name -and $_.'lifecycle-state' -ne "DELETED"
  } | Select-Object -First 1

  if ($null -eq $match) {
    throw "No encontrado compartment '$Name' bajo parent '$ParentOcid'."
  }
  return $match.id
}

function New-ImportSpec {
  param(
    [string]$Address,
    [string]$ImportId,
    [string]$Type,
    [string]$Key,
    [string]$Name
  )
  [pscustomobject]@{
    Address  = $Address
    ImportId = $ImportId
    Type     = $Type
    Key      = $Key
    Name     = $Name
  }
}

function Add-CompartmentSpecsRecursive {
  param(
    $CompartmentsObject,
    [string]$ParentOcid,
    [int]$Level,
    [System.Collections.Generic.List[object]]$Specs
  )

  foreach ($cmpKey in (Get-PropNames $CompartmentsObject)) {
    $cmp = Get-PropValue $CompartmentsObject $cmpKey
    $cmpName = $cmp.name

    Write-Log INFO ("Resolviendo compartment L{0}: {1} ({2}). Parent={3}" -f $Level, $cmpKey, $cmpName, $ParentOcid)
    $cmpOcid = Get-CompartmentOcidByNameAndParent -Name $cmpName -ParentOcid $ParentOcid

    if ($Level -eq 1) {
      $address = 'module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.these["{0}"]' -f $cmpKey
    }
    else {
      $address = 'module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_{0}["{1}"]' -f $Level, $cmpKey
    }

    $Specs.Add((New-ImportSpec -Address $address -ImportId $cmpOcid -Type "oci_identity_compartment" -Key $cmpKey -Name $cmpName))

    if ($cmp.PSObject.Properties.Name -contains "children") {
      Add-CompartmentSpecsRecursive -CompartmentsObject $cmp.children -ParentOcid $cmpOcid -Level ($Level + 1) -Specs $Specs
    }
  }
}

function Get-FoundationImportSpecs {
  param($Config)

  $specs = [System.Collections.Generic.List[object]]::new()

  if (-not ($Config.PSObject.Properties.Name -contains "tags_configuration")) {
    throw "JSON sin tags_configuration."
  }
  if (-not ($Config.PSObject.Properties.Name -contains "compartments_configuration")) {
    throw "JSON sin compartments_configuration."
  }

  $namespaces = $Config.tags_configuration.namespaces
  $namespaceKeys = Get-PropNames $namespaces

  foreach ($nsKey in $namespaceKeys) {
    $ns = Get-PropValue $namespaces $nsKey
    $nsName = $ns.name

    Write-Log INFO ("Resolviendo tag namespace: {0} ({1})" -f $nsKey, $nsName)
    $nsOcid = Get-TagNamespaceOcid -Name $nsName

    $nsAddress = 'module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag_namespace.these["{0}"]' -f $nsKey
    $specs.Add((New-ImportSpec -Address $nsAddress -ImportId $nsOcid -Type "oci_identity_tag_namespace" -Key $nsKey -Name $nsName))

    if ($ns.PSObject.Properties.Name -contains "tags") {
      foreach ($tagKey in (Get-PropNames $ns.tags)) {
        $tag = Get-PropValue $ns.tags $tagKey
        $tagName = $tag.name
        $tagAddress = 'module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["{0}"]' -f $tagKey
        $tagImportId = "tagNamespaces/$nsOcid/tags/$tagName"
        $specs.Add((New-ImportSpec -Address $tagAddress -ImportId $tagImportId -Type "oci_identity_tag" -Key $tagKey -Name "$nsName/$tagName"))
      }
    }
  }

  $compartments = $Config.compartments_configuration.compartments
  Add-CompartmentSpecsRecursive -CompartmentsObject $compartments -ParentOcid $TenancyOcid -Level 1 -Specs $specs

  return @($specs)
}


function Read-DependencyFiles {
  param([string[]]$Files)

  $deps = @{
    compartments = @{}
    identity_domains = @{}
    network_resources = @{}
    tags = @{}
  }

  foreach ($file in $Files) {
    if (-not (Test-Path $file)) { throw "No existe dependency file: $file" }
    Write-Log OK "Dependency file: $((Resolve-Path $file).Path)"
    $d = Get-Json -Path $file

    if ($d.PSObject.Properties.Name -contains "compartments") {
      foreach ($k in (Get-PropNames $d.compartments)) {
        $deps.compartments[$k] = (Get-PropValue $d.compartments $k)
      }
    }
    if ($d.PSObject.Properties.Name -contains "identity_domains") {
      foreach ($k in (Get-PropNames $d.identity_domains)) {
        $deps.identity_domains[$k] = (Get-PropValue $d.identity_domains $k)
      }
    }
    if ($d.PSObject.Properties.Name -contains "network_resources") {
      $deps.network_resources = $d.network_resources
    }
    if ($d.PSObject.Properties.Name -contains "tags") {
      foreach ($k in (Get-PropNames $d.tags)) {
        $deps.tags[$k] = (Get-PropValue $d.tags $k)
      }
    }
  }
  return $deps
}

function Get-CompartmentIdFromDependency {
  param(
    [hashtable]$Dependencies,
    [string]$Key
  )
  if ($Key -eq "TENANCY-ROOT") { return $TenancyOcid }
  if ($Key -match "^ocid1\..*") { return $Key }
  if ($Dependencies.compartments.ContainsKey($Key)) { return $Dependencies.compartments[$Key].id }
  throw "No se pudo resolver compartment dependency '$Key'. Proporciona compartments_output.json en -DependencyFiles."
}

function Get-IdentityDomainByDisplayName {
  param([string]$DisplayName)

  $res = Invoke-Oci -Arguments @(
    "iam","domain","list",
    "--compartment-id", $TenancyOcid,
    "--all",
    "--output","json"
  )

  $json = $res.Output | ConvertFrom-Json -Depth 80
  $items = @($json.data)

  $visible = @()
  foreach ($i in $items) {
    $dn = $i.'display-name'
    if ($null -eq $dn) { $dn = $i.displayName }
    $visible += ("{0}[{1}]" -f $dn, $i.'lifecycle-state')
  }
  Write-Log INFO ("Identity domains visibles: " + ($visible -join ", "))

$match = $items | Where-Object {
  $dn = $_.'display-name'
  if ($null -eq $dn -and $_.PSObject.Properties.Name -contains 'displayName') { $dn = $_.displayName }
  $ls = $_.'lifecycle-state'
  ($dn -ieq $DisplayName) -and ($ls -ne "DELETED")
} | Select-Object -First 1

  if ($null -eq $match) { throw "No encontrado identity domain con display_name '$DisplayName'." }
  return $match
}

function Get-IdentityDomainGroupId {
  param(
    [string]$Endpoint,
    [string]$DisplayName
  )

  $res = Invoke-Oci -Arguments @(
    "identity-domains","groups","list",
    "--endpoint", $Endpoint,
    "--all",
    "--output","json"
  )

  $json = $res.Output | ConvertFrom-Json -Depth 100

  $items = @()
  if ($json.PSObject.Properties.Name -contains "data") {
    if ($json.data.PSObject.Properties.Name -contains "Resources") { $items = @($json.data.Resources) }
    elseif ($json.data.PSObject.Properties.Name -contains "resources") { $items = @($json.data.resources) }
    else { $items = @($json.data) }
  }
  elseif ($json.PSObject.Properties.Name -contains "Resources") { $items = @($json.Resources) }
  elseif ($json.PSObject.Properties.Name -contains "resources") { $items = @($json.resources) }

$match = $items | Where-Object {
  $dn = $null

  if ($_.PSObject.Properties.Name -contains 'displayName') {
    $dn = $_.displayName
  }
  elseif ($_.PSObject.Properties.Name -contains 'display_name') {
    $dn = $_.display_name
  }
  elseif ($_.PSObject.Properties.Name -contains 'display-name') {
    $dn = $_.'display-name'
  }

  $deleteInProgress = $false
  if ($_.PSObject.Properties.Name -contains 'deleteInProgress') {
    $deleteInProgress = $_.deleteInProgress
  }
  elseif ($_.PSObject.Properties.Name -contains 'delete-in-progress') {
    $deleteInProgress = $_.'delete-in-progress'
  }

  ($dn -ieq $DisplayName) -and ($deleteInProgress -ne $true)
} | Select-Object -First 1

  if ($null -eq $match) { throw "No encontrado group '$DisplayName' en endpoint '$Endpoint'." }
  return $match.id
}

function Get-PolicyOcidByName {
  param(
    [string]$Name,
    [string]$CompartmentOcid
  )

  $res = Invoke-Oci -Arguments @(
    "iam","policy","list",
    "--compartment-id", $CompartmentOcid,
    "--all",
    "--output","json"
  )

  $json = $res.Output | ConvertFrom-Json -Depth 80
  $items = @($json.data)

  $match = $items | Where-Object {
    $_.name -ieq $Name -and $_.'lifecycle-state' -ne "DELETED"
  } | Select-Object -First 1

  if ($null -eq $match) { throw "No encontrada policy '$Name' en compartment '$CompartmentOcid'." }
  return $match.id
}

function Get-IdentityImportSpecs {
  param(
    $Config,
    [hashtable]$Dependencies
  )

  $specs = [System.Collections.Generic.List[object]]::new()

  if ($Config.PSObject.Properties.Name -contains "identity_domains_configuration") {
    foreach ($domainKey in (Get-PropNames $Config.identity_domains_configuration.identity_domains)) {
      $domain = Get-PropValue $Config.identity_domains_configuration.identity_domains $domainKey
      $displayName = $domain.display_name
      Write-Log INFO ("Resolviendo identity domain: {0} ({1})" -f $domainKey, $displayName)
      $found = Get-IdentityDomainByDisplayName -DisplayName $displayName
      $address = 'module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domain.these["{0}"]' -f $domainKey
      $specs.Add((New-ImportSpec -Address $address -ImportId $found.id -Type "oci_identity_domain" -Key $domainKey -Name $displayName))
    }
  }

  $domainEndpointByKey = @{}
  if ($Config.PSObject.Properties.Name -contains "identity_domains_configuration") {
    foreach ($domainKey in (Get-PropNames $Config.identity_domains_configuration.identity_domains)) {
      $domain = Get-PropValue $Config.identity_domains_configuration.identity_domains $domainKey
      $found = Get-IdentityDomainByDisplayName -DisplayName $domain.display_name
      $endpoint = $found.url
      if ($null -eq $endpoint -or [string]::IsNullOrWhiteSpace($endpoint)) { $endpoint = $found.'url' }
      if ($null -eq $endpoint -or [string]::IsNullOrWhiteSpace($endpoint)) { throw "El domain '$domainKey' no tiene URL/endpoint en la respuesta OCI." }
      $domainEndpointByKey[$domainKey] = $endpoint
    }
  }

  if ($Config.PSObject.Properties.Name -contains "identity_domain_groups_configuration") {
    $defaultDomainKey = $Config.identity_domain_groups_configuration.default_identity_domain_id
    foreach ($groupKey in (Get-PropNames $Config.identity_domain_groups_configuration.groups)) {
      $group = Get-PropValue $Config.identity_domain_groups_configuration.groups $groupKey
      $groupName = $group.name
      $domainKey = $defaultDomainKey
      if ($group.PSObject.Properties.Name -contains "identity_domain_id" -and $null -ne $group.identity_domain_id) { $domainKey = $group.identity_domain_id }

      if (-not $domainEndpointByKey.ContainsKey($domainKey)) {
        throw "No se pudo resolver endpoint para identity domain '$domainKey' requerido por group '$groupKey'."
      }
      $endpoint = $domainEndpointByKey[$domainKey]
      Write-Log INFO ("Resolviendo identity domain group: {0} ({1}) en {2}" -f $groupKey, $groupName, $domainKey)
      $groupId = Get-IdentityDomainGroupId -Endpoint $endpoint -DisplayName $groupName

      $address = 'module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["{0}"]' -f $groupKey
      $importId = "idcsEndpoint/$endpoint/groups/$groupId"
      $specs.Add((New-ImportSpec -Address $address -ImportId $importId -Type "oci_identity_domains_group" -Key $groupKey -Name $groupName))
    }
  }

  if ($Config.PSObject.Properties.Name -contains "policies_configuration") {
    foreach ($policyKey in (Get-PropNames $Config.policies_configuration.supplied_policies)) {
      $policy = Get-PropValue $Config.policies_configuration.supplied_policies $policyKey
      $policyName = $policy.name
      $cmpOcid = Get-CompartmentIdFromDependency -Dependencies $Dependencies -Key $policy.compartment_id
      Write-Log INFO ("Resolviendo policy: {0} ({1}) en compartment {2}" -f $policyKey, $policyName, $policy.compartment_id)
      $policyOcid = Get-PolicyOcidByName -Name $policyName -CompartmentOcid $cmpOcid
      $address = 'module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["{0}"]' -f $policyKey
      $specs.Add((New-ImportSpec -Address $address -ImportId $policyOcid -Type "oci_identity_policy" -Key $policyKey -Name $policyName))
    }
  }

  return @($specs)
}

function Write-ImportBlocksFile {
  param(
    [object[]]$Specs,
    [hashtable]$ExistingStateAddresses,
    [string]$Path
  )

  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add("# -----------------------------------------------------------------------------")
  $lines.Add("# Archivo generado automaticamente para importar recursos existentes al tfstate.")
  $lines.Add("# Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")")
  $lines.Add("# StackType: $StackType")
  $lines.Add("# No editar manualmente salvo revision controlada.")
  $lines.Add("# Borrar este fichero despues de materializar los imports en el state.")
  $lines.Add("# -----------------------------------------------------------------------------")
  $lines.Add("")

  $included = 0
  $skipped = 0

  foreach ($s in $Specs) {
    if ((-not $IncludeAlreadyManaged) -and $ExistingStateAddresses.ContainsKey($s.Address)) {
      Write-Log WARN ("Ya gestionado en state, se omite import block: {0}" -f $s.Address)
      $skipped++
      continue
    }

    $lines.Add("# $($s.Type) | $($s.Key) | $($s.Name)")
    $lines.Add("import {")
    $lines.Add("  to = $($s.Address)")
    $lines.Add("  id = $(ConvertTo-HclString $s.ImportId)")
    $lines.Add("}")
    $lines.Add("")
    $included++
  }

  if (Test-Path $Path) {
    $backup = "$Path.bak_$(Get-Date -Format "yyyyMMdd_HHmmss")"
    Copy-Item -Path $Path -Destination $backup -Force
    Write-Log WARN "Existia $Path. Backup generado: $backup"
  }

  Set-Content -Path $Path -Value $lines -Encoding UTF8

  [pscustomobject]@{
    Included = $included
    Skipped  = $skipped
  }
}

function Get-VarFileArgs {
  $args = @()
  foreach ($vf in $VarFiles) {
    $full = Resolve-Path $vf -ErrorAction Stop
    $args += "-var-file=$full"
  }
  return $args
}

function Run-Precheck {
  if ($NoPrecheck) {
    Write-Log WARN "Precheck omitido por parametro -NoPrecheck."
    return
  }

  Write-Log INFO "Precheck Terraform: configuracion evaluable sin refresh."
  $args = @("plan","-refresh=false","-input=false","-lock=false","-detailed-exitcode") + (Get-VarFileArgs)
  $res = Invoke-Terraform -Arguments $args -AllowFailure

  if ($res.ExitCode -eq 0 -or $res.ExitCode -eq 2) {
    Write-Log OK "Precheck correcto. ExitCode=$($res.ExitCode)"
  }
  else {
    Write-Log ERROR $res.Output
    throw "Precheck Terraform fallido. ExitCode=$($res.ExitCode)"
  }
}

function Run-Plan {
  Write-Log INFO "Ejecutando terraform plan con import blocks. Revisar que sea SOLO imports."
  $args = @("plan","-input=false","-out=$PlanOut") + (Get-VarFileArgs)
  $res = Invoke-Terraform -Arguments $args -AllowFailure
  Write-Log INFO $res.Output

  if ($res.ExitCode -ne 0) {
    throw "terraform plan fallido. ExitCode=$($res.ExitCode)"
  }

  Write-Log OK "Plan generado: $PlanOut"
  Write-Log WARN "No ejecutes apply si el plan muestra add/change/destroy. Criterio seguro: N to import, 0 to add, 0 to change, 0 to destroy."
}

# MAIN
Write-Log INFO "=========================================================================================="
Write-Log INFO "  GENERADOR DECLARATIVO DE IMPORT BLOCKS - OCI LANDING ZONE ORCHESTRATOR"
Write-Log INFO "=========================================================================================="
Write-Log INFO "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Log INFO "Working directory: $(Get-Location)"
Write-Log INFO "ConfigPath: $ConfigPath"
Write-Log INFO "StackType: $StackType"
Write-Log INFO "Mode: $Mode"

if (-not (Test-Path $ConfigPath)) { throw "No existe ConfigPath: $ConfigPath" }
foreach ($vf in $VarFiles) {
  if (-not (Test-Path $vf)) { throw "No existe var-file: $vf" }
  Write-Log OK "Var-file: $((Resolve-Path $vf).Path)"
}
foreach ($df in $DependencyFiles) {
  if (-not (Test-Path $df)) { throw "No existe dependency file: $df" }
  Write-Log OK "Dependency file declarado: $((Resolve-Path $df).Path)"
}

$ociVersion = Invoke-Native -FilePath "oci" -Arguments @("--version")
Write-Log OK "OCI CLI: $($ociVersion.Output.Trim())"
$tfVersion = Invoke-Native -FilePath "terraform" -Arguments @("version")
Write-Log OK (($tfVersion.Output -split "`r?`n")[0])

Write-Log INFO "Verificando acceso OCI con profile '$Profile'..."
$null = Invoke-Oci -Arguments @("iam","tenancy","get","--tenancy-id",$TenancyOcid,"--output","json")
Write-Log OK "Tenancy accesible."

if (-not (Test-Path ".terraform")) {
  throw "Directorio .terraform no encontrado. Ejecuta terraform init en el repo antes."
}

$config = Get-Json -Path $ConfigPath
$dependencies = Read-DependencyFiles -Files $DependencyFiles
Run-Precheck

Write-Log INFO "Leyendo state actual para omitir direcciones ya importadas."
$existing = Get-ExistingStateAddresses
Write-Log INFO ("Recursos ya presentes en state: {0}" -f $existing.Count)

switch ($StackType) {
  "foundation" {
    $specs = Get-FoundationImportSpecs -Config $config
    if ([string]::IsNullOrWhiteSpace($OutputImportFile)) { $OutputImportFile = ".\foundation_imports.auto.tf" }
    if ([string]::IsNullOrWhiteSpace($PlanOut)) { $PlanOut = ".\foundation-import.tfplan" }
  }
  "identity" {
    $specs = Get-IdentityImportSpecs -Config $config -Dependencies $dependencies
    if ([string]::IsNullOrWhiteSpace($OutputImportFile)) { $OutputImportFile = ".\identity_imports.auto.tf" }
    if ([string]::IsNullOrWhiteSpace($PlanOut)) { $PlanOut = ".\identity-import.tfplan" }
  }
  default {
    throw "StackType no soportado: $StackType"
  }
}

$byType = $specs | Group-Object Type | Sort-Object Name
Write-Log INFO "Resumen de specs resueltas:"
foreach ($g in $byType) {
  Write-Log INFO ("  {0}: {1}" -f $g.Name, $g.Count)
}
Write-Log INFO ("  Total specs: {0}" -f $specs.Count)

$result = Write-ImportBlocksFile -Specs $specs -ExistingStateAddresses $existing -Path $OutputImportFile
Write-Log OK "Import blocks generados: $OutputImportFile"
Write-Log INFO ("Incluidos: {0}" -f $result.Included)
Write-Log INFO ("Omitidos por existir en state: {0}" -f $result.Skipped)

if ($result.Included -eq 0) {
  Write-Log WARN "No hay imports pendientes. No se ejecuta plan."
  exit 0
}

if ($Mode -eq "Plan") {
  Run-Plan
}
else {
  Write-Log WARN "Modo Generate completado. Siguiente paso recomendado:"
  Write-Log WARN "terraform plan -input=false -out=`"$PlanOut`" <var-files>"
  Write-Log WARN "Aplicar solo si el plan indica exclusivamente imports y 0 add/change/destroy."
}

Write-Log INFO "Log completo: $script:LogFile"
