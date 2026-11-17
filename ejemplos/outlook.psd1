# EJEMPLO. El archivo real lo genera Extraer en config\outlook.psd1 (y las firmas en config\outlook\).
#
# Cuentas y ArchivosPst: informativos; al aplicar quedan como pendientes.
# Firmas: se copian las que falten desde config\outlook\<usuario>\Firmas.

@{
    Usuarios = @(
        @{
            Usuario = 'ana'
            Cuentas = @(
                @{
                    Perfil = 'Outlook'
                    Email = 'ana@empresa.com'
                    Tipo = 'Exchange / Microsoft 365 / Outlook.com'
                }
                @{
                    Perfil = 'Outlook'
                    Email = 'ana@correo.es'
                    Tipo = 'IMAP'
                    Entrada = 'imap.correo.es:993 (SSL)'
                    UsuarioServidor = 'ana@correo.es'
                    Salida = 'smtp.correo.es:465 (SSL)'
                }
            )
            ArchivosPst = @(
                'D:\Correo\Archivo 2020.pst'
            )
            Firmas = $false
        }
    )
}
