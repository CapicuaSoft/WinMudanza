# EJEMPLO. El archivo real lo genera Extraer en config\unidadesred.psd1.
#
# Letra: letra de unidad. Ruta: \\servidor\recurso. Usuario: '' = el de Windows.
# Se aplican al usuario que ejecuta WinMudanza y se conectan al iniciar sesion.

@{
    Unidades = @(
        @{
            Letra = 'Z'
            Ruta = '\\nas\fotos'
            Usuario = ''
        }
    )
}
