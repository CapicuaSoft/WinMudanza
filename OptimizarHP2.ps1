<#
.SYNOPSIS
    Configura un Windows 11 recien instalado y traslada la configuracion de un equipo a otro.

.DESCRIPTION
    OptimizarHP2 tiene dos acciones principales:

      Extraer  Lee la configuracion de ESTE equipo (usuarios, carpetas compartidas, paquetes,
               Office, UniGetUI, Steam) y la guarda en archivos .psd1 editables dentro de config\.
      Aplicar  Lee config\ y ajustes.psd1 y los aplica a ESTE equipo.

    Que modulos se ejecutan lo decide perfil.psd1; -Solo y -Omitir lo sobrescriben.
    Sin parametros se abre un menu interactivo.

    Requiere PowerShell como Administrador (la simulacion funciona sin serlo).

.PARAMETER Accion
    Extraer, Aplicar, Estado o Ayuda. Si se omite, se abre el menu.

.PARAMETER Solo
    Ejecuta solo estos modulos (ignora perfil.psd1). Ej: -Solo Usuarios,Compartidas

.PARAMETER Omitir
    Excluye estos modulos de la ejecucion. Ej: -Omitir Steam

.PARAMETER WhatIf
    Simulacion: muestra lo que haria Aplicar sin cambiar nada.

.PARAMETER DirConfig
    Carpeta de configuracion extraida. Por defecto: <carpeta del script>\config

.PARAMETER SinConfirmar
    No pide confirmacion antes de aplicar.

.EXAMPLE
    .\OptimizarHP2.ps1
    Abre el menu interactivo.

.EXAMPLE
    .\OptimizarHP2.ps1 -Accion Extraer
    Extrae la configuracion de este equipo a config\.

.EXAMPLE
    .\OptimizarHP2.ps1 -Accion Aplicar -WhatIf
    Muestra lo que se aplicaria, sin cambiar nada.

.EXAMPLE
    .\OptimizarHP2.ps1 -Accion Aplicar -Solo Compartidas,Ajustes
    Aplica solo esos dos modulos (util para completar pendientes).

.EXAMPLE
    .\OptimizarHP2.ps1 -Accion Aplicar -Omitir Steam -SinConfirmar
    Aplica todo lo activo en perfil.psd1 excepto Steam, sin preguntar.

.NOTES
    Documentacion completa en README.md y en la carpeta docs\.
#>
[CmdletBinding()]
param(
    [ValidateSet('Extraer', 'Aplicar', 'Estado', 'Ayuda')]
    [string]$Accion,
    [string[]]$Solo,
    [string[]]$Omitir,
    [switch]$WhatIf,
    [string]$DirConfig,
    [switch]$SinConfirmar
)

$ErrorActionPreference = 'Continue'
$Raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$Version = '2.1.0'

Import-Module (Join-Path $Raiz 'lib\Comun.psm1') -Force -DisableNameChecking -Global
Import-Module (Join-Path $Raiz 'lib\Psd1.psm1')  -Force -DisableNameChecking -Global
Import-Module (Join-Path $Raiz 'lib\Vdf.psm1')   -Force -DisableNameChecking -Global

# ==================================================
# CARGA DE PERFIL Y MODULOS
# ==================================================

$rutaPerfil = Join-Path $Raiz 'perfil.psd1'
if (-not (Test-Path -LiteralPath $rutaPerfil)) {
    Write-Host "No se encuentra perfil.psd1 en $Raiz" -ForegroundColor Red
    exit 1
}
$Perfil = Read-ConfigPsd1 $rutaPerfil

if (-not $DirConfig) {
    $DirConfig = 'config'
    if ($Perfil.DirConfig) { $DirConfig = $Perfil.DirConfig }
}
if (-not [IO.Path]::IsPathRooted($DirConfig)) { $DirConfig = Join-Path $Raiz $DirConfig }

# Cada archivo de modulos\ devuelve una tabla con:
#   Nombre, Descripcion, Orden, DependeDe, ArchivoConfig, Extraer {param($Ctx)}, Aplicar {param($Ctx)}
$Modulos = @(
    Get-ChildItem -LiteralPath (Join-Path $Raiz 'modulos') -Filter '*.ps1' |
        ForEach-Object { & $_.FullName } |
        Sort-Object { $_.Orden }
)
$NombresModulos = @($Modulos | ForEach-Object { $_.Nombre })

