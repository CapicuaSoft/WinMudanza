# Lectura y escritura de archivos VDF de Steam.
#
# - Binario (shortcuts.vdf): tipos 0x00 mapa, 0x01 cadena, 0x02 int32, 0x07 uint64, 0x08 fin.
#   Escritura: [int]/[uint32] -> int32, [long]/[uint64] -> uint64, string -> cadena, diccionario -> mapa.
# - Texto (localconfig.vdf): "clave" "valor" y "clave" { ... }.
#   Read-VdfTexto marca $resultado.Duplicados si encuentra claves repetidas en un mismo bloque;
#   en ese caso NO se debe reescribir el archivo (se perderian datos).

# ==================================================
# BINARIO
# ==================================================

function Read-VdfBinCadena([byte[]]$B, [ref]$Pos) {
    $ini = $Pos.Value
    $fin = [Array]::IndexOf($B, [byte]0, $ini)
    if ($fin -lt 0) { throw "VDF binario: cadena sin terminar en posicion $ini" }
    $Pos.Value = $fin + 1
    return [Text.Encoding]::UTF8.GetString($B, $ini, $fin - $ini)
}

function Read-VdfBinMapa([byte[]]$B, [ref]$Pos) {
    $m = [ordered]@{}
    while ($Pos.Value -lt $B.Length) {
        $tipo = $B[$Pos.Value]
        $Pos.Value++
        if ($tipo -eq 8) { break }
        $clave = Read-VdfBinCadena $B $Pos
        switch ($tipo) {
            0 { $m[$clave] = Read-VdfBinMapa $B $Pos }
            1 { $m[$clave] = Read-VdfBinCadena $B $Pos }
            2 { $m[$clave] = [BitConverter]::ToInt32($B, $Pos.Value); $Pos.Value += 4 }
            7 { $m[$clave] = [BitConverter]::ToUInt64($B, $Pos.Value); $Pos.Value += 8 }
            default { throw "VDF binario: tipo $tipo no soportado en posicion $($Pos.Value)" }
        }
    }
    return $m
}

function Read-VdfBinario([Parameter(Mandatory)][string]$Ruta) {
    $bytes = [IO.File]::ReadAllBytes($Ruta)
    $pos = 0
    return (Read-VdfBinMapa $bytes ([ref]$pos))
}

function Write-VdfBinCadena([IO.MemoryStream]$Ms, [string]$Texto) {
    $b = [Text.Encoding]::UTF8.GetBytes($Texto)
    $Ms.Write($b, 0, $b.Length)
    $Ms.WriteByte(0)
}

function Write-VdfBinMapa([IO.MemoryStream]$Ms, $Mapa) {
    foreach ($k in @($Mapa.Keys)) {
        $v = $Mapa[$k]
        if ($v -is [System.Collections.IDictionary]) {
            $Ms.WriteByte(0); Write-VdfBinCadena $Ms $k
            Write-VdfBinMapa $Ms $v
            $Ms.WriteByte(8)
        } elseif ($v -is [string]) {
            $Ms.WriteByte(1); Write-VdfBinCadena $Ms $k; Write-VdfBinCadena $Ms $v
        } elseif ($v -is [int]) {
            $Ms.WriteByte(2); Write-VdfBinCadena $Ms $k
            $Ms.Write([BitConverter]::GetBytes([int]$v), 0, 4)
        } elseif ($v -is [uint32]) {
            $Ms.WriteByte(2); Write-VdfBinCadena $Ms $k
            $Ms.Write([BitConverter]::GetBytes([uint32]$v), 0, 4)
        } elseif ($v -is [long] -or $v -is [uint64]) {
            $Ms.WriteByte(7); Write-VdfBinCadena $Ms $k
            $Ms.Write([BitConverter]::GetBytes([uint64]$v), 0, 8)
        } elseif ($null -eq $v) {
            $Ms.WriteByte(1); Write-VdfBinCadena $Ms $k; Write-VdfBinCadena $Ms ''
        } else {
            throw "VDF binario: tipo no soportado para '$k' ($($v.GetType().Name))"
        }
    }
}

function ConvertTo-VdfBinarioBytes([Parameter(Mandatory)]$Datos) {
    $ms = New-Object IO.MemoryStream
    Write-VdfBinMapa $ms $Datos
    $ms.WriteByte(8)
    return ,$ms.ToArray()
}

