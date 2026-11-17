# Perfil de ejecucion de WinMudanza.
#
# Decide que modulos se ejecutan en cada accion:
#   Extraer -> lee este equipo y genera config\*.psd1 (tambien decide que se revisa con Revisar)
#   Aplicar -> aplica config\*.psd1 (y ajustes.psd1) a este equipo (tambien lo que compara Comparar)
#
# Los parametros -Solo y -Omitir de WinMudanza.ps1 tienen prioridad sobre este archivo,
# y en el menu interactivo se pueden marcar/desmarcar antes de ejecutar.
#
# Ejemplo: para no restaurar Steam pon  Steam = @{ Extraer = $true; Aplicar = $false }

@{
    # Carpeta donde se guarda/lee la configuracion extraida (relativa a la carpeta WinMudanza o ruta absoluta).
    # ATENCION: lo extraido contiene contrasenas en texto plano y esta excluido de git.
    DirConfig = 'config'

    # Copia de seguridad fuera de C: tras Extraer (y destino por defecto de -Accion Copiar).
    # Vacio = no copiar. Si la unidad no existe se avisa y no se copia.
    CopiarA = 'D:\WinMudanza'

    # Si un modulo necesita reiniciar (p. ej. al activar WSL o Hyper-V), Aplicar se detiene,
    # programa una tarea y continua solo al volver a iniciar sesion. $false = seguir sin reiniciar.
    ContinuarTrasReinicio = $true

    # Carpetas del Programador de tareas que guarda y restaura el modulo Tareas.
    CarpetasTareas = @('\Personal\')

    Modulos = @{
        Ajustes         = @{ Extraer = $false; Aplicar = $true }   # 01-06: menu, terminales, Edge, Explorador, energia, PowerShell (valores en ajustes.psd1)
        Wifi            = @{ Extraer = $true;  Aplicar = $true }   # redes Wi-Fi guardadas, con contrasena
        Caracteristicas = @{ Extraer = $true;  Aplicar = $true }   # caracteristicas de Windows (Hyper-V, WSL, Sandbox...); solo activa
        Usuarios        = @{ Extraer = $true;  Aplicar = $true }   # usuarios locales y sus grupos
        Carpetas        = @{ Extraer = $true;  Aplicar = $true }   # Descargas, Documentos... fuera de su sitio (p. ej. en D:)
        Compartidas     = @{ Extraer = $true;  Aplicar = $true }   # carpetas compartidas + permisos NTFS
        UnidadesRed     = @{ Extraer = $true;  Aplicar = $true }   # unidades de red mapeadas (Z: -> \\servidor\recurso)
        Impresoras      = @{ Extraer = $true;  Aplicar = $true }   # impresoras de red y predeterminada
        Hosts           = @{ Extraer = $true;  Aplicar = $true }   # entradas personalizadas del archivo hosts
        Paquetes        = @{ Extraer = $true;  Aplicar = $true }   # winget, npm, pip, dotnet tool, modulos PowerShell
        Office          = @{ Extraer = $true;  Aplicar = $true }   # Microsoft 365 / Office con la Office Deployment Tool
        Menus           = @{ Extraer = $false; Aplicar = $true }   # menus contextuales de Claude, VS Code, Everything, WinMerge (en ajustes.psd1)
        Entorno         = @{ Extraer = $true;  Aplicar = $true }   # variables de entorno y PATH personalizados
        Desarrollo      = @{ Extraer = $true;  Aplicar = $true }   # .gitconfig, .ssh, perfil de PowerShell, Terminal, VS Code
        Navegadores     = @{ Extraer = $true;  Aplicar = $true }   # favoritos de Edge, Chrome, Brave, Vivaldi, Opera, Firefox
        Outlook         = @{ Extraer = $true;  Aplicar = $true }   # firmas; cuentas de correo y .pst como pendientes
        Tareas          = @{ Extraer = $true;  Aplicar = $true }   # tareas programadas de CarpetasTareas
        Inicio          = @{ Extraer = $true;  Aplicar = $true }   # menu Inicio, barra de tareas y programas al iniciar sesion
        UniGetUI        = @{ Extraer = $true;  Aplicar = $true }   # configuracion de UniGetUI
        Steam           = @{ Extraer = $true;  Aplicar = $true }   # imagenes, juegos no-Steam, colecciones, opciones
    }
}