function Get-ModulosSeleccionados([string]$Acc, [string[]]$SoloLista, [string[]]$OmitirLista) {
    foreach ($n in @($SoloLista) + @($OmitirLista)) {
        if ($n -and $NombresModulos -notcontains $n) {
            throw "Modulo desconocido: '$n'. Disponibles: $($NombresModulos -join ', ')"
        }
    }
    $sel = @()
    foreach ($m in $Modulos) {
        $activo = $false
        if ($SoloLista) {
            $activo = $SoloLista -contains $m.Nombre
        } elseif ($Perfil.Modulos -and $Perfil.Modulos[$m.Nombre]) {
            $activo = [bool]$Perfil.Modulos[$m.Nombre][$Acc]
        }
        if ($OmitirLista -contains $m.Nombre) { $activo = $false }
        if ($activo) { $sel += $m.Nombre }
    }
    return $sel
}

# ==================================================
# EJECUCION
# ==================================================

function Invoke-Accion([string]$Acc, [string[]]$Seleccion, [bool]$Simular) {
    $estado = Initialize-OHP2 -Raiz $Raiz -Accion $Acc -Simular:$Simular

    if (-not (Test-Admin)) {
        if ($Simular) {
            Write-Host ''
            Write-Host 'Aviso: sin permisos de Administrador. La simulacion continua, pero el resultado real puede variar.' -ForegroundColor Yellow
        } elseif ($Acc -eq 'Extraer') {
            Write-Host ''
            Write-Host 'Aviso: sin permisos de Administrador. Algunos datos (permisos de carpetas compartidas) pueden faltar.' -ForegroundColor Yellow
            Write-Host '       Para una extraccion completa ejecuta PowerShell como Administrador.' -ForegroundColor Yellow
        } else {
            Write-Host ''
            Write-Host 'Esta accion requiere PowerShell como Administrador.' -ForegroundColor Red
            return 1
        }
    }

    if ($Acc -eq 'Extraer' -and -not (Test-Path -LiteralPath $DirConfig)) {
        New-Item -ItemType Directory -Path $DirConfig -Force | Out-Null
    }

    $ctx = [pscustomobject]@{
        Raiz      = $Raiz
        DirConfig = $DirConfig
        Simular   = $Simular
        Accion    = $Acc
        Version   = $Version
        Seleccion = $Seleccion
    }

    $aEjecutar = @($Modulos | Where-Object { $Seleccion -contains $_.Nombre })
    $resultados = @()
    $i = 0
    foreach ($m in $Modulos) {
        if ($Seleccion -notcontains $m.Nombre) {
            $resultados += [pscustomobject]@{ Modulo = $m.Nombre; Resultado = 'OMITIDO'; Detalle = 'no seleccionado' }
            continue
        }
        $i++
        Write-Titulo ("[{0}/{1} {2}] {3}" -f $i, $aEjecutar.Count, $m.Nombre, $m.Descripcion)
        Set-ModuloActual $m.Nombre

        foreach ($dep in @($m.DependeDe)) {
            if ($dep -and $Acc -eq 'Aplicar' -and $Seleccion -notcontains $dep) {
                Write-Info "Depende de '$dep', que no se ejecuta ahora; se usa el estado actual del equipo."
            }
        }

        $bloque = $m[$Acc]
        if (-not $bloque) {
            Write-Omitido "Este modulo no tiene accion '$Acc'"
            $resultados += [pscustomobject]@{ Modulo = $m.Nombre; Resultado = 'OMITIDO'; Detalle = "sin accion $Acc" }
            continue
        }
        if ($Acc -eq 'Aplicar' -and $m.ArchivoConfig) {
            $rutaCfg = Join-Path $DirConfig $m.ArchivoConfig
            if (-not (Test-Path -LiteralPath $rutaCfg)) {
                Write-Omitido "No existe $($m.ArchivoConfig) en $DirConfig (ejecuta antes Extraer)"
                $resultados += [pscustomobject]@{ Modulo = $m.Nombre; Resultado = 'OMITIDO'; Detalle = "falta $($m.ArchivoConfig)" }
                continue
            }
        }

        $errAntes = $estado.Errores
        $avAntes = $estado.Avisos
        try {
            $null = & $bloque $ctx
        } catch {
            Write-Fallo "Error no controlado: $($_.Exception.Message)"
            Write-Log $_.ScriptStackTrace
        }
        $res = 'OK'
        if ($estado.Errores -gt $errAntes) { $res = 'ERROR' }
        elseif ($estado.Avisos -gt $avAntes) { $res = 'CON AVISOS' }
        $resultados += [pscustomobject]@{
            Modulo = $m.Nombre; Resultado = $res
            Detalle = ('{0} errores, {1} avisos' -f ($estado.Errores - $errAntes), ($estado.Avisos - $avAntes))
        }
    }
    Set-ModuloActual ''

    # ---- Resumen ----
    $titulo = "RESUMEN $($Acc.ToUpper())"
    if ($Simular) { $titulo += ' (SIMULACION: no se cambio nada)' }
    Write-Host ''
    Write-Host '  ==============================================' -ForegroundColor White
    Write-Host "   $titulo" -ForegroundColor White
    Write-Host '  ==============================================' -ForegroundColor White
    foreach ($r in $resultados) {
        $color = switch ($r.Resultado) { 'OK' { 'Green' } 'ERROR' { 'Red' } 'CON AVISOS' { 'Yellow' } default { 'DarkGray' } }
        Write-Host ('   {0,-12} {1,-11} {2}' -f $r.Modulo, $r.Resultado, $r.Detalle) -ForegroundColor $color
        Write-Log ('RESUMEN {0} {1} {2}' -f $r.Modulo, $r.Resultado, $r.Detalle)
    }
    if ($estado.Pendientes.Count -gt 0) {
        Write-Host ''
        Write-Host '   PENDIENTE (hacer a mano):' -ForegroundColor Magenta
        foreach ($p in $estado.Pendientes) { Write-Host "    - $p" -ForegroundColor Magenta; Write-Log "PENDIENTE $p" }
    }
    Write-Host ''
    if ($Acc -eq 'Aplicar' -and -not $Simular) { Write-Host '   Reinicia el equipo para completar los cambios.' -ForegroundColor White }
    Write-Host "   Log: $($estado.Log)" -ForegroundColor DarkGray

    if ($estado.Errores -gt 0) { return 1 }
    return 0
}

