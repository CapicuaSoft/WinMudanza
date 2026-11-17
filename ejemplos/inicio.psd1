# Menu Inicio, barra de tareas, escritorio y programas al iniciar sesion (ejemplo).
#
# Los archivos estan en config\inicio\<usuario>\ (MenuInicio, BarraTareas, AlIniciar).
# MenuInicio = $false o BarraTareas = @() para no restaurarlos a ese usuario.
# AccesoRapido (carpetas) y Favoritos (archivos): anclados del Explorador, en orden; editables.
#   shell:Downloads = carpeta conocida del usuario; @() = no tocar los de ese usuario.
# Menu Inicio y barra de tareas se restauran una sola vez por usuario; de AlIniciar se copian los que falten.
# Taskband: registro de la barra de tareas (binario en base64). No editar.

@{
    Usuarios = @(
        @{
            Usuario     = 'ana'
            MenuInicio  = $false
            BarraTareas = @()
            Taskband    = @{}
            AccesoRapido = @('shell:Downloads', '%USERPROFILE%')
            Favoritos   = @()
            Escritorio  = @()
            IconosSistema = @{}
            Posiciones  = @{}
            AlIniciar   = @()
        }
    )
    AlIniciarComun  = @()
    EscritorioComun = @()
}
