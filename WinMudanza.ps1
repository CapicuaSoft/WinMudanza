<#
.SYNOPSIS
    Configura un Windows 11 recien instalado y traslada la configuracion de un equipo a otro.

.DESCRIPTION
    Acciones:

      Extraer   Lee la configuracion de ESTE equipo y la guarda en archivos .psd1 editables en config\.
                Al terminar revisa que no dependa de nada que este en C: y, si perfil.psd1 tiene
                CopiarA, copia WinMudanza y config\ alli (p. ej. a D: o un USB).
      Revisar   Antes de formatear: avisa de todo lo que la configuracion necesita y esta en C:
                (carpetas compartidas, juegos, la propia config\...).
      Copiar    Copia WinMudanza con su config\ a otra unidad (-Destino o CopiarA de perfil.psd1).
      Aplicar   Lee config\ y lo aplica a ESTE equipo. Si un modulo necesita reiniciar (p. ej. al
                activar WSL), programa la continuacion y sigue sola tras reiniciar.
      Comparar  Muestra que diferencias hay entre config\ y este equipo (no cambia nada).
      Estado    Muestra que hay en config\.

    Que modulos se ejecutan lo decide config\perfil.psd1; -Solo y -Omitir lo sobrescriben.
    Sin parametros se abre un menu interactivo. Facil de arrancar con doble clic en WinMudanza.cmd.

    Aplicar requiere PowerShell como Administrador (la simulacion y Comparar funcionan sin serlo).

.PARAMETER Accion
    Extraer, Revisar, Copiar, Aplicar, Comparar, Estado o Ayuda. Si se omite, se abre el menu.

.PARAMETER Solo
    Ejecuta solo estos modulos (ignora perfil.psd1). Ej: -Solo Usuarios,Compartidas

.PARAMETER Omitir
    Excluye estos modulos de la ejecucion. Ej: -Omitir Steam

.PARAMETER WhatIf
    Simulacion: muestra lo que haria Aplicar sin cambiar nada.

.PARAMETER DirConfig
    Carpeta de la configuracion extraida. Por defecto: <carpeta del script>\config

.PARAMETER Destino
    Para -Accion Copiar: carpeta de destino (p. ej. D:\WinMudanza).

.PARAMETER SinConfirmar
    No pregunta nada: ni confirmacion, ni contrasenas, ni reiniciar.

.PARAMETER SinReiniciar
    Aplica todos los modulos seguidos aunque alguno necesite reiniciar (el reinicio queda pendiente).

.PARAMETER Continuacion
    Uso interno: ejecucion programada tras un reinicio.

.EXAMPLE
    .\WinMudanza.ps1
    Abre el menu interactivo.

.EXAMPLE
    .\WinMudanza.ps1 -Accion Extraer
    Extrae la configuracion de este equipo a config\ y revisa lo que hay en C:.

.EXAMPLE
    .\WinMudanza.ps1 -Accion Copiar -Destino D:\WinMudanza
    Copia WinMudanza y su configuracion a D: antes de formatear C:.

.EXAMPLE
    .\WinMudanza.ps1 -Accion Aplicar -WhatIf
    Muestra lo que se aplicaria, sin cambiar nada.

.EXAMPLE
    .\WinMudanza.ps1 -Accion Comparar
    Lista las diferencias entre config\ y este equipo.

.EXAMPLE
    .\WinMudanza.ps1 -Accion Aplicar -Omitir Steam -SinConfirmar
    Aplica todo lo activo en perfil.psd1 excepto Steam, sin preguntar.

.NOTES
    Documentacion completa en README.md y en la carpeta docs\.
#>
[CmdletBinding()]
param(
    [ValidateSet('Extraer', 'Revisar', 'Copiar', 'Aplicar', 'Comparar', 'Estado', 'Ayuda')]
    [string]$Accion,
    [string[]]$Solo,
    [string[]]$Omitir,
    [switch]$WhatIf,
    [string]$DirConfig,
    [string]$Destino,
    [switch]$SinConfirmar,
    [switch]$SinReiniciar,
    [switch]$Continuacion
)

