# Modulo Outlook: cuentas de correo y firmas de Outlook clasico (Microsoft 365 / Office 2016+).
# Windows no permite trasladar las contrasenas y copiar el perfil del registro a otro equipo no es
# fiable, asi que:
# - Extraer: de cada perfil de Windows, lista las cuentas de cada perfil de Outlook (email, tipo,
#   servidores IMAP/POP/SMTP), los archivos de datos .pst y copia las firmas
#   (%APPDATA%\Microsoft\Signatures) a config\outlook\<usuario>\Firmas.
# - Aplicar: copia las firmas que falten y deja como pendiente anadir cada cuenta (Exchange,
#   Microsoft 365, Outlook.com y Gmail solo piden el email e iniciar sesion) y abrir los .pst.

@{
    Nombre        = 'Outlook'
    Descripcion   = 'Cuentas de correo y firmas de Outlook'
    Orden         = 53
    DependeDe     = @('Usuarios', 'Office')
    ArchivoConfig = 'outlook.psd1'

    Extraer = {
        param($Ctx)
        $dirBase = Join-Path $Ctx.DirConfig 'outlook'
        if (Test-Path -LiteralPath $dirBase) { Remove-Item -LiteralPath $dirBase -Recurse -Force }
        $acumulado = New-Object System.Collections.ArrayList

        # Los valores de texto de Outlook se guardan como binario UTF-16
        function ConvertFrom-ValorOutlook($v) {
            if ($v -is [byte[]]) { return ([Text.Encoding]::Unicode.GetString($v)).TrimEnd([char]0) }
            return [string]$v
        }

        Invoke-EnPerfiles {
            param($P)
            if ($P.EsDefault) { return }
            $cuentas = @()
            $pst = @()
            foreach ($ver in '16.0', '15.0') {
                $base = "$($P.HKCU)\Software\Microsoft\Office\$ver\Outlook\Profiles"
                foreach ($perfil in Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue) {
                    # Cuentas
                    foreach ($k in Get-ChildItem -LiteralPath "$($perfil.PSPath)\9375CFF0413111d3B88A00104B2A6676" -ErrorAction SilentlyContinue) {
                        $c = Get-Item -LiteralPath $k.PSPath
                        $email = ConvertFrom-ValorOutlook $c.GetValue('Email')
                        $nombre = ConvertFrom-ValorOutlook $c.GetValue('Account Name')
                        if (-not $email) { $email = $nombre }
                        if ($email -notmatch '@') { continue }   # libreta de direcciones, etc.
                        $cuenta = [ordered]@{ Perfil = $perfil.PSChildName; Email = $email; Tipo = 'Exchange / Microsoft 365 / Outlook.com' }
                        foreach ($t in 'IMAP', 'POP3') {
                            $srv = ConvertFrom-ValorOutlook $c.GetValue("$t Server")
                            if (-not $srv) { continue }
                            $cuenta.Tipo = $t -replace '3$', ''
                            $cuenta.Entrada = '{0}:{1}{2}' -f $srv, $c.GetValue("$t Port"), $(if ($c.GetValue("$t Use SSL")) { ' (SSL)' } else { '' })
                            $cuenta.UsuarioServidor = ConvertFrom-ValorOutlook $c.GetValue("$t User")
                        }
                        $smtp = ConvertFrom-ValorOutlook $c.GetValue('SMTP Server')
                        if ($smtp) { $cuenta.Salida = '{0}:{1}{2}' -f $smtp, $c.GetValue('SMTP Port'), $(if ($c.GetValue('SMTP Use SSL')) { ' (SSL)' } else { '' }) }
                        $cuentas += $cuenta
                        Write-Ok "$($P.Nombre): $email ($($cuenta.Tipo))"
                    }
                    # Archivos de datos .pst (PR_PST_PATH = 001f6700); los .ost son copia del servidor
                    foreach ($k in Get-ChildItem -LiteralPath $perfil.PSPath -ErrorAction SilentlyContinue) {
                        $v = (Get-Item -LiteralPath $k.PSPath).GetValue('001f6700')
                        if (-not $v) { continue }
                        $ruta = ConvertFrom-ValorOutlook $v
                        if ($ruta -match '\.pst$' -and $pst -notcontains $ruta) { $pst += $ruta; Write-Ok "$($P.Nombre): archivo de datos $ruta" }
                    }
                }
            }
            # Firmas
            $firmas = Join-Path $P.Ruta 'AppData\Roaming\Microsoft\Signatures'
            $numFirmas = 0
            if (Test-Path -LiteralPath $firmas) {
                $archivos = @(Get-ChildItem -LiteralPath $firmas -Recurse -File -ErrorAction SilentlyContinue)
                if ($archivos.Count -gt 0) {
                    $dest = Join-Path $dirBase "$($P.Nombre)\Firmas"
                    New-Item -ItemType Directory -Path $dest -Force | Out-Null
                    Copy-Item -Path (Join-Path $firmas '*') -Destination $dest -Recurse -Force
                    $numFirmas = @(Get-ChildItem -LiteralPath $firmas -Filter '*.htm' -File).Count
                    Write-Ok "$($P.Nombre): $numFirmas firmas"
                }
            }
            if ($cuentas.Count -gt 0 -or $pst.Count -gt 0 -or $numFirmas -gt 0) {
                [void]$acumulado.Add([ordered]@{ Usuario = $P.Nombre; Cuentas = $cuentas; ArchivosPst = $pst; Firmas = ($numFirmas -gt 0) })
            }
        }
        $usuarios = @($acumulado)
        if ($usuarios.Count -eq 0) { Write-Omitido 'Sin cuentas de Outlook clasico' }

        $ruta = Join-Path $Ctx.DirConfig 'outlook.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Usuarios = $usuarios }) -Cabecera @(
            "Cuentas y firmas de Outlook de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Cuentas: solo informativo. Al aplicar quedan como pendientes para anadirlas en Outlook'
            '  (Archivo > Agregar cuenta). Exchange, Microsoft 365, Outlook.com y Gmail solo piden el email.'
            'ArchivosPst: archivos de datos a abrir de nuevo (Archivo > Abrir y exportar > Abrir archivo de datos).'
            'Firmas: se copian las que falten desde config\outlook\<usuario>\Firmas.'
        )
        Write-Info "-> $ruta"
    }

    Revisar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'outlook.psd1')
        foreach ($u in @($cfg.Usuarios | Where-Object { $_ })) {
            foreach ($p in @($u.ArchivosPst | Where-Object { $_ })) {
                if (Test-EnUnidadSistema $p) { Write-Aviso "$($u.Usuario): el archivo de Outlook $p esta en C:. Copialo fuera antes de formatear." }
            }
        }
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'outlook.psd1')
        $usuarios = @($cfg.Usuarios | Where-Object { $_ })
        if ($usuarios.Count -eq 0) { Write-Omitido 'No hay cuentas de Outlook'; return }
        $perfiles = @{}
        foreach ($p in Get-PerfilesUsuario | Where-Object { -not $_.EsDefault }) { $perfiles[$p.Nombre] = $p }

        foreach ($u in $usuarios) {
            # Firmas: solo las que falten
            if ($u.Firmas) {
                $origen = Join-Path $Ctx.DirConfig "outlook\$($u.Usuario)\Firmas"
                if (-not $perfiles.ContainsKey($u.Usuario)) {
                    Add-Pendiente "Firmas de Outlook de '$($u.Usuario)': aun no tiene perfil. Inicia sesion con esa cuenta una vez y vuelve a ejecutar -Solo Outlook"
                } elseif (Test-Path -LiteralPath $origen) {
                    $destino = Join-Path $perfiles[$u.Usuario].Ruta 'AppData\Roaming\Microsoft\Signatures'
                    $faltan = @(Get-ChildItem -LiteralPath $origen -Recurse -File | Where-Object {
                        -not (Test-Path -LiteralPath (Join-Path $destino $_.FullName.Substring($origen.Length).TrimStart('\')))
                    })
                    if ($faltan.Count -eq 0) { Write-Omitido "$($u.Usuario): firmas de Outlook ya estan" }
                    else {
                        $null = Invoke-Cambio "$($u.Usuario): copiar firmas de Outlook ($($faltan.Count) archivos)" {
                            foreach ($a in $faltan) {
                                Copy-ArchivoSeguro -Origen $a.FullName -Destino (Join-Path $destino $a.FullName.Substring($origen.Length).TrimStart('\'))
                            }
                        }
                    }
                }
            }
            # Cuentas y .pst: manuales
            $cuentas = @($u.Cuentas | Where-Object { $_ })
            if ($cuentas.Count -gt 0) {
                $texto = ($cuentas | ForEach-Object {
                    $d = "$($_.Email) [$($_.Tipo)"
                    if ($_.Entrada) { $d += "; entrada $($_.Entrada)" }
                    if ($_.Salida) { $d += "; salida $($_.Salida)" }
                    $d + ']'
                }) -join ', '
                Add-Pendiente "Outlook de '$($u.Usuario)': abre Outlook con esa cuenta y anade (Archivo > Agregar cuenta): $texto"
            }
            foreach ($p in @($u.ArchivosPst | Where-Object { $_ })) {
                if (Test-Path -LiteralPath $p) { Add-Pendiente "Outlook de '$($u.Usuario)': abre el archivo de datos $p (Archivo > Abrir y exportar > Abrir archivo de datos)" }
                else { Write-Aviso "$($u.Usuario): el archivo de Outlook $p no existe en este equipo (restauralo desde tu copia)" }
            }
        }
    }
}
