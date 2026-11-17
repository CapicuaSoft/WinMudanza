# Funciones comunes de WinMudanza:
# - Estado de la ejecucion (simulacion, log, contadores, pendientes)
# - Mensajes en pantalla + log
# - Cambios con soporte de simulacion (Invoke-Cambio, Set-RegValor)
# - Perfiles de usuario (aplicar ajustes HKCU en todos los perfiles y en Default)
# - Utilidades (admin, cuentas, PATH, archivos)

Set-StrictMode -Off

$script:Estado = $null
$script:ModuloActual = ''

# ==================================================
# ESTADO Y LOG
# ==================================================

function Initialize-WinMudanza {
    param(
        [Parameter(Mandatory)][string]$Raiz,
        [Parameter(Mandatory)][string]$Accion,
        [switch]$Simular,
        [string]$DirLogs
    )
    if (-not $DirLogs) { $DirLogs = Join-Path $Raiz 'logs' }
    if (-not (Test-Path -LiteralPath $DirLogs)) { New-Item -ItemType Directory -Path $DirLogs -Force | Out-Null }
    $sufijo = ''
    if ($Simular) { $sufijo = '_simulacion' }
    $nombreLog = '{0}_{1}{2}.log' -f (Get-Date -Format 'yyyy-MM-dd_HHmmss'), $Accion.ToLower(), $sufijo

    $script:Estado = [pscustomobject]@{
        Raiz       = $Raiz
        Accion     = $Accion
        Simular    = [bool]$Simular
        Log        = Join-Path $DirLogs $nombreLog
        Errores    = 0
        Avisos     = 0
        Simulados  = 0          # cambios que haria (simulacion / Comparar)
        Reinicio   = ''         # motivo si algun modulo necesita reiniciar antes de seguir
        Pendientes = New-Object System.Collections.ArrayList
    }
    $modo = 'REAL'
    if ($Simular) { $modo = 'SIMULACION' }
    Write-Log ("WinMudanza - {0} - {1} - {2}\{3}" -f $Accion, $modo, $env:COMPUTERNAME, $env:USERNAME)
    return $script:Estado
}

function Get-WinMudanzaEstado { return $script:Estado }

function Set-ModuloActual([string]$Nombre) { $script:ModuloActual = $Nombre }

function Test-Simulacion {
    return ($script:Estado -and $script:Estado.Simular)
}

