# Modulo Office: instala Microsoft 365 / Office con la Office Deployment Tool (ODT) de Microsoft.
# - Extraer lee la instalacion Click-to-Run del registro (producto, idioma, canal, apps excluidas).
# - Aplicar descarga setup.exe de Microsoft, genera el configuration.xml a partir de office.psd1
#   e instala en silencio. Si los productos ya estan instalados no hace nada.
# - La activacion (iniciar sesion con la cuenta Microsoft) queda como pendiente manual.
# - Si este modulo esta activo, Paquetes NO instala 'Microsoft.Office' con winget (lo instalaria
#   con la configuracion por defecto: todas las apps).

@{
    Nombre        = 'Office'
    Descripcion   = 'Microsoft 365 / Office (Office Deployment Tool)'
    Orden         = 45
    DependeDe     = @()
    ArchivoConfig = 'office.psd1'

    Extraer = {
        param($Ctx)
        $rutaC2R = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
        # GUID de canal (en la URL del CDN) -> nombre de canal de la ODT
        $canales = @{
            '492350f6-3a01-4f97-b9c0-c7c6ddf67d60' = 'Current'
            '64256afe-f5d9-4f86-8936-8840a6a4f5be' = 'CurrentPreview'
            '5440fd1f-7ecb-4221-8110-145efaa6372f' = 'BetaChannel'
            '55336b82-a18d-4dd6-b5f6-9e5095c314a6' = 'MonthlyEnterprise'
            '7ffbc6bf-bc32-4f92-8982-f9dd17fd3114' = 'SemiAnnual'
            'b8f9b850-328d-4355-9145-c59439a0c4cf' = 'SemiAnnualPreview'
        }
        # Nombre de app en el registro (minusculas) -> ID de ExcludeApp en la ODT
        $apps = @{
            access = 'Access'; bing = 'Bing'; excel = 'Excel'; groove = 'Groove'; lync = 'Lync'
            onedrive = 'OneDrive'; onenote = 'OneNote'; outlook = 'Outlook'; olk = 'OutlookForWindows'
            powerpoint = 'PowerPoint'; publisher = 'Publisher'; teams = 'Teams'; word = 'Word'
        }
        $c = Get-ItemProperty -LiteralPath $rutaC2R -ErrorAction SilentlyContinue
        $activo = $true
        if (-not $c -or -not $c.ProductReleaseIds) {
            Write-Omitido 'Office (Click-to-Run) no esta instalado; se genera office.psd1 desactivado con valores por defecto'
            $activo = $false
            $productos = @([ordered]@{ Id = 'O365HomePremRetail'; Excluir = @('Groove', 'Lync') })
            $arq = '64'; $canal = 'Current'; $idiomas = @('es-mx'); $updates = $true
        } else {
            $arq = '64'
            if ($c.Platform -eq 'x86') { $arq = '32' }

            $canal = $null
            foreach ($url in @($c.UpdateChannel, $c.CDNBaseUrl)) {
                if (-not $url) { continue }
                $guid = ([string]$url).TrimEnd('/').Split('/')[-1].ToLower()
                if ($canales.ContainsKey($guid)) { $canal = $canales[$guid]; break }
            }
            if (-not $canal) { $canal = 'Current'; Write-Aviso "Canal de Office no reconocido ($($c.CDNBaseUrl)); se usa 'Current'" }

            $idiomas = @(([string]$c.ClientCulture).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            if ($idiomas.Count -eq 0) { $idiomas = @('MatchOS') }

            $updates = [string]$c.UpdatesEnabled -ne 'False'

            $productos = @()
            foreach ($id in ([string]$c.ProductReleaseIds).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) {
                $excl = @()
                $valor = $c.PSObject.Properties["$id.ExcludedApps"]
                if ($valor -and $valor.Value) {
                    foreach ($app in ([string]$valor.Value).Split(',') | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }) {
                        if ($apps.ContainsKey($app)) { $excl += $apps[$app] } else { $excl += $app }
                    }
                }
                $productos += [ordered]@{ Id = $id; Excluir = $excl }
                Write-Ok ("{0} {1} bits, canal {2}, idioma {3}, excluye: {4}" -f $id, $arq, $canal, ($idiomas -join ','), ($excl -join ', '))
            }
        }

        $datos = [ordered]@{
            Activo          = $activo
            Arquitectura    = $arq
            Canal           = $canal
            Idiomas         = $idiomas
            Productos       = $productos
            Actualizaciones = $updates
            Silencioso      = $true
        }
        $ruta = Join-Path $Ctx.DirConfig 'office.psd1'
        Write-Psd1 -Ruta $ruta -Datos $datos -Cabecera @(
            "Office extraido de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Activo          : $false = no instalar Office.'
            'Arquitectura    : 64 | 32'
            'Canal           : Current | MonthlyEnterprise | SemiAnnual | CurrentPreview | BetaChannel'
            'Idiomas         : es-mx, es-es, en-us... o MatchOS (idioma de Windows).'
            'Productos       : Id del producto (O365HomePremRetail = Microsoft 365 Familia/Personal,'
            '                  O365ProPlusRetail = Apps para empresa, ProPlus2024Retail...).'
            '                  Excluir: Access, Excel, Groove, Lync, OneDrive, OneNote, Outlook,'
            '                  OutlookForWindows, PowerPoint, Publisher, Teams, Word, Bing.'
            'Actualizaciones : $true = Office se actualiza solo.'
            'Silencioso      : $true = sin ventanas; $false = muestra el progreso de instalacion.'
            'La activacion se hace a mano: abre Word e inicia sesion con la cuenta Microsoft.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $rutaC2R = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
        $urlSetup = 'https://officecdn.microsoft.com/pr/wsus/setup.exe'
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'office.psd1')
        if (-not $cfg.Activo) { Write-Omitido 'Office desactivado en office.psd1 (Activo = $false)'; return }

        $productos = @($cfg.Productos | Where-Object { $_ -and $_.Id })
        if ($productos.Count -eq 0) { Write-Fallo 'office.psd1 no tiene Productos'; return }

        # ---- Que falta por instalar ----
        $instalados = @()
        $c = Get-ItemProperty -LiteralPath $rutaC2R -ErrorAction SilentlyContinue
        if ($c -and $c.ProductReleaseIds) { $instalados = @(([string]$c.ProductReleaseIds).Split(',') | ForEach-Object { $_.Trim().ToLower() }) }
        $faltan = @($productos | Where-Object { $instalados -notcontains ([string]$_.Id).ToLower() })
        foreach ($p in $productos) {
            if ($faltan -notcontains $p) { Write-Omitido "$($p.Id) ya instalado (no se modifica)" }
        }
        if ($faltan.Count -eq 0) { return }

        # ---- configuration.xml ----
        $arq = [string]$cfg.Arquitectura
        if ($arq -notin '32', '64') { $arq = '64' }
        $canal = [string]$cfg.Canal
        if (-not $canal) { $canal = 'Current' }
        $idiomas = @($cfg.Idiomas | Where-Object { $_ })
        if ($idiomas.Count -eq 0) { $idiomas = @('MatchOS') }
        $nivel = 'None'
        if ($cfg.Silencioso -eq $false) { $nivel = 'Full' }
        $upd = 'TRUE'
        if ($cfg.Actualizaciones -eq $false) { $upd = 'FALSE' }

        $esc = { param($t) [System.Security.SecurityElement]::Escape([string]$t) }
        $xml = @("<Configuration>", "  <Add OfficeClientEdition=`"$arq`" Channel=`"$(& $esc $canal)`">")
        foreach ($p in $faltan) {
            $xml += "    <Product ID=`"$(& $esc $p.Id)`">"
            foreach ($l in $idiomas) { $xml += "      <Language ID=`"$(& $esc $l)`" />" }
            foreach ($e in @($p.Excluir | Where-Object { $_ })) { $xml += "      <ExcludeApp ID=`"$(& $esc $e)`" />" }
            $xml += '    </Product>'
        }
        $xml += '  </Add>'
        $xml += "  <Updates Enabled=`"$upd`" />"
        $xml += "  <Display Level=`"$nivel`" AcceptEULA=`"TRUE`" />"
        $xml += '</Configuration>'

        foreach ($p in $faltan) {
            Write-Info ("{0}: {1} bits, canal {2}, idioma {3}, excluye: {4}" -f $p.Id, $arq, $canal, ($idiomas -join ','), (@($p.Excluir) -join ', '))
        }

        $dir = Join-Path $env:TEMP 'OHP2_Office'
        $setup = Join-Path $dir 'setup.exe'
        $rutaXml = Join-Path $dir 'configuration.xml'

        $ok = Invoke-Cambio "Descargar Office Deployment Tool ($urlSetup)" {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $urlSetup -OutFile $setup -UseBasicParsing -ErrorAction Stop
            $firma = Get-AuthenticodeSignature -LiteralPath $setup
            if ($firma.Status -ne 'Valid' -or $firma.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
                Remove-Item -LiteralPath $setup -Force -ErrorAction SilentlyContinue
                throw "setup.exe no tiene una firma valida de Microsoft ($($firma.Status))"
            }
            [IO.File]::WriteAllLines($rutaXml, [string[]]$xml, (New-Object System.Text.UTF8Encoding $false))
        }
        if (-not $ok) { return }

        if (-not (Test-Simulacion)) { Write-Info 'Instalando Office en segundo plano: suele tardar entre 10 y 30 minutos (descarga ~3 GB)...' }
        $ok = Invoke-Cambio "Instalar Office ($(($faltan | ForEach-Object { $_.Id }) -join ', '))" {
            $proc = Start-Process -FilePath $setup -ArgumentList '/configure', "`"$rutaXml`"" -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            if ($proc.ExitCode -ne 0) {
                throw ('setup.exe termino con codigo {0}. Log en {1}' -f $proc.ExitCode, $env:TEMP)
            }
            $c2 = Get-ItemProperty -LiteralPath $rutaC2R -ErrorAction SilentlyContinue
            $ya = @()
            if ($c2 -and $c2.ProductReleaseIds) { $ya = @(([string]$c2.ProductReleaseIds).Split(',') | ForEach-Object { $_.Trim().ToLower() }) }
            $sinInstalar = @($faltan | Where-Object { $ya -notcontains ([string]$_.Id).ToLower() } | ForEach-Object { $_.Id })
            if ($sinInstalar.Count -gt 0) { throw "setup.exe termino pero no aparece instalado: $($sinInstalar -join ', ')" }
        }
        if ($ok) {
            Add-Pendiente 'Office: abre Word e inicia sesion con la cuenta Microsoft para activarlo'
            if (-not (Test-Simulacion)) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