function Show-Estado {
    Write-Host ''
    Write-Host "Configuracion en: $DirConfig" -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $DirConfig)) {
        Write-Host '  (no existe todavia: ejecuta Extraer)' -ForegroundColor DarkGray
        return
    }
    foreach ($m in $Modulos) {
        if (-not $m.ArchivoConfig) { continue }
        $ruta = Join-Path $DirConfig $m.ArchivoConfig
        if (Test-Path -LiteralPath $ruta) {
            $f = Get-Item -LiteralPath $ruta
            Write-Host ('  {0,-12} {1,-18} {2:yyyy-MM-dd HH:mm}' -f $m.Nombre, $m.ArchivoConfig, $f.LastWriteTime) -ForegroundColor Green
        } else {
            Write-Host ('  {0,-12} {1,-18} (no extraido)' -f $m.Nombre, $m.ArchivoConfig) -ForegroundColor DarkGray
        }
    }
    $usuarios = Join-Path $DirConfig 'usuarios.psd1'
    if (Test-Path -LiteralPath $usuarios) {
        $cfg = Import-PowerShellDataFile -LiteralPath $usuarios
        $sinPass = @($cfg.Usuarios | Where-Object { $_.Password -eq 'CAMBIAR' })
        if ($sinPass.Count -gt 0) {
            Write-Host ''
            Write-Host ("  Contrasenas sin completar en usuarios.psd1: {0}" -f (($sinPass | ForEach-Object { $_.Nombre }) -join ', ')) -ForegroundColor Yellow
        }
    }
}

function Show-Ayuda {
    Get-Help $PSCommandPath -Detailed
    Write-Host ''
    Write-Host 'Documentacion: README.md y docs\ (GUIA_USO.md, CONFIGURACION.md, MODULOS.md, PROBLEMAS.md)' -ForegroundColor Cyan
}

# ==================================================
# MENU INTERACTIVO
# ==================================================

