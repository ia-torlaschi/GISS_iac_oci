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

  Para network soporta imports declarativos basados en discovery plan JSON:
    - oci_core_vcn
    - oci_core_subnet
    - oci_core_route_table
    - oci_core_route_table_attachment
    - oci_core_security_list
    - oci_core_default_security_list
    - oci_core_network_security_group
    - oci_core_network_security_group_security_rule
    - oci_core_nat_gateway
    - oci_core_service_gateway
    - oci_core_drg
    - oci_core_drg_attachment
    - oci_core_drg_route_table
    - oci_core_drg_route_distribution
    - oci_core_drg_route_table_route_rule
    - OCI Network Firewall resources where present in OCI

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
  Version: 3.2.7
  Fecha: 11/05/2026

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

  [ValidateSet("foundation","identity","network")]
  [string]$StackType = "foundation",

  [string]$DiscoveryPlanJson = ".\migration\network-discovery.json",

  [switch]$SkipMissing,

  [string[]]$DependencyFiles = @(),

  [ValidateSet("Generate","Plan")]
  [string]$Mode = "Generate",

  [string]$OutputImportFile = "",

  [string]$PlanOut = "",

  [switch]$IncludeAlreadyManaged,

  [switch]$NoPrecheck
)

# Network discovery uses heterogeneous Terraform plan objects; strict mode breaks on optional attributes.
Set-StrictMode -Off
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
    [string[]]$Arguments = @(),
    [switch]$AllowFailure
  )
  $Arguments = @($Arguments | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) })
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
  param([string[]]$Arguments = @())
  $clean = @($Arguments | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) })
  $args = @("--profile", $Profile) + $clean
  return Invoke-Native -FilePath "oci" -Arguments $args
}

function Invoke-Terraform {
  param([string[]]$Arguments = @(), [switch]$AllowFailure)
  $clean = @($Arguments | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) })
  return Invoke-Native -FilePath "terraform" -Arguments $clean -AllowFailure:$AllowFailure
}

