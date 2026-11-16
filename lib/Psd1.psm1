# Serializador de datos a formato .psd1 (PowerShell Data File).
# La lectura se hace con Import-PowerShellDataFile (incluido en PowerShell 5.1).
#
# Admite: $null, bool, numeros, cadenas, hashtables/[ordered], arrays y PSCustomObject.
# Cada elemento de un array va en su propia linea para poder comentarlo con '#'.

function Format-Psd1Clave([string]$Clave) {
    if ($Clave -match '^[A-Za-z_][A-Za-z0-9_]*$') { return $Clave }
    return "'" + ($Clave -replace "'", "''") + "'"
}

function ConvertTo-Psd1Texto {
    param($Valor, [int]$Nivel = 0)

    $ind  = '    ' * $Nivel
    $ind1 = '    ' * ($Nivel + 1)

    if ($null -eq $Valor) { return '$null' }
    if ($Valor -is [bool]) { if ($Valor) { return '$true' } else { return '$false' } }
    if ($Valor -is [int] -or $Valor -is [long] -or $Valor -is [int16] -or $Valor -is [byte] -or
        $Valor -is [uint16] -or $Valor -is [uint32] -or $Valor -is [uint64] -or
        $Valor -is [double] -or $Valor -is [decimal] -or $Valor -is [single]) {
        return [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $Valor)
    }
    if ($Valor -is [string] -or $Valor -is [char] -or $Valor -is [datetime] -or $Valor -is [enum] -or $Valor -is [guid]) {
        return "'" + ([string]$Valor -replace "'", "''") + "'"
    }
    if ($Valor -is [System.Management.Automation.PSCustomObject]) {
        $d = [ordered]@{}
        foreach ($p in $Valor.PSObject.Properties) { $d[$p.Name] = $p.Value }
        $Valor = $d
    }
    if ($Valor -is [System.Collections.IDictionary]) {
        if ($Valor.Count -eq 0) { return '@{}' }
        $lineas = New-Object System.Collections.Generic.List[string]
        $lineas.Add('@{')
        foreach ($k in $Valor.Keys) {
            $lineas.Add($ind1 + (Format-Psd1Clave ([string]$k)) + ' = ' + (ConvertTo-Psd1Texto -Valor $Valor[$k] -Nivel ($Nivel + 1)))
        }
        $lineas.Add($ind + '}')
        return ($lineas -join "`r`n")
    }
    if ($Valor -is [System.Collections.IEnumerable]) {
        $items = @($Valor)
        if ($items.Count -eq 0) { return '@()' }
        $lineas = New-Object System.Collections.Generic.List[string]
        $lineas.Add('@(')
        foreach ($i in $items) { $lineas.Add($ind1 + (ConvertTo-Psd1Texto -Valor $i -Nivel ($Nivel + 1))) }
        $lineas.Add($ind + ')')
        return ($lineas -join "`r`n")
    }
    return "'" + ([string]$Valor -replace "'", "''") + "'"
}

# Escribe un .psd1 (UTF-8 con BOM). $Cabecera son lineas de comentario al inicio.
function Write-Psd1 {
    param(
        [Parameter(Mandatory)][string]$Ruta,
        [Parameter(Mandatory)]$Datos,
        [string[]]$Cabecera
    )
    $sb = New-Object System.Text.StringBuilder
    foreach ($l in $Cabecera) { [void]$sb.AppendLine(('# ' + $l).TrimEnd()) }
    if ($Cabecera) { [void]$sb.AppendLine('') }
    [void]$sb.AppendLine((ConvertTo-Psd1Texto -Valor $Datos))
    $dir = Split-Path -Parent $Ruta
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($Ruta, $sb.ToString(), (New-Object System.Text.UTF8Encoding $true))
}

Export-ModuleMember -Function ConvertTo-Psd1Texto, Write-Psd1
