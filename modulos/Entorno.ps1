# Modulo Entorno: variables de entorno y PATH personalizados.
# - Equipo (HKLM) y usuario (HKCU del que ejecuta). Se omiten las que crea Windows.
# - Las rutas del perfil se guardan portables (%USERPROFILE%, %APPDATA%...).
# - Aplicar: crea las variables que falten (no cambia las que ya existen con otro valor) y anade
#   al PATH las carpetas que falten. Va despues de Paquetes: los programas ya estan instalados.

@{
    Nombre        = 'Entorno'
    Descripcion   = 'Variables de entorno y PATH personalizados'
    Orden         = 47
    DependeDe     = @('Paquetes')
    ArchivoConfig = 'entorno.psd1'

    Extraer = {
        param($Ctx)
        $deWindows = @{
            Equipo  = @('ComSpec', 'DriverData', 'NUMBER_OF_PROCESSORS', 'OS', 'PATHEXT', 'PROCESSOR_ARCHITECTURE', 'PROCESSOR_IDENTIFIER',
                        'PROCESSOR_LEVEL', 'PROCESSOR_REVISION', 'PSModulePath', 'TEMP', 'TMP', 'USERNAME', 'windir', 'Path',
                        'OnlineServices', 'platformcode', 'RegionCode', 'configsetroot')
            Usuario = @('TEMP', 'TMP', 'Path', 'OneDrive', 'OneDriveConsumer', 'OneDriveCommercial')
        }
        $claves = @{
            Equipo  = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
            Usuario = 'HKCU:\Environment'
        }
        $datos = [ordered]@{}
        foreach ($ambito in 'Equipo', 'Usuario') {
            $k = Get-Item -LiteralPath $claves[$ambito]
            $vars = [ordered]@{}
            foreach ($n in ($k.GetValueNames() | Sort-Object)) {
                if (-not $n -or $deWindows[$ambito] -contains $n) { continue }
                $v = [string]$k.GetValue($n, $null, 'DoNotExpandEnvironmentNames')
                if ($ambito -eq 'Usuario') { $v = ConvertTo-RutaPortable $v }
                $vars[$n] = $v
                Write-Ok "${ambito}: $n = $v"
            }
            $path = @(([string]$k.GetValue('Path', '', 'DoNotExpandEnvironmentNames')).Split(';') |
                ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { ConvertTo-RutaPortable $_ })
            $path = @($path | Select-Object -Unique)
            Write-Ok "${ambito}: PATH con $($path.Count) carpetas"
            $datos[$ambito] = [ordered]@{ Variables = $vars; Path = $path }
        }
        $ruta = Join-Path $Ctx.DirConfig 'entorno.psd1'
        Write-Psd1 -Ruta $ruta -Datos $datos -Cabecera @(
            "Variables de entorno de $env:COMPUTERNAME ($env:USERNAME) el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Equipo : variables de todo el equipo. Usuario: del usuario que ejecute WinMudanza al aplicar.'
            'Variables: se crean las que falten. Si ya existen con otro valor NO se cambian (se avisa).'
            'Path     : se anaden las carpetas que falten, al final. Si la carpeta no existe se avisa y se omite'
            '           (normalmente es de un programa que aun no esta instalado).'
            'Las rutas %USERPROFILE%, %APPDATA%... se expanden en el equipo nuevo. Comenta (#) lo que no quieras.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'entorno.psd1')
        $claves = @{
            Equipo  = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
            Usuario = 'HKCU:\Environment'
        }
        $cambios = 0
        foreach ($ambito in 'Equipo', 'Usuario') {
            $sec = $cfg[$ambito]
            if (-not $sec) { continue }
            $k = Get-Item -LiteralPath $claves[$ambito]

            # ---- Variables ----
            if ($sec.Variables) {
                foreach ($n in $sec.Variables.Keys) {
                    $nuevo = [string]$sec.Variables[$n]
                    $actual = $k.GetValue($n, $null, 'DoNotExpandEnvironmentNames')
                    if ($null -ne $actual) {
                        if ([Environment]::ExpandEnvironmentVariables($actual) -ieq [Environment]::ExpandEnvironmentVariables($nuevo)) {
                            Write-Omitido "${ambito}: $n ya vale $actual"
                        } else {
                            Write-Aviso "${ambito}: $n ya existe con otro valor ($actual); no se cambia (en config: $nuevo)"
                        }
                        continue
                    }
                    $tipo = 'String'
                    if ($nuevo -match '%[^%]+%') { $tipo = 'ExpandString' }
                    if (Set-RegValor -Ruta $claves[$ambito] -Nombre $n -Valor $nuevo -Tipo $tipo) {
                        $cambios++
                        if (-not (Test-Simulacion)) { Write-Ok "${ambito}: $n = $nuevo" }
                    }
                    $exp = [Environment]::ExpandEnvironmentVariables($nuevo)
                    if ($exp -match '^[A-Za-z]:\\' -and -not (Test-Path -LiteralPath $exp)) { Write-Aviso "${ambito}: $n apunta a $exp, que no existe (todavia)" }
                }
            }

            # ---- PATH ----
            $raw = [string]$k.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
            $actuales = @($raw.Split(';') | Where-Object { $_.Trim() } | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_.Trim()).TrimEnd('\').ToLower() })
            $anadir = @()
            foreach ($c in @($sec.Path | Where-Object { $_ })) {
                $exp = [Environment]::ExpandEnvironmentVariables($c).TrimEnd('\')
                if ($actuales -contains $exp.ToLower()) { continue }
                if (-not (Test-Path -LiteralPath $exp)) { Write-Aviso "${ambito} PATH: $c no existe aqui (programa sin instalar?); se omite"; continue }
                $anadir += $c
            }
            if ($anadir.Count -eq 0) { Write-Omitido "${ambito}: PATH ya tiene todas las carpetas"; continue }
            $nuevoPath = (@($raw.TrimEnd(';')) + $anadir | Where-Object { $_ }) -join ';'
            if (Set-RegValor -Ruta $claves[$ambito] -Nombre 'Path' -Valor $nuevoPath -Tipo ExpandString) {
                $cambios++
                if (-not (Test-Simulacion)) { foreach ($c in $anadir) { Write-Ok "${ambito} PATH: + $c" } }
                elseif ($anadir.Count -gt 0) { Write-Info "${ambito} PATH: + $($anadir -join '; ')" }
            }
        }

        # Avisa a las ventanas abiertas para que lean las variables nuevas
        if ($cambios -gt 0 -and -not (Test-Simulacion)) {
            $null = Invoke-Cambio 'Notificar el cambio de variables de entorno' {
                if (-not ('WMud.Entorno' -as [type])) {
                    Add-Type -Namespace WMud -Name Entorno -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
                }
                $r = [UIntPtr]::Zero
                $null = [WMud.Entorno]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r)
                Update-RutaEntorno
            } -Silencioso
        }
    }
}
