<#
.SYNOPSIS
    Abre Windows Sandbox con la carpeta de OptimizarHP2 en el escritorio, para probar Aplicar
    en un Windows limpio y desechable.

.DESCRIPTION
    Genera un archivo .wsb (configuracion de Sandbox) en %TEMP% y lo abre.
    Dentro de Sandbox la carpeta aparece en el escritorio: C:\Users\WDAGUtilityAccount\Desktop\OptimizarHP2
    El usuario de Sandbox es Administrador.

    Todo lo que se haga dentro de Sandbox se pierde al cerrarlo, EXCEPTO lo que se escriba en la
    carpeta compartida (por ejemplo logs\). Usa -SoloLectura para que Sandbox no pueda escribir en ella.

    Limitaciones de Sandbox: no trae winget ni Microsoft Store, no hay disco D: y no existen tus
    usuarios. Recomendado: .\OptimizarHP2.ps1 -Accion Aplicar -Omitir Paquetes,Steam

.PARAMETER SoloLectura
    Monta la carpeta del proyecto en solo lectura (los logs no se guardaran).

.EXAMPLE
    .\pruebas\Abrir-Sandbox.ps1
#>
param([switch]$SoloLectura)

$raiz = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$exe = Join-Path $env:windir 'System32\WindowsSandbox.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    Write-Host 'Windows Sandbox no esta activado.' -ForegroundColor Yellow
    Write-Host 'Activalo desde PowerShell como Administrador y reinicia:' -ForegroundColor Yellow
    Write-Host '  Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All' -ForegroundColor White
    Write-Host 'o en "Activar o desactivar las caracteristicas de Windows" > "Espacio aislado de Windows".' -ForegroundColor Yellow
    exit 1
}

$destino = 'C:\Users\WDAGUtilityAccount\Desktop\OptimizarHP2'
$ro = 'false'
if ($SoloLectura) { $ro = 'true' }
$wsb = @"
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$raiz</HostFolder>
      <SandboxFolder>$destino</SandboxFolder>
      <ReadOnly>$ro</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>explorer.exe $destino</Command>
  </LogonCommand>
</Configuration>
"@
$ruta = Join-Path $env:TEMP 'OptimizarHP2.wsb'
[IO.File]::WriteAllText($ruta, $wsb, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Abriendo Sandbox ($ruta)..." -ForegroundColor Cyan
Write-Host 'Dentro: abre PowerShell como Administrador y ejecuta:' -ForegroundColor Cyan
Write-Host "  Set-ExecutionPolicy -Scope Process Bypass -Force; cd $destino" -ForegroundColor White
Write-Host '  .\OptimizarHP2.ps1 -Accion Aplicar -Omitir Paquetes,Steam' -ForegroundColor White
Start-Process -FilePath $ruta
