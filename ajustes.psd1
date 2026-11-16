# Ajustes del modulo "Ajustes" (no se extraen: se definen aqui a mano).
# Cada seccion tiene Activo = $true/$false y sus opciones.
# Los ajustes de usuario se aplican a TODOS los perfiles existentes y al perfil Default
# (los usuarios que se creen despues los heredan).

@{
    # Reinicia el Explorador al terminar para ver los cambios sin cerrar sesion.
    ReiniciarExplorer = $false

    # 01 - Menu contextual clasico de Windows 10 (sin "Mostrar mas opciones")
    MenuClasico = @{
        Activo = $true
    }

    # 02 - Entradas en el menu contextual del Explorador
    Terminales = @{
        Activo         = $true
        CmdAqui        = $true    # "Abrir CMD aqui" (normal y Administrador)
        PowerShellAqui = $true    # "Abrir PowerShell aqui" (normal y Administrador)
        Ps1ComoAdmin   = $true    # clic derecho en .ps1 -> ejecutar como administrador
        CmdComoAdmin   = $true    # clic derecho en .cmd/.bat -> ejecutar como administrador
    }

    # 03 - Microsoft Edge por directivas
    Edge = @{
        Activo        = $true
        # 'Obligatoria' = el usuario no puede cambiarlo.
        # 'Recomendada' = valor inicial que el usuario puede cambiar.
        # En equipos sin dominio Edge puede ignorar las obligatorias de inicio/buscador;
        # si pasa, cambia a 'Recomendada'.
        TipoDirectiva = 'Obligatoria'
        PaginaInicio  = 'https://www.google.com'   # vacio = no tocar
        BotonInicio   = $true
        Buscador      = @{
            Nombre    = 'Google'                   # Nombre vacio = no tocar el buscador
            Palabra   = 'google.com'
            Url       = 'https://www.google.com/search?q={searchTerms}'
            Sugerir   = 'https://clients1.google.com/complete/search?client=chrome&q={searchTerms}'
            Icono     = 'https://www.google.com/favicon.ico'
        }
        SinFeedNuevaPestana = $true                # sin noticias ni sitios sugeridos
        SinSugerenciasBing  = $true
        CerrarEdge          = $true                # cierra Edge para que aplique al reabrir
    }

    # 04 - Explorador, barra de tareas y menu Inicio
    Explorador = @{
        Activo                     = $true
        MostrarOcultos             = $true
        MostrarExtensiones         = $true
        MostrarArchivosSistema     = $true
        AbrirEnEsteEquipo          = $true
        VistaCompacta              = $true
        RutaCompletaEnTitulo       = $true
        IconosCentrados            = $true
        OcultarBotonWidgets        = $true
        OcultarBotonChat           = $true
        DeshabilitarWidgets        = $true         # directiva de equipo: el panel no arranca
        SegundosEnReloj            = $true
        OcultarBusquedaBarra       = $true
        OcultarSpotlightEscritorio = $true         # icono "Descubre mas sobre esta imagen"
        QuitarRecomendadosInicio   = $true
        OcultarOneDriveNavegacion  = $true
        # Solo para el usuario que ejecuta el script (Windows no permite hacerlo en otros perfiles):
        DesanclarCarpetas          = @('Desktop', 'MyPictures', 'MyMusic', 'MyVideos')
        DesanclarGaleria           = $true
        AnclarCarpetaPersonal      = $true
    }

    # 05 - Energia y rendimiento (pensado para equipos de escritorio)
    Energia = @{
        Activo                = $true
        PlanAltoRendimiento   = $true
        SinSuspensionUSB      = $true
        DiscoNuncaApagar      = $true
        SinPowerThrottling    = $true
        EfectosVisualesRendimiento = $true
        SinGameModeNiGameDVR  = $true
        SinHibernacion        = $true              # borra hiberfil.sys (desactiva tambien el inicio rapido)
    }
}
