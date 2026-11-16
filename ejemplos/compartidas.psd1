# EJEMPLO con datos ficticios. El archivo real lo genera Extraer en config\compartidas.psd1.
#
# Nombre/Ruta : nombre del recurso y carpeta. Puedes cambiar la Ruta si en el equipo nuevo es otra.
# CrearCarpeta: $true crea la carpeta si no existe; $false da error si falta.
# Acceso      : permisos del recurso compartido. Derecho = Full | Change | Read. Tipo = Allow | Deny.
# NTFS        : permisos explicitos de la carpeta (los heredados no se guardan).
#               HerenciaDesactivada = $true si la carpeta no hereda permisos de su padre.
# Cuenta/Sid  : el Sid solo aparece en cuentas de Windows; las cuentas locales se buscan por nombre.

@{
    Compartidas = @(
        @{
            Nombre = 'Fotos'
            Ruta = 'D:\Fotos'
            Descripcion = 'Fotos familiares'
            CrearCarpeta = $true
            Acceso = @(
                @{
                    Cuenta = 'Everyone'
                    Sid = 'S-1-1-0'
                    Derecho = 'Read'
                    Tipo = 'Allow'
                }
                @{
                    Cuenta = 'ana'
                    Sid = $null
                    Derecho = 'Full'
                    Tipo = 'Allow'
                }
            )
            NTFS = @{
                HerenciaDesactivada = $false
                Permisos = @(
                    @{
                        Cuenta = 'ana'
                        Sid = $null
                        Derechos = 'Modify, Synchronize'
                        Tipo = 'Allow'
                        Herencia = 'ContainerInherit, ObjectInherit'
                        Propagacion = 'None'
                    }
                )
            }
        }
    )
}
