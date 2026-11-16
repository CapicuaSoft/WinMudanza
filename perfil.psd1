# Perfil de ejecucion de OptimizarHP2.
#
# Decide que modulos se ejecutan en cada accion:
#   Extraer -> lee este equipo y genera config\*.psd1
#   Aplicar -> aplica config\*.psd1 (y ajustes.psd1) a este equipo
#
# Los parametros -Solo y -Omitir de OptimizarHP2.ps1 tienen prioridad sobre este archivo,
# y en el menu interactivo se pueden marcar/desmarcar antes de ejecutar.
#
# Ejemplo: para no restaurar Steam pon  Steam = @{ Extraer = $true; Aplicar = $false }

@{
    # Carpeta donde se guarda/lee la configuracion extraida (relativa a esta carpeta o ruta absoluta).
    # ATENCION: contiene contrasenas en texto plano. Esta excluida de git.
    DirConfig = 'config'

    Modulos = @{
        Ajustes     = @{ Extraer = $false; Aplicar = $true }   # 01-05: menu, terminales, Edge, Explorador, energia (valores en ajustes.psd1)
        Usuarios    = @{ Extraer = $true;  Aplicar = $true }   # usuarios locales y sus grupos
        Compartidas = @{ Extraer = $true;  Aplicar = $true }   # carpetas compartidas + permisos NTFS
        Paquetes    = @{ Extraer = $true;  Aplicar = $true }   # winget, npm, pip, dotnet tool, modulos PowerShell
        Office      = @{ Extraer = $true;  Aplicar = $true }   # Microsoft 365 / Office con la Office Deployment Tool
        UniGetUI    = @{ Extraer = $true;  Aplicar = $true }   # configuracion de UniGetUI
        Steam       = @{ Extraer = $true;  Aplicar = $true }   # imagenes, juegos no-Steam, colecciones, opciones
    }
}
