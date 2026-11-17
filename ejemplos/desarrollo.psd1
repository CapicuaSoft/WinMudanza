# EJEMPLO. El archivo real lo genera Extraer en config\desarrollo.psd1 junto con
# config\desarrollo\ (copia de los archivos; puede incluir claves SSH privadas).
# Aqui va vacio porque no hay archivos de ejemplo.
#
# Elementos: Archivo (en config\desarrollo\) -> Ruta de destino (%USERPROFILE%, %APPDATA%, {Documentos}...).

@{
    Elementos = @(
        # @{ Nombre = 'Git'; Ruta = '%USERPROFILE%\.gitconfig'; Archivo = '01_.gitconfig' }
        # @{ Nombre = 'SSH'; Ruta = '%USERPROFILE%\.ssh'; Archivo = '02_.ssh' }
    )
}
