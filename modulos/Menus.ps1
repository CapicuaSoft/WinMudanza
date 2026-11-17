# Modulo Menus: menus contextuales del Explorador de programas instalados con winget,
# que winget no anade (instala en silencio sin las opciones de menu del instalador).
#   ClaudeCode -> "Abrir en Claude" en carpetas (claude en Windows Terminal, o PowerShell)
#   VSCode     -> "Abrir con Code" en archivos, carpetas y fondo de carpeta (como el instalador)
#   Everything -> "Buscar con Everything..." en carpetas y fondo de carpeta
#   WinMerge   -> registra su extension del Explorador (Comparar)
# Solo anade el menu si el programa esta instalado. Va despues de Paquetes.
# No tiene Extraer: se activa en config\ajustes.psd1, seccion Menus.
# Programa instalado para todos -> HKLM; instalado solo para el usuario -> HKCU de ese usuario.

@{
    Nombre        = 'Menus'
    Descripcion   = 'Menus contextuales de Claude, VS Code, Everything y WinMerge'
    Orden         = 46
    DependeDe     = @('Paquetes')
    ArchivoConfig = $null
    Extraer       = $null
    Aplicar       = {
        param($Ctx)
        $rutaCfg = Join-Path $Ctx.Raiz 'config\ajustes.psd1'
        if (-not (Test-Path -LiteralPath $rutaCfg)) { Write-Fallo "No existe $rutaCfg"; return }
        $cfg = (Read-ConfigPsd1 $rutaCfg).Menus
        if (-not $cfg -or -not $cfg.Activo) { Write-Omitido 'Desactivado en ajustes.psd1 (Menus.Activo)'; return }
        Update-RutaEntorno

        # Primer ejecutable que exista de la lista
        function Find-Exe([string[]]$Rutas) {
            foreach ($r in $Rutas) {
                $x = [Environment]::ExpandEnvironmentVariables($r)
                if (Test-Path -LiteralPath $x) { return $x }
            }
            return $null
        }
        # HKLM si el programa es para todos; HKCU si esta en el perfil del usuario
        function Get-RaizClases([string]$Exe) {
            if ($Exe -and $Exe.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) { return 'HKCU:\Software\Classes' }
            return 'HKLM:\SOFTWARE\Classes'
        }
        # Otra entrada (con otro nombre) que ya abre este programa: no se duplica
        function Find-VerboExistente([string]$Clase, [string]$Clave, [string]$Exe) {
            $hoja = Split-Path $Exe -Leaf
            foreach ($k in Get-ChildItem -LiteralPath "Registry::HKEY_CLASSES_ROOT\$Clase\shell" -ErrorAction SilentlyContinue) {
                if ($k.PSChildName -eq $Clave) { continue }
                $cmd = [string](Get-ItemProperty -LiteralPath (Join-Path $k.PSPath 'command') -ErrorAction SilentlyContinue).'(default)'
                if ($cmd -and $cmd.IndexOf($hoja, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and $cmd -match '"?([A-Za-z]:\\[^"]+?\.exe)') {
                    if (Test-Path -LiteralPath $Matches[1]) { return $k.PSChildName }
                }
            }
            return $null
        }
        # Crea (o corrige) un verbo de menu: <Raiz>\<Clase>\shell\<Clave>
        function Set-Verbo([string]$Raiz, [string]$Clase, [string]$Clave, [string]$Texto, [string]$Comando, [string]$Icono, [string]$Exe) {
            $otro = Find-VerboExistente $Clase $Clave $Exe
            if ($otro) { Write-Omitido "$Texto en $Clase (ya existe como '$otro')"; return }
            $ruta = "$Raiz\$Clase\shell\$Clave"
            # Una entrada de HKCU con el mismo nombre tapa a la de HKLM: si apunta a otro sitio, se corrige
            $hkcu = "HKCU:\Software\Classes\$Clase\shell\$Clave"
            $cmdU = $null
            if ($Raiz -like 'HKLM:*') { $cmdU = [string](Get-ItemProperty -LiteralPath "$hkcu\command" -ErrorAction SilentlyContinue).'(default)' }
            $tapada = $cmdU -and $cmdU -ne $Comando
            $igual = (Test-RegValorIgual $ruta '(Default)' $Texto 'String') -and
                     (Test-RegValorIgual "$ruta\command" '(Default)' $Comando 'String') -and
                     (-not $Icono -or (Test-RegValorIgual $ruta 'Icon' $Icono 'String'))
            if ($igual -and -not $tapada) { Write-Omitido "$Texto en $Clase (ya esta)"; return }
            $ok = (Set-RegValor -Ruta $ruta -Nombre '(Default)' -Valor $Texto -Tipo String) -and
                  (Set-RegValor -Ruta "$ruta\command" -Nombre '(Default)' -Valor $Comando -Tipo String)
            if ($ok -and $Icono) { $ok = Set-RegValor -Ruta $ruta -Nombre 'Icon' -Valor $Icono -Tipo String }
            if ($ok -and $tapada) {
                $ok = Set-RegValor -Ruta "$hkcu\command" -Nombre '(Default)' -Valor $Comando -Tipo String
                if ($ok -and $Icono) { $ok = Set-RegValor -Ruta $hkcu -Nombre 'Icon' -Valor $Icono -Tipo String }
            }
            if ($ok -and -not (Test-Simulacion)) { Write-Ok "$Texto en $Clase" }
        }

        # ---------- Claude Code ----------
        if ($cfg.ClaudeCode) {
            $claude = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $claude) { Write-Omitido 'Claude Code no esta instalado (Anthropic.ClaudeCode)' }
            else {
                $exe = $claude.Source
                # wt.exe necesita la ruta sin barra final antes de la comilla: "C:\" se rompe, "C:\." no
                if (Test-Comando 'wt.exe') { $cmd = 'wt.exe -d "%V." claude' }
                else { $cmd = "powershell.exe -NoExit -NoLogo -Command `"Set-Location -LiteralPath '%V'; claude`"" }
                $icono = $null
                if (-not $exe.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) { $icono = "`"$exe`",0" }
                $raiz = Get-RaizClases $exe
                foreach ($clase in 'Directory', 'Directory\Background', 'Drive') {
                    Set-Verbo $raiz $clase 'ClaudeCode' 'Abrir en Claude' $cmd $icono $exe
                }
            }
        } else { Write-Omitido 'Claude Code desactivado (Menus.ClaudeCode)' }

        # ---------- VS Code ----------
        if ($cfg.VSCode) {
            $exe = Find-Exe @('%ProgramFiles%\Microsoft VS Code\Code.exe', '%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe')
            if (-not $exe) { Write-Omitido 'VS Code no esta instalado (Microsoft.VisualStudioCode)' }
            else {
                $raiz = Get-RaizClases $exe
                $icono = "`"$exe`",0"
                Set-Verbo $raiz '*' 'VSCode' 'Abrir con Code' "`"$exe`" `"%1`"" $icono $exe
                Set-Verbo $raiz 'Directory' 'VSCode' 'Abrir con Code' "`"$exe`" `"%V`"" $icono $exe
                Set-Verbo $raiz 'Directory\Background' 'VSCode' 'Abrir con Code' "`"$exe`" `"%V`"" $icono $exe
                Set-Verbo $raiz 'Drive' 'VSCode' 'Abrir con Code' "`"$exe`" `"%V`"" $icono $exe
            }
        } else { Write-Omitido 'VS Code desactivado (Menus.VSCode)' }

        # ---------- Everything ----------
        if ($cfg.Everything) {
            $exe = Find-Exe @('%ProgramFiles%\Everything\Everything.exe', '%ProgramFiles(x86)%\Everything\Everything.exe',
                              '%ProgramFiles%\Everything 1.5a\Everything64.exe', '%LOCALAPPDATA%\Programs\Everything\Everything.exe')
            if (-not $exe) { Write-Omitido 'Everything no esta instalado (voidtools.Everything)' }
            else {
                $raiz = Get-RaizClases $exe
                $icono = "`"$exe`",0"
                Set-Verbo $raiz 'Directory' 'Everything' 'Buscar con Everything...' "`"$exe`" -path `"%1`"" $icono $exe
                Set-Verbo $raiz 'Directory\Background' 'Everything' 'Buscar con Everything...' "`"$exe`" -path `"%V`"" $icono $exe
                Set-Verbo $raiz 'Drive' 'Everything' 'Buscar con Everything...' "`"$exe`" -path `"%1`"" $icono $exe
            }
        } else { Write-Omitido 'Everything desactivado (Menus.Everything)' }

        # ---------- WinMerge ----------
        if ($cfg.WinMerge) {
            $exe = Find-Exe @('%ProgramFiles%\WinMerge\WinMergeU.exe', '%ProgramFiles(x86)%\WinMerge\WinMergeU.exe', '%LOCALAPPDATA%\Programs\WinMerge\WinMergeU.exe')
            if (-not $exe) { Write-Omitido 'WinMerge no esta instalado (WinMerge.WinMerge)' }
            else {
                $dir = Split-Path $exe
                $dll = Find-Exe @((Join-Path $dir 'ShellExtensionX64.dll'), (Join-Path $dir 'ShellExtensionU.dll'))
                if (-not $dll) { Write-Aviso "WinMerge: no se encontro su extension del Explorador (ShellExtensionX64.dll) en $dir" }
                else {
                    # Ya registrada si *\shellex\ContextMenuHandlers\WinMerge apunta a un CLSID cuya DLL existe
                    $registrada = $false
                    $clsid = [string](Get-ItemProperty -LiteralPath 'Registry::HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\WinMerge' -ErrorAction SilentlyContinue).'(default)'
                    if ($clsid) {
                        $srv = [string](Get-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\CLSID\$clsid\InprocServer32" -ErrorAction SilentlyContinue).'(default)'
                        $registrada = $srv -and (Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($srv)))
                    }
                    if ($registrada) { Write-Omitido 'WinMerge: extension del Explorador ya registrada' }
                    else {
                        $null = Invoke-Cambio "WinMerge: registrar extension del Explorador ($(Split-Path $dll -Leaf))" {
                            $p = Start-Process regsvr32.exe -ArgumentList '/s', "`"$dll`"" -Wait -PassThru -WindowStyle Hidden
                            if ($p.ExitCode -ne 0) { throw "regsvr32 termino con codigo $($p.ExitCode)" }
                        }
                    }
                    # La extension solo se muestra si ContextMenuEnabled tiene el bit 1 (lo pone el instalador
                    # en el usuario que instala). Se activa en los perfiles que no lo tengan; no se cambia si ya existe.
                    Invoke-EnPerfiles {
                        param($P)
                        $clave = "$($P.HKCU)\Software\Thingamahoochie\WinMerge"
                        $actual = (Get-ItemProperty -LiteralPath $clave -ErrorAction SilentlyContinue).ContextMenuEnabled
                        if ($null -ne $actual) { Write-Omitido "WinMerge: menu ya configurado en $($P.Nombre)"; return }
                        if (Set-RegValor -Ruta $clave -Nombre 'ContextMenuEnabled' -Valor 1 -Tipo DWord) {
                            if (-not (Test-Simulacion)) { Write-Ok "WinMerge: menu activado en $($P.Nombre)" }
                        }
                    }
                }
            }
        } else { Write-Omitido 'WinMerge desactivado (Menus.WinMerge)' }

        Write-Info 'Con el menu clasico (ajuste 01) se ven directamente; si no, en "Mostrar mas opciones".'
    }
}