function Write-Log([string]$Texto) {
    if (-not $script:Estado) { return }
    try {
        Add-Content -LiteralPath $script:Estado.Log -Encoding UTF8 -ErrorAction Stop `
            -Value ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Texto)
    } catch { }
}

# ==================================================
# MENSAJES
# ==================================================

function Write-Linea([string]$Prefijo, [string]$Texto, [ConsoleColor]$Color) {
    Write-Host ('  {0}  {1}' -f $Prefijo, $Texto) -ForegroundColor $Color
    Write-Log ('{0}  {1}' -f $Prefijo, $Texto)
}

function Write-Titulo([string]$Texto) {
    Write-Host ''
    Write-Host $Texto -ForegroundColor Cyan
    Write-Log "== $Texto"
}

function Write-Ok([string]$Texto)       { Write-Linea 'OK ' $Texto Green }
function Write-Omitido([string]$Texto)  { Write-Linea '-- ' $Texto DarkGray }
function Write-Simulado([string]$Texto) {
    if ($script:Estado) { $script:Estado.Simulados++ }
    Write-Linea 'SIM' $Texto Cyan
}
function Write-Info([string]$Texto)     { Write-Linea '   ' $Texto Gray }

function Write-Aviso([string]$Texto) {
    if ($script:Estado) { $script:Estado.Avisos++ }
    Write-Linea '!! ' $Texto Yellow
}

function Write-Fallo([string]$Texto) {
    if ($script:Estado) { $script:Estado.Errores++ }
    Write-Linea 'ERR' $Texto Red
}

# Registra algo que el usuario debe hacer a mano; se muestra en el resumen final.
function Add-Pendiente([string]$Texto) {
    $linea = $Texto
    if ($script:ModuloActual) { $linea = '[{0}] {1}' -f $script:ModuloActual, $Texto }
    if ($script:Estado) { [void]$script:Estado.Pendientes.Add($linea) }
    Write-Linea 'PEN' $Texto Magenta
}

# Indica que hay que reiniciar antes de seguir con los modulos siguientes
# (p. ej. tras activar WSL o Hyper-V). WinMudanza.ps1 decide si para y continua tras reiniciar.
function Set-ReinicioNecesario([string]$Motivo) {
    if ($script:Estado -and -not (Test-Simulacion)) { $script:Estado.Reinicio = $Motivo }
}

# ==================================================
# CAMBIOS (con simulacion)
# ==================================================

# Ejecuta un cambio en el sistema. En simulacion solo muestra lo que haria.
# Dentro de $Accion usar -ErrorAction Stop en cmdlets y comprobar $LASTEXITCODE en
# comandos externos (lanzar throw si fallan).
# Devuelve $true si se aplico (o se simulo) y $false si fallo.
function Invoke-Cambio {
    param(
        [Parameter(Mandatory)][string]$Descripcion,
        [Parameter(Mandatory)][scriptblock]$Accion,
        [switch]$Silencioso,
        [switch]$FalloComoAviso
    )
    if (Test-Simulacion) { Write-Simulado $Descripcion; return $true }
    try {
        $null = & $Accion
        if (-not $Silencioso) { Write-Ok $Descripcion }
        return $true
    } catch {
        $msg = '{0} - {1}' -f $Descripcion, $_.Exception.Message
        if ($FalloComoAviso) { Write-Aviso $msg } else { Write-Fallo $msg }
        return $false
    }
}

# Escribe un valor de registro. Crea la clave solo si no existe (nunca la borra ni la recrea).
# Ruta admite "HKLM:\...", "HKCU:\..." o "Registry::HKEY_USERS\...".
# Nombre '(Default)' escribe el valor predeterminado de la clave.
function Set-RegValor {
    param(
        [Parameter(Mandatory)][string]$Ruta,
        [Parameter(Mandatory)][string]$Nombre,
        [Parameter(Mandatory)][AllowEmptyString()]$Valor,
        [ValidateSet('String', 'ExpandString', 'DWord', 'QWord', 'MultiString', 'Binary')]
        [string]$Tipo = 'DWord',
        [switch]$FalloComoAviso
    )
    $texto = '{0} \ {1} = {2}' -f $Ruta, $Nombre, $Valor
    # Si ya tiene ese valor no se escribe (asi la simulacion y Comparar solo muestran diferencias reales)
    if (Test-RegValorIgual -Ruta $Ruta -Nombre $Nombre -Valor $Valor -Tipo $Tipo) { Write-Log "REG= $texto (ya estaba)"; return $true }
    if (Test-Simulacion) { Write-Simulado "Registro: $texto"; return $true }
    try {
        if (-not (Test-Path -LiteralPath $Ruta)) {
            New-Item -Path $Ruta -Force -ErrorAction Stop | Out-Null
        }
        New-ItemProperty -LiteralPath $Ruta -Name $Nombre -Value $Valor -PropertyType $Tipo -Force -ErrorAction Stop | Out-Null
        Write-Log "REG  $texto"
        return $true
    } catch {
        $msg = 'Registro: {0} - {1}' -f $texto, $_.Exception.Message
        if ($FalloComoAviso) { Write-Aviso $msg } else { Write-Fallo $msg }
        return $false
    }
}

# $true si el valor de registro ya existe con ese contenido y tipo.
function Test-RegValorIgual([string]$Ruta, [string]$Nombre, $Valor, [string]$Tipo) {
    try {
        if ($Ruta -match '<') { return $false }                       # ruta virtual de simulacion
        if (-not (Test-Path -LiteralPath $Ruta)) { return $false }
        $clave = Get-Item -LiteralPath $Ruta -ErrorAction Stop
        $n = $Nombre
        if ($Nombre -eq '(Default)') { $n = '' }
        if ($clave.GetValueNames() -notcontains $n) { return $false }
        $tipos = @{ String = 'String'; ExpandString = 'ExpandString'; DWord = 'DWord'; QWord = 'QWord'; MultiString = 'MultiString'; Binary = 'Binary' }
        if ([string]$clave.GetValueKind($n) -ne $tipos[$Tipo]) { return $false }
        $actual = $clave.GetValue($n, $null, 'DoNotExpandEnvironmentNames')
        switch ($Tipo) {
            'DWord' { return ([uint32]([int64]$Valor -band 0xFFFFFFFF)) -eq ([uint32]([int64]$actual -band 0xFFFFFFFF)) }
            'QWord' { return [int64]$actual -eq [int64]$Valor }
            'MultiString' { return (@($actual) -join "`n") -ceq (@($Valor) -join "`n") }
            'Binary' { return (@($actual) -join ',') -eq (@($Valor) -join ',') }
            default { return [string]$actual -ceq [string]$Valor }
        }
    } catch { return $false }
}

# Copia un archivo creando la carpeta destino. Con -Respaldo guarda el original como .wmud.bak.
function Copy-ArchivoSeguro {
    param(
        [Parameter(Mandatory)][string]$Origen,
        [Parameter(Mandatory)][string]$Destino,
        [switch]$Respaldo
    )
    $dir = Split-Path -Parent $Destino
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null }
    if ($Respaldo -and (Test-Path -LiteralPath $Destino)) {
        Copy-Item -LiteralPath $Destino -Destination "$Destino.wmud.bak" -Force -ErrorAction Stop
    }
    Copy-Item -LiteralPath $Origen -Destination $Destino -Force -ErrorAction Stop
}

# ==================================================
# PERFILES DE USUARIO
# ==================================================

# Devuelve los perfiles de usuario locales con NTUSER.DAT y el perfil Default.
function Get-PerfilesUsuario {
    $base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    # Perfiles de cuentas gestionadas por el sistema: no se tocan
    $sistema = @('WsiAccount', 'WDAGUtilityAccount', 'defaultuser0', 'defaultuser100000', 'DefaultAccount')
    $lista = @()
    foreach ($clave in Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue) {
        if ($clave.PSChildName -notmatch '^S-1-5-21-[\d-]+$') { continue }
        $ruta = (Get-ItemProperty -LiteralPath $clave.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
        if (-not $ruta) { continue }
        $ruta = [Environment]::ExpandEnvironmentVariables($ruta)
        if ($sistema -contains (Split-Path $ruta -Leaf)) { continue }
        # Sin Administrador no se pueden ver los perfiles de otros usuarios: se omiten en silencio
        if (-not (Test-Path -LiteralPath (Join-Path $ruta 'NTUSER.DAT') -ErrorAction SilentlyContinue)) { continue }
        $lista += [pscustomobject]@{ Nombre = (Split-Path $ruta -Leaf); Sid = $clave.PSChildName; Ruta = $ruta; EsDefault = $false }
    }
    $def = (Get-ItemProperty -LiteralPath $base -ErrorAction SilentlyContinue).Default
    if ($def) {
        $def = [Environment]::ExpandEnvironmentVariables($def)
        if (Test-Path -LiteralPath (Join-Path $def 'NTUSER.DAT')) {
            $lista += [pscustomobject]@{ Nombre = 'Default'; Sid = $null; Ruta = $def; EsDefault = $true }
        }
    }
    return $lista
}

function Mount-Colmena([string]$Nombre, [string]$Archivo) {
    $null = & reg.exe load "HKU\$Nombre" "$Archivo" 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return "Registry::HKEY_USERS\$Nombre"
}

function Dismount-Colmena([string]$Nombre) {
    for ($i = 0; $i -lt 5; $i++) {
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $null = & reg.exe unload "HKU\$Nombre" 2>&1
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Milliseconds 500
    }
    Write-Aviso "No se pudo descargar la colmena HKU\$Nombre (se liberara al reiniciar)"
}

# Ejecuta $Accion una vez por perfil de usuario (y Default), pasando un objeto con:
#   Nombre, Sid, Ruta, EsDefault
#   HKCU   -> raiz del registro del usuario (equivale a HKCU:\)
#   Clases -> raiz de HKCU\Software\Classes del usuario, o $null si no esta disponible
#             (en Default siempre es $null: las claves de clases se aplican con RunOnce)
# Los perfiles sin sesion abierta se cargan temporalmente con reg load.
function Invoke-EnPerfiles {
    param([Parameter(Mandatory)][scriptblock]$Accion)

    $indice = 0
    foreach ($p in Get-PerfilesUsuario) {
        $indice++
        $montadas = @()
        try {
            $hkcu = $null
            $clases = $null
            if (Test-Simulacion) {
                # Simulacion: no se cargan colmenas. Si el perfil ya esta cargado (sesion abierta) se usa
                # su registro real (solo se lee); si no, una ruta virtual <Nombre>.
                $hkcu = "Registry::HKEY_USERS\<$($p.Nombre)>"
                if ($p.Sid -and (Test-Path -LiteralPath "Registry::HKEY_USERS\$($p.Sid)")) { $hkcu = "Registry::HKEY_USERS\$($p.Sid)" }
                if (-not $p.EsDefault) {
                    $clases = "Registry::HKEY_USERS\<$($p.Nombre)>_Classes"
                    if ($p.Sid -and (Test-Path -LiteralPath "Registry::HKEY_USERS\$($p.Sid)_Classes")) { $clases = "Registry::HKEY_USERS\$($p.Sid)_Classes" }
                }
            } else {
                if ($p.Sid -and (Test-Path -LiteralPath "Registry::HKEY_USERS\$($p.Sid)")) {
                    $hkcu = "Registry::HKEY_USERS\$($p.Sid)"
                } else {
                    $nombre = "WMUD_P$indice"
                    $hkcu = Mount-Colmena $nombre (Join-Path $p.Ruta 'NTUSER.DAT')
                    if ($hkcu) { $montadas += $nombre }
                }
                if (-not $p.EsDefault) {
                    if ($p.Sid -and (Test-Path -LiteralPath "Registry::HKEY_USERS\$($p.Sid)_Classes")) {
                        $clases = "Registry::HKEY_USERS\$($p.Sid)_Classes"
                    } else {
                        $usr = Join-Path $p.Ruta 'AppData\Local\Microsoft\Windows\UsrClass.dat'
                        if (Test-Path -LiteralPath $usr) {
                            $nombre = "WMUD_P${indice}_Classes"
                            $clases = Mount-Colmena $nombre $usr
                            if ($clases) { $montadas += $nombre }
                        }
                    }
                }
            }
            if (-not $hkcu) {
                Write-Aviso "Perfil $($p.Nombre): no se pudo cargar su registro (en uso o sin permisos); se omite"
                continue
            }
            $perfil = [pscustomobject]@{
                Nombre = $p.Nombre; Sid = $p.Sid; Ruta = $p.Ruta; EsDefault = $p.EsDefault
                HKCU = $hkcu; Clases = $clases
            }
            $null = & $Accion $perfil
        } catch {
            Write-Fallo "Perfil $($p.Nombre): $($_.Exception.Message)"
        } finally {
            foreach ($m in $montadas) { Dismount-Colmena $m }
        }
    }
}

# Programa un comando para el primer inicio de sesion del usuario (RunOnce de su HKCU).
function Set-RunOnce([string]$HKCU, [string]$Nombre, [string]$Comando) {
    return (Set-RegValor -Ruta "$HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Nombre $Nombre -Valor $Comando -Tipo String)
}

# ==================================================
# UTILIDADES
# ==================================================

function Test-Admin {
    $id = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $id.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Comando([string]$Nombre) {
    return [bool](Get-Command $Nombre -ErrorAction SilentlyContinue)
}

# Recarga PATH desde el registro (tras instalar programas en esta misma sesion).
function Update-RutaEntorno {
    $maquina = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $usuario = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($maquina, $usuario | Where-Object { $_ }) -join ';'
}

# Convierte una identidad (IdentityReference o texto) en datos portables entre equipos:
#   Cuenta -> nombre sin el prefijo del equipo local (MADRID\maria -> maria)
#   Sid    -> SID solo si es una cuenta conocida de Windows (Todos, Administradores, SYSTEM...);
#             las cuentas locales cambian de SID en cada instalacion y se resuelven por nombre.
function ConvertTo-CuentaPortable($Identidad) {
    $nombre = [string]$Identidad
    $sid = $null
    try {
        $sid = (New-Object System.Security.Principal.NTAccount $nombre).Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        if ($nombre -match '^S-1-') { $sid = $nombre }
    }
    $prefijo = "$env:COMPUTERNAME\"
    if ($nombre.StartsWith($prefijo, [StringComparison]::OrdinalIgnoreCase)) { $nombre = $nombre.Substring($prefijo.Length) }
    $sidPortable = $null
    if ($sid -and $sid -notmatch '^S-1-5-21-') { $sidPortable = $sid }
    return [ordered]@{ Cuenta = $nombre; Sid = $sidPortable }
}

# Resuelve una cuenta portable en este equipo. Devuelve el nombre NT (localizado) o $null.
function Resolve-Cuenta([string]$Cuenta, [string]$Sid) {
    if ($Sid) {
        try { return (New-Object System.Security.Principal.SecurityIdentifier $Sid).Translate([System.Security.Principal.NTAccount]).Value } catch { }
    }
    if ($Cuenta) {
        $candidatos = @($Cuenta)
        if ($Cuenta -notmatch '\\') { $candidatos = @("$env:COMPUTERNAME\$Cuenta", $Cuenta) }
        foreach ($c in $candidatos) {
            try {
                $null = (New-Object System.Security.Principal.NTAccount $c).Translate([System.Security.Principal.SecurityIdentifier])
                return $c
            } catch { }
        }
    }
    return $null
}

# Nombres de los miembros de un grupo local (via ADSI: tolera SID huerfanos y cuentas Microsoft,
# con los que Get-LocalGroupMember falla).
function Get-MiembrosGrupo([string]$Grupo) {
    $adsi = [ADSI]"WinNT://$env:COMPUTERNAME/$Grupo,group"
    return @($adsi.psbase.Invoke('Members') | ForEach-Object { $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null) })
}

# Devuelve el comando de Python que tiene pip ('python' o 'py'), o $null.
# Ignora el alias de Microsoft Store (WindowsApps) y los Python sin pip.
function Get-PythonConPip {
    foreach ($c in 'python', 'py') {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if (-not $cmd -or $cmd.Source -match 'WindowsApps') { continue }
        $null = & $c -m pip --version 2>&1
        if ($LASTEXITCODE -eq 0) { return $c }
    }
    return $null
}

# Rutas portables entre usuarios/equipos: C:\Users\josel\AppData\Roaming\x -> %APPDATA%\x
# (se prueban de la mas larga a la mas corta). ConvertFrom-RutaPortable las expande.
function ConvertTo-RutaPortable([string]$Ruta) {
    if (-not $Ruta) { return $Ruta }
    $vars = @(
        @{ N = '%LOCALAPPDATA%'; V = $env:LOCALAPPDATA }
        @{ N = '%APPDATA%'; V = $env:APPDATA }
        @{ N = '%USERPROFILE%'; V = $env:USERPROFILE }
        @{ N = '%ProgramFiles(x86)%'; V = ${env:ProgramFiles(x86)} }
        @{ N = '%ProgramFiles%'; V = $env:ProgramFiles }
        @{ N = '%ProgramData%'; V = $env:ProgramData }
        @{ N = '%SystemRoot%'; V = $env:SystemRoot }
    )
    foreach ($v in $vars) {
        if (-not $v.V) { continue }
        $base = $v.V.TrimEnd('\')
        if ($Ruta.Equals($base, [StringComparison]::OrdinalIgnoreCase)) { return $v.N }
        if ($Ruta.StartsWith("$base\", [StringComparison]::OrdinalIgnoreCase)) { return $v.N + $Ruta.Substring($base.Length) }
    }
    return $Ruta
}

function ConvertFrom-RutaPortable([string]$Ruta) {
    if (-not $Ruta) { return $Ruta }
    return [Environment]::ExpandEnvironmentVariables($Ruta)
}

# $true si la ruta esta en la unidad de Windows (C:), la que se borra al reinstalar.
function Test-EnUnidadSistema([string]$Ruta) {
    if (-not $Ruta) { return $false }
    $r = ConvertFrom-RutaPortable $Ruta
    if (-not [IO.Path]::IsPathRooted($r) -or $r.StartsWith('\\')) { return $false }
    return ([IO.Path]::GetPathRoot($r).TrimEnd('\')) -ieq $env:SystemDrive
}

function Read-ConfigPsd1([string]$Ruta) {
    try {
        return Import-PowerShellDataFile -LiteralPath $Ruta -ErrorAction Stop
    } catch {
        throw "No se pudo leer '$Ruta': $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function *
