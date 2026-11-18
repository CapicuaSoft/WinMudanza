# 07 - Escritorio remoto: permite conectarse a este equipo por RDP.
#   Permitir        -> acepta conexiones de Escritorio remoto (fDenyTSConnections = 0)
#   NLA             -> exige autenticacion a nivel de red (UserAuthentication = 1, recomendado)
#   Firewall        -> activa las reglas del grupo "Escritorio remoto" del Firewall de Windows
# Solo Windows Pro, Enterprise o Education: Home no puede recibir conexiones (se avisa).
# Los administradores pueden entrar; el resto de usuarios necesita el grupo
# "Usuarios de escritorio remoto" (modulo Usuarios, config\usuarios.psd1).

@{
    Clave  = 'EscritorioRemoto'
    Nombre = 'Escritorio remoto'
    Aplicar = {
        param($Cfg, $Ctx)
        $edicion = [string](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).EditionID
        if ($edicion -like 'Core*') {
            Write-Aviso "Escritorio remoto: Windows $edicion (Home) no permite recibir conexiones; se necesita Pro"
            return
        }

        $ts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
        if ($Cfg.Permitir) {
            if (Test-RegValorIgual $ts 'fDenyTSConnections' 0 'DWord') { Write-Omitido 'Escritorio remoto ya permitido' }
            elseif ((Set-RegValor -Ruta $ts -Nombre 'fDenyTSConnections' -Valor 0 -Tipo DWord) -and -not (Test-Simulacion)) {
                Write-Ok 'Escritorio remoto permitido'
            }
            # El servicio debe poder arrancar (Manual es lo normal: se inicia al conectar)
            $svc = Get-Service TermService -ErrorAction SilentlyContinue
            if ($svc -and $svc.StartType -eq 'Disabled') {
                $null = Invoke-Cambio 'Servicio de Escritorio remoto (TermService): inicio Manual' {
                    Set-Service TermService -StartupType Manual -ErrorAction Stop
                }
            }
        }

        if ($Cfg.NLA) {
            $rdp = "$ts\WinStations\RDP-Tcp"
            if (Test-RegValorIgual $rdp 'UserAuthentication' 1 'DWord') { Write-Omitido 'Escritorio remoto: autenticacion a nivel de red ya exigida' }
            elseif ((Set-RegValor -Ruta $rdp -Nombre 'UserAuthentication' -Valor 1 -Tipo DWord) -and -not (Test-Simulacion)) {
                Write-Ok 'Escritorio remoto: autenticacion a nivel de red exigida'
            }
        }

        if ($Cfg.Firewall) {
            # Grupo por su recurso (no por el nombre, que cambia con el idioma)
            $reglas = @(Get-NetFirewallRule -Group '@FirewallAPI.dll,-28752' -ErrorAction SilentlyContinue)
            if ($reglas.Count -eq 0) { Write-Aviso 'Escritorio remoto: no se encontraron sus reglas del Firewall' }
            else {
                $apagadas = @($reglas | Where-Object { $_.Enabled -ne 'True' })
                if ($apagadas.Count -eq 0) { Write-Omitido 'Escritorio remoto: reglas del Firewall ya activas' }
                else {
                    $null = Invoke-Cambio "Escritorio remoto: activar $($apagadas.Count) regla(s) del Firewall" {
                        $apagadas | Enable-NetFirewallRule -ErrorAction Stop
                    }
                }
            }
        }
    }
}
