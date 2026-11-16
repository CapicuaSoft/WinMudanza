# Comprueba la sintaxis de todos los .ps1/.psm1 y que los .psd1 se pueden leer.
# Tambien verifica que todos los archivos de codigo estan en UTF-8 con BOM.
# Uso: .\pruebas\Probar-Sintaxis.ps1   (no necesita Administrador, no cambia nada)

$raiz = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$errores = 0

$archivos = Get-ChildItem -LiteralPath $raiz -Recurse -File |
    Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' -and $_.FullName -notmatch '\\(config|logs)\\' }

foreach ($f in $archivos) {
    $rel = $f.FullName.Substring($raiz.Length + 1)
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    if (-not $bom) { Write-Host "  BOM  $rel (falta UTF-8 con BOM)" -ForegroundColor Red; $errores++ }

    $tokens = $null; $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs)
    if ($errs.Count -gt 0) {
        foreach ($e in $errs) { Write-Host ("  ERR  {0}:{1} {2}" -f $rel, $e.Extent.StartLineNumber, $e.Message) -ForegroundColor Red }
        $errores++
        continue
    }
    if ($f.Extension -eq '.psd1') {
        try { $null = Import-PowerShellDataFile -LiteralPath $f.FullName -ErrorAction Stop }
        catch { Write-Host "  ERR  ${rel}: $($_.Exception.Message)" -ForegroundColor Red; $errores++; continue }
    }
    Write-Host "  OK   $rel" -ForegroundColor Green
}

Write-Host ''
if ($errores -eq 0) { Write-Host "Todo correcto ($($archivos.Count) archivos)." -ForegroundColor Green; exit 0 }
Write-Host "$errores archivo(s) con problemas." -ForegroundColor Red
exit 1