function Select-Modulos([string]$Acc) {
    $sel = New-Object System.Collections.ArrayList
    foreach ($n in (Get-ModulosSeleccionados $Acc $null $null)) { [void]$sel.Add($n) }
    while ($true) {
        Write-Host ''
        Write-Host "  Modulos a $($Acc.ToLower()) (segun perfil.psd1):" -ForegroundColor White
        for ($i = 0; $i -lt $Modulos.Count; $i++) {
            $m = $Modulos[$i]
            $marca = ' '
            if ($sel -contains $m.Nombre) { $marca = 'x' }
            $sinAccion = ''
            if (-not $m[$Acc]) { $sinAccion = ' (no aplica)' }
            Write-Host ('   [{0}] {1} {2,-12} {3}{4}' -f $marca, ($i + 1), $m.Nombre, $m.Descripcion, $sinAccion)
        }
        $r = Read-Host '  Numero para marcar/desmarcar, Enter para continuar, 0 para cancelar'
        if ($r -eq '') { return , @($sel) }
        if ($r -eq '0') { return $null }
        $n = 0
        if ([int]::TryParse($r, [ref]$n) -and $n -ge 1 -and $n -le $Modulos.Count) {
            $nombre = $Modulos[$n - 1].Nombre
            if ($sel -contains $nombre) { $sel.Remove($nombre) } else { [void]$sel.Add($nombre) }
        }
    }
}

function Show-Menu {
    $adminTxt = 'NO admin'
    if (Test-Admin) { $adminTxt = 'admin' }
    $os = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue)
    while ($true) {
        Write-Host ''
        Write-Host '  ==============================================' -ForegroundColor Cyan
        Write-Host ("   OptimizarHP2 v{0}        Equipo: {1}" -f $Version, $env:COMPUTERNAME) -ForegroundColor Cyan
        Write-Host ("   {0} {1}   Usuario: {2} ({3})" -f ($os.Caption -replace 'Microsoft ', ''), $os.BuildNumber, $env:USERNAME, $adminTxt) -ForegroundColor Cyan
        Write-Host '  ==============================================' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '   1) Extraer configuracion de este equipo'
        Write-Host '   2) Aplicar configuracion a este equipo'
        Write-Host '   3) Aplicar en modo simulacion (no cambia nada)'
        Write-Host '   4) Ver estado de config\'
        Write-Host '   5) Ayuda'
        Write-Host '   0) Salir'
        Write-Host ''
        $op = Read-Host '  Opcion'
        switch ($op) {
            '1' {
                $sel = Select-Modulos 'Extraer'
                if ($null -ne $sel) { $null = Invoke-Accion 'Extraer' $sel $false }
            }
            '2' {
                $sel = Select-Modulos 'Aplicar'
                if ($null -ne $sel) {
                    $r = Read-Host "  Se aplicaran: $($sel -join ', '). Continuar? (S/N)"
                    if ($r -match '^[sS]') { $null = Invoke-Accion 'Aplicar' $sel $false }
                }
            }
            '3' {
                $sel = Select-Modulos 'Aplicar'
                if ($null -ne $sel) { $null = Invoke-Accion 'Aplicar' $sel $true }
            }
            '4' { Show-Estado }
            '5' { Show-Ayuda }
            '0' { return }
            default { continue }
        }
        Write-Host ''
        $null = Read-Host '  Pulsa Enter para volver al menu'
    }
}

# ==================================================
# ENTRADA
# ==================================================

if (-not $Accion) {
    Show-Menu
    exit 0
}

switch ($Accion) {
    'Estado' { Show-Estado; exit 0 }
    'Ayuda'  { Show-Ayuda;  exit 0 }
}

try {
    $seleccion = Get-ModulosSeleccionados $Accion $Solo $Omitir
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
if ($seleccion.Count -eq 0) {
    Write-Host 'No hay modulos seleccionados (revisa perfil.psd1, -Solo y -Omitir).' -ForegroundColor Yellow
    exit 0
}

$simular = [bool]$WhatIf
if ($Accion -eq 'Extraer' -and $simular) {
    Write-Host 'Extraer no cambia el equipo: -WhatIf no es necesario y se ignora.' -ForegroundColor DarkGray
    $simular = $false
}

if ($Accion -eq 'Aplicar' -and -not $simular -and -not $SinConfirmar) {
    Write-Host ''
    Write-Host "  Se aplicaran: $($seleccion -join ', ')" -ForegroundColor White
    $r = Read-Host '  Continuar? (S/N)'
    if ($r -notmatch '^[sS]') { Write-Host '  Cancelado.'; exit 0 }
}

$codigo = Invoke-Accion $Accion $seleccion $simular
exit $codigo
