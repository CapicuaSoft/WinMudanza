# Modulo Paquetes: programas y paquetes de desarrollo.
#   Winget      -> solo fuente 'winget'
#   Npm         -> paquetes globales (npm -g)
#   Pip         -> paquetes de Python de primer nivel (no dependencias)
#   DotnetTool  -> herramientas globales de .NET
#   PowerShell  -> modulos instalados con Install-Module
# Al aplicar, winget va primero (instala Node, Python, .NET...) y despues el resto.

@{
    Nombre        = 'Paquetes'
    Descripcion   = 'winget, npm, pip, dotnet tool, modulos PowerShell'
    Orden         = 40
    DependeDe     = @()
    ArchivoConfig = 'paquetes.psd1'

    Extraer = {
        param($Ctx)

        # ---------- Winget ----------
        $winget = @()
        if (Test-Comando 'winget') {
            $tmp = Join-Path $env:TEMP "wmud_winget_$PID.json"
            $salida = & winget export -o $tmp --source winget --accept-source-agreements --disable-interactivity 2>&1
            if (Test-Path -LiteralPath $tmp) {
                $json = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8 | ConvertFrom-Json
                $winget = @($json.Sources | ForEach-Object { $_.Packages } | ForEach-Object { $_.PackageIdentifier } | Sort-Object -Unique)
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                Write-Ok "winget: $($winget.Count) paquetes"
            } else {
                Write-Fallo "winget export no genero el archivo: $($salida | Select-Object -Last 3)"
            }
            # Lo que winget no reconoce: solo informativo
            $noDisponibles = @($salida | ForEach-Object { [string]$_ } | Where-Object { $_ -match ':\s*\S' -and $_ -notmatch '^\s*[-\\|/]' })
            if ($noDisponibles.Count -gt 0) {
                $rutaTxt = Join-Path $Ctx.DirConfig 'paquetes_no_reinstalables.txt'
                $cab = @(
                    "Mensajes de 'winget export' en $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
                    "- 'no esta disponible desde ningun origen': winget NO lo reinstalara; instalalo a mano si lo necesitas."
                    "- 'requiere un contrato de licencia': SI esta en paquetes.psd1; winget lo instala aceptando la licencia."
                    ''
                )
                [IO.File]::WriteAllLines($rutaTxt, [string[]]($cab + $noDisponibles), (New-Object System.Text.UTF8Encoding $true))
                Write-Aviso "$($noDisponibles.Count) mensajes de winget (programas que no reinstalara, licencias...) -> $rutaTxt"
            }
        } else {
            Write-Aviso 'winget no esta disponible'
        }

        # ---------- npm ----------
        $npm = @()
        if (Test-Comando 'npm') {
            try {
                $j = (& npm ls -g --depth=0 --json 2>$null) -join "`n" | ConvertFrom-Json
                if ($j.dependencies) {
                    $npm = @($j.dependencies.PSObject.Properties.Name | Where-Object { $_ -notin @('npm', 'corepack') } | Sort-Object)
                }
                Write-Ok "npm: $($npm.Count) paquetes globales"
            } catch { Write-Aviso "npm: no se pudo leer la lista ($($_.Exception.Message))" }
        } else { Write-Omitido 'npm no instalado' }

        # ---------- pip ----------
        $pip = @()
        $py = Get-PythonConPip
        if ($py) {
            try {
                $j = (& $py -m pip list --not-required --format=json 2>$null) -join "`n" | ConvertFrom-Json
                $pip = @($j | ForEach-Object { $_.name } | Where-Object { $_ -notin @('pip', 'setuptools', 'wheel') } | Sort-Object)
                Write-Ok "pip: $($pip.Count) paquetes"
            } catch { Write-Aviso "pip: no se pudo leer la lista ($($_.Exception.Message))" }
        } elseif ((Test-Comando 'python') -or (Test-Comando 'py')) {
            Write-Aviso 'Python esta instalado pero ninguno tiene pip: no se pueden listar sus paquetes'
        } else { Write-Omitido 'Python no instalado' }

        # ---------- dotnet tool ----------
        $dotnet = @()
        if (Test-Comando 'dotnet') {
            $lineas = @(& dotnet tool list -g 2>$null)
            $dotnet = @($lineas | Select-Object -Skip 2 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ } | Sort-Object)
            Write-Ok "dotnet tool: $($dotnet.Count) herramientas"
        } else { Write-Omitido '.NET SDK no instalado' }

        # ---------- Modulos PowerShell ----------
        $psmod = @()
        try {
            $psmod = @(Get-InstalledModule -ErrorAction Stop | ForEach-Object { $_.Name } |
                Where-Object { $_ -notin @('PowerShellGet', 'PackageManagement') } | Sort-Object -Unique)
            Write-Ok "PowerShell: $($psmod.Count) modulos"
        } catch { Write-Omitido 'Sin modulos instalados con Install-Module' }

        $datos = [ordered]@{
            Winget     = [ordered]@{ Activo = $true; Paquetes = $winget }
            Npm        = [ordered]@{ Activo = $true; Paquetes = $npm }
            Pip        = [ordered]@{ Activo = $true; Paquetes = $pip }
            DotnetTool = [ordered]@{ Activo = $true; Paquetes = $dotnet }
            PowerShell = [ordered]@{ Activo = $true; Paquetes = $psmod }
        }
        $ruta = Join-Path $Ctx.DirConfig 'paquetes.psd1'
        Write-Psd1 -Ruta $ruta -Datos $datos -Cabecera @(
            "Paquetes extraidos de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Activo = $false desactiva un gestor completo.'
            'Para no instalar un paquete, comenta su linea con # o borrala.'
            'Se instala la ultima version disponible. Los que ya esten instalados se saltan.'
            'Orden al aplicar: Winget -> Npm -> Pip -> DotnetTool -> PowerShell'
            '(winget instala Node, Python o .NET si estan en su lista, y luego se usan).'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'paquetes.psd1')

        function Get-Lista($Seccion) {
            if (-not $Seccion -or -not $Seccion.Activo) { return $null }
            return @($Seccion.Paquetes | Where-Object { $_ })
        }

        # ---------- Winget ----------
        $lista = Get-Lista $cfg.Winget
        if ($null -eq $lista) { Write-Omitido 'Winget desactivado' }
        elseif (-not (Test-Comando 'winget')) {
            Write-Fallo 'winget no esta disponible. Actualiza "Instalador de aplicacion" desde Microsoft Store e inicia sesion una vez.'
        } else {
            $instalados = @{}
            $tmp = Join-Path $env:TEMP "wmud_winget_inst_$PID.json"
            $null = & winget export -o $tmp --source winget --accept-source-agreements --disable-interactivity 2>&1
            if (Test-Path -LiteralPath $tmp) {
                $json = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($id in @($json.Sources | ForEach-Object { $_.Packages } | ForEach-Object { $_.PackageIdentifier })) { $instalados[$id.ToLower()] = $true }
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            }
            # Si el modulo Office se ejecuta y esta activo, Office lo instala el (con su configuracion)
            $officeAparte = $false
            $rutaOffice = Join-Path $Ctx.DirConfig 'office.psd1'
            if (@($Ctx.Seleccion) -contains 'Office' -and (Test-Path -LiteralPath $rutaOffice)) {
                try { $officeAparte = [bool](Read-ConfigPsd1 $rutaOffice).Activo } catch { }
            }
            $n = 0
            foreach ($id in $lista) {
                $n++
                $etiqueta = 'winget [{0,2}/{1}] {2}' -f $n, $lista.Count, $id
                if ($officeAparte -and $id -like 'Microsoft.Office') { Write-Omitido "$etiqueta (lo instala el modulo Office)"; continue }
                if ($instalados.ContainsKey($id.ToLower())) { Write-Omitido "$etiqueta (ya instalado)"; continue }
                $null = Invoke-Cambio $etiqueta {
                    $out = & winget install --id $id -e --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1
                    $codigo = $LASTEXITCODE
                    # 0x8A150061 ya instalado, 0x8A15002B sin actualizacion aplicable
                    if ($codigo -eq 0 -or $codigo -eq -1978335135 -or $codigo -eq -1978335189) { return }
                    if ($codigo -eq 3010 -or $codigo -eq 1641) { Write-Aviso "${id}: requiere reiniciar"; return }
                    throw ('codigo 0x{0:X8}: {1}' -f $codigo, (($out | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() } | Select-Object -Last 2) -join ' '))
                }
            }
            Update-RutaEntorno
        }

        # ---------- npm ----------
        $lista = Get-Lista $cfg.Npm
        if ($null -eq $lista -or $lista.Count -eq 0) { Write-Omitido 'npm: nada que instalar' }
        elseif (-not (Test-Comando 'npm')) { Write-Fallo 'npm no esta disponible (instala Node.js, p. ej. OpenJS.NodeJS.LTS en winget)' }
        else {
            $inst = @()
            try { $j = (& npm ls -g --depth=0 --json 2>$null) -join "`n" | ConvertFrom-Json; if ($j.dependencies) { $inst = @($j.dependencies.PSObject.Properties.Name) } } catch { }
            foreach ($p in $lista) {
                if ($inst -contains $p) { Write-Omitido "npm $p (ya instalado)"; continue }
                $null = Invoke-Cambio "npm $p" {
                    $out = & npm install -g $p 2>&1
                    if ($LASTEXITCODE -ne 0) { throw (($out | Select-Object -Last 2) -join ' ') }
                }
            }
        }

        # ---------- pip ----------
        $lista = Get-Lista $cfg.Pip
        if ($null -eq $lista -or $lista.Count -eq 0) { Write-Omitido 'pip: nada que instalar' }
        else {
            $py = Get-PythonConPip
            if (-not $py) { Write-Fallo 'No hay un Python con pip disponible (instala Python con winget, p. ej. Python.Python.3.14)' }
            else {
                $inst = @()
                try { $inst = @((& $py -m pip list --format=json 2>$null) -join "`n" | ConvertFrom-Json | ForEach-Object { $_.name.ToLower() }) } catch { }
                foreach ($p in $lista) {
                    if ($inst -contains $p.ToLower()) { Write-Omitido "pip $p (ya instalado)"; continue }
                    $null = Invoke-Cambio "pip $p" {
                        $out = & $py -m pip install --disable-pip-version-check $p 2>&1
                        if ($LASTEXITCODE -ne 0) { throw (($out | ForEach-Object { [string]$_ } | Select-Object -Last 2) -join ' ') }
                    }
                }
            }
        }

        # ---------- dotnet tool ----------
        $lista = Get-Lista $cfg.DotnetTool
        if ($null -eq $lista -or $lista.Count -eq 0) { Write-Omitido 'dotnet tool: nada que instalar' }
        elseif (-not (Test-Comando 'dotnet')) { Write-Fallo 'dotnet no esta disponible (instala el SDK de .NET en winget)' }
        else {
            $inst = @(& dotnet tool list -g 2>$null | Select-Object -Skip 2 | ForEach-Object { ($_ -split '\s+')[0].ToLower() })
            foreach ($p in $lista) {
                if ($inst -contains $p.ToLower()) { Write-Omitido "dotnet $p (ya instalado)"; continue }
                $null = Invoke-Cambio "dotnet tool $p" {
                    $out = & dotnet tool install -g $p 2>&1
                    if ($LASTEXITCODE -ne 0) { throw (($out | ForEach-Object { [string]$_ } | Select-Object -Last 2) -join ' ') }
                }
            }
        }

        # ---------- Modulos PowerShell ----------
        $lista = Get-Lista $cfg.PowerShell
        if ($null -eq $lista -or $lista.Count -eq 0) { Write-Omitido 'PowerShell: nada que instalar' }
        else {
            $preparado = Invoke-Cambio 'Preparar PowerShell Gallery (TLS 1.2 + NuGet)' {
                [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
                if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -ErrorAction Stop | Out-Null
                }
            } -Silencioso
            if ($preparado) {
                foreach ($p in $lista) {
                    if (Get-Module -ListAvailable -Name $p) { Write-Omitido "PowerShell $p (ya instalado)"; continue }
                    $null = Invoke-Cambio "PowerShell $p" {
                        Install-Module -Name $p -Scope AllUsers -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
                    }
                }
            }
        }
    }
}