function Get-Json {
  param([string]$Path)
  $raw = Get-Content -Path $Path -Raw -Encoding UTF8
  return $raw | ConvertFrom-Json
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

  $json = $res.Output | ConvertFrom-Json
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

  $json = $res.Output | ConvertFrom-Json
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

  $json = $res.Output | ConvertFrom-Json
  $items = @($json.data)

  $visible = @()
  foreach ($i in $items) {
    $dn = $i.'display-name'
    if ($null -eq $dn) { $dn = $i.displayName }
    $visible += ("{0}[{1}]" -f $dn, $i.'lifecycle-state')
  }
  Write-Log INFO ("Identity domains visibles: " + ($visible -join ", "))

  $match = $items | Where-Object {
    (($_.'display-name' -ieq $DisplayName) -or ($_.displayName -ieq $DisplayName)) -and $_.'lifecycle-state' -ne "DELETED"
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

  $json = $res.Output | ConvertFrom-Json

  $items = @()
  if ($json.PSObject.Properties.Name -contains "data") {
    if ($json.data.PSObject.Properties.Name -contains "Resources") { $items = @($json.data.Resources) }
    elseif ($json.data.PSObject.Properties.Name -contains "resources") { $items = @($json.data.resources) }
    else { $items = @($json.data) }
  }
  elseif ($json.PSObject.Properties.Name -contains "Resources") { $items = @($json.Resources) }
  elseif ($json.PSObject.Properties.Name -contains "resources") { $items = @($json.resources) }

  $match = $items | Where-Object {
    (($_.displayName -ieq $DisplayName) -or ($_.display_name -ieq $DisplayName)) -and ($_.deleteInProgress -ne $true)
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

  $json = $res.Output | ConvertFrom-Json
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



# -----------------------------------------------------------------------------
# NETWORK SUPPORT v3.2
# -----------------------------------------------------------------------------
function Get-ResourceKeyFromAddress {
  param([string]$Address)
  $m = [regex]::Match($Address, '\["(.+)"\]')
  if ($m.Success) { return $m.Groups[1].Value }
  return $null
}

function Get-SafeProperty {
  param($Object, [string[]]$Names)
  if ($null -eq $Object) { return $null }
  foreach ($n in $Names) {
    if ($Object.PSObject.Properties.Name -contains $n) { return $Object.PSObject.Properties[$n].Value }
  }
  return $null
}

function Get-OciItems {
  param([string[]]$Arguments)
  $res = Invoke-Oci -Arguments ($Arguments + @("--all","--output","json"))
  $json = $res.Output | ConvertFrom-Json
  if ($json.PSObject.Properties.Name -contains "data") { return @($json.data) }
  return @()
}

function Find-OciByDisplayName {
  param(
    [string]$Label,
    [string[]]$Arguments,
    [string]$DisplayName,
    [string[]]$StateProperties = @("lifecycle-state","state")
  )
  if ([string]::IsNullOrWhiteSpace($DisplayName)) { Write-Log WARN "$Label sin display_name; se omite lookup."; return $null }
  $cleanArgs = @($Arguments | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) })
  $items = Get-OciItems -Arguments $cleanArgs
  $visible = @()
  foreach ($i in $items) {
    $dn = Get-SafeProperty $i @("display-name","display_name","displayName","name")
    $st = Get-SafeProperty $i $StateProperties
    if ($dn) { $visible += ("{0}[{1}]" -f $dn, $st) }
  }
  Write-Log INFO ("{0} visibles: {1}" -f $Label, ($visible -join ", "))
  $match = $items | Where-Object {
    $dn = Get-SafeProperty $_ @("display-name","display_name","displayName","name")
    $st = Get-SafeProperty $_ $StateProperties
    ($dn -ieq $DisplayName) -and ($st -notin @("DELETED","TERMINATED"))
  } | Select-Object -First 1
  if ($null -eq $match) {
    if ($SkipMissing) {
      Write-Log WARN ("No encontrado {0} con display_name/name '{1}'. Se omite por -SkipMissing." -f $Label, $DisplayName)
      return $null
    }
    throw "No encontrado $Label con display_name/name '$DisplayName'."
  }
  return $match
}

function New-NetworkIndex {
  param($Config)
  $idx = @{
    vcns = @{}
    subnets = @{}
    route_tables = @{}
    security_lists = @{}
    nsgs = @{}
    nat_gateways = @{}
    service_gateways = @{}
    drgs = @{}
    drg_route_tables = @{}
    drg_route_distributions = @{}
  }

  $nc = $Config.network_configuration
  if ($null -eq $nc) { return $idx }
  $cats = $nc.network_configuration_categories
  foreach ($catKey in (Get-PropNames $cats)) {
    $cat = Get-PropValue $cats $catKey
    foreach ($vcnKey in (Get-PropNames $cat.vcns)) {
      $vcn = Get-PropValue $cat.vcns $vcnKey
      $vcnCmp = $vcn.compartment_id
      if ($null -eq $vcnCmp) { $vcnCmp = $cat.category_compartment_id }
      if ($null -eq $vcnCmp) { $vcnCmp = $nc.default_compartment_id }
      $idx.vcns[$vcnKey] = @{
        key = $vcnKey
        display_name = $vcn.display_name
        compartment_key = $vcnCmp
      }

      foreach ($sk in (Get-PropNames $vcn.subnets)) {
        $s = Get-PropValue $vcn.subnets $sk
        $idx.subnets[$sk] = @{
          key = $sk
          display_name = $s.display_name
          route_table_key = $s.route_table_key
          vcn_key = $vcnKey
          compartment_key = $vcnCmp
        }
      }
      foreach ($rtk in (Get-PropNames $vcn.route_tables)) {
        $rt = Get-PropValue $vcn.route_tables $rtk
        $idx.route_tables[$rtk] = @{
          key = $rtk
          display_name = $rt.display_name
          vcn_key = $vcnKey
          compartment_key = $vcnCmp
        }
      }
      foreach ($slk in (Get-PropNames $vcn.security_lists)) {
        $sl = Get-PropValue $vcn.security_lists $slk
        $idx.security_lists[$slk] = @{
          key = $slk
          display_name = $sl.display_name
          vcn_key = $vcnKey
          compartment_key = $vcnCmp
        }
      }
      foreach ($nsgk in (Get-PropNames $vcn.network_security_groups)) {
        $nsg = Get-PropValue $vcn.network_security_groups $nsgk
        $idx.nsgs[$nsgk] = @{
          key = $nsgk
          display_name = $nsg.display_name
          vcn_key = $vcnKey
          compartment_key = $vcnCmp
        }
      }
      foreach ($ngwk in (Get-PropNames $vcn.nat_gateways)) {
        $ngw = Get-PropValue $vcn.nat_gateways $ngwk
        $idx.nat_gateways[$ngwk] = @{
          key = $ngwk
          display_name = $ngw.display_name
          vcn_key = $vcnKey
          compartment_key = $vcnCmp
        }
      }
      foreach ($sgwk in (Get-PropNames $vcn.service_gateways)) {
        $sgw = Get-PropValue $vcn.service_gateways $sgwk
        $idx.service_gateways[$sgwk] = @{
          key = $sgwk
          display_name = $sgw.display_name
          vcn_key = $vcnKey
          compartment_key = $vcnCmp
        }
      }
    }
  }

  foreach ($drgk in (Get-PropNames $nc.drgs)) {
    $drg = Get-PropValue $nc.drgs $drgk
    $cmp = $drg.compartment_id
    if ($null -eq $cmp) { $cmp = $nc.default_compartment_id }
    $idx.drgs[$drgk] = @{
      key = $drgk
      display_name = $drg.display_name
      compartment_key = $cmp
    }
  }
  foreach ($rtk in (Get-PropNames $nc.drg_route_tables)) {
    $rt = Get-PropValue $nc.drg_route_tables $rtk
    $idx.drg_route_tables[$rtk] = @{
      key = $rtk
      display_name = $rt.display_name
      drg_key = $rt.drg_key
    }
  }
  foreach ($rdk in (Get-PropNames $nc.drg_route_distributions)) {
    $rd = Get-PropValue $nc.drg_route_distributions $rdk
    $idx.drg_route_distributions[$rdk] = @{
      key = $rdk
      display_name = $rd.display_name
      drg_key = $rd.drg_key
    }
  }
  return $idx
}

function Resolve-CompartmentKeyOrOcid {
  param([string]$Value, [hashtable]$Dependencies)
  if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
  if ($Value -match "^ocid1\.") { return $Value }
  if ($Value -eq "TENANCY-ROOT") { return $TenancyOcid }
  if ($Dependencies.compartments.ContainsKey($Value)) { return $Dependencies.compartments[$Value].id }
  throw "No se pudo resolver compartment '$Value'."
}

function Get-NetworkPlanChanges {
  if (-not (Test-Path $DiscoveryPlanJson)) {
    throw "No existe DiscoveryPlanJson: $DiscoveryPlanJson. Genera antes: terraform plan -out .\migration\network-discovery.tfplan y terraform show -json."
  }
  $json = Get-Content $DiscoveryPlanJson -Raw -Encoding UTF8 | ConvertFrom-Json
  return @($json.resource_changes | Where-Object {
    $_.mode -eq "managed" -and $_.change.actions -contains "create" -and $_.type -notin @("local_file","time_sleep")
  })
}

function Get-Cached {
  param([hashtable]$Cache, [string]$Key, [scriptblock]$Resolver)
  if ($Cache.ContainsKey($Key)) { return $Cache[$Key] }
  $val = & $Resolver
  if ($null -ne $val) { $Cache[$Key] = $val }
  return $val
}

function Resolve-VcnId {
  param($Key, $After, $Idx, $Deps, [hashtable]$Cache)
  $cacheKey = "vcn:$Key"
  return Get-Cached $Cache $cacheKey {
    $info = $Idx.vcns[$Key]
    $display = if ($After.display_name) { $After.display_name } else { $info.display_name }
    $cmpVal = if ($After.compartment_id) { $After.compartment_id } else { $info.compartment_key }
    $cmp = Resolve-CompartmentKeyOrOcid $cmpVal $Deps
    $obj = Find-OciByDisplayName -Label "VCN" -Arguments @("network","vcn","list","--compartment-id",$cmp) -DisplayName $display
    if ($null -eq $obj) { return $null }
    return $obj.id
  }
}

function Resolve-GenericInVcn {
  param(
    [string]$Label,
    [string[]]$CliBase,
    [string]$Key,
    $After,
    [hashtable]$InfoMap,
    $Idx,
    $Deps,
    [hashtable]$Cache,
    [switch]$NoVcnArg
  )
  $cacheKey = "${Label}:$Key"
  return Get-Cached $Cache $cacheKey {
    $info = $InfoMap[$Key]
    $display = if ($After.display_name) { $After.display_name } else { $info.display_name }
    $cmpVal = if ($After.compartment_id) { $After.compartment_id } else { $info.compartment_key }
    $cmp = Resolve-CompartmentKeyOrOcid $cmpVal $Deps
    $args = @($CliBase + @("--compartment-id",$cmp))
    if (-not $NoVcnArg) {
      $vcnId = Resolve-VcnId -Key $info.vcn_key -After ([pscustomobject]@{}) -Idx $Idx -Deps $Deps -Cache $Cache
      if ($vcnId) { $args += @("--vcn-id",$vcnId) }
    }
    $obj = Find-OciByDisplayName -Label $Label -Arguments $args -DisplayName $display
    if ($null -eq $obj) { return $null }
    return $obj.id
  }
}

function Resolve-DefaultSecurityListId {
  param([string]$Key, $Idx, $Deps, [hashtable]$Cache)
  $vcnKey = $Key -replace "^CUSTOM-DEFAULT-SEC-LIST-",""
  $vcnId = Resolve-VcnId -Key $vcnKey -After ([pscustomobject]@{}) -Idx $Idx -Deps $Deps -Cache $Cache
  if (-not $vcnId) { return $null }
  $res = Invoke-Oci -Arguments @("network","vcn","get","--vcn-id",$vcnId,"--output","json")
  $json = $res.Output | ConvertFrom-Json
  return $json.data.'default-security-list-id'
}

function Resolve-NsgRuleId {
  param($Key, $After, $Idx, $Deps, [hashtable]$Cache)
  $parts = $Key -split "\.", 2
  $nsgKey = $parts[0]
  $nsgId = Resolve-GenericInVcn -Label "NSG" -CliBase @("network","nsg","list") -Key $nsgKey -After ([pscustomobject]@{}) -InfoMap $Idx.nsgs -Idx $Idx -Deps $Deps -Cache $Cache
  if (-not $nsgId) { return $null }
  $items = Get-OciItems -Arguments @("network","nsg","rules","list","--nsg-id",$nsgId)
  $match = $items | Where-Object {
    $dir = Get-SafeProperty $_ @("direction")
    $proto = Get-SafeProperty $_ @("protocol")
    $desc = Get-SafeProperty $_ @("description")
    $src = Get-SafeProperty $_ @("source")
    $dst = Get-SafeProperty $_ @("destination")
    ($dir -ieq $After.direction) -and
    ($proto -ieq $After.protocol) -and
    (($null -eq $After.description) -or ($desc -eq $After.description)) -and
    (($null -eq $After.source) -or ($src -eq $After.source)) -and
    (($null -eq $After.destination) -or ($dst -eq $After.destination))
  } | Select-Object -First 1
  if ($null -eq $match) {
    if ($SkipMissing) {
      Write-Log WARN "No encontrada regla NSG '$Key'. Se omite por -SkipMissing."
      return $null
    }
    throw "No encontrada regla NSG '$Key' en NSG '$nsgKey'."
  }
  return "networkSecurityGroups/$nsgId/securityRules/$($match.id)"
}


function Resolve-SingleDiscoveryDrgId {
  param($Deps, [hashtable]$Cache)
  return Get-Cached $Cache "drg:__single_discovery__" {
    $changes = Get-NetworkPlanChanges
    $drgChanges = @($changes | Where-Object { $_.type -eq "oci_core_drg" })
    if ($drgChanges.Count -ne 1) { return $null }

    $after = $drgChanges[0].change.after
    $display = $after.display_name
    $cmpVal = $after.compartment_id
    if ([string]::IsNullOrWhiteSpace($display) -or [string]::IsNullOrWhiteSpace($cmpVal)) { return $null }

    $cmp = Resolve-CompartmentKeyOrOcid $cmpVal $Deps
    if ([string]::IsNullOrWhiteSpace($cmp)) { return $null }

    $obj = Find-OciByDisplayName -Label "DRG" -Arguments @("network","drg","list","--compartment-id",$cmp) -DisplayName $display
    if ($null -eq $obj) { return $null }
    return $obj.id
  }
}

function Resolve-DrgId {
  param($Key, $After, $Idx, $Deps, [hashtable]$Cache)
  return Get-Cached $Cache "drg:$Key" {
    $info = $null
    if ($Idx.drgs.ContainsKey($Key)) { $info = $Idx.drgs[$Key] }

    $display = $null
    if ($After.display_name) { $display = $After.display_name }
    elseif ($null -ne $info) { $display = $info.display_name }

    $cmpVal = $null
    if ($After.compartment_id) { $cmpVal = $After.compartment_id }
    elseif ($null -ne $info) { $cmpVal = $info.compartment_key }

    if ([string]::IsNullOrWhiteSpace($display) -or [string]::IsNullOrWhiteSpace($cmpVal)) {
      return Resolve-SingleDiscoveryDrgId -Deps $Deps -Cache $Cache
    }

    $cmp = Resolve-CompartmentKeyOrOcid $cmpVal $Deps
    if ([string]::IsNullOrWhiteSpace($cmp)) { return Resolve-SingleDiscoveryDrgId -Deps $Deps -Cache $Cache }

    $obj = Find-OciByDisplayName -Label "DRG" -Arguments @("network","drg","list","--compartment-id",$cmp) -DisplayName $display
    if ($null -eq $obj) { return $null }
    return $obj.id
  }
}

function Resolve-DrgAttachmentId {
  param($Key, $After, $Deps)
  $display = $After.display_name
  $items = Get-OciItems -Arguments @("network","drg-attachment","list","--compartment-id",$TenancyOcid)
  # Fallback: list in tenancy compartment may not return child compartments. Use display-name best effort.
  $match = $items | Where-Object { $_.'display-name' -ieq $display -and $_.'lifecycle-state' -ne "DETACHED" } | Select-Object -First 1
  if ($null -eq $match) {
    if ($SkipMissing) { Write-Log WARN "No encontrado DRG attachment '$display'. Se omite."; return $null }
    throw "No encontrado DRG attachment '$display'. Si está en subcompartment, amplía lookup o añade OCID manual."
  }
  return $match.id
}

function Resolve-DrgRouteTableId {
  param($Key, $After, $Idx, $Deps, [hashtable]$Cache)
  return Get-Cached $Cache "drgrt:$Key" {
    $display = if ($After.display_name) { $After.display_name } else { $Idx.drg_route_tables[$Key].display_name }
    $drgId = $null
    if ($Idx.drg_route_tables.ContainsKey($Key) -and $Idx.drg_route_tables[$Key].drg_key) {
      $drgId = Resolve-DrgId -Key $Idx.drg_route_tables[$Key].drg_key -After ([pscustomobject]@{}) -Idx $Idx -Deps $Deps -Cache $Cache
    }
    if (-not $drgId -and $Idx.drgs.Count -eq 1) {
      $firstKey = @($Idx.drgs.Keys)[0]
      $drgId = Resolve-DrgId -Key $firstKey -After ([pscustomobject]@{}) -Idx $Idx -Deps $Deps -Cache $Cache
    }
    if (-not $drgId) {
      $drgId = Resolve-SingleDiscoveryDrgId -Deps $Deps -Cache $Cache
    }
    if (-not $drgId) { throw "No se pudo resolver DRG para DRG route table '$Key'." }
    $obj = Find-OciByDisplayName -Label "DRG route table" -Arguments @("network","drg-route-table","list","--drg-id",$drgId) -DisplayName $display
    if ($null -eq $obj) { return $null }
    return $obj.id
  }
}

function Resolve-DrgRouteDistributionId {
  param($Key, $After, $Idx, $Deps, [hashtable]$Cache)
  return Get-Cached $Cache "drgrd:$Key" {
    $display = if ($After.display_name) { $After.display_name } else { $Idx.drg_route_distributions[$Key].display_name }
    $drgId = $null
    if ($Idx.drg_route_distributions.ContainsKey($Key) -and $Idx.drg_route_distributions[$Key].drg_key) {
      $drgId = Resolve-DrgId -Key $Idx.drg_route_distributions[$Key].drg_key -After ([pscustomobject]@{}) -Idx $Idx -Deps $Deps -Cache $Cache
    }
    if (-not $drgId -and $Idx.drgs.Count -eq 1) {
      $firstKey = @($Idx.drgs.Keys)[0]
      $drgId = Resolve-DrgId -Key $firstKey -After ([pscustomobject]@{}) -Idx $Idx -Deps $Deps -Cache $Cache
    }
    if (-not $drgId) {
      $drgId = Resolve-SingleDiscoveryDrgId -Deps $Deps -Cache $Cache
    }
    if (-not $drgId) {
      if ($SkipMissing) { Write-Log WARN "No se pudo resolver DRG para DRG route distribution '$Key'. Se omite."; return $null }
      throw "No se pudo resolver DRG para DRG route distribution '$Key'."
    }
    $obj = Find-OciByDisplayName -Label "DRG route distribution" -Arguments @("network","drg-route-distribution","list","--drg-id",$drgId) -DisplayName $display
    if ($null -eq $obj) { return $null }
    return $obj.id
  }
}

function Resolve-DrgRouteRuleId {
  param($Key, $After, $Idx, $Deps, [hashtable]$Cache)

  # En el discovery plan del modulo networking, las route rules no siempre llevan drg_route_table_id.
  # Inferimos la DRG route table desde la key del recurso. Ejemplo:
  #   Rule key: DRGRT-VLL-LZ-SPOKES-STATIC-ROUTE
  #   Table key: DRGRT-VLL-LZ-SPOKES-KEY
  $rtKey = $null
  $candidateKeys = @($Idx.drg_route_tables.Keys)

  foreach ($candidate in $candidateKeys) {
    if ($Key -like "$candidate*") { $rtKey = $candidate; break }

    $normalizedCandidate = ([string]$candidate) -replace "-KEY$",""
    if ($Key -like "$normalizedCandidate*") { $rtKey = $candidate; break }
  }

  if (-not $rtKey -and $candidateKeys.Count -eq 1) {
    $rtKey = $candidateKeys[0]
  }

  if (-not $rtKey) {
    foreach ($candidate in $candidateKeys) {
      $candidateText = [string]$candidate
      if ($Key -match "SPOKES" -and $candidateText -match "SPOKES") { $rtKey = $candidate; break }
      if ($Key -match "HUB" -and $candidateText -match "HUB") { $rtKey = $candidate; break }
    }
  }

  if (-not $rtKey) {
    if ($SkipMissing) { Write-Log WARN "No se pudo inferir DRG route table para route rule '$Key'. Se omite."; return $null }
    throw "No se pudo inferir DRG route table para route rule '$Key'."
  }

  Write-Log INFO "DRG route rule '$Key' asociada a DRG route table '$rtKey'."

  $rtId = Resolve-DrgRouteTableId -Key $rtKey -After ([pscustomobject]@{}) -Idx $Idx -Deps $Deps -Cache $Cache
  $items = Get-OciItems -Arguments @("network","drg-route-table-route-rule","list","--drg-route-table-id",$rtId)
  $match = $items | Where-Object {
    $_.destination -eq $After.destination -and $_.'destination-type' -eq $After.destination_type
  } | Select-Object -First 1
  if ($null -eq $match) {
    if ($SkipMissing) { Write-Log WARN "No encontrada DRG route rule '$Key'. Se omite."; return $null }
    throw "No encontrada DRG route rule '$Key'."
  }
  return "drgRouteTables/$rtId/routeRules/$($match.id)"
}

function Resolve-NetworkFirewallImportId {
  param($Type, $Key, $After, $Idx, $Deps, [hashtable]$Cache)
  # Soporte best-effort para addon NFW. Si el add-on no está desplegado, usar -SkipMissing para omitir.
  switch ($Type) {
    "oci_network_firewall_network_firewall" {
      $cmp = Resolve-CompartmentKeyOrOcid $After.compartment_id $Deps
      $obj = Find-OciByDisplayName -Label "Network Firewall" -Arguments @("network-firewall","network-firewall","list","--compartment-id",$cmp) -DisplayName $After.display_name
      if ($obj) { return $obj.id }
    }
    "oci_network_firewall_network_firewall_policy" {
      $cmp = Resolve-CompartmentKeyOrOcid $After.compartment_id $Deps
      $obj = Find-OciByDisplayName -Label "Network Firewall Policy" -Arguments @("network-firewall","network-firewall-policy","list","--compartment-id",$cmp) -DisplayName $After.display_name
      if ($obj) { return $obj.id }
    }
    default {
      if ($After.network_firewall_policy_id -and $After.name) {
        # Muchos subrecursos NFW se importan por name dentro de policy según provider.
        return $After.name
      }
    }
  }
  if ($SkipMissing) { Write-Log WARN "NFW recurso '$Type/$Key' no encontrado; omitido."; return $null }
  throw "No se pudo resolver import id para recurso NFW '$Type/$Key'."
}

function Get-NetworkImportSpecs {
  param($Config, [hashtable]$Dependencies)

  $idx = New-NetworkIndex -Config $Config
  $changes = Get-NetworkPlanChanges
  $specs = [System.Collections.Generic.List[object]]::new()
  $cache = @{}

  # Lookup auxiliar del discovery plan por tipo + key. Es crítico para recursos
  # como oci_core_route_table_attachment, cuyo change.after no trae subnet_id ni
  # route_table_id porque se calculan desde otros recursos del mismo módulo.
  $afterByTypeKey = @{}
  foreach ($c in $changes) {
    $cKey = Get-ResourceKeyFromAddress $c.address
    if (-not [string]::IsNullOrWhiteSpace($cKey)) {
      $afterByTypeKey["$($c.type)|$cKey"] = $c.change.after
    }
  }

  Write-Log INFO ("Recursos candidatos del discovery plan: {0}" -f $changes.Count)

  foreach ($rc in $changes) {
    $type = $rc.type
    $address = $rc.address
    $key = Get-ResourceKeyFromAddress $address
    $after = $rc.change.after
    $importId = $null

    Write-Log INFO ("Resolviendo network import: {0} key={1}" -f $type, $key)

    switch ($type) {
      "oci_core_vcn" {
        $importId = Resolve-VcnId -Key $key -After $after -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_subnet" {
        $importId = Resolve-GenericInVcn -Label "Subnet" -CliBase @("network","subnet","list") -Key $key -After $after -InfoMap $idx.subnets -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_route_table" {
        $importId = Resolve-GenericInVcn -Label "Route table" -CliBase @("network","route-table","list") -Key $key -After $after -InfoMap $idx.route_tables -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_security_list" {
        $importId = Resolve-GenericInVcn -Label "Security list" -CliBase @("network","security-list","list") -Key $key -After $after -InfoMap $idx.security_lists -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_default_security_list" {
        $importId = Resolve-DefaultSecurityListId -Key $key -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_network_security_group" {
        $importId = Resolve-GenericInVcn -Label "NSG" -CliBase @("network","nsg","list") -Key $key -After $after -InfoMap $idx.nsgs -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_network_security_group_security_rule" {
        $importId = Resolve-NsgRuleId -Key $key -After $after -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_nat_gateway" {
        $importId = Resolve-GenericInVcn -Label "NAT Gateway" -CliBase @("network","nat-gateway","list") -Key $key -After $after -InfoMap $idx.nat_gateways -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_service_gateway" {
        $importId = Resolve-GenericInVcn -Label "Service Gateway" -CliBase @("network","service-gateway","list") -Key $key -After $after -InfoMap $idx.service_gateways -Idx $idx -Deps $Dependencies -Cache $cache -NoVcnArg
      }
      "oci_core_route_table_attachment" {
        $subnetInfo = $idx.subnets[$key]
        if ($null -eq $subnetInfo) { throw "No se encuentra subnet '$key' en config para route_table_attachment." }

        $subnetAfter = $afterByTypeKey["oci_core_subnet|$key"]
        if ($null -eq $subnetAfter) { $subnetAfter = [pscustomobject]@{} }

        $subnetId = Resolve-GenericInVcn -Label "Subnet" -CliBase @("network","subnet","list") -Key $key -After $subnetAfter -InfoMap $idx.subnets -Idx $idx -Deps $Dependencies -Cache $cache

        $rtKey = $subnetInfo.route_table_key
        $rtAfter = $null
        if (-not [string]::IsNullOrWhiteSpace($rtKey)) {
          $rtAfter = $afterByTypeKey["oci_core_route_table|$rtKey"]
        }
        if ($null -eq $rtAfter) { $rtAfter = [pscustomobject]@{} }

        $rtId = Resolve-GenericInVcn -Label "Route table" -CliBase @("network","route-table","list") -Key $rtKey -After $rtAfter -InfoMap $idx.route_tables -Idx $idx -Deps $Dependencies -Cache $cache

        if ([string]::IsNullOrWhiteSpace($subnetId) -or [string]::IsNullOrWhiteSpace($rtId)) {
          $msg = "No se pudo resolver route_table_attachment '$key'. subnetId='$subnetId' routeTableId='$rtId'."
          if ($SkipMissing) {
            Write-Log WARN "$msg Se omite por -SkipMissing."
            $importId = $null
          }
          else {
            throw $msg
          }
        }
        else {
          $importId = "$subnetId/$rtId"
        }
      }
      "oci_core_drg" {
        $importId = Resolve-DrgId -Key $key -After $after -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_drg_attachment" {
        $importId = Resolve-DrgAttachmentId -Key $key -After $after -Deps $Dependencies
      }
      "oci_core_drg_route_table" {
        $importId = Resolve-DrgRouteTableId -Key $key -After $after -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_drg_route_distribution" {
        $importId = Resolve-DrgRouteDistributionId -Key $key -After $after -Idx $idx -Deps $Dependencies -Cache $cache
      }
      "oci_core_drg_route_table_route_rule" {
        $importId = Resolve-DrgRouteRuleId -Key $key -After $after -Idx $idx -Deps $Dependencies -Cache $cache
      }
      { $_ -like "oci_network_firewall_*" } {
        $importId = Resolve-NetworkFirewallImportId -Type $type -Key $key -After $after -Idx $idx -Deps $Dependencies -Cache $cache
      }
      default {
        if ($SkipMissing) {
          Write-Log WARN "Tipo de red no soportado por v3.2, omitido: $type / $address"
          continue
        }
        throw "Tipo de red no soportado por v3.2: $type / $address"
      }
    }

    if (-not [string]::IsNullOrWhiteSpace($importId)) {
      $specs.Add((New-ImportSpec -Address $address -ImportId $importId -Type $type -Key $key -Name $key))
    }
  }

  return @($specs)
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
  "network" {
    $specs = Get-NetworkImportSpecs -Config $config -Dependencies $dependencies
    if ([string]::IsNullOrWhiteSpace($OutputImportFile)) { $OutputImportFile = ".\network_imports.auto.tf" }
    if ([string]::IsNullOrWhiteSpace($PlanOut)) { $PlanOut = ".\network-import.tfplan" }
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
