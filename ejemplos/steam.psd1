# EJEMPLO con datos ficticios. El archivo real lo genera Extraer en config\steam.psd1
# (imagenes y colecciones se copian en config\steam\<Id>\).
#
# RutaSteam: carpeta de Steam en el equipo nuevo. Vacio = detectarla automaticamente.
# Id       : cuenta de Steam de origen (carpeta userdata\<Id>).
# Destino  : 'auto' = la misma cuenta si existe, o la unica cuenta del equipo nuevo.
#            Escribe un Id para forzar otra cuenta.
# Imagenes / JuegosNoSteam / Colecciones / Lanzamiento: $false para no aplicar esa parte.
# Accesos  : juegos no-Steam. Puedes cambiar Exe y StartDir si el programa esta en otra ruta.
#            No cambies appid: es el nombre de sus imagenes en grid.
# OpcionesLanzamiento: 'appid' = 'opciones' de juegos de Steam.

@{
    RutaSteam = ''
    Cuentas = @(
        @{
            Id = '12345678'
            Destino = 'auto'
            Imagenes = $true
            JuegosNoSteam = $true
            Colecciones = $true
            Lanzamiento = $true
            Accesos = @(
                @{
                    appid = 3000000001
                    AppName = 'Mi Emulador'
                    Exe = '"D:\Juegos\Emulador\emulador.exe"'
                    StartDir = 'D:\Juegos\Emulador\'
                    icon = ''
                    ShortcutPath = ''
                    LaunchOptions = '--fullscreen'
                    IsHidden = 0
                    AllowDesktopConfig = 1
                    AllowOverlay = 1
                    OpenVR = 0
                    Devkit = 0
                    DevkitGameID = ''
                    DevkitOverrideAppID = 0
                    LastPlayTime = 0
                    FlatpakAppID = ''
                    sortas = ''
                    tags = @{}
                }
            )
            OpcionesLanzamiento = @{
                '440' = '-novid -console'
            }
        }
    )
}
