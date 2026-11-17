# EJEMPLO. El archivo real lo genera Extraer en config\navegadores.psd1 (y los favoritos en config\navegadores\).
#
# Al aplicar se restauran solo si ese perfil del navegador no tiene favoritos; si ya tiene,
# queda como pendiente importar favoritos.html. Firefox se restaura desde el propio Firefox.

@{
    Favoritos = @(
        @{
            Usuario = 'ana'
            Navegador = 'Edge'
            Perfil = 'Default'
            Carpeta = 'ana\Edge\Default'
            Favoritos = 120
        }
        @{
            Usuario = 'ana'
            Navegador = 'Firefox'
            Perfil = 'abcd1234.default-release'
            Carpeta = 'ana\Firefox\abcd1234.default-release'
            Archivo = 'bookmarks-2026-11-16.jsonlz4'
        }
    )
}
