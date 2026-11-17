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

# ---- Anclados del Explorador (Acceso rapido y Favoritos) ----
# Windows los guarda en listas de saltos (archivos compuestos OLE) de AutomaticDestinations:
#   f01b4d95cf55d32a -> carpetas ancladas a Acceso rapido
#   5f7b5f1e01b83767 -> archivos en Favoritos (Windows 11)
# Su flujo DestList tiene cada elemento con su ruta y su posicion de anclado (-1 si no lo esta).
# Se leen del archivo (no con el Shell) para poder extraer tambien los de otros usuarios.

# Lee un flujo de un archivo compuesto OLE (CFB). Devuelve byte[] o $null.
function Read-FlujoCfb([string]$Archivo, [string]$Flujo) {
    $fs = [IO.File]::Open($Archivo, 'Open', 'Read', 'ReadWrite')
    try { $b = New-Object 'byte[]' $fs.Length; [void]$fs.Read($b, 0, $b.Length) } finally { $fs.Close() }
    if ($b.Length -lt 512 -or [BitConverter]::ToInt32($b, 0) -ne 0xE011CFD0) { return $null }
    $ss = 1 -shl [BitConverter]::ToUInt16($b, 30)
    $mss = 1 -shl [BitConverter]::ToUInt16($b, 32)
    $nFat = [BitConverter]::ToInt32($b, 44)
    $dir1 = [BitConverter]::ToInt32($b, 48)
    $corte = [BitConverter]::ToUInt32($b, 56)
    $mini1 = [BitConverter]::ToInt32($b, 60)
    $difat1 = [BitConverter]::ToInt32($b, 68)
    $nSec = [int][Math]::Floor($b.Length / $ss) - 1

    # Sectores de la FAT (DIFAT de la cabecera y su cadena)
    $fatSec = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt 109; $i++) { $v = [BitConverter]::ToInt32($b, 76 + 4 * $i); if ($v -ge 0) { $fatSec.Add($v) } }
    $d = $difat1; $vueltas = 0
    while ($d -ge 0 -and $d -lt $nSec -and $fatSec.Count -lt $nFat -and $vueltas++ -lt $nSec) {
        $o = ($d + 1) * $ss
        for ($i = 0; $i -lt $ss / 4 - 1; $i++) { $v = [BitConverter]::ToInt32($b, $o + 4 * $i); if ($v -ge 0) { $fatSec.Add($v) } }
        $d = [BitConverter]::ToInt32($b, $o + $ss - 4)
    }
    $fat = New-Object 'int[]' ($fatSec.Count * $ss / 4)
    $k = 0
    foreach ($s in $fatSec) {
        $o = ($s + 1) * $ss
        if ($o + $ss -gt $b.Length) { return $null }
        for ($i = 0; $i -lt $ss / 4; $i++) { $fat[$k++] = [BitConverter]::ToInt32($b, $o + 4 * $i) }
    }

    # Directorio: entrada raiz (contenedor del mini flujo) y la del flujo buscado
    $dir = Read-CadenaCfb $dir1 $fat $b $ss $ss -1
    $raiz = $null; $ent = $null
    for ($o = 0; $o + 128 -le $dir.Length; $o += 128) {
        $nl = [BitConverter]::ToUInt16($dir, $o + 64)
        if ($nl -lt 2 -or $nl -gt 64) { continue }
        $nombre = [Text.Encoding]::Unicode.GetString($dir, $o, $nl - 2)
        $e = @{ Tipo = $dir[$o + 66]; Inicio = [BitConverter]::ToInt32($dir, $o + 116); Tam = [long][BitConverter]::ToUInt32($dir, $o + 120) }
        if ($e.Tipo -eq 5) { $raiz = $e }
        elseif ($e.Tipo -eq 2 -and $nombre -eq $Flujo) { $ent = $e }
    }
    if (-not $ent) { return $null }
    if ($ent.Tam -ge $corte) { return (Read-CadenaCfb $ent.Inicio $fat $b $ss $ss $ent.Tam) }
    if (-not $raiz) { return $null }
    $miniFat = Read-CadenaCfb $mini1 $fat $b $ss $ss -1
    $mini = New-Object 'int[]' ([Math]::Floor($miniFat.Length / 4))
    for ($i = 0; $i -lt $mini.Length; $i++) { $mini[$i] = [BitConverter]::ToInt32($miniFat, 4 * $i) }
    $contenedor = Read-CadenaCfb $raiz.Inicio $fat $b $ss $ss $raiz.Tam
    return (Read-CadenaCfb $ent.Inicio $mini $contenedor $mss 0 $ent.Tam)
}

