# Modulo UnidadesRed: unidades de red mapeadas persistentes (Z: -> \\servidor\recurso).
# - Extraer: HKCU\Network del usuario que ejecuta.
# - Aplicar: escribe HKCU\Network del usuario que ejecuta; Windows las conecta al iniciar sesion.
#   (Se usa el registro y no "net use" porque, al ejecutar como Administrador, net use crea la
#   unidad solo para la sesion elevada y no se ve en el Explorador.)
# Las contrasenas de los servidores no se guardan: Windows las pedira la primera vez.

@{
    Nombre        = 'UnidadesRed'
    Descripcion   = 'Unidades de red mapeadas (Z: -> \\servidor\recurso)'
    Orden         = 32
    DependeDe     = @()
    ArchivoConfig = 'unidadesred.psd1'

    Extraer = {
        param($Ctx)
        $lista = @()
        foreach ($k in Get-ChildItem -LiteralPath 'HKCU:\Network' -ErrorAction SilentlyContinue | Sort-Object PSChildName) {
            $p = Get-ItemProperty -LiteralPath $k.PSPath
            if (-not $p.RemotePath) { continue }
            $lista += [ordered]@{ Letra = $k.PSChildName.ToUpper(); Ruta = [string]$p.RemotePath; Usuario = [string]$p.UserName }
            Write-Ok ("{0}: -> {1}" -f $k.PSChildName.ToUpper(), $p.RemotePath)
        }
        if ($lista.Count -eq 0) { Write-Omitido "No hay unidades de red mapeadas ($env:USERNAME)" }
        $ruta = Join-Path $Ctx.DirConfig 'unidadesred.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Unidades = $lista }) -Cabecera @(
            "Unidades de red de $env:USERNAME en $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Letra  : letra de unidad (sin los dos puntos).'
            'Ruta   : recurso de red \\servidor\recurso.'
            "Usuario: cuenta con la que conectar ('' = la del usuario de Windows). La contrasena la pedira Windows."
            'Se aplican al usuario que ejecuta WinMudanza y se conectan al iniciar sesion.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'unidadesred.psd1')
        $lista = @($cfg.Unidades | Where-Object { $_ -and $_.Letra -and $_.Ruta })
        if ($lista.Count -eq 0) { Write-Omitido 'No hay unidades de red que crear'; return }
        foreach ($u in $lista) {
            $letra = ([string]$u.Letra).TrimEnd(':').ToUpper()
            $clave = "HKCU:\Network\$letra"
            $actual = (Get-ItemProperty -LiteralPath $clave -ErrorAction SilentlyContinue).RemotePath
            if ($actual -eq $u.Ruta) { Write-Omitido "${letra}: -> $($u.Ruta) ya existe"; continue }
            if ($actual) { Write-Aviso "${letra}: ya apunta a $actual; no se cambia (borra la unidad si quieres reemplazarla)"; continue }
            if (Test-Path -LiteralPath "${letra}:\" -ErrorAction SilentlyContinue) { Write-Aviso "${letra}: ya esta en uso en este equipo; se omite $($u.Ruta)"; continue }
            $ok = Set-RegValor -Ruta $clave -Nombre 'RemotePath' -Valor $u.Ruta -Tipo String
            $ok = (Set-RegValor -Ruta $clave -Nombre 'UserName' -Valor ([string]$u.Usuario) -Tipo String) -and $ok
            $ok = (Set-RegValor -Ruta $clave -Nombre 'ProviderName' -Valor 'Microsoft Windows Network' -Tipo String) -and $ok
            $ok = (Set-RegValor -Ruta $clave -Nombre 'ProviderType' -Valor 0x20000 -Tipo DWord) -and $ok
            $ok = (Set-RegValor -Ruta $clave -Nombre 'ConnectionType' -Valor 1 -Tipo DWord) -and $ok
            $ok = (Set-RegValor -Ruta $clave -Nombre 'DeferFlags' -Valor 4 -Tipo DWord) -and $ok
            if ($ok -and -not (Test-Simulacion)) { Write-Ok "${letra}: -> $($u.Ruta) (se conectara al iniciar sesion)" }
        }
    }
}
