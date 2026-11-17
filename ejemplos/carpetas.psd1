# EJEMPLO. El archivo real lo genera Extraer en config\carpetas.psd1.
#
# Usuarios = @{ <usuario> = @{ <Carpeta> = <ruta> } }
# Carpetas: Escritorio, Documentos, Descargas, Musica, Imagenes, Videos, Favoritos.
# Al aplicar se apuntan ahi (se crea la carpeta si falta); no se mueve ningun archivo.

@{
    Usuarios = @{
        ana = @{
            Descargas = 'D:\Descargas'
            Musica = 'D:\Multimedia\Musica'
        }
        luis = @{
            Documentos = 'D:\Luis\Documentos'
        }
    }
}
