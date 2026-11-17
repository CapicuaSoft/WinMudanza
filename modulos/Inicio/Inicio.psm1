# Rutas y utilidades del modulo Inicio (menu Inicio, barra de tareas, escritorio, carpeta Inicio).
# Las rutas de archivos son relativas a la carpeta del perfil; las de registro, a su HKCU.

function Get-RutasInicio {
    return @{
        MenuInicio    = 'AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState'
        BarraTareas   = 'AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
        AlIniciar     = 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
        Taskband      = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
        IconosSistema = 'Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
        Posiciones    = 'Software\Microsoft\Windows\Shell\Bags\1\Desktop'
    }
}

# Extensiones de acceso directo que se copian del escritorio (no documentos)
$script:ExtAccesos = @('.lnk', '.url', '.website', '.appref-ms')
function Test-EsAcceso([IO.FileInfo]$Archivo) { return ($script:ExtAccesos -contains $Archivo.Extension.ToLower()) }

# Carpeta del escritorio de un perfil (de su User Shell Folders) y si esta dentro del perfil
function Get-EscritorioPerfil($P) {
    $ruta = Join-Path $P.Ruta 'Desktop'
    $k = Get-Item -LiteralPath "$($P.HKCU)\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -ErrorAction SilentlyContinue
    if ($k) {
        try {
            $v = $k.GetValue('Desktop', $null, 'DoNotExpandEnvironmentNames')
            if ($v) { $ruta = ([string]$v) -replace '(?i)%USERPROFILE%', $P.Ruta }
        } finally { $k.Close() }
    }
    $ruta = [Environment]::ExpandEnvironmentVariables($ruta)
    $dentro = $ruta.StartsWith($P.Ruta.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
    return [pscustomobject]@{ Ruta = $ruta; EnPerfil = $dentro; EnOneDrive = ($ruta -match '\\OneDrive') }
}

# Valores de una clave de registro -> tabla { Nombre = @{ Tipo; Valor } } (binario en base64)
function Export-RegValores([string]$Clave) {
    $t = [ordered]@{}
    $k = Get-Item -LiteralPath $Clave -ErrorAction SilentlyContinue
    if (-not $k) { return $t }
    try {
        foreach ($n in $k.GetValueNames()) {
            if (-not $n) { continue }
            $tipo = [string]$k.GetValueKind($n)
            $v = $k.GetValue($n, $null, 'DoNotExpandEnvironmentNames')
            if ($tipo -eq 'Binary') { $v = [Convert]::ToBase64String([byte[]]$v) }
            $t[$n] = [ordered]@{ Tipo = $tipo; Valor = $v }
        }
    } finally { $k.Close() }
    return $t
}

# Escribe con Set-RegValor los valores exportados por Export-RegValores. $true si todo fue bien.
function Import-RegValores([string]$Clave, $Valores) {
    $ok = $true
    if (-not $Valores) { return $ok }
    foreach ($n in @($Valores.Keys)) {
        $e = $Valores[$n]
        $v = $e.Valor
        if ($e.Tipo -eq 'Binary') { $v = [Convert]::FromBase64String([string]$v) }
        if (-not (Set-RegValor -Ruta $Clave -Nombre $n -Valor $v -Tipo $e.Tipo)) { $ok = $false }
    }
    return $ok
}

Export-ModuleMember -Function Get-RutasInicio, Test-EsAcceso, Get-EscritorioPerfil, Export-RegValores, Import-RegValores