# Lee una cadena de sectores. Normales: Desp = tamano de sector (se salta la cabecera); mini: Desp = 0.
function Read-CadenaCfb([int]$Inicio, [int[]]$Tabla, [byte[]]$Origen, [int]$Tam, [int]$Desp, [long]$Limite) {
    $ms = New-Object IO.MemoryStream
    $s = $Inicio; $n = 0
    while ($s -ge 0 -and $s -lt $Tabla.Length -and $n++ -le $Tabla.Length) {
        $o = $s * $Tam + $Desp
        if ($o + $Tam -gt $Origen.Length) { break }
        $ms.Write($Origen, $o, $Tam)
        if ($Limite -ge 0 -and $ms.Length -ge $Limite) { break }
        $s = $Tabla[$s]
    }
    $r = $ms.ToArray()
    if ($Limite -ge 0 -and $r.Length -gt $Limite) { $c = New-Object 'byte[]' $Limite; [Array]::Copy($r, $c, $Limite); $r = $c }
    return , $r
}

# Rutas ancladas de una lista de saltos, en su orden
function Get-AncladosDestList([string]$Archivo) {
    if (-not (Test-Path -LiteralPath $Archivo)) { return @() }
    try { $d = Read-FlujoCfb $Archivo 'DestList' } catch { return @() }
    if (-not $d -or $d.Length -lt 32) { return @() }
    $ver = [BitConverter]::ToInt32($d, 0)
    $n = [BitConverter]::ToInt32($d, 4)
    # Windows 7/8: cabecera de 114 bytes y posicion en +104; Windows 10/11 (version 3+): 130 bytes, +108
    $cab = 114; $posPin = 104
    if ($ver -ge 3) { $cab = 130; $posPin = 108 }
    $res = New-Object System.Collections.ArrayList
    $o = 32
    for ($i = 0; $i -lt $n -and $o + $cab -le $d.Length; $i++) {
        $pin = [BitConverter]::ToInt32($d, $o + $posPin)
        $len = [BitConverter]::ToUInt16($d, $o + $cab - 2)
        if ($o + $cab + 2 * $len -gt $d.Length) { break }
        $ruta = [Text.Encoding]::Unicode.GetString($d, $o + $cab, 2 * $len)
        if ($pin -ge 0) { [void]$res.Add([pscustomobject]@{ Ruta = $ruta; Pin = $pin }) }
        $o += $cab + 2 * $len
        if ($ver -ge 3) { $o += 4 }
    }
    return @($res | Sort-Object Pin | ForEach-Object { $_.Ruta })
}

# Ruta de la lista de saltos -> ruta portable: carpetas conocidas como shell:Nombre (shell:Downloads),
# objetos del Shell como shell:::{GUID} y lo del perfil con %USERPROFILE%.
function ConvertTo-RutaAnclado([string]$Ruta, [string]$Perfil) {
    if ($Ruta -match '^knownfolder:(\{[0-9A-Fa-f-]+\})$') {
        $fd = Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$($Matches[1])" -ErrorAction SilentlyContinue
        if ($fd -and $fd.Name) { return "shell:$($fd.Name)" }
        return "shell:::$($Matches[1])"
    }
    if ($Ruta -match '^::\{') { return "shell:$Ruta" }
    $base = $Perfil.TrimEnd('\')
    if ($Ruta.Equals($base, [StringComparison]::OrdinalIgnoreCase)) { return '%USERPROFILE%' }
    if ($Ruta.StartsWith("$base\", [StringComparison]::OrdinalIgnoreCase)) { return '%USERPROFILE%' + $Ruta.Substring($base.Length) }
    return $Ruta
}

# Anclados del Explorador de un perfil: @{ AccesoRapido = @(carpetas); Favoritos = @(archivos) }
function Get-AncladosExplorador($P) {
    $dir = Join-Path $P.Ruta 'AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations'
    return [ordered]@{
        AccesoRapido = @(Get-AncladosDestList (Join-Path $dir 'f01b4d95cf55d32a.automaticDestinations-ms') | ForEach-Object { ConvertTo-RutaAnclado $_ $P.Ruta })
        Favoritos    = @(Get-AncladosDestList (Join-Path $dir '5f7b5f1e01b83767.automaticDestinations-ms') | ForEach-Object { ConvertTo-RutaAnclado $_ $P.Ruta })
    }
}

# $true si un anclado existe para el perfil (shell:... se da por bueno: se resuelve en su sesion)
function Test-AncladoExiste([string]$Ruta, $P) {
    if ($Ruta -like 'shell:*') { return $true }
    $r = $Ruta -replace '(?i)%USERPROFILE%', $P.Ruta.TrimEnd('\')
    return (Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($r)))
}

Export-ModuleMember -Function Get-RutasInicio, Test-EsAcceso, Get-EscritorioPerfil, Export-RegValores, Import-RegValores,
    Get-AncladosExplorador, Test-AncladoExiste
