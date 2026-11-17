# Modulo Navegadores: favoritos de cada usuario en Edge, Chrome, Brave, Vivaldi, Opera y Firefox.
# - Extraer: de cada perfil de Windows y cada perfil del navegador, copia "Bookmarks" a
#   config\navegadores\<usuario>\<navegador>\<perfil>\ y crea al lado favoritos.html (para importar
#   a mano). De Firefox guarda la ultima copia de bookmarkbackups (.jsonlz4).
# - Aplicar: si el navegador esta instalado y ese perfil no tiene favoritos, los restaura.
#   Si ya tiene (p. ej. por la sincronizacion de la cuenta) no los toca: deja como pendiente
#   importar favoritos.html. Firefox siempre queda como pendiente (se restaura desde el propio Firefox).
#   Los navegadores deben estar cerrados.

@{
    Nombre        = 'Navegadores'
    Descripcion   = 'Favoritos de Edge, Chrome, Brave, Vivaldi, Opera y Firefox'
    Orden         = 52
    DependeDe     = @('Usuarios', 'Paquetes')
    ArchivoConfig = 'navegadores.psd1'

    Extraer = {
        param($Ctx)
        $dirBase = Join-Path $Ctx.DirConfig 'navegadores'
        if (Test-Path -LiteralPath $dirBase) { Remove-Item -LiteralPath $dirBase -Recurse -Force }
        $navs = Get-NavegadoresChromium
        $lista = @()
        foreach ($p in Get-PerfilesUsuario | Where-Object { -not $_.EsDefault }) {
            # ---- Chromium ----
            foreach ($n in $navs.GetEnumerator()) {
                $datos = Join-Path $p.Ruta $n.Value.Datos
                if (-not (Test-Path -LiteralPath $datos)) { continue }
                $perfilesNav = @()
                if ($n.Value.Raiz) { $perfilesNav = @(Get-Item -LiteralPath $datos) }
                else { $perfilesNav = @(Get-ChildItem -LiteralPath $datos -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile \d+$' }) }
                foreach ($pn in $perfilesNav) {
                    $archivo = Join-Path $pn.FullName 'Bookmarks'
                    if (-not (Test-Path -LiteralPath $archivo)) { continue }
                    $json = Read-Favoritos $archivo
                    if (-not $json) { Write-Aviso "$($p.Nombre) / $($n.Key): no se pudieron leer los favoritos ($archivo)"; continue }
                    $num = Get-NumFavoritos $json
                    if ($num -eq 0) { Write-Omitido "$($p.Nombre) / $($n.Key) / $($pn.Name): sin favoritos"; continue }
                    $nombrePerfil = $pn.Name
                    if ($n.Value.Raiz) { $nombrePerfil = '.' }
                    $rel = Join-Path (Join-Path $p.Nombre $n.Key) $(if ($n.Value.Raiz) { 'Perfil' } else { $pn.Name })
                    $dest = Join-Path $dirBase $rel
                    New-Item -ItemType Directory -Path $dest -Force | Out-Null
                    Copy-Item -LiteralPath $archivo -Destination (Join-Path $dest 'Bookmarks') -Force
                    [IO.File]::WriteAllText((Join-Path $dest 'favoritos.html'), (ConvertTo-FavoritosHtml $json), (New-Object System.Text.UTF8Encoding $false))
                    $lista += [ordered]@{ Usuario = $p.Nombre; Navegador = $n.Key; Perfil = $nombrePerfil; Carpeta = $rel; Favoritos = $num }
                    Write-Ok "$($p.Nombre) / $($n.Key) / $($pn.Name): $num favoritos"
                }
            }
            # ---- Firefox ----
            $ff = Join-Path $p.Ruta 'AppData\Roaming\Mozilla\Firefox\Profiles'
            foreach ($pf in Get-ChildItem -LiteralPath $ff -Directory -ErrorAction SilentlyContinue) {
                $copia = Get-ChildItem -LiteralPath (Join-Path $pf.FullName 'bookmarkbackups') -Filter '*.jsonlz4' -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if (-not $copia) { continue }
                $rel = Join-Path (Join-Path $p.Nombre 'Firefox') $pf.Name
                $dest = Join-Path $dirBase $rel
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
                Copy-Item -LiteralPath $copia.FullName -Destination (Join-Path $dest $copia.Name) -Force
                $lista += [ordered]@{ Usuario = $p.Nombre; Navegador = 'Firefox'; Perfil = $pf.Name; Carpeta = $rel; Archivo = $copia.Name }
                Write-Ok "$($p.Nombre) / Firefox / $($pf.Name): copia de favoritos del $($copia.LastWriteTime.ToString('yyyy-MM-dd'))"
            }
        }
        if ($lista.Count -eq 0) { Write-Omitido 'No hay favoritos en ningun navegador' }
        $ruta = Join-Path $Ctx.DirConfig 'navegadores.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Favoritos = $lista }) -Cabecera @(
            "Favoritos de navegadores de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Cada entrada esta en config\navegadores\<Carpeta> (Bookmarks y favoritos.html para importar a mano).'
            'Al aplicar se restauran solo si ese perfil del navegador no tiene favoritos; si ya tiene,'
            'queda como pendiente importar favoritos.html. Firefox se restaura desde el propio Firefox.'
            'Para no restaurar una entrada, borra o comenta (#) su bloque.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'navegadores.psd1')
        $lista = @($cfg.Favoritos | Where-Object { $_ })
        if ($lista.Count -eq 0) { Write-Omitido 'No hay favoritos que restaurar'; return }
        $dirBase = Join-Path $Ctx.DirConfig 'navegadores'
        $navs = Get-NavegadoresChromium
        $perfiles = @{}
        foreach ($p in Get-PerfilesUsuario | Where-Object { -not $_.EsDefault }) { $perfiles[$p.Nombre] = $p }

        foreach ($f in $lista) {
            $etiqueta = "$($f.Usuario) / $($f.Navegador) / $($f.Perfil)"
            $origen = Join-Path $dirBase $f.Carpeta
            if (-not $perfiles.ContainsKey($f.Usuario)) {
                Add-Pendiente "Favoritos ${etiqueta}: '$($f.Usuario)' aun no tiene perfil. Inicia sesion con esa cuenta una vez y vuelve a ejecutar -Solo Navegadores"
                continue
            }
            $p = $perfiles[$f.Usuario]

            if ($f.Navegador -eq 'Firefox') {
                Add-Pendiente "Favoritos ${etiqueta}: en Firefox, Ctrl+Mayus+O > Importar y respaldar > Restaurar > Elegir archivo: $(Join-Path $origen $f.Archivo)"
                continue
            }
            $nav = $navs[$f.Navegador]
            if (-not $nav) { Write-Aviso "${etiqueta}: navegador desconocido"; continue }
            if (-not (Test-NavegadorInstalado $nav $p.Ruta)) {
                Add-Pendiente "Favoritos ${etiqueta}: $($f.Navegador) no esta instalado. Instalalo y vuelve a ejecutar -Solo Navegadores (o importa $(Join-Path $origen 'favoritos.html'))"
                continue
            }
            if (Get-Process -Name $nav.Proceso -ErrorAction SilentlyContinue) {
                Write-Aviso "${etiqueta}: $($f.Navegador) esta abierto; cierralo y vuelve a ejecutar -Solo Navegadores"
                continue
            }
            $carpeta = Join-Path $p.Ruta $nav.Datos
            if (-not $nav.Raiz) { $carpeta = Join-Path $carpeta $f.Perfil }
            $destino = Join-Path $carpeta 'Bookmarks'
            if (Test-Path -LiteralPath $destino) {
                $actual = Read-Favoritos $destino
                $num = 0
                if ($actual) { $num = Get-NumFavoritos $actual }
                if ($num -gt 0) {
                    Write-Omitido "$etiqueta ya tiene $num favoritos (no se tocan)"
                    # Con menos de los guardados (p. ej. solo los de la sincronizacion) puede que falten
                    if ($num -lt [int]$f.Favoritos) {
                        Add-Pendiente "Favoritos ${etiqueta}: tiene $num de $($f.Favoritos). Si faltan, importa $(Join-Path $origen 'favoritos.html') (Configuracion > Importar)"
                    }
                    continue
                }
            }
            $null = Invoke-Cambio "Favoritos ${etiqueta}: $($f.Favoritos) restaurados" {
                New-Item -ItemType Directory -Path $carpeta -Force -ErrorAction Stop | Out-Null
                Copy-Item -LiteralPath (Join-Path $origen 'Bookmarks') -Destination $destino -Force -ErrorAction Stop
                # Si no, el navegador podria recuperar la copia vieja
                Remove-Item -LiteralPath "$destino.bak" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
