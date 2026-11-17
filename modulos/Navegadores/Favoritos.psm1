# Favoritos de navegadores basados en Chromium (Edge, Chrome, Brave, Vivaldi, Opera).
# El archivo "Bookmarks" es JSON: roots.bookmark_bar / other / synced, con nodos
# { type = 'url' | 'folder'; name; url; children; date_added (microsegundos desde 1601) }.

# Navegadores conocidos. Rutas relativas a la carpeta del perfil de Windows.
#   Datos     -> carpeta de datos del navegador
#   Raiz      -> $true si los favoritos estan en Datos directamente (Opera), no en Default\, Profile 1\...
#   Exe       -> rutas posibles del programa (para saber si esta instalado)
#   Proceso   -> nombre del proceso (debe estar cerrado para escribir)
function Get-NavegadoresChromium {
    return [ordered]@{
        Edge    = @{ Datos = 'AppData\Local\Microsoft\Edge\User Data'; Raiz = $false; Proceso = 'msedge'
                     Exe = @('%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe', '%ProgramFiles%\Microsoft\Edge\Application\msedge.exe') }
        Chrome  = @{ Datos = 'AppData\Local\Google\Chrome\User Data'; Raiz = $false; Proceso = 'chrome'
                     Exe = @('%ProgramFiles%\Google\Chrome\Application\chrome.exe', '%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe', '<perfil>\AppData\Local\Google\Chrome\Application\chrome.exe') }
        Brave   = @{ Datos = 'AppData\Local\BraveSoftware\Brave-Browser\User Data'; Raiz = $false; Proceso = 'brave'
                     Exe = @('%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe', '<perfil>\AppData\Local\BraveSoftware\Brave-Browser\Application\brave.exe') }
        Vivaldi = @{ Datos = 'AppData\Local\Vivaldi\User Data'; Raiz = $false; Proceso = 'vivaldi'
                     Exe = @('%ProgramFiles%\Vivaldi\Application\vivaldi.exe', '<perfil>\AppData\Local\Vivaldi\Application\vivaldi.exe') }
        Opera   = @{ Datos = 'AppData\Roaming\Opera Software\Opera Stable'; Raiz = $true; Proceso = 'opera'
                     Exe = @('%ProgramFiles%\Opera\opera.exe', '<perfil>\AppData\Local\Programs\Opera\opera.exe') }
    }
}

# $true si el navegador esta instalado (para todos o en el perfil indicado)
function Test-NavegadorInstalado($Navegador, [string]$RutaPerfil) {
    foreach ($r in $Navegador.Exe) {
        $x = [Environment]::ExpandEnvironmentVariables($r.Replace('<perfil>', $RutaPerfil))
        if (Test-Path -LiteralPath $x) { return $true }
    }
    # Ruta que registra el instalador (App Paths), por si esta en otra carpeta
    foreach ($h in 'HKLM:', 'HKCU:') {
        $r = [string](Get-ItemProperty -LiteralPath "$h\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$($Navegador.Proceso).exe" -ErrorAction SilentlyContinue).'(default)'
        if ($r -and (Test-Path -LiteralPath $r.Trim('"'))) { return $true }
    }
    return $false
}

function Read-Favoritos([string]$Archivo) {
    try { return (Get-Content -LiteralPath $Archivo -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

# Numero de favoritos (enlaces) de un Bookmarks ya leido
function Get-NumFavoritos($Json) {
    $n = 0
    $pila = New-Object System.Collections.Stack
    foreach ($r in 'bookmark_bar', 'other', 'synced') { if ($Json.roots.$r) { $pila.Push($Json.roots.$r) } }
    while ($pila.Count -gt 0) {
        $nodo = $pila.Pop()
        if ($nodo.type -eq 'url') { $n++ }
        foreach ($h in @($nodo.children)) { if ($h) { $pila.Push($h) } }
    }
    return $n
}

# Convierte un Bookmarks ya leido al formato HTML que importan todos los navegadores
function ConvertTo-FavoritosHtml($Json) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!DOCTYPE NETSCAPE-Bookmark-file-1>')
    [void]$sb.AppendLine('<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">')
    [void]$sb.AppendLine('<TITLE>Bookmarks</TITLE>')
    [void]$sb.AppendLine('<H1>Bookmarks</H1>')
    [void]$sb.AppendLine('<DL><p>')
    function Add-Nodo($Nodo, [int]$Nivel) {
        $ind = '    ' * $Nivel
        $fecha = ''
        if ($Nodo.date_added) {
            try { $fecha = ' ADD_DATE="{0}"' -f [int64]([int64]$Nodo.date_added / 1000000 - 11644473600) } catch { }
        }
        $nombre = [Net.WebUtility]::HtmlEncode([string]$Nodo.name)
        if ($Nodo.type -eq 'url') {
            [void]$sb.AppendLine(('{0}<DT><A HREF="{1}"{2}>{3}</A>' -f $ind, [Net.WebUtility]::HtmlEncode([string]$Nodo.url), $fecha, $nombre))
        } else {
            [void]$sb.AppendLine(('{0}<DT><H3{1}>{2}</H3>' -f $ind, $fecha, $nombre))
            [void]$sb.AppendLine("$ind<DL><p>")
            foreach ($h in @($Nodo.children)) { if ($h) { Add-Nodo $h ($Nivel + 1) } }
            [void]$sb.AppendLine("$ind</DL><p>")
        }
    }
    foreach ($r in 'bookmark_bar', 'other', 'synced') {
        $raiz = $Json.roots.$r
        if ($raiz -and @($raiz.children).Count -gt 0) { Add-Nodo $raiz 1 }
    }
    [void]$sb.AppendLine('</DL><p>')
    return $sb.ToString()
}

Export-ModuleMember -Function Get-NavegadoresChromium, Test-NavegadorInstalado, Read-Favoritos, Get-NumFavoritos, ConvertTo-FavoritosHtml
