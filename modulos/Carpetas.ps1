# Modulo Carpetas: ubicacion de las carpetas personales de cada usuario (Descargas, Documentos,
# Musica...) cuando no estan en su sitio por defecto (p. ej. Descargas en D:\Downloads).
# - Extraer: lee "User Shell Folders" de cada perfil. Solo guarda las que apuntan fuera del perfil
#   y no a OneDrive (OneDrive las vuelve a mover el solo al iniciar sesion).
# - Aplicar: apunta las carpetas del usuario a esas rutas (crea la carpeta si falta). No mueve
#   archivos. El usuario lo vera al volver a iniciar sesion. Si el usuario aun no tiene perfil
#   (cuenta Microsoft sin iniciar sesion) queda como pendiente.

@{
    Nombre        = 'Carpetas'
    Descripcion   = 'Ubicacion de Descargas, Documentos, Musica... de cada usuario'
    Orden         = 22
    DependeDe     = @('Usuarios')
    ArchivoConfig = 'carpetas.psd1'

    Extraer = {
        param($Ctx)
        $usuarios = [ordered]@{}
        foreach ($p in Get-PerfilesUsuario | Where-Object { -not $_.EsDefault }) {
            $montada = $null
            try {
                $hkcu = "Registry::HKEY_USERS\$($p.Sid)"
                if (-not (Test-Path -LiteralPath $hkcu)) {
                    $montada = 'WMUD_CARP'
                    $hkcu = Mount-Colmena $montada (Join-Path $p.Ruta 'NTUSER.DAT')
                    if (-not $hkcu) { $montada = $null; Write-Aviso "$($p.Nombre): no se pudo leer su registro (en uso o sin permisos)"; continue }
                }
                $usf = Get-Item -LiteralPath "$hkcu\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -ErrorAction SilentlyContinue
                if (-not $usf) { continue }
                $suyas = [ordered]@{}
                foreach ($c in (Get-CarpetasConocidas).GetEnumerator()) {
                    $v = $usf.GetValue($c.Value[0], $null, 'DoNotExpandEnvironmentNames')
                    if (-not $v) { continue }
                    $real = $v -replace '(?i)%USERPROFILE%', $p.Ruta
                    $real = [Environment]::ExpandEnvironmentVariables($real)
                    if ($real.StartsWith($p.Ruta, [StringComparison]::OrdinalIgnoreCase)) { continue }   # en el perfil: por defecto u OneDrive
                    if ($real -match '\\OneDrive( - [^\\]+)?(\\|$)') { continue }
                    $suyas[$c.Key] = $v
                    Write-Ok "$($p.Nombre): $($c.Key) -> $v"
                }
                if ($suyas.Count -gt 0) { $usuarios[$p.Nombre] = $suyas }
            } finally {
                if ($montada) { Dismount-Colmena $montada }
            }
        }
        if ($usuarios.Count -eq 0) { Write-Omitido 'Todas las carpetas personales estan en su sitio por defecto (o en OneDrive)' }
        $ruta = Join-Path $Ctx.DirConfig 'carpetas.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Usuarios = $usuarios }) -Cabecera @(
            "Carpetas personales fuera de su sitio por defecto en $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Usuarios = @{ <usuario> = @{ <Carpeta> = <ruta> } }'
            'Carpetas: Escritorio, Documentos, Descargas, Musica, Imagenes, Videos, Favoritos.'
            'Al aplicar se apuntan ahi (se crea la carpeta si falta); no se mueve ningun archivo.'
            'Borra o comenta (#) las que no quieras.'
        )
        Write-Info "-> $ruta"
    }

    Revisar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'carpetas.psd1')
        foreach ($u in @($cfg.Usuarios.Keys)) {
            foreach ($c in @($cfg.Usuarios[$u].Keys)) {
                $r = [string]$cfg.Usuarios[$u][$c]
                if (Test-EnUnidadSistema $r) { Write-Aviso "${u}: $c esta en $r (en C:): se borrara al formatear" }
            }
        }
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'carpetas.psd1')
        $config = $cfg.Usuarios
        if (-not $config -or $config.Count -eq 0) { Write-Omitido 'No hay carpetas que reubicar'; return }
        $conocidas = Get-CarpetasConocidas
        $perfiles = @(Get-PerfilesUsuario | Where-Object { -not $_.EsDefault } | ForEach-Object { $_.Nombre })
        foreach ($u in @($config.Keys)) {
            if ($perfiles -notcontains $u) {
                Add-Pendiente "Carpetas de '$u': aun no tiene perfil. Inicia sesion con esa cuenta una vez y vuelve a ejecutar -Solo Carpetas"
            }
        }
        Invoke-EnPerfiles {
            param($P)
            if ($P.EsDefault -or -not $config.Contains($P.Nombre)) { return }
            $suyas = $config[$P.Nombre]
            $clave = "$($P.HKCU)\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
            foreach ($c in @($suyas.Keys)) {
                if (-not $conocidas.Contains($c)) { Write-Aviso "$($P.Nombre): carpeta '$c' desconocida (validas: $($conocidas.Keys -join ', '))"; continue }
                $destino = [string]$suyas[$c]
                $real = [Environment]::ExpandEnvironmentVariables(($destino -replace '(?i)%USERPROFILE%', $P.Ruta))
                $unidad = [IO.Path]::GetPathRoot($real)
                if ($unidad -and -not (Test-Path -LiteralPath $unidad)) { Write-Fallo "$($P.Nombre): $c -> $destino (la unidad $unidad no existe)"; continue }
                if (-not (Test-Path -LiteralPath $real)) {
                    $null = Invoke-Cambio "$($P.Nombre): crear carpeta $real" { New-Item -ItemType Directory -Path $real -Force -ErrorAction Stop | Out-Null }
                }
                $igual = $true
                foreach ($n in $conocidas[$c]) { if (-not (Test-RegValorIgual $clave $n $destino 'ExpandString')) { $igual = $false } }
                if ($igual) { Write-Omitido "$($P.Nombre): $c ya apunta a $destino"; continue }
                $ok = $true
                foreach ($n in $conocidas[$c]) { if (-not (Set-RegValor -Ruta $clave -Nombre $n -Valor $destino -Tipo ExpandString)) { $ok = $false } }
                if ($ok -and -not (Test-Simulacion)) { Write-Ok "$($P.Nombre): $c -> $destino" }
            }
        }
        Write-Info 'Cada usuario vera sus carpetas en la nueva ubicacion al volver a iniciar sesion.'
    }
}
