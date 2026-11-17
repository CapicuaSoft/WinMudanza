<#
.SYNOPSIS
    Abre Windows Sandbox con la carpeta de WinMudanza en el escritorio, para probar Aplicar
    en un Windows limpio y desechable.

.DESCRIPTION
    Genera un archivo .wsb (configuracion de Sandbox) en %TEMP% y lo abre.
    Dentro de Sandbox la carpeta aparece en el escritorio: C:\Users\WDAGUtilityAccount\Desktop\WinMudanza
    El usuario de Sandbox es Administrador.

    Con -Probar, Sandbox ejecuta Aplicar solo al arrancar (con config\sandbox) y deja el log en
    logs\ de este equipo. Si config\sandbox no existe se crea a partir de config\ (o con -Preparar):
      - contrasenas 'CAMBIAR' -> 'Prueba-Sandbox-1'
      - rutas de D:\ -> C:\D_Simulado\ (Sandbox no tiene disco D:)

    Todo lo que se haga dentro de Sandbox se pierde al cerrarlo, EXCEPTO lo que se escriba en la
    carpeta compartida (logs\). Usa -SoloLectura para que Sandbox no pueda escribir en ella.

    Limitaciones de Sandbox: no trae winget ni Microsoft Store, no hay disco D:, no existen tus
    usuarios y no se puede activar Hyper-V ni Sandbox dentro. Paquetes y parte de Caracteristicas fallaran.

.PARAMETER Probar
    Ejecuta Aplicar automaticamente al arrancar Sandbox.

.PARAMETER Preparar
    Regenera config\sandbox a partir de config\ aunque ya exista.

.PARAMETER Argumentos
    Parametros extra para WinMudanza.ps1 en la prueba automatica. Ej: -Argumentos '-Solo Ajustes,Office'

.PARAMETER SoloLectura
    Monta la carpeta del proyecto en solo lectura (los logs no se guardaran).

.EXAMPLE
    .\pruebas\Abrir-Sandbox.ps1
    Abre Sandbox con el proyecto; la prueba se lanza a mano.

.EXAMPLE
    .\pruebas\Abrir-Sandbox.ps1 -Probar -Argumentos '-Omitir Paquetes'
    Abre Sandbox y aplica todo excepto Paquetes con config\sandbox.
#>
param(
    [switch]$Probar,
    [switch]$Preparar,
    [string]$Argumentos = '',
    [switch]$SoloLectura
)

$raiz = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$nombre = Split-Path $raiz -Leaf
$exe = Join-Path $env:windir 'System32\WindowsSandbox.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    Write-Host 'Windows Sandbox no esta activado.' -ForegroundColor Yellow
    Write-Host 'Activalo desde PowerShell como Administrador y reinicia:' -ForegroundColor Yellow
    Write-Host '  Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All' -ForegroundColor White
    Write-Host 'o en "Activar o desactivar las caracteristicas de Windows" > "Espacio aislado de Windows".' -ForegroundColor Yellow
    exit 1
}
if (Get-Process -Name WindowsSandbox, WindowsSandboxRemoteSession -ErrorAction SilentlyContinue) {
    Write-Host 'Ya hay un Windows Sandbox abierto: cierralo antes (solo puede haber uno).' -ForegroundColor Yellow
    exit 1
}

# ---- config\sandbox: copia de config\ adaptada a Sandbox ----
$cfg = Join-Path $raiz 'config'
$cfgSandbox = Join-Path $cfg 'sandbox'
if ($Probar -and ($Preparar -or -not (Test-Path -LiteralPath $cfgSandbox))) { $Preparar = $true }
if ($Preparar) {
    if (-not (Test-Path -LiteralPath (Join-Path $cfg 'usuarios.psd1'))) {
        Write-Host 'No hay configuracion extraida en config\: ejecuta antes .\WinMudanza.ps1 -Accion Extraer' -ForegroundColor Red
        exit 1
    }
    if (Test-Path -LiteralPath $cfgSandbox) { Remove-Item -LiteralPath $cfgSandbox -Recurse -Force }
    New-Item -ItemType Directory -Path $cfgSandbox | Out-Null
    Get-ChildItem -LiteralPath $cfg | Where-Object { $_.Name -notin 'sandbox', 'perfil.psd1', 'ajustes.psd1' } |
        Copy-Item -Destination $cfgSandbox -Recurse
    $utf8 = New-Object System.Text.UTF8Encoding $true
    foreach ($f in Get-ChildItem -LiteralPath $cfgSandbox -Filter '*.psd1') {
        $t = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
        $n = $t.Replace("Password = 'CAMBIAR'", "Password = 'Prueba-Sandbox-1'") -replace "'D:\\", "'C:\D_Simulado\"
        if ($n -ne $t) { [IO.File]::WriteAllText($f.FullName, $n, $utf8) }
    }
    Write-Host "config\sandbox preparado (contrasenas de prueba 'Prueba-Sandbox-1', D:\ -> C:\D_Simulado\)." -ForegroundColor Green
}

$destino = "C:\Users\WDAGUtilityAccount\Desktop\$nombre"
$ro = 'false'
if ($SoloLectura) { $ro = 'true' }
$comando = "explorer.exe $destino"
if ($Probar) {
    $ps = "-NoExit -ExecutionPolicy Bypass -File $destino\WinMudanza.ps1 -Accion Aplicar -DirConfig $destino\config\sandbox -SinConfirmar -SinReiniciar $Argumentos"
    $comando = "cmd.exe /c start `"WinMudanza - prueba`" powershell.exe $ps"
}
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
    <Command>$comando</Command>
  </LogonCommand>
</Configuration>
"@
$ruta = Join-Path $env:TEMP "$nombre.wsb"
[IO.File]::WriteAllText($ruta, $wsb, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Abriendo Sandbox ($ruta)..." -ForegroundColor Cyan
if ($Probar) {
    Write-Host 'La prueba arranca sola al iniciar Sandbox. El log quedara en:' -ForegroundColor Cyan
    Write-Host "  $raiz\logs\" -ForegroundColor White
} else {
    Write-Host 'Dentro: abre PowerShell (ya eres Administrador) y ejecuta:' -ForegroundColor Cyan
    Write-Host "  Set-ExecutionPolicy -Scope Process Bypass -Force; cd $destino" -ForegroundColor White
    Write-Host '  .\WinMudanza.ps1 -Accion Aplicar -DirConfig .\config\sandbox -SinConfirmar -SinReiniciar' -ForegroundColor White
}
Start-Process -FilePath $ruta
