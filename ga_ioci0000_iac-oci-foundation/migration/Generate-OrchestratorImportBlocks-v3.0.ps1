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
  Version: 3.0
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

  [ValidateSet("foundation")]
  [string]$StackType = "foundation",

  [ValidateSet("Generate","Plan")]
  [string]$Mode = "Generate",

  [string]$OutputImportFile = ".\foundation_imports.auto.tf",

  [string]$PlanOut = ".\foundation-import.tfplan",

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
Run-Precheck

Write-Log INFO "Leyendo state actual para omitir direcciones ya importadas."
$existing = Get-ExistingStateAddresses
Write-Log INFO ("Recursos ya presentes en state: {0}" -f $existing.Count)

switch ($StackType) {
  "foundation" {
    $specs = Get-FoundationImportSpecs -Config $config
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
