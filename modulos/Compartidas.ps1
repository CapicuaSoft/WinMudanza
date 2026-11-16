# Modulo Compartidas: recursos compartidos SMB y permisos NTFS de sus carpetas.
# - Las cuentas se guardan por nombre (las locales cambian de SID al reinstalar) y,
#   si son cuentas de Windows (Todos, Administradores, SYSTEM...), tambien por SID.
# - Del NTFS se guardan solo los permisos explicitos (los heredados vienen de la carpeta padre).
# - Si una cuenta no existe todavia, se avisa y se omite; se puede volver a ejecutar mas tarde.

@{
    Nombre        = 'Compartidas'
    Descripcion   = 'Carpetas compartidas y permisos'
    Orden         = 30
    DependeDe     = @('Usuarios')
    ArchivoConfig = 'compartidas.psd1'

    Extraer = {
        param($Ctx)
        $lista = @()
        $shares = @(Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.Name -notmatch '\$$' })
        if ($shares.Count -eq 0) { Write-Omitido 'No hay carpetas compartidas' }
        foreach ($s in $shares) {
            $acceso = @()
            try {
                foreach ($a in Get-SmbShareAccess -Name $s.Name -ErrorAction Stop) {
                    $c = ConvertTo-CuentaPortable $a.AccountName
                    $acceso += [ordered]@{ Cuenta = $c.Cuenta; Sid = $c.Sid; Derecho = [string]$a.AccessRight; Tipo = [string]$a.AccessControlType }
                }
            } catch {
                Write-Fallo "$($s.Name): no se pudieron leer los permisos del recurso compartido ($($_.Exception.Message))"
                continue
            }

            $ntfs = @()
            $protegida = $false
            try {
                $acl = (Get-Item -LiteralPath $s.Path -ErrorAction Stop).GetAccessControl('Access')
                $protegida = $acl.AreAccessRulesProtected
                foreach ($r in $acl.Access) {
                    if ($r.IsInherited) { continue }
                    $c = ConvertTo-CuentaPortable $r.IdentityReference.Value
                    $ntfs += [ordered]@{
                        Cuenta      = $c.Cuenta
                        Sid         = $c.Sid
                        Derechos    = [string]$r.FileSystemRights
                        Tipo        = [string]$r.AccessControlType
                        Herencia    = [string]$r.InheritanceFlags
                        Propagacion = [string]$r.PropagationFlags
                    }
                }
            } catch {
                Write-Aviso "$($s.Name): no se pudieron leer los permisos NTFS de $($s.Path) ($($_.Exception.Message))"
            }

            $lista += [ordered]@{
                Nombre       = $s.Name
                Ruta         = $s.Path
                Descripcion  = [string]$s.Description
                CrearCarpeta = $true
                Acceso       = $acceso
                NTFS         = [ordered]@{ HerenciaDesactivada = [bool]$protegida; Permisos = $ntfs }
            }
            $resumenAcceso = ($acceso | ForEach-Object { "$($_.Cuenta)=$($_.Derecho)" }) -join ', '
            Write-Ok ("{0,-12} {1,-18} recurso: {2}  NTFS: {3} explicitos" -f $s.Name, $s.Path, $resumenAcceso, $ntfs.Count)
        }

        $ruta = Join-Path $Ctx.DirConfig 'compartidas.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Compartidas = $lista }) -Cabecera @(
            "Carpetas compartidas extraidas de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            ''
            'Nombre/Ruta : nombre del recurso y carpeta. Puedes cambiar la Ruta si en el equipo nuevo es otra.'
            'CrearCarpeta: $true crea la carpeta si no existe; $false da error si falta.'
            'Acceso      : permisos del recurso compartido. Derecho = Full | Change | Read. Tipo = Allow | Deny.'
            'NTFS        : permisos explicitos de la carpeta (los heredados no se guardan).'
            '              HerenciaDesactivada = $true si la carpeta no hereda permisos de su padre.'
            '              Derechos: FullControl, Modify, ReadAndExecute, Read, Write... (combinables con coma).'
            'Cuenta/Sid  : el Sid solo aparece en cuentas de Windows; las cuentas locales se buscan por nombre.'
            'Para no recrear un recurso, borra o comenta (#) su bloque.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'compartidas.psd1')

        foreach ($s in @($cfg.Compartidas)) {
            if (-not $s -or -not $s.Nombre) { continue }
            Write-Info "$($s.Nombre) -> $($s.Ruta)"

            # ---- Carpeta ----
            if (-not (Test-Path -LiteralPath $s.Ruta)) {
                if (-not $s.CrearCarpeta) { Write-Fallo "$($s.Nombre): no existe $($s.Ruta) (CrearCarpeta = `$false)"; continue }
                $ok = Invoke-Cambio "Crear carpeta $($s.Ruta)" { New-Item -ItemType Directory -Path $s.Ruta -Force -ErrorAction Stop | Out-Null }
                if (-not $ok) { continue }
            } else {
                Write-Omitido "$($s.Ruta) ya existe (datos intactos)"
            }

            # ---- Recurso compartido ----
            $cuentasAcceso = @{ Full = @(); Change = @(); Read = @() }
            $denegar = @()
            foreach ($a in @($s.Acceso)) {
                $nt = Resolve-Cuenta $a.Cuenta $a.Sid
                if (-not $nt) { Write-Aviso "$($s.Nombre): la cuenta '$($a.Cuenta)' no existe aqui; se omite su permiso de recurso"; continue }
                if ($a.Tipo -eq 'Deny') { $denegar += $nt } else { $cuentasAcceso[$a.Derecho] += $nt }
            }
            $existente = Get-SmbShare -Name $s.Nombre -ErrorAction SilentlyContinue
            if ($existente) {
                if ($existente.Path.TrimEnd('\') -ne ([string]$s.Ruta).TrimEnd('\')) {
                    Write-Fallo "$($s.Nombre): ya existe compartido con otra ruta ($($existente.Path))"
                    continue
                }
                $actual = @(Get-SmbShareAccess -Name $s.Nombre -ErrorAction SilentlyContinue)
                foreach ($derecho in 'Full', 'Change', 'Read') {
                    foreach ($nt in $cuentasAcceso[$derecho]) {
                        $ya = $actual | Where-Object { $_.AccountName -eq $nt -and [string]$_.AccessRight -eq $derecho -and [string]$_.AccessControlType -eq 'Allow' }
                        if ($ya) { continue }
                        $null = Invoke-Cambio "$($s.Nombre): permiso $derecho para $nt" {
                            Grant-SmbShareAccess -Name $s.Nombre -AccountName $nt -AccessRight $derecho -Force -ErrorAction Stop | Out-Null
                        }
                    }
                }
                Write-Omitido "$($s.Nombre) ya estaba compartido; permisos del recurso revisados"
            } else {
                $null = Invoke-Cambio "Compartir $($s.Ruta) como '$($s.Nombre)'" {
                    $p = @{ Name = $s.Nombre; Path = $s.Ruta; ErrorAction = 'Stop' }
                    if ($s.Descripcion) { $p.Description = $s.Descripcion }
                    if ($cuentasAcceso.Full.Count)   { $p.FullAccess   = $cuentasAcceso.Full }
                    if ($cuentasAcceso.Change.Count) { $p.ChangeAccess = $cuentasAcceso.Change }
                    if ($cuentasAcceso.Read.Count)   { $p.ReadAccess   = $cuentasAcceso.Read }
                    New-SmbShare @p | Out-Null
                }
            }
            foreach ($nt in $denegar) {
                $null = Invoke-Cambio "$($s.Nombre): denegar acceso a $nt" {
                    Block-SmbShareAccess -Name $s.Nombre -AccountName $nt -Force -ErrorAction Stop | Out-Null
                }
            }

            # ---- Permisos NTFS ----
            $reglas = @()
            $omitidas = 0
            foreach ($r in @($s.NTFS.Permisos)) {
                if (-not $r) { continue }
                $nt = Resolve-Cuenta $r.Cuenta $r.Sid
                if (-not $nt) {
                    $omitidas++
                    Write-Aviso "$($s.Nombre): la cuenta '$($r.Cuenta)' no existe aqui; se omite su permiso NTFS"
                    Add-Pendiente "Permisos NTFS de '$($r.Cuenta)' en $($s.Ruta): vuelve a ejecutar -Solo Compartidas cuando exista"
                    continue
                }
                try {
                    $reglas += New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $nt,
                        [System.Security.AccessControl.FileSystemRights]$r.Derechos,
                        [System.Security.AccessControl.InheritanceFlags]$r.Herencia,
                        [System.Security.AccessControl.PropagationFlags]$r.Propagacion,
                        [System.Security.AccessControl.AccessControlType]$r.Tipo)
                } catch {
                    Write-Fallo "$($s.Nombre): permiso NTFS no valido para '$($r.Cuenta)' ($($_.Exception.Message))"
                }
            }
            # Quita las reglas que la carpeta ya tiene (mismo SID, derechos, tipo y herencia)
            if ($reglas.Count -gt 0 -and (Test-Path -LiteralPath $s.Ruta)) {
                try {
                    $existentes = @((Get-Item -LiteralPath $s.Ruta).GetAccessControl('Access').GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]))
                    $reglas = @($reglas | Where-Object {
                        $nueva = $_
                        $sidNueva = $nueva.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
                        -not ($existentes | Where-Object {
                            $_.IdentityReference.Value -eq $sidNueva -and $_.FileSystemRights -eq $nueva.FileSystemRights -and
                            $_.AccessControlType -eq $nueva.AccessControlType -and $_.InheritanceFlags -eq $nueva.InheritanceFlags -and
                            $_.PropagationFlags -eq $nueva.PropagationFlags })
                    })
                } catch { }
            }
            $protegerFalta = $false
            if ($s.NTFS.HerenciaDesactivada -and (Test-Path -LiteralPath $s.Ruta)) {
                try { $protegerFalta = -not (Get-Item -LiteralPath $s.Ruta).GetAccessControl('Access').AreAccessRulesProtected } catch { $protegerFalta = $true }
            } elseif ($s.NTFS.HerenciaDesactivada) { $protegerFalta = $true }

            if ($reglas.Count -eq 0 -and -not $protegerFalta) {
                if ($omitidas -eq 0) { Write-Omitido "$($s.Nombre): permisos NTFS ya al dia" }
            } else {
                $desc = "$($s.Nombre): permisos NTFS ($($reglas.Count) cuentas)"
                if ($s.NTFS.HerenciaDesactivada) { $desc += ', herencia desactivada' }
                $null = Invoke-Cambio $desc {
                    $dir = Get-Item -LiteralPath $s.Ruta -ErrorAction Stop
                    $acl = $dir.GetAccessControl('Access')
                    if ($s.NTFS.HerenciaDesactivada -and -not $acl.AreAccessRulesProtected) {
                        $acl.SetAccessRuleProtection($true, $true)   # conserva los heredados como explicitos
                    }
                    foreach ($regla in $reglas) { $acl.AddAccessRule($regla) }
                    $dir.SetAccessControl($acl)
                }
            }
        }
    }
}
