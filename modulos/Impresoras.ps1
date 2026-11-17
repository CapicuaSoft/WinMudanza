# Modulo Impresoras: impresoras de red y la predeterminada.
# - Conexiones a impresoras compartidas (\\servidor\impresora): se reconectan para el usuario que ejecuta.
# - Impresoras por IP (puerto TCP/IP): se crea el puerto y la impresora para todo el equipo.
#   Necesita el controlador: si Windows no lo tiene, queda como pendiente instalarlo.
# - No se tocan las virtuales de Windows (PDF, XPS, OneNote, Fax) ni las WSD/USB (Windows las detecta solo).

@{
    Nombre        = 'Impresoras'
    Descripcion   = 'Impresoras de red y predeterminada'
    Orden         = 34
    DependeDe     = @()
    ArchivoConfig = 'impresoras.psd1'

    Extraer = {
        param($Ctx)
        $lista = @()
        $predeterminada = ''
        $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
        if (-not $spooler -or $spooler.Status -ne 'Running') {
            Write-Omitido 'La Cola de impresion (Spooler) esta detenida: no hay impresoras que guardar'
            $impresoras = @()
        } else { try {
            $impresoras = @(Get-Printer -ErrorAction Stop)
        } catch {
            Write-Aviso "No se pudieron leer las impresoras (servicio Cola de impresion detenido?): $($_.Exception.Message)"
            $impresoras = @()
        } }
        $puertos = @{}
        foreach ($p in Get-PrinterPort -ErrorAction SilentlyContinue) { $puertos[$p.Name] = $p }
        try { $predeterminada = [string](Get-CimInstance Win32_Printer -Filter 'Default = TRUE' -ErrorAction Stop).Name } catch { }

        foreach ($i in $impresoras) {
            if ($i.Type -eq 'Connection' -or $i.Name -like '\\*') {
                $lista += [ordered]@{ Tipo = 'Red'; Nombre = [string]$i.Name; Conexion = [string]$i.Name }
                Write-Ok "Red: $($i.Name)"
                continue
            }
            $puerto = $puertos[$i.PortName]
            if ($puerto -and $puerto.PrinterHostAddress) {
                $lista += [ordered]@{
                    Tipo = 'IP'; Nombre = [string]$i.Name; Direccion = [string]$puerto.PrinterHostAddress
                    PuertoTcp = [int]$puerto.PortNumber; Controlador = [string]$i.DriverName
                }
                Write-Ok "IP: $($i.Name) -> $($puerto.PrinterHostAddress) ($($i.DriverName))"
                continue
            }
            Write-Omitido "$($i.Name) ($($i.PortName)): virtual, USB o WSD; Windows la gestiona solo"
        }
        if ($impresoras.Count -eq 0) { Write-Omitido 'No hay impresoras' }
        $ruta = Join-Path $Ctx.DirConfig 'impresoras.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Impresoras = $lista; Predeterminada = $predeterminada }) -Cabecera @(
            "Impresoras de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            "Tipo 'Red': conexion a una impresora compartida (\\servidor\impresora), para el usuario que ejecuta."
            "Tipo 'IP' : impresora con puerto TCP/IP (Direccion, PuertoTcp, Controlador), para todo el equipo."
            '            El Controlador debe existir en Windows o instalarse antes (si falta queda pendiente).'
            'Predeterminada: impresora predeterminada del usuario que ejecuta (vacio = no cambiar).'
            'Las virtuales (PDF, XPS, OneNote, Fax), USB y WSD no se guardan: Windows las detecta solo.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'impresoras.psd1')
        $lista = @($cfg.Impresoras | Where-Object { $_ -and $_.Nombre })
        if ($lista.Count -eq 0 -and -not $cfg.Predeterminada) { Write-Omitido 'No hay impresoras que anadir'; return }
        $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
        if (-not $spooler) { Write-Fallo 'No existe el servicio Cola de impresion (Spooler)'; return }
        if ($spooler.Status -ne 'Running') {
            if (Test-Simulacion) {
                Write-Aviso 'La Cola de impresion (Spooler) esta detenida: al aplicar se intentara iniciar'
            } else {
                $ok = Invoke-Cambio 'Iniciar la Cola de impresion (Spooler)' {
                    if ((Get-Service Spooler).StartType -eq 'Disabled') { Set-Service -Name Spooler -StartupType Automatic -ErrorAction Stop }
                    Start-Service -Name Spooler -ErrorAction Stop
                }
                if (-not $ok) { return }
            }
        }
        $existentes = @(Get-Printer -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })

        foreach ($i in $lista) {
            if ($existentes -contains $i.Nombre) { Write-Omitido "$($i.Nombre) ya existe"; continue }
            if ($i.Tipo -eq 'Red') {
                $null = Invoke-Cambio "Conectar impresora $($i.Conexion)" {
                    Add-Printer -ConnectionName $i.Conexion -ErrorAction Stop
                } -FalloComoAviso
                continue
            }
            # ---- IP ----
            if (-not (Get-PrinterDriver -Name $i.Controlador -ErrorAction SilentlyContinue)) {
                $hayDriver = $false
                if (-not (Test-Simulacion)) {
                    # Intenta con los controladores incluidos en Windows
                    try { Add-PrinterDriver -Name $i.Controlador -ErrorAction Stop; $hayDriver = $true } catch { }
                }
                if (-not $hayDriver -and -not (Test-Simulacion)) {
                    Add-Pendiente "Impresora '$($i.Nombre)': instala el controlador '$($i.Controlador)' y vuelve a ejecutar -Solo Impresoras"
                    continue
                }
            }
            $puerto = "IP_$($i.Direccion)"
            $null = Invoke-Cambio "Impresora $($i.Nombre) -> $($i.Direccion)" {
                if (-not (Get-PrinterPort -Name $puerto -ErrorAction SilentlyContinue)) {
                    $pp = @{ Name = $puerto; PrinterHostAddress = $i.Direccion; ErrorAction = 'Stop' }
                    if ($i.PuertoTcp) { $pp.PortNumber = [int]$i.PuertoTcp }
                    Add-PrinterPort @pp
                }
                Add-Printer -Name $i.Nombre -DriverName $i.Controlador -PortName $puerto -ErrorAction Stop
            }
        }

        if ($cfg.Predeterminada) {
            $actual = $null
            try { $actual = [string](Get-CimInstance Win32_Printer -Filter 'Default = TRUE' -ErrorAction Stop).Name } catch { }
            if ($actual -eq $cfg.Predeterminada) { Write-Omitido "Predeterminada: $actual" }
            else {
                $null = Invoke-Cambio "Impresora predeterminada: $($cfg.Predeterminada) (usuario $env:USERNAME)" {
                    $p = Get-CimInstance Win32_Printer -ErrorAction Stop | Where-Object { $_.Name -eq $cfg.Predeterminada }
                    if (-not $p) { throw 'no existe en este equipo' }
                    $r = Invoke-CimMethod -InputObject $p -MethodName SetDefaultPrinter -ErrorAction Stop
                    if ($r.ReturnValue -ne 0) { throw "codigo $($r.ReturnValue)" }
                    # Si Windows gestiona la predeterminada, la cambiaria sola
                    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows' -Name 'LegacyDefaultPrinterMode' -Value 1 -Type DWord -ErrorAction Stop
                } -FalloComoAviso
            }
        }
    }
}