$ErrorActionPreference = 'Continue'
$Raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$Version = '3.0.0'
$TareaContinuar = 'WinMudanza-Continuar'

# Librerias comunes (lib\) y librerias propias de cada modulo (modulos\<Modulo>\*.psm1)
Import-Module (Join-Path $Raiz 'lib\Comun.psm1') -Force -DisableNameChecking -Global
Import-Module (Join-Path $Raiz 'lib\Psd1.psm1')  -Force -DisableNameChecking -Global
Get-ChildItem -Path (Join-Path $Raiz 'modulos\*\*.psm1') -File | Sort-Object FullName |
    ForEach-Object { Import-Module $_.FullName -Force -DisableNameChecking -Global }

# Con powershell -File las listas llegan como un solo texto "A,B": se separan aqui.
$Solo   = @($Solo   | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Omitir = @($Omitir | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# ==================================================
# CARGA DE PERFIL Y MODULOS
# ==================================================

$rutaPerfil = Join-Path $Raiz 'config\perfil.psd1'
if (-not (Test-Path -LiteralPath $rutaPerfil)) {
    Write-Host "No se encuentra $rutaPerfil" -ForegroundColor Red
    exit 1
}
$Perfil = Read-ConfigPsd1 $rutaPerfil

if (-not $DirConfig) {
    $DirConfig = 'config'
    if ($Perfil.DirConfig) { $DirConfig = $Perfil.DirConfig }
}
if (-not [IO.Path]::IsPathRooted($DirConfig)) { $DirConfig = Join-Path $Raiz $DirConfig }

# Cada archivo de modulos\ devuelve una tabla con:
#   Nombre, Descripcion, Orden, DependeDe, ArchivoConfig,
#   Extraer {param($Ctx)}, Aplicar {param($Ctx)} y, opcional, Revisar {param($Ctx)}
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
    # Comparar usa la seleccion de Aplicar; Revisar la de Extraer
    $clave = $Acc
    if ($Acc -eq 'Comparar') { $clave = 'Aplicar' }
    if ($Acc -eq 'Revisar') { $clave = 'Extraer' }
    $sel = @()
    foreach ($m in $Modulos) {
        $activo = $false
        if ($SoloLista) {
            $activo = $SoloLista -contains $m.Nombre
        } elseif ($Perfil.Modulos -and $Perfil.Modulos[$m.Nombre]) {
            $activo = [bool]$Perfil.Modulos[$m.Nombre][$clave]
        }
        if ($OmitirLista -contains $m.Nombre) { $activo = $false }
        if ($activo) { $sel += $m.Nombre }
    }
    return $sel
}

# ==================================================
# REVISION ANTES DE FORMATEAR
# ==================================================

# Comprobaciones generales + el bloque Revisar de cada modulo seleccionado.
function Invoke-Revision($Ctx, [string[]]$Seleccion) {
    Write-Titulo 'REVISION ANTES DE FORMATEAR (lo que esta en C: se borrara)'
    Set-ModuloActual 'Revisar'
    $avisosAntes = (Get-WinMudanzaEstado).Avisos

    if (Test-EnUnidadSistema $Ctx.DirConfig) {
        $copia = [string]$Perfil.CopiarA
        $unidadCopia = $null
        if ($copia) { $unidadCopia = [IO.Path]::GetPathRoot($copia) }
        if ($Ctx.Accion -eq 'Extraer' -and $copia -and -not (Test-EnUnidadSistema $copia) -and $unidadCopia -and (Test-Path -LiteralPath $unidadCopia)) {
            Write-Ok "La configuracion esta en C:, pero al terminar se copiara a $copia (CopiarA)"
        } elseif ($copia -and -not (Test-EnUnidadSistema $copia) -and (Test-Path -LiteralPath (Join-Path $copia 'WinMudanza.ps1'))) {
            $f = (Get-Item -LiteralPath (Join-Path $copia 'WinMudanza.ps1')).LastWriteTime
            Write-Ok "Hay una copia de WinMudanza en $copia (actualizada $($f.ToString('yyyy-MM-dd HH:mm')))"
        } else {
            Write-Aviso "La configuracion extraida esta en C: ($($Ctx.DirConfig)). Copiala fuera antes de formatear: -Accion Copiar -Destino D:\WinMudanza"
        }
    } else {
        Write-Ok "La configuracion esta fuera de C: ($($Ctx.DirConfig))"
    }

    foreach ($m in $Modulos) {
        if ($Seleccion -notcontains $m.Nombre -or -not $m.Revisar) { continue }
        if ($m.ArchivoConfig -and -not (Test-Path -LiteralPath (Join-Path $Ctx.DirConfig $m.ArchivoConfig))) { continue }
        Set-ModuloActual $m.Nombre
        try { $null = & $m.Revisar $Ctx } catch { Write-Fallo "$($m.Nombre): $($_.Exception.Message)" }
    }
    Set-ModuloActual 'Revisar'
    Write-Info 'Recuerda: WinMudanza NO copia tus documentos, fotos, escritorio ni descargas de C:\Users.'
    Write-Info 'Haz copia de seguridad de esos datos aparte.'
    if ((Get-WinMudanzaEstado).Avisos -eq $avisosAntes) { Write-Ok 'Nada de la configuracion depende de C:' }
    Set-ModuloActual ''
}

# ==================================================
# COPIAR FUERA DE C:
# ==================================================

function Copy-WinMudanza([string]$Dest) {
    if (-not $Dest) { $Dest = [string]$Perfil.CopiarA }
    if (-not $Dest) {
        Write-Host 'Indica el destino: -Destino D:\WinMudanza (o CopiarA en config\perfil.psd1).' -ForegroundColor Red
        return 1
    }
    $Dest = $Dest.TrimEnd('\')
    $unidad = [IO.Path]::GetPathRoot($Dest)
    if (-not $unidad -or -not (Test-Path -LiteralPath $unidad)) {
        Write-Host "No existe la unidad de destino ($unidad). Conecta el disco o USB, o cambia CopiarA." -ForegroundColor Red
        return 1
    }
    if ($Dest -ieq $Raiz.TrimEnd('\')) { Write-Host 'El destino es la propia carpeta de WinMudanza.' -ForegroundColor Yellow; return 0 }
    if (Test-EnUnidadSistema $Dest) { Write-Host "Aviso: $Dest tambien esta en $env:SystemDrive y se borrara al formatear." -ForegroundColor Yellow }
    if ((Test-Path -LiteralPath $Dest) -and (Get-ChildItem -LiteralPath $Dest -Force | Select-Object -First 1) -and
        -not (Test-Path -LiteralPath (Join-Path $Dest 'WinMudanza.ps1'))) {
        Write-Host "$Dest no esta vacia y no es una copia de WinMudanza: no se sobrescribe." -ForegroundColor Red
        return 1
    }

    Write-Host "Copiando $Raiz -> $Dest ..." -ForegroundColor Cyan
    $null = & robocopy.exe $Raiz $Dest /MIR /XD (Join-Path $Raiz 'logs') /R:1 /W:1 /NFL /NDL /NJH /NP
    if ($LASTEXITCODE -ge 8) { Write-Host "Error al copiar (robocopy codigo $LASTEXITCODE)." -ForegroundColor Red; return 1 }

    # Configuracion extraida fuera de la carpeta del proyecto
    $dentro = $DirConfig.StartsWith("$($Raiz.TrimEnd('\'))\", [StringComparison]::OrdinalIgnoreCase)
    if (-not $dentro -and (Test-Path -LiteralPath $DirConfig)) {
        $null = & robocopy.exe $DirConfig (Join-Path $Dest 'config') /E /R:1 /W:1 /NFL /NDL /NJH /NP
        if ($LASTEXITCODE -ge 8) { Write-Host "Error al copiar $DirConfig (robocopy codigo $LASTEXITCODE)." -ForegroundColor Red; return 1 }
    }
    Write-Host "Copia lista en $Dest" -ForegroundColor Green
    Write-Host "En el equipo nuevo ejecuta $Dest\WinMudanza.cmd" -ForegroundColor Green
    return 0
}

# ==================================================
# CONTINUAR TRAS REINICIAR
# ==================================================

function Register-Continuacion([string[]]$Restantes) {
    $cuenta = "$env:USERDOMAIN\$env:USERNAME"
    $argumentos = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" -Accion Aplicar -Solo $($Restantes -join ',') -DirConfig `"$DirConfig`" -Continuacion"
    if ($SinConfirmar) { $argumentos += ' -SinConfirmar' }
    $accionTarea = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argumentos -WorkingDirectory $Raiz
    $disparador = New-ScheduledTaskTrigger -AtLogOn -User $cuenta
    $principal = New-ScheduledTaskPrincipal -UserId $cuenta -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $TareaContinuar -Action $accionTarea -Trigger $disparador -Principal $principal `
        -Description 'WinMudanza: continua Aplicar tras reiniciar (se borra sola)' -Force -ErrorAction Stop | Out-Null
}

# ==================================================
# EJECUCION
# ==================================================

# $Acc: Extraer | Revisar | Aplicar | Comparar. Comparar = Aplicar simulado contando diferencias.
function Invoke-Accion([string]$Acc, [string[]]$Seleccion, [bool]$Simular) {
    $accionReal = $Acc
    if ($Acc -eq 'Comparar') { $accionReal = 'Aplicar'; $Simular = $true }
    $estado = Initialize-WinMudanza -Raiz $Raiz -Accion $Acc -Simular:$Simular

    if (-not (Test-Admin)) {
        if ($Simular) {
            Write-Host ''
            Write-Host 'Aviso: sin permisos de Administrador. La simulacion continua, pero el resultado real puede variar.' -ForegroundColor Yellow
        } elseif ($Acc -in 'Extraer', 'Revisar') {
            Write-Host ''
            Write-Host 'Aviso: sin permisos de Administrador. Algunos datos (permisos de carpetas compartidas, Wi-Fi) pueden faltar.' -ForegroundColor Yellow
            Write-Host '       Para una extraccion completa ejecuta PowerShell como Administrador.' -ForegroundColor Yellow
        } else {
            Write-Host ''
            Write-Host 'Esta accion requiere PowerShell como Administrador (usa WinMudanza.cmd).' -ForegroundColor Red
            return 1
        }
    }

    if ($Acc -eq 'Extraer' -and -not (Test-Path -LiteralPath $DirConfig)) {
        New-Item -ItemType Directory -Path $DirConfig -Force | Out-Null
    }

    $ctx = [pscustomobject]@{
        Raiz       = $Raiz
        DirConfig  = $DirConfig
        Simular    = $Simular
        Accion     = $accionReal
        Version    = $Version
        Seleccion  = $Seleccion
        Interactivo = (-not $SinConfirmar) -and [Environment]::UserInteractive
    }

    if ($Acc -eq 'Revisar') {
        Invoke-Revision $ctx $Seleccion
        Write-Host ''
        Write-Host "   Log: $($estado.Log)" -ForegroundColor DarkGray
        if ($estado.Errores -gt 0) { return 1 }
        return 0
    }

    $continuar = [bool]$Perfil.ContinuarTrasReinicio -and -not $SinReiniciar -and -not $Simular -and $accionReal -eq 'Aplicar'
    $aEjecutar = @($Modulos | Where-Object { $Seleccion -contains $_.Nombre })
    $resultados = @()
    $restantes = @()
    $i = 0
    foreach ($m in $Modulos) {
        if ($Seleccion -notcontains $m.Nombre) {
            $resultados += [pscustomobject]@{ Modulo = $m.Nombre; Resultado = 'OMITIDO'; Detalle = 'no seleccionado' }
            continue
        }
        if ($estado.Reinicio -and $continuar) {
            $restantes += $m.Nombre
            $resultados += [pscustomobject]@{ Modulo = $m.Nombre; Resultado = 'TRAS REINICIO'; Detalle = 'continuara al iniciar sesion' }
            continue
        }
        $i++
        Write-Titulo ("[{0}/{1} {2}] {3}" -f $i, $aEjecutar.Count, $m.Nombre, $m.Descripcion)
        Set-ModuloActual $m.Nombre

        foreach ($dep in @($m.DependeDe)) {
            if ($dep -and $accionReal -eq 'Aplicar' -and $Seleccion -notcontains $dep) {
                Write-Info "Depende de '$dep', que no se ejecuta ahora; se usa el estado actual del equipo."
            }
        }

        $bloque = $m[$accionReal]
        if (-not $bloque) {
            Write-Omitido "Este modulo no tiene accion '$accionReal'"
            $resultados += [pscustomobject]@{ Modulo = $m.Nombre; Resultado = 'OMITIDO'; Detalle = "sin accion $accionReal" }
            continue
        }
        if ($accionReal -eq 'Aplicar' -and $m.ArchivoConfig) {
            $rutaCfg = Join-Path $DirConfig $m.ArchivoConfig
            if (-not (Test-Path -LiteralPath $rutaCfg)) {
                Write-Omitido "No existe $($m.ArchivoConfig) en $DirConfig (ejecuta antes Extraer)"
                $resultados += [pscustomobject]@{ Modulo = $m.Nombre; Resultado = 'OMITIDO'; Detalle = "falta $($m.ArchivoConfig)" }
                continue
            }
        }

        $errAntes = $estado.Errores
        $avAntes = $estado.Avisos
        $simAntes = $estado.Simulados
        try {
            $null = & $bloque $ctx
        } catch {
            Write-Fallo "Error no controlado: $($_.Exception.Message)"
            Write-Log $_.ScriptStackTrace
        }
        $errores = $estado.Errores - $errAntes
        $avisos = $estado.Avisos - $avAntes
        if ($Acc -eq 'Comparar') {
            $dif = $estado.Simulados - $simAntes
            $res = 'AL DIA'
            $detalle = 'sin diferencias'
            if ($dif -gt 0) { $res = 'DIFERENCIAS'; $detalle = "$dif cambios por aplicar" }
            if ($errores -gt 0) { $res = 'ERROR'; $detalle += ", $errores errores" }
        } else {
            $res = 'OK'
            if ($errores -gt 0) { $res = 'ERROR' } elseif ($avisos -gt 0) { $res = 'CON AVISOS' }
            $detalle = '{0} errores, {1} avisos' -f $errores, $avisos
        }
        $resultados += [pscustomobject]@{ Modulo = $m.Nombre; Resultado = $res; Detalle = $detalle }
    }
    Set-ModuloActual ''

    if ($Acc -eq 'Extraer') { Invoke-Revision $ctx $Seleccion }

    # ---- Continuacion tras reiniciar ----
    $reiniciarAhora = $false
    if ($restantes.Count -gt 0) {
        Write-Host ''
        Write-Host "  Hay que reiniciar antes de seguir: $($estado.Reinicio)" -ForegroundColor Magenta
        try {
            Register-Continuacion $restantes
            Write-Host "  Al iniciar sesion de nuevo como $env:USERNAME se continuara con: $($restantes -join ', ')" -ForegroundColor Magenta
            Write-Log "CONTINUACION programada: $($restantes -join ',')"
            if ($ctx.Interactivo) {
                $r = Read-Host '  Reiniciar ahora? (S/N)'
                $reiniciarAhora = $r -match '^[sS]'
            }
        } catch {
            Write-Fallo "No se pudo programar la continuacion ($($_.Exception.Message)). Reinicia y ejecuta: -Accion Aplicar -Solo $($restantes -join ',')"
        }
    }

    # ---- Resumen ----
    $titulo = "RESUMEN $($Acc.ToUpper())"
    if ($Simular -and $Acc -ne 'Comparar') { $titulo += ' (SIMULACION: no se cambio nada)' }
    if ($Acc -eq 'Comparar') { $titulo += ' (no se cambio nada)' }
    Write-Host ''
    Write-Host '  ==============================================' -ForegroundColor White
    Write-Host "   $titulo" -ForegroundColor White
    Write-Host '  ==============================================' -ForegroundColor White
    foreach ($r in $resultados) {
        $color = switch ($r.Resultado) {
            'OK' { 'Green' } 'AL DIA' { 'Green' } 'ERROR' { 'Red' } 'CON AVISOS' { 'Yellow' }
            'DIFERENCIAS' { 'Yellow' } 'TRAS REINICIO' { 'Magenta' } default { 'DarkGray' }
        }
        Write-Host ('   {0,-15} {1,-13} {2}' -f $r.Modulo, $r.Resultado, $r.Detalle) -ForegroundColor $color
        Write-Log ('RESUMEN {0} {1} {2}' -f $r.Modulo, $r.Resultado, $r.Detalle)
    }
    if ($estado.Pendientes.Count -gt 0) {
        Write-Host ''
        Write-Host '   PENDIENTE (hacer a mano):' -ForegroundColor Magenta
        foreach ($p in $estado.Pendientes) { Write-Host "    - $p" -ForegroundColor Magenta; Write-Log "PENDIENTE $p" }
    }
    Write-Host ''
    if ($accionReal -eq 'Aplicar' -and -not $Simular -and $restantes.Count -eq 0) { Write-Host '   Reinicia el equipo para completar los cambios.' -ForegroundColor White }
    Write-Host "   Log: $($estado.Log)" -ForegroundColor DarkGray

    if ($Acc -eq 'Extraer' -and $Perfil.CopiarA) {
        Write-Host ''
        $null = Copy-WinMudanza ([string]$Perfil.CopiarA)
    }
    if ($reiniciarAhora) {
        Write-Host '   Reiniciando en 10 segundos (Ctrl+C para cancelar)...' -ForegroundColor Magenta
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }

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
            Write-Host ('  {0,-15} {1,-20} {2:yyyy-MM-dd HH:mm}' -f $m.Nombre, $m.ArchivoConfig, $f.LastWriteTime) -ForegroundColor Green
        } else {
            Write-Host ('  {0,-15} {1,-20} (no extraido)' -f $m.Nombre, $m.ArchivoConfig) -ForegroundColor DarkGray
        }
    }
    $usuarios = Join-Path $DirConfig 'usuarios.psd1'
    if (Test-Path -LiteralPath $usuarios) {
        $cfg = Import-PowerShellDataFile -LiteralPath $usuarios
        $sinPass = @($cfg.Usuarios | Where-Object { $_.Password -eq 'CAMBIAR' })
        if ($sinPass.Count -gt 0) {
            Write-Host ''
            Write-Host ("  Contrasenas sin completar en usuarios.psd1: {0} (se pediran al aplicar)" -f (($sinPass | ForEach-Object { $_.Nombre }) -join ', ')) -ForegroundColor Yellow
        }
    }
    if (Get-ScheduledTask -TaskName $TareaContinuar -ErrorAction SilentlyContinue) {
        Write-Host ''
        Write-Host "  Hay una continuacion programada tras reiniciar (tarea $TareaContinuar)." -ForegroundColor Magenta
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
    $clave = $Acc
    if ($Acc -eq 'Comparar') { $clave = 'Aplicar' }
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
            if (-not $m[$clave]) { $sinAccion = ' (no aplica)' }
            Write-Host ('   [{0}] {1,2} {2,-15} {3}{4}' -f $marca, ($i + 1), $m.Nombre, $m.Descripcion, $sinAccion)
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
        Write-Host ("   WinMudanza v{0}        Equipo: {1}" -f $Version, $env:COMPUTERNAME) -ForegroundColor Cyan
        Write-Host ("   {0} {1}   Usuario: {2} ({3})" -f ($os.Caption -replace 'Microsoft ', ''), $os.BuildNumber, $env:USERNAME, $adminTxt) -ForegroundColor Cyan
        Write-Host '  ==============================================' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '   EQUIPO ACTUAL (antes de formatear)'
        Write-Host '   1) Extraer configuracion de este equipo'
        Write-Host '   2) Revisar lo que se perderia al formatear C:'
        Write-Host '   3) Copiar WinMudanza y su configuracion a otra unidad'
        Write-Host ''
        Write-Host '   EQUIPO NUEVO'
        Write-Host '   4) Aplicar configuracion a este equipo'
        Write-Host '   5) Aplicar en modo simulacion (no cambia nada)'
        Write-Host '   6) Comparar configuracion con este equipo'
        Write-Host ''
        Write-Host '   7) Ver estado de config\      8) Ayuda      0) Salir'
        Write-Host ''
        $op = Read-Host '  Opcion'
        switch ($op) {
            '1' {
                $sel = Select-Modulos 'Extraer'
                if ($null -ne $sel) { $null = Invoke-Accion 'Extraer' $sel $false }
            }
            '2' { $null = Invoke-Accion 'Revisar' (Get-ModulosSeleccionados 'Revisar' $null $null) $false }
            '3' {
                $d = [string]$Perfil.CopiarA
                $r = Read-Host "  Destino [$d]"
                if ($r) { $d = $r }
                $null = Copy-WinMudanza $d
            }
            '4' {
                $sel = Select-Modulos 'Aplicar'
                if ($null -ne $sel) {
                    $r = Read-Host "  Se aplicaran: $($sel -join ', '). Continuar? (S/N)"
                    if ($r -match '^[sS]') { $null = Invoke-Accion 'Aplicar' $sel $false }
                }
            }
            '5' {
                $sel = Select-Modulos 'Aplicar'
                if ($null -ne $sel) { $null = Invoke-Accion 'Aplicar' $sel $true }
            }
            '6' {
                $sel = Select-Modulos 'Comparar'
                if ($null -ne $sel) { $null = Invoke-Accion 'Comparar' $sel $true }
            }
            '7' { Show-Estado }
            '8' { Show-Ayuda }
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

if ($Continuacion) {
    Unregister-ScheduledTask -TaskName $TareaContinuar -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host '  WinMudanza: continuando tras el reinicio...' -ForegroundColor Cyan
}

if (-not $Accion) {
    Show-Menu
    exit 0
}

switch ($Accion) {
    'Estado' { Show-Estado; exit 0 }
    'Ayuda'  { Show-Ayuda;  exit 0 }
    'Copiar' { exit (Copy-WinMudanza $Destino) }
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
if ($Accion -in 'Extraer', 'Revisar', 'Comparar' -and $simular) {
    Write-Host "$Accion no cambia el equipo: -WhatIf no es necesario y se ignora." -ForegroundColor DarkGray
    $simular = $false
}

if ($Accion -eq 'Aplicar' -and -not $simular -and -not $SinConfirmar -and -not $Continuacion) {
    Write-Host ''
    Write-Host "  Se aplicaran: $($seleccion -join ', ')" -ForegroundColor White
    $r = Read-Host '  Continuar? (S/N)'
    if ($r -notmatch '^[sS]') { Write-Host '  Cancelado.'; exit 0 }
}

$codigo = Invoke-Accion $Accion $seleccion $simular
exit $codigo
