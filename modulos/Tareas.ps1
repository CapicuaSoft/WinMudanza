# Modulo Tareas: tareas programadas de las carpetas del Programador de tareas indicadas en
# perfil.psd1 (CarpetasTareas, por defecto '\Personal\').
# - Extraer: exporta cada tarea a config\tareas\<carpeta>\<nombre>.xml. Los usuarios (SID, que
#   cambian al reinstalar) se guardan por nombre de cuenta.
# - Aplicar: registra las que no existan, con el SID de la cuenta en este equipo. Si la cuenta aun
#   no existe (cuenta Microsoft sin iniciar sesion) o la tarea guarda contrasena, queda pendiente.
#   Las que ya existen no se tocan.

@{
    Nombre        = 'Tareas'
    Descripcion   = 'Tareas programadas propias (carpeta Personal del Programador de tareas)'
    Orden         = 55
    DependeDe     = @('Usuarios')
    ArchivoConfig = 'tareas.psd1'

    Extraer = {
        param($Ctx)
        $carpetas = @($Ctx.Perfil.CarpetasTareas | Where-Object { $_ })
        if ($carpetas.Count -eq 0) { $carpetas = @('\Personal\') }
        $dirXml = Join-Path $Ctx.DirConfig 'tareas'
        if (Test-Path -LiteralPath $dirXml) { Remove-Item -LiteralPath $dirXml -Recurse -Force }
        $tareas = @()
        foreach ($c in $carpetas) {
            $c = '\' + $c.Trim('\') + '\'
            $lista = @(Get-ScheduledTask -TaskPath $c -ErrorAction SilentlyContinue)
            if ($lista.Count -eq 0) { Write-Omitido "No hay tareas en $c"; continue }
            foreach ($t in $lista) {
                try {
                    $xml = [xml](Export-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop)
                } catch { Write-Aviso "$c$($t.TaskName): no se pudo exportar ($($_.Exception.Message))"; continue }
                # SID de cuentas locales -> nombre (en el equipo nuevo el SID sera otro)
                $cuentas = @()
                foreach ($n in $xml.GetElementsByTagName('UserId')) {
                    $v = $n.InnerText
                    if ($v -match '^S-1-5-21-') {
                        try { $v = (New-Object System.Security.Principal.SecurityIdentifier $v).Translate([System.Security.Principal.NTAccount]).Value } catch { }
                    }
                    $port = ConvertTo-CuentaPortable $v
                    if ($port.Sid) { $n.InnerText = $port.Sid } else { $n.InnerText = $port.Cuenta }
                    if (-not $port.Sid) { $cuentas += $port.Cuenta }
                }
                $logon = [string]$xml.Task.Principals.Principal.LogonType
                $relativa = Join-Path $c.Trim('\') ($t.TaskName + '.xml')
                $archivo = Join-Path $dirXml $relativa
                New-Item -ItemType Directory -Path (Split-Path $archivo) -Force | Out-Null
                $xml.Save($archivo)
                $tareas += [ordered]@{
                    Carpeta  = $c
                    Nombre   = $t.TaskName
                    Archivo  = $relativa
                    Cuentas  = @($cuentas | Select-Object -Unique)
                    Activa   = [string]$t.State -ne 'Disabled'
                }
                $extra = ''
                if ($logon -eq 'Password') { $extra = ' (guarda contrasena: al aplicar quedara pendiente)' }
                Write-Ok "$c$($t.TaskName) [$(@($cuentas | Select-Object -Unique) -join ', ')]$extra"
            }
        }
        $ruta = Join-Path $Ctx.DirConfig 'tareas.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Tareas = $tareas }) -Cabecera @(
            "Tareas programadas de $env:COMPUTERNAME ($($carpetas -join ', ')) el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Cada tarea esta completa en config\tareas\<Archivo> (XML del Programador de tareas).'
            'Cuentas: usuarios de la tarea, por nombre; al aplicar se usa su SID en el equipo nuevo.'
            'Se registran las que no existan; las que ya existen no se tocan.'
            'Para no restaurar una tarea, borra o comenta (#) su bloque.'
        )
        Write-Info "-> $ruta"
    }

    Revisar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'tareas.psd1')
        foreach ($t in @($cfg.Tareas | Where-Object { $_ })) {
            $archivo = Join-Path (Join-Path $Ctx.DirConfig 'tareas') $t.Archivo
            if (-not (Test-Path -LiteralPath $archivo)) { continue }
            $xml = [xml](Get-Content -LiteralPath $archivo -Raw)
            foreach ($e in $xml.GetElementsByTagName('Exec')) {
                $cmd = [Environment]::ExpandEnvironmentVariables(([string]$e.Command).Trim('"'))
                if (-not [IO.Path]::IsPathRooted($cmd) -or -not (Test-EnUnidadSistema $cmd)) { continue }
                # Lo de Windows y Archivos de programa se reinstala; lo demas de C: se pierde
                $fuera = $true
                foreach ($b in $env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}) {
                    if ($b -and $cmd.StartsWith($b.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { $fuera = $false }
                }
                if ($fuera) { Write-Aviso "Tarea $($t.Carpeta)$($t.Nombre): ejecuta $cmd (en C:). Copialo fuera de C: o reinstalalo." }
            }
        }
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'tareas.psd1')
        $tareas = @($cfg.Tareas | Where-Object { $_ })
        if ($tareas.Count -eq 0) { Write-Omitido 'No hay tareas que restaurar'; return }
        foreach ($t in $tareas) {
            $etiqueta = "$($t.Carpeta)$($t.Nombre)"
            if (Get-ScheduledTask -TaskName $t.Nombre -TaskPath $t.Carpeta -ErrorAction SilentlyContinue) { Write-Omitido "$etiqueta (ya existe)"; continue }
            $archivo = Join-Path (Join-Path $Ctx.DirConfig 'tareas') $t.Archivo
            if (-not (Test-Path -LiteralPath $archivo)) { Write-Fallo "${etiqueta}: falta $archivo"; continue }
            $xml = [xml](Get-Content -LiteralPath $archivo -Raw)
            # Cuentas por nombre -> SID de este equipo
            $faltan = @()
            foreach ($n in $xml.GetElementsByTagName('UserId')) {
                if ($n.InnerText -match '^S-1-') { continue }
                $nt = Resolve-Cuenta $n.InnerText $null
                if (-not $nt) { $faltan += $n.InnerText; continue }
                $n.InnerText = (New-Object System.Security.Principal.NTAccount $nt).Translate([System.Security.Principal.SecurityIdentifier]).Value
            }
            if ($faltan.Count -gt 0) {
                Add-Pendiente "Tarea ${etiqueta}: la cuenta '$($faltan -join ', ')' no existe aun. Inicia sesion con ella y vuelve a ejecutar -Solo Tareas"
                continue
            }
            if ([string]$xml.Task.Principals.Principal.LogonType -eq 'Password') {
                Add-Pendiente "Tarea ${etiqueta}: se ejecuta aunque el usuario no haya iniciado sesion y necesita su contrasena. Importala a mano desde $archivo"
                continue
            }
            $texto = $xml.OuterXml
            $null = Invoke-Cambio "Registrar tarea $etiqueta" {
                $null = Register-ScheduledTask -Xml $texto -TaskName $t.Nombre -TaskPath $t.Carpeta -ErrorAction Stop
                if ($t.Activa -eq $false) { $null = Disable-ScheduledTask -TaskName $t.Nombre -TaskPath $t.Carpeta -ErrorAction Stop }
            }
        }
    }
}
