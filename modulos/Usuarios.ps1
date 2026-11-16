# Modulo Usuarios: usuarios locales y sus grupos.
# - Las contrasenas NO se pueden extraer de Windows: se escriben a mano en config\usuarios.psd1.
# - Las cuentas Microsoft no se pueden crear por script: quedan como pendientes. Si ya existen
#   en el equipo destino (alguien inicio sesion con ellas) se les asignan sus grupos.
# - Los grupos se guardan con su SID cuando son de Windows, para funcionar en cualquier idioma.

@{
    Nombre        = 'Usuarios'
    Descripcion   = 'Usuarios locales y grupos'
    Orden         = 20
    DependeDe     = @()
    ArchivoConfig = 'usuarios.psd1'

    Extraer = {
        param($Ctx)
        # RID de cuentas integradas: 500 Administrador, 501 Invitado, 503 DefaultAccount, 504 WDAGUtilityAccount
        $integradas = '-(500|501|503|504)$'
        $sistema = @('WsiAccount', 'defaultuser0', 'defaultuser100000')

        # Miembros de cada grupo local (via ADSI: evita el fallo de Get-LocalGroupMember con SID huerfanos)
        $miembros = @{}
        $grupos = [ordered]@{}
        foreach ($g in Get-LocalGroup) {
            $grupos[$g.Name] = $g.SID.Value
            try {
                foreach ($n in Get-MiembrosGrupo $g.Name) {
                    if (-not $miembros.ContainsKey($n)) { $miembros[$n] = @() }
                    $miembros[$n] += $g.Name
                }
            } catch {
                Write-Aviso "No se pudieron leer los miembros del grupo $($g.Name): $($_.Exception.Message)"
            }
        }

        $usuarios = @()
        $cuentasMs = @()
        $gruposUsados = @{}
        foreach ($u in Get-LocalUser) {
            if ($u.SID.Value -match $integradas -or $sistema -contains $u.Name) {
                Write-Omitido "$($u.Name) (cuenta del sistema)"
                continue
            }
            $susGrupos = @()
            if ($miembros.ContainsKey($u.Name)) { $susGrupos = @($miembros[$u.Name]) }
            foreach ($g in $susGrupos) { $gruposUsados[$g] = $true }

            if ([string]$u.PrincipalSource -eq 'MicrosoftAccount') {
                $cuentasMs += [ordered]@{ Nombre = $u.Name; NombreCompleto = [string]$u.FullName; Grupos = $susGrupos }
                Write-Aviso "$($u.Name): cuenta Microsoft -> quedara como pendiente manual (grupos: $($susGrupos -join ', '))"
                continue
            }
            $usuarios += [ordered]@{
                Nombre             = $u.Name
                NombreCompleto     = [string]$u.FullName
                Descripcion        = [string]$u.Description
                Password           = 'CAMBIAR'
                PasswordNuncaExpira = ($null -eq $u.PasswordExpires)
                Activo             = [bool]$u.Enabled
                Grupos             = $susGrupos
            }
            Write-Ok ("{0} (local) grupos: {1}" -f $u.Name, ($susGrupos -join ', '))
        }

        # SID de los grupos usados (solo los integrados de Windows, S-1-5-32-*, son portables)
        $sids = [ordered]@{}
        foreach ($g in $grupos.Keys) {
            if ($gruposUsados.ContainsKey($g) -and $grupos[$g] -match '^S-1-5-32-') { $sids[$g] = $grupos[$g] }
        }

        $datos = [ordered]@{
            Usuarios       = $usuarios
            CuentasMicrosoft = $cuentasMs
            GruposSid      = $sids
        }
        $ruta = Join-Path $Ctx.DirConfig 'usuarios.psd1'
        Write-Psd1 -Ruta $ruta -Datos $datos -Cabecera @(
            "Usuarios locales extraidos de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            ''
            'Usuarios: se crean si no existen. Si ya existen solo se ajustan sus grupos.'
            "  Password = 'CAMBIAR' -> hay que escribir la contrasena (Windows no permite extraerla)."
            "  Password = ''        -> usuario sin contrasena."
            '  Para no crear un usuario, borra o comenta (#) su bloque.'
            'CuentasMicrosoft: no se pueden crear por script. Inicia sesion con su email en el equipo'
            '  nuevo y vuelve a ejecutar Usuarios para asignarles sus grupos.'
            'GruposSid: SID de los grupos de Windows, para encontrarlos en cualquier idioma. No editar.'
            ''
            'ATENCION: este archivo contiene contrasenas en texto plano. No lo compartas.'
        )
        Write-Info "-> $ruta"
        if ($usuarios.Count -gt 0) { Add-Pendiente "Escribe las contrasenas en $ruta (Password = 'CAMBIAR')" }
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'usuarios.psd1')
        $sids = @{}
        if ($cfg.GruposSid) { $sids = $cfg.GruposSid }

        function Resolve-Grupo([string]$Nombre) {
            if ($sids.ContainsKey($Nombre)) {
                $g = Get-LocalGroup -SID $sids[$Nombre] -ErrorAction SilentlyContinue
                if ($g) { return $g.Name }
            }
            $g = Get-LocalGroup -Name $Nombre -ErrorAction SilentlyContinue
            if ($g) { return $g.Name }
            return $null
        }

        function Set-Grupos([string]$Usuario, [string[]]$Grupos) {
            foreach ($gNombre in @($Grupos | Where-Object { $_ })) {
                $g = Resolve-Grupo $gNombre
                if (-not $g) { Write-Aviso "${Usuario}: el grupo '$gNombre' no existe en este equipo"; continue }
                $yaEsta = $false
                try { $yaEsta = (Get-MiembrosGrupo $g) -contains $Usuario } catch { }
                if ($yaEsta) { Write-Omitido "$Usuario ya pertenece a $g"; continue }
                $null = Invoke-Cambio "$Usuario -> grupo $g" {
                    Add-LocalGroupMember -Group $g -Member $Usuario -ErrorAction Stop
                }
            }
        }

        foreach ($u in @($cfg.Usuarios)) {
            if (-not $u -or -not $u.Nombre) { continue }
            $existe = Get-LocalUser -Name $u.Nombre -ErrorAction SilentlyContinue
            if ($existe) {
                Write-Omitido "$($u.Nombre) ya existe (no se cambia su contrasena)"
            } else {
                if ($u.Password -eq 'CAMBIAR') {
                    Write-Fallo "$($u.Nombre): falta la contrasena en usuarios.psd1 (Password = 'CAMBIAR')"
                    continue
                }
                $creado = Invoke-Cambio "Crear usuario $($u.Nombre)" {
                    $param = @{ Name = $u.Nombre; ErrorAction = 'Stop' }
                    if ($u.NombreCompleto) { $param.FullName = $u.NombreCompleto }
                    if ($u.Descripcion)    { $param.Description = $u.Descripcion }
                    if ([string]::IsNullOrEmpty($u.Password)) {
                        $param.NoPassword = $true
                    } else {
                        $param.Password = ConvertTo-SecureString $u.Password -AsPlainText -Force
                        if ($u.PasswordNuncaExpira) { $param.PasswordNeverExpires = $true }
                    }
                    $nuevo = New-LocalUser @param
                    if ($u.Activo -eq $false) { Disable-LocalUser -Name $u.Nombre -ErrorAction Stop }
                }
                if (-not $creado) { continue }
            }
            Set-Grupos $u.Nombre $u.Grupos
        }

        foreach ($ms in @($cfg.CuentasMicrosoft)) {
            if (-not $ms -or -not $ms.Nombre) { continue }
            if (Get-LocalUser -Name $ms.Nombre -ErrorAction SilentlyContinue) {
                Write-Info "$($ms.Nombre) (cuenta Microsoft) ya existe en este equipo: se ajustan sus grupos"
                Set-Grupos $ms.Nombre $ms.Grupos
            } else {
                Add-Pendiente ("Cuenta Microsoft '{0}': inicia sesion con su email y vuelve a ejecutar -Solo Usuarios,Compartidas,Ajustes (grupos: {1})" -f $ms.Nombre, ($ms.Grupos -join ', '))
            }
        }
    }
}
