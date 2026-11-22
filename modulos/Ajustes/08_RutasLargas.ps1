# 08 - Rutas largas: permite rutas de mas de 260 caracteres en los programas que lo admiten
# (npm, pip, PowerShell 7, .NET...). Ajuste de equipo (HKLM), todos los usuarios.
# Git usa su propia opcion (core.longpaths), que pone el modulo Paquetes al instalar Git.

@{
    Clave  = 'RutasLargas'
    Nombre = 'Rutas largas'
    Aplicar = {
        param($Cfg, $Ctx)
        $fs = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
        if (Test-RegValorIgual $fs 'LongPathsEnabled' 1 'DWord') { Write-Omitido 'Rutas largas ya permitidas' }
        elseif ((Set-RegValor -Ruta $fs -Nombre 'LongPathsEnabled' -Valor 1 -Tipo DWord) -and -not (Test-Simulacion)) {
            Write-Ok 'Rutas largas permitidas (LongPathsEnabled)'
        }
    }
}
