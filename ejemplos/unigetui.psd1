# EJEMPLO. El archivo real lo genera Extraer en config\unigetui.psd1
# (los archivos de valor y las opciones de instalacion se copian en config\unigetui\).
#
# Gestores           : $true = activo, $false = desactivado en UniGetUI.
# OpcionesActivadas  : opciones marcadas (cada una es un archivo vacio). Comenta con # para no aplicarla.
# ArchivosDeValor    : opciones con valor; se copian desde config\unigetui\Configuration\.
# OpcionesInstalacion: $true copia config\unigetui\InstallationOptions\ (opciones por paquete).
# QuitarInicioAutomatico: $true quita la entrada Run de UniGetUI (todos los perfiles y equipo),
#   porque lo inicia una tarea programada (p. ej. \Personal\, como administrador; modulo Tareas).

@{
    Gestores = @{
        Winget = $true
        Npm = $true
        Pip = $true
        Scoop = $false
        Chocolatey = $false
    }
    OpcionesActivadas = @(
        'DoCacheAdminRights'
        'DoCacheAdminRightsForBatches'
    )
    ArchivosDeValor = @(
        'WinGetTrustedInstallerHosts.json'
    )
    OpcionesInstalacion = $true
    QuitarInicioAutomatico = $true
}
