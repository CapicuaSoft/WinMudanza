# 02 - Entradas del menu contextual para abrir CMD/PowerShell en carpetas
# y ejecutar .ps1 / .cmd / .bat como administrador.
# Ajuste de equipo: se escribe en HKLM\SOFTWARE\Classes (afecta a todos los usuarios).

@{
    Clave  = 'Terminales'
    Nombre = 'Terminales en menu contextual'
    Aplicar = {
        param($Cfg, $Ctx)
        $c = 'HKLM:\SOFTWARE\Classes'

        # Crea un verbo: clave con texto, icono opcional, escudo opcional y comando.
        function Set-Verbo([string]$Ruta, [string]$Texto, [string]$Comando, [string]$Icono, [switch]$Admin) {
            $ok = Set-RegValor -Ruta $Ruta -Nombre '(Default)' -Valor $Texto -Tipo String
            if ($Icono) { $ok = (Set-RegValor -Ruta $Ruta -Nombre 'Icon' -Valor $Icono -Tipo String) -and $ok }
            if ($Admin) { $ok = (Set-RegValor -Ruta $Ruta -Nombre 'HasLUAShield' -Valor '' -Tipo String) -and $ok }
            $ok = (Set-RegValor -Ruta "$Ruta\command" -Nombre '(Default)' -Valor $Comando -Tipo String) -and $ok
            return $ok
        }

        # %1 = carpeta seleccionada; %V = carpeta actual (clic en el fondo)
        foreach ($zona in @(@{ Base = "$c\Directory\shell"; Arg = '%1' }, @{ Base = "$c\Directory\Background\shell"; Arg = '%V' })) {
            $b = $zona.Base
            $a = $zona.Arg
            if ($Cfg.CmdAqui) {
                $ok = Set-Verbo "$b\CmdHere" 'Abrir CMD aqui' "cmd.exe /k cd /d `"$a`"" 'cmd.exe'
                $ok = (Set-Verbo "$b\CmdHereAdmin" 'Abrir CMD aqui (Administrador)' `
                    "powershell.exe -NoProfile -Command `"Start-Process cmd.exe -ArgumentList '/k cd /d \`"$a\`"' -Verb RunAs`"" 'cmd.exe' -Admin) -and $ok
                if ($ok -and -not (Test-Simulacion)) { Write-Ok "CMD aqui ($a)" }
            }
            if ($Cfg.PowerShellAqui) {
                $ok = Set-Verbo "$b\PSHere" 'Abrir PowerShell aqui' "powershell.exe -NoExit -Command `"Set-Location -LiteralPath '$a'`"" 'powershell.exe'
                $ok = (Set-Verbo "$b\PSHereAdmin" 'Abrir PowerShell aqui (Administrador)' `
                    "powershell.exe -NoProfile -Command `"Start-Process PowerShell -ArgumentList '-NoExit -Command Set-Location -LiteralPath \`"$a\`"' -Verb RunAs`"" 'powershell.exe' -Admin) -and $ok
                if ($ok -and -not (Test-Simulacion)) { Write-Ok "PowerShell aqui ($a)" }
            }
        }

        if ($Cfg.Ps1ComoAdmin) {
            $cmd = "powershell.exe -NoProfile -Command `"Start-Process PowerShell -ArgumentList '-NoExit -ExecutionPolicy Bypass -File \`"%1\`"' -Verb RunAs`""
            $ok = Set-Verbo "$c\Microsoft.PowerShellScript.1\Shell\RunAs" 'Ejecutar en PowerShell como administrador' $cmd -Admin
            $ok = (Set-Verbo "$c\SystemFileAssociations\.ps1\shell\runas" 'Ejecutar en PowerShell como administrador' $cmd -Admin) -and $ok
            if ($ok -and -not (Test-Simulacion)) { Write-Ok '.ps1: ejecutar como administrador' }
        }

        if ($Cfg.CmdComoAdmin) {
            # El verbo "runas" eleva automaticamente
            $ok = Set-Verbo "$c\cmdfile\shell\runas" 'Ejecutar como administrador' 'cmd.exe /k "%1"' -Admin
            $ok = (Set-Verbo "$c\batfile\shell\runas" 'Ejecutar como administrador' 'cmd.exe /k "%1"' -Admin) -and $ok
            if ($ok -and -not (Test-Simulacion)) { Write-Ok '.cmd/.bat: ejecutar como administrador' }
        }
    }
}
