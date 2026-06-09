# ====================================================
# Sincronizador Robocopy Seguro (Generico)
# Origen por defecto: repo actual
# Destino por defecto: Documentos del usuario (Windows 11)
# NO elimina archivos en destino
# Logs dentro del ORIGEN
#
# REQUISITOS: Windows PowerShell 5.x (no PS 7)
# ENCODING:   UTF-8 con BOM (obligatorio para PS 5.x)
#
# USO:
#   .\sync-giss-terraform.ps1            -> modo silencioso (solo resumen)
#   .\sync-giss-terraform.ps1 -Detalle   -> muestra archivos copiados y extras
# ====================================================
#Requires -Version 5.0

param(
    [switch]$Detalle
)

Write-Host "============================================"
Write-Host "  Sincronizador Robocopy Seguro"
Write-Host "  .\sync-giss-terraform.ps1            -> modo silencioso (solo resumen)"
Write-Host "  .\sync-giss-terraform.ps1 -Detalle   -> muestra archivos copiados y extras"


if ($Detalle) {
    Write-Host "  Modo: DETALLE activado"
}
Write-Host "============================================"
Write-Host ""

# Funcion: elimina comillas dobles/simples que el usuario pueda pegar por habito DOS/CMD
function Strip-Quotes {
    param([string]$Path)
    return $Path.Trim().Trim('"').Trim("'").Trim()
}

# Valores por defecto
$DefaultSource      = "C:\gitlab\ga_ioci_iac-oci"
$DefaultDestination = Join-Path $env:USERPROFILE "Documents"

# Entrada interactiva
Write-Host "[INFO]  Las rutas NO necesitan comillas aunque tengan espacios."
$Source = Read-Host ">> Origen      (Enter = '$DefaultSource')"
if ([string]::IsNullOrWhiteSpace($Source)) {
    $Source = $DefaultSource
} else {
    $Source = Strip-Quotes $Source
}

$Destination = Read-Host ">> Destino     (Enter = '$DefaultDestination')"
if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = $DefaultDestination
} else {
    $Destination = Strip-Quotes $Destination
}

# Validaciones
if (!(Test-Path $Source)) {
    Write-Host "[ERROR] El origen no existe: $Source"
    exit 1
}

if (!(Test-Path $Destination)) {
    Write-Host "[INFO]  El destino no existe, se creara: $Destination"
    New-Item -ItemType Directory -Path $Destination | Out-Null
}

# Carpeta de logs dentro del origen
$LogDir = Join-Path $Source "_sync_logs"
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile   = Join-Path $LogDir ("sync-" + $Timestamp + ".log")

Write-Host ""
Write-Host "--------------------------------------------"
Write-Host "  Origen  : $Source"
Write-Host "  Destino : $Destination"
Write-Host "  Log     : $LogFile"
Write-Host "--------------------------------------------"
Write-Host ""

# Robocopy NO destructivo
# /NFL y /NDL se activan solo en modo silencioso para mantener el log limpio
# En modo -Detalle se suprimen para que el log liste todos los archivos
$RoboArgs = @(
    $Source,
    $Destination,
    "/E",           # Copia subdirectorios incluyendo vacios
    "/COPY:DAT",    # Data + Attributes + Timestamps (no requiere Admin)
    "/DCOPY:DAT",   # Copia atributos de directorio: Data, Attributes, Timestamps
    "/SL",          # Copia symbolic links como links (no sigue el target)
    "/FFT",         # FAT File Times (tolerancia 2s, util en red/SMB)
    "/XO",          # Excluye archivos mas antiguos (no sobreescribe mas nuevos)
    "/Z",           # Modo reiniciable (resume en cortes de red)
    "/R:3",         # Reintentos por archivo
    "/W:5",         # Espera entre reintentos (segundos)
    "/LOG:$LogFile" # Redirige salida a log (suprime consola)
)

if (-not $Detalle) {
    $RoboArgs += "/NFL"   # No lista nombres de archivo (modo silencioso)
    $RoboArgs += "/NDL"   # No lista nombres de directorio (modo silencioso)
}

Write-Host "[INFO]  Iniciando Robocopy..."
& robocopy @RoboArgs
$ExitCode = $LASTEXITCODE

