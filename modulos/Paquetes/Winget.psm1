# Utilidades de winget para el modulo Paquetes.

# Busca paquetes de la fuente winget por nombre. Devuelve objetos { Nombre; Id } o nada.
# winget search no tiene salida estructurada: se lee su tabla usando las posiciones del encabezado
# (Nombre/Name, Id, Version...). Los Id recortados con '…' se descartan.
function Find-WingetPaquete([string]$Nombre) {
    if (-not $Nombre) { return }
    $codAnterior = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        $salida = @(& winget search --name $Nombre --source winget --accept-source-agreements --disable-interactivity 2>$null |
            ForEach-Object { [string]$_ })
    } catch { return } finally { [Console]::OutputEncoding = $codAnterior }
    if ($LASTEXITCODE -ne 0) { return }
    $iSep = -1
    for ($i = 1; $i -lt $salida.Count; $i++) { if ($salida[$i] -match '^-{10,}\s*$') { $iSep = $i; break } }
    if ($iSep -lt 1) { return }
    $cab = $salida[$iSep - 1]
    $cols = @([regex]::Matches($cab, '\S+') | ForEach-Object { $_.Index })
    if ($cols.Count -lt 3) { return }
    $iniId = $cols[1]; $iniVer = $cols[2]
    for ($i = $iSep + 1; $i -lt $salida.Count; $i++) {
        $l = $salida[$i]
        if ($l.Length -le $iniId) { continue }
        $nom = $l.Substring(0, $iniId).Trim()
        $id = $l.Substring($iniId, [Math]::Min($iniVer, $l.Length) - $iniId).Trim()
        if (-not $id -or $id -match '…' -or $id -match '\s') { continue }
        [pscustomobject]@{ Nombre = $nom; Id = $id }
    }
}

Export-ModuleMember -Function Find-WingetPaquete
