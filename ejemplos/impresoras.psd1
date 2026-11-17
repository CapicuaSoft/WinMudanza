# EJEMPLO. El archivo real lo genera Extraer en config\impresoras.psd1.
#
# Tipo 'Red': impresora compartida \\servidor\impresora. Tipo 'IP': puerto TCP/IP + controlador.

@{
    Impresoras = @(
        @{
            Tipo = 'IP'
            Nombre = 'Impresora salon'
            Direccion = '192.168.1.50'
            PuertoTcp = 9100
            Controlador = 'Microsoft IPP Class Driver'
        }
        @{
            Tipo = 'Red'
            Nombre = '\\servidor\Laser'
            Conexion = '\\servidor\Laser'
        }
    )
    Predeterminada = 'Impresora salon'
}