# ----------------------------------------------------------
# REPORTE DE DETALLE: archivos copiados y extras en destino
# ----------------------------------------------------------
if ($Detalle -and (Test-Path $LogFile)) {

    Write-Host ""
    Write-Host "============================================"
    Write-Host "  DETALLE: Archivos copiados en esta sesion"
    Write-Host "============================================"

    $LogLines = Get-Content $LogFile

    # Robocopy marca los archivos copiados con una linea que empieza
    # por TAB + fecha/hora o directamente con la ruta relativa.
    # Filtramos las lineas que contienen rutas de archivo copiadas:
    # en el log sin /NFL aparecen como "    <fecha>  <tamano>  <nombre>"
    $Copiados = $LogLines | Where-Object {
        $_ -match "^\s+\d{4}/\d{2}/\d{2}" -or $_ -match "^\s+New File"
    }

    if ($Copiados) {
        $Copiados | ForEach-Object { Write-Host "  COPIADO : $_".Trim() }
    } else {
        Write-Host "  (ninguno copiado en esta sesion)"
    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host "  DETALLE: Archivos EXTRA en destino"
    Write-Host "  (existen en destino pero NO en origen)"
    Write-Host "============================================"

    # Comparacion de listas de archivos con rutas relativas
    $SrcFiles  = Get-ChildItem -Recurse -File -Path $Source |
                 Where-Object { $_.FullName -notlike "*\_sync_logs\*" } |
                 ForEach-Object { $_.FullName.Substring($Source.TrimEnd('\').Length) }

    $DestFiles = Get-ChildItem -Recurse -File -Path $Destination |
                 ForEach-Object { $_.FullName.Substring($Destination.TrimEnd('\').Length) }

    $Extras = Compare-Object -ReferenceObject $SrcFiles -DifferenceObject $DestFiles |
              Where-Object { $_.SideIndicator -eq '=>' } |
              Select-Object -ExpandProperty InputObject

    if ($Extras) {
        $Extras | ForEach-Object { Write-Host "  EXTRA   : $Destination$_" }
        Write-Host ""
        Write-Host "  Total extras: $($Extras.Count) archivo(s)"
        Write-Host "  [INFO] Estos archivos NO se eliminan (sync no destructivo)"
    } else {
        Write-Host "  (no hay archivos extra en destino)"
    }

    Write-Host "============================================"
}

# ----------------------------------------------------------
Write-Host ""
Write-Host "--------------------------------------------"
Write-Host "  Sincronizacion finalizada"
Write-Host "  Codigo Robocopy : $ExitCode"

# Robocopy usa mascara de bits en el exit code:
#   Bit 0 (+1)  : Archivos copiados OK
#   Bit 1 (+2)  : Extras en destino (inofensivo en sync no destructivo)
#   Bit 2 (+4)  : Archivos no coincidentes (tamano/fecha distintos)
#   Bit 3 (+8)  : Uno o mas archivos no pudieron copiarse
#   Bit 4 (+16) : Error fatal
#
#   0-3  -> OK   (copia exitosa con o sin extras/omitidos)
#   4-7  -> WARN (no coincidencias, revisar log)
#   8+   -> ERROR (fallos reales de copia)

if ($ExitCode -ge 8) {
    Write-Host "  Estado : [ERROR] Fallos de copia. Revise: $LogFile"
} elseif ($ExitCode -ge 4) {
    Write-Host "  Estado : [WARN]  Archivos no coincidentes. Revise: $LogFile"
} elseif ($ExitCode -eq 3) {
    Write-Host "  Estado : [OK]    Archivos copiados. Hay extras en destino (normal)"
} elseif ($ExitCode -eq 2) {
    Write-Host "  Estado : [OK]    Sin cambios nuevos. Hay extras en destino (normal)"
} elseif ($ExitCode -eq 1) {
    Write-Host "  Estado : [OK]    Archivos sincronizados correctamente"
} else {
    Write-Host "  Estado : [OK]    Sin cambios (destino ya actualizado)"
}

Write-Host "--------------------------------------------"
Write-Host ""

# Normalizar exit code: 0-3 son exito en sync no destructivo -> exit 0
if ($ExitCode -le 3) {
    exit 0
} else {
    exit $ExitCode
}