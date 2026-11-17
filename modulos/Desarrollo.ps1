# Modulo Desarrollo: archivos de configuracion de herramientas del usuario que ejecuta.
#   .gitconfig, claves .ssh, .npmrc, .wslconfig, perfiles de PowerShell (5.1 y 7),
#   Windows Terminal y VS Code (settings, atajos y fragmentos).
# - Extraer copia los que existan a config\desarrollo\ (las claves SSH privadas van EN CLARO).
# - Aplicar los copia al perfil del usuario que ejecuta; si un archivo ya existe y es distinto,
#   guarda antes <archivo>.wmud.bak. A las claves SSH privadas les deja permisos solo del usuario
#   (OpenSSH las rechaza si otros pueden leerlas).

@{
    Nombre        = 'Desarrollo'
    Descripcion   = '.gitconfig, .ssh, perfil PowerShell, Terminal, VS Code'
    Orden         = 48
    DependeDe     = @()
    ArchivoConfig = 'desarrollo.psd1'

    Extraer = {
        param($Ctx)
        $docs = [Environment]::GetFolderPath('MyDocuments')
        $wt = '%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
        $wtp = '%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState'
        # N = nombre, R = ruta (con %VARIABLES% o {Documentos})
        $candidatos = @(
            @{ N = 'Git'; R = '%USERPROFILE%\.gitconfig' }
            @{ N = 'SSH'; R = '%USERPROFILE%\.ssh' }
            @{ N = 'npm'; R = '%USERPROFILE%\.npmrc' }
            @{ N = 'WSL'; R = '%USERPROFILE%\.wslconfig' }
            @{ N = 'PowerShell 5.1'; R = '{Documentos}\WindowsPowerShell\Microsoft.PowerShell_profile.ps1' }
            @{ N = 'PowerShell 5.1'; R = '{Documentos}\WindowsPowerShell\profile.ps1' }
            @{ N = 'PowerShell 5.1'; R = '{Documentos}\WindowsPowerShell\Microsoft.VSCode_profile.ps1' }
            @{ N = 'PowerShell 7'; R = '{Documentos}\PowerShell\Microsoft.PowerShell_profile.ps1' }
            @{ N = 'PowerShell 7'; R = '{Documentos}\PowerShell\profile.ps1' }
            @{ N = 'PowerShell 7'; R = '{Documentos}\PowerShell\Microsoft.VSCode_profile.ps1' }
            @{ N = 'Windows Terminal'; R = "$wt\settings.json" }
            @{ N = 'Windows Terminal Preview'; R = "$wtp\settings.json" }
            @{ N = 'Windows Terminal'; R = '%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json' }
            @{ N = 'VS Code'; R = '%APPDATA%\Code\User\settings.json' }
            @{ N = 'VS Code'; R = '%APPDATA%\Code\User\keybindings.json' }
            @{ N = 'VS Code'; R = '%APPDATA%\Code\User\snippets' }
        )
        $dirDestino = Join-Path $Ctx.DirConfig 'desarrollo'
        if (Test-Path -LiteralPath $dirDestino) { Remove-Item -LiteralPath $dirDestino -Recurse -Force }
        $lista = @()
        $n = 0
        foreach ($c in $candidatos) {
            $real = [Environment]::ExpandEnvironmentVariables($c.R.Replace('{Documentos}', $docs))
            if (-not (Test-Path -LiteralPath $real)) { continue }
            $item = Get-Item -LiteralPath $real -Force
            if ($item.PSIsContainer -and -not (Get-ChildItem -LiteralPath $real -Recurse -File -Force | Select-Object -First 1)) { continue }
            $n++
            $archivo = '{0:D2}_{1}' -f $n, $item.Name
            $destino = Join-Path $dirDestino $archivo
            New-Item -ItemType Directory -Path $dirDestino -Force | Out-Null
            if ($item.PSIsContainer) { Copy-Item -LiteralPath $real -Destination $destino -Recurse -Force }
            else { Copy-Item -LiteralPath $real -Destination $destino -Force }
            $lista += [ordered]@{ Nombre = $c.N; Ruta = $c.R; Archivo = $archivo }
            $extra = ''
            if ($item.PSIsContainer) { $extra = " ($(@(Get-ChildItem -LiteralPath $real -Recurse -File -Force).Count) archivos)" }
            Write-Ok "$($c.N): $($c.R)$extra"
        }
        if ($lista.Count -eq 0) { Write-Omitido 'No hay archivos de configuracion de desarrollo' }
        $ruta = Join-Path $Ctx.DirConfig 'desarrollo.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Elementos = $lista }) -Cabecera @(
            "Configuracion de desarrollo de $env:USERNAME en $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Elementos: archivo o carpeta guardado en config\desarrollo\<Archivo> y su destino (Ruta).'
            '  Ruta admite %USERPROFILE%, %APPDATA%, %LOCALAPPDATA%... y {Documentos} (carpeta Documentos).'
            '  Se copia al usuario que ejecute WinMudanza. Si el destino existe y es distinto se guarda .wmud.bak.'
            '  Comenta (#) o borra los que no quieras.'
            'ATENCION: config\desarrollo\ puede contener claves SSH privadas y tokens (.npmrc). No lo compartas.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'desarrollo.psd1')
        $docs = [Environment]::GetFolderPath('MyDocuments')
        $lista = @($cfg.Elementos | Where-Object { $_ -and $_.Ruta -and $_.Archivo })
        if ($lista.Count -eq 0) { Write-Omitido 'No hay nada que restaurar'; return }

        foreach ($e in $lista) {
            $origen = Join-Path (Join-Path $Ctx.DirConfig 'desarrollo') $e.Archivo
            $destino = [Environment]::ExpandEnvironmentVariables(([string]$e.Ruta).Replace('{Documentos}', $docs))
            if (-not (Test-Path -LiteralPath $origen)) { Write-Fallo "$($e.Nombre): falta $origen"; continue }

            # Pares origen -> destino (un archivo, o todos los de la carpeta)
            $pares = @()
            if ((Get-Item -LiteralPath $origen).PSIsContainer) {
                $base = (Get-Item -LiteralPath $origen).FullName.TrimEnd('\')
                foreach ($f in Get-ChildItem -LiteralPath $origen -Recurse -File -Force) {
                    $pares += , @($f.FullName, (Join-Path $destino $f.FullName.Substring($base.Length + 1)))
                }
            } else {
                $pares += , @($origen, $destino)
            }

            $copiados = 0
            foreach ($p in $pares) {
                $o = $p[0]; $d = $p[1]
                if ((Test-Path -LiteralPath $d) -and (Get-FileHash -LiteralPath $o).Hash -eq (Get-FileHash -LiteralPath $d).Hash) { continue }
                $existe = Test-Path -LiteralPath $d
                $desc = "$($e.Nombre): $d"
                if ($existe) { $desc += ' (el actual se guarda como .wmud.bak)' }
                if (Invoke-Cambio $desc { Copy-ArchivoSeguro -Origen $o -Destino $d -Respaldo } -Silencioso) { $copiados++ }
            }
            if ($copiados -eq 0) { Write-Omitido "$($e.Nombre): $($e.Ruta) ya al dia" }
            elseif (-not (Test-Simulacion)) { Write-Ok "$($e.Nombre): $($e.Ruta) ($copiados archivos)" }

            # Claves SSH privadas: solo el usuario puede leerlas
            if ($e.Nombre -eq 'SSH' -and $copiados -gt 0) {
                $privadas = @($pares | ForEach-Object { $_[1] } | Where-Object {
                    $n = Split-Path $_ -Leaf
                    $n -notmatch '\.(pub|wmud\.bak)$' -and $n -notin 'known_hosts', 'known_hosts.old', 'config', 'authorized_keys'
                })
                foreach ($k in $privadas) {
                    $null = Invoke-Cambio "SSH: permisos solo para $env:USERNAME en $(Split-Path $k -Leaf)" {
                        $out = & icacls.exe $k /inheritance:r /grant:r "${env:USERNAME}:F" /setowner $env:USERNAME 2>&1
                        if ($LASTEXITCODE -ne 0) { throw (($out | ForEach-Object { [string]$_ }) -join ' ') }
                    } -Silencioso
                }
            }
        }
        Write-Info "Se ha restaurado para el usuario $env:USERNAME. Para otro usuario, ejecuta -Solo Desarrollo con su sesion."
    }
}
