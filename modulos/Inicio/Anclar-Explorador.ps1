# Ancla carpetas a Acceso rapido y archivos a Favoritos del Explorador, en el orden dado, para el
# usuario que lo ejecuta (el Shell solo cambia los anclados de su propia sesion).
# Lo usa el modulo Inicio: directamente para el usuario que ejecuta WinMudanza y con RunOnce (al
# iniciar sesion) para los demas. Si una lista viene con elementos, antes se desanclan los que
# haya de ese tipo, para que quede igual que en el equipo de origen.
# Uso: Anclar-Explorador.ps1 -Config <archivo.psd1 con AccesoRapido y Favoritos> [-Log <archivo>]
#      Anclar-Explorador.ps1 -AccesoRapido 'D:\Datos', 'shell:Downloads' -Favoritos 'D:\notas.txt'

param(
    [string]$Config,
    [string[]]$AccesoRapido = @(),
    [string[]]$Favoritos = @(),
    [string]$Log
)

$ErrorActionPreference = 'Stop'
function Write-Registro([string]$Texto) {
    Write-Output $Texto
    if ($Log) { Add-Content -LiteralPath $Log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Texto" -Encoding UTF8 -ErrorAction SilentlyContinue }
}

if ($Config) {
    $c = Import-PowerShellDataFile -LiteralPath $Config
    $AccesoRapido = @($c.AccesoRapido | Where-Object { $_ })
    $Favoritos = @($c.Favoritos | Where-Object { $_ })
}

$sh = New-Object -ComObject Shell.Application
$inicioExplorador = 'shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}'

# Elemento del Shell de una ruta (carpeta, archivo o shell:...), o $null si no existe
function Get-ElementoShell([string]$Ruta) {
    $r = [Environment]::ExpandEnvironmentVariables($Ruta)
    if ($r -like 'shell:*') {
        $ns = $sh.Namespace($r)
        if ($ns) { return $ns.Self }
        return $null
    }
    if (Test-Path -LiteralPath $r -PathType Container) {
        $ns = $sh.Namespace($r)
        if ($ns) { return $ns.Self }
    } elseif (Test-Path -LiteralPath $r -PathType Leaf) {
        $ns = $sh.Namespace((Split-Path -Parent $r))
        if ($ns) { return $ns.ParseName((Split-Path -Leaf $r)) }
    }
    return $null
}

# Anclados actuales de Inicio del Explorador: carpetas (Acceso rapido) o archivos (Favoritos)
function Get-AncladosActuales([bool]$Carpetas) {
    return @($sh.Namespace($inicioExplorador).Items() | Where-Object {
        $_.ExtendedProperty('System.Home.IsPinned') -and ([bool]$_.IsFolder -eq $Carpetas)
    })
}

function Set-Anclados([string[]]$Rutas, [bool]$Carpetas) {
    if (@($Rutas).Count -eq 0) { return }
    $tipo = 'Favoritos'; $anclar = 'pintohomefile'; $desanclar = 'unpinfromhomefile'
    if ($Carpetas) { $tipo = 'Acceso rapido'; $anclar = 'pintohome'; $desanclar = 'unpinfromhome' }

    foreach ($e in Get-AncladosActuales $Carpetas) { $e.InvokeVerb($desanclar) }
    Start-Sleep -Seconds 2   # el Shell desancla de forma asincrona
    foreach ($r in $Rutas) {
        $e = Get-ElementoShell $r
        if (-not $e) { Write-Registro "FALTA $tipo`: $r (no existe)"; continue }
        # El Shell ancla de forma asincrona: se espera a que aparezca (asi se respeta el orden) y se reintenta
        $antes = @(Get-AncladosActuales $Carpetas).Count
        for ($intento = 1; $intento -le 3; $intento++) {
            $e.InvokeVerb($anclar)
            $ok = $false
            for ($i = 0; $i -lt 10 -and -not $ok; $i++) {
                Start-Sleep -Milliseconds 300
                $ok = @(Get-AncladosActuales $Carpetas).Count -gt $antes
            }
            if ($ok) { break }
            $e = Get-ElementoShell $r
        }
        if (-not $ok) { Write-Registro "NO ANCLADO $tipo`: $r" }
    }
    Start-Sleep -Seconds 1
    $n = @(Get-AncladosActuales $Carpetas).Count
    Write-Registro "$tipo`: $n anclados (de $(@($Rutas).Count))"
}

Set-Anclados $AccesoRapido $true
Set-Anclados $Favoritos $false
