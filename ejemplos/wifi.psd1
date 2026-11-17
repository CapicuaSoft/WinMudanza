# EJEMPLO. El archivo real lo genera Extraer en config\wifi.psd1 junto con config\wifi\*.xml
# (perfiles de Windows con la contrasena en claro). Aqui va vacio porque no hay XML de ejemplo.
#
# Redes: cada red apunta a su perfil en config\wifi\. Las que ya existan no se tocan.

@{
    Redes = @(
        # @{ Nombre = 'MiCasa'; Archivo = 'Wi-Fi-MiCasa.xml' }
    )
}