function Write-VdfBinario([Parameter(Mandatory)]$Datos, [Parameter(Mandatory)][string]$Ruta) {
    [IO.File]::WriteAllBytes($Ruta, (ConvertTo-VdfBinarioBytes $Datos))
}

# ==================================================
# TEXTO
# ==================================================

function ConvertFrom-VdfEscape([string]$T) {
    if ($T.IndexOf('\') -lt 0) { return $T }
    return [regex]::Replace($T, '\\(.)', {
        param($m)
        switch ($m.Groups[1].Value) { 'n' { "`n" } 't' { "`t" } default { $m.Groups[1].Value } }
    })
}

function ConvertTo-VdfEscape([string]$T) {
    return $T.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`t", '\t')
}

# Devuelve @{ Datos = [ordered]; Duplicados = $bool }
function Read-VdfTexto([Parameter(Mandatory)][string]$Ruta) {
    $texto = [IO.File]::ReadAllText($Ruta)
    $tokens = [regex]::Matches($texto, '"((?:[^"\\]|\\.)*)"|(\{)|(\})|(//[^\n]*)')
    $raiz = [ordered]@{}
    $pila = New-Object System.Collections.Stack
    $actual = $raiz
    $clave = $null
    $duplicados = $false
    foreach ($t in $tokens) {
        if ($t.Groups[4].Success) { continue }   # comentario
        if ($t.Groups[2].Success) {
            if ($null -eq $clave) { throw "VDF texto: '{' sin clave en posicion $($t.Index)" }
            $nuevo = [ordered]@{}
            if ($actual.Contains($clave)) { $duplicados = $true }
            $actual[$clave] = $nuevo
            $pila.Push($actual)
            $actual = $nuevo
            $clave = $null
        } elseif ($t.Groups[3].Success) {
            if ($pila.Count -eq 0) { throw "VDF texto: '}' sin abrir en posicion $($t.Index)" }
            $actual = $pila.Pop()
            $clave = $null
        } else {
            $valor = ConvertFrom-VdfEscape $t.Groups[1].Value
            if ($null -eq $clave) {
                $clave = $valor
            } else {
                if ($actual.Contains($clave)) { $duplicados = $true }
                $actual[$clave] = $valor
                $clave = $null
            }
        }
    }
    return [pscustomobject]@{ Datos = $raiz; Duplicados = $duplicados }
}

function ConvertTo-VdfTexto($Mapa, [int]$Nivel = 0) {
    $sb = New-Object System.Text.StringBuilder
    $ind = "`t" * $Nivel
    foreach ($k in @($Mapa.Keys)) {
        $v = $Mapa[$k]
        if ($v -is [System.Collections.IDictionary]) {
            [void]$sb.Append($ind).Append('"').Append((ConvertTo-VdfEscape $k)).Append("`"`n")
            [void]$sb.Append($ind).Append("{`n")
            [void]$sb.Append((ConvertTo-VdfTexto $v ($Nivel + 1)))
            [void]$sb.Append($ind).Append("}`n")
        } else {
            [void]$sb.Append($ind).Append('"').Append((ConvertTo-VdfEscape $k)).Append("`"`t`t`"").Append((ConvertTo-VdfEscape ([string]$v))).Append("`"`n")
        }
    }
    return $sb.ToString()
}

function Write-VdfTexto([Parameter(Mandatory)]$Datos, [Parameter(Mandatory)][string]$Ruta) {
    [IO.File]::WriteAllText($Ruta, (ConvertTo-VdfTexto $Datos), (New-Object System.Text.UTF8Encoding $false))
}

# Busca una clave hija sin distinguir mayusculas; devuelve la clave real o $null.
function Find-VdfClave($Mapa, [string]$Clave) {
    foreach ($k in @($Mapa.Keys)) { if ([string]::Equals($k, $Clave, [StringComparison]::OrdinalIgnoreCase)) { return $k } }
    return $null
}

Export-ModuleMember -Function Read-VdfBinario, Write-VdfBinario, ConvertTo-VdfBinarioBytes, Read-VdfTexto, Write-VdfTexto, ConvertTo-VdfTexto, Find-VdfClave
