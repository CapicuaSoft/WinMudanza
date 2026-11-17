# 06 - PowerShell preparado para ejecutar y crear scripts.
#   DirectivaEjecucion -> directiva de ejecucion de todo el equipo (Windows PowerShell 5.1 y PowerShell 7)
#   NuGetYGaleria      -> proveedor NuGet instalado y PowerShell Gallery de confianza (Install-Module sin preguntas)
#   Tls12              -> .NET Framework usa TLS 1.2+ siempre (evita errores al descargar en PowerShell 5.1)
#   DobleClicEjecuta   -> doble clic en un .ps1 lo ejecuta con PowerShell en vez de abrir el Bloc de notas

@{
    Clave  = 'PowerShell'
    Nombre = 'PowerShell preparado para scripts'
    Aplicar = {
        param($Cfg, $Ctx)

        # ---- Directiva de ejecucion (ambito LocalMachine) ----
        $directiva = [string]$Cfg.DirectivaEjecucion
        if ($directiva) {
            if ($directiva -notin 'Restricted', 'AllSigned', 'RemoteSigned', 'Unrestricted', 'Bypass') {
                Write-Fallo "DirectivaEjecucion no valida: '$directiva' (usa RemoteSigned, AllSigned, Unrestricted o Bypass)"
            } else {
                # Se escribe en el registro: Set-ExecutionPolicy falla si hay una directiva de proceso mas especifica
                $actual = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' -ErrorAction SilentlyContinue).ExecutionPolicy
                if ($actual -eq $directiva) {
                    Write-Omitido "Windows PowerShell: directiva $directiva ya establecida"
                } else {
                    foreach ($base in 'HKLM:\SOFTWARE\Microsoft', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft') {
                        $null = Set-RegValor -Ruta "$base\PowerShell\1\ShellIds\Microsoft.PowerShell" -Nombre 'ExecutionPolicy' -Valor $directiva -Tipo String
                    }
                    if (-not (Test-Simulacion)) { Write-Ok "Windows PowerShell: directiva de ejecucion $directiva (todo el equipo)" }
                }
                # PowerShell 7 guarda la suya en $PSHOME\powershell.config.json
                if (Test-Comando 'pwsh') {
                    $actual7 = (& pwsh -NoProfile -Command 'Get-ExecutionPolicy -Scope LocalMachine' 2>$null | Select-Object -Last 1)
                    if ([string]$actual7 -eq $directiva) {
                        Write-Omitido "PowerShell 7: directiva $directiva ya establecida"
                    } else {
                        $null = Invoke-Cambio "PowerShell 7: directiva de ejecucion $directiva" {
                            $out = & pwsh -NoProfile -Command "Set-ExecutionPolicy -ExecutionPolicy $directiva -Scope LocalMachine -Force -ErrorAction Stop" 2>&1
                            if ($LASTEXITCODE -ne 0) { throw (($out | ForEach-Object { [string]$_ }) -join ' ') }
                        }
                    }
                }
                # Una directiva de grupo (GPO) tiene prioridad sobre la de equipo
                $gpo = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell' -ErrorAction SilentlyContinue).ExecutionPolicy
                if ($gpo -and $gpo -ne $directiva) { Write-Aviso "Una directiva de grupo fuerza '$gpo' y tiene prioridad sobre $directiva" }
            }
        }

        # ---- TLS 1.2 para .NET Framework ----
        if ($Cfg.Tls12) {
            $ok = $true
            foreach ($base in 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319') {
                $ok = (Set-RegValor -Ruta $base -Nombre 'SchUseStrongCrypto' -Valor 1 -Tipo DWord) -and $ok
                $ok = (Set-RegValor -Ruta $base -Nombre 'SystemDefaultTlsVersions' -Valor 1 -Tipo DWord) -and $ok
            }
            if ($ok -and -not (Test-Simulacion)) { Write-Ok '.NET Framework: TLS 1.2 o superior siempre' }
        }

        # ---- NuGet + PowerShell Gallery ----
        if ($Cfg.NuGetYGaleria) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            if (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue | Where-Object { $_.Version -ge [version]'2.8.5.201' }) {
                Write-Omitido 'Proveedor NuGet ya instalado'
            } else {
                $null = Invoke-Cambio 'Instalar proveedor NuGet (todos los usuarios)' {
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -ErrorAction Stop | Out-Null
                }
            }
            $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
            if ($repo -and $repo.InstallationPolicy -eq 'Trusted') {
                Write-Omitido 'PowerShell Gallery ya es de confianza'
            } else {
                # La confianza en repositorios es por usuario: se aplica al que ejecuta WinMudanza
                $null = Invoke-Cambio "PowerShell Gallery de confianza (usuario $env:USERNAME)" {
                    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
                }
            }
        }

        # ---- Doble clic en .ps1 ejecuta ----
        if ($Cfg.DobleClicEjecuta) {
            $clase = 'HKLM:\SOFTWARE\Classes\Microsoft.PowerShellScript.1\Shell'
            $comando = "`"$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`" -NoLogo -ExecutionPolicy RemoteSigned -File `"%1`" %*"
            $actual = (Get-ItemProperty -LiteralPath $clase -ErrorAction SilentlyContinue).'(default)'
            $actualCmd = (Get-ItemProperty -LiteralPath "$clase\0\Command" -ErrorAction SilentlyContinue).'(default)'
            if ($actual -eq '0' -and $actualCmd -eq $comando) {
                Write-Omitido 'Doble clic en .ps1 ya ejecuta con PowerShell'
            } else {
                $ok = Set-RegValor -Ruta "$clase\0" -Nombre 'MUIVerb' -Valor 'Ejecutar con PowerShell' -Tipo String
                $ok = (Set-RegValor -Ruta "$clase\0\Command" -Nombre '(Default)' -Valor $comando -Tipo String) -and $ok
                $ok = (Set-RegValor -Ruta $clase -Nombre '(Default)' -Valor '0' -Tipo String) -and $ok
                if ($ok -and -not (Test-Simulacion)) { Write-Ok 'Doble clic en .ps1: ejecutar con PowerShell (Editar sigue en el clic derecho)' }
            }
            # Si un usuario eligio "Abrir con..." para .ps1, su eleccion tiene prioridad
            $eleccion = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ps1\UserChoice'
            if (Test-Path -LiteralPath $eleccion) {
                Write-Aviso "$env:USERNAME eligio un programa para abrir .ps1; el doble clic seguira usandolo (cambialo en Configuracion > Aplicaciones predeterminadas)"
            }
        }
    }
}
