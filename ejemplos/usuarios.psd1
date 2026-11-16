# EJEMPLO con datos ficticios. El archivo real lo genera Extraer en config\usuarios.psd1.
#
# Usuarios: se crean si no existen. Si ya existen solo se ajustan sus grupos.
#   Password = 'CAMBIAR' -> hay que escribir la contrasena (Windows no permite extraerla).
#   Password = ''        -> usuario sin contrasena.
#   Para no crear un usuario, borra o comenta (#) su bloque.
# CuentasMicrosoft: no se pueden crear por script. Inicia sesion con su email en el equipo
#   nuevo y vuelve a ejecutar Usuarios para asignarles sus grupos.
# GruposSid: SID de los grupos de Windows, para encontrarlos en cualquier idioma. No editar.

@{
    Usuarios = @(
        @{
            Nombre = 'ana'
            NombreCompleto = 'Ana Ejemplo'
            Descripcion = 'Usuario de prueba'
            Password = 'Contrasena-de-ejemplo-123'
            PasswordNuncaExpira = $true
            Activo = $true
            Grupos = @(
                'Administradores'
                'Usuarios'
            )
        }
        @{
            Nombre = 'salon'
            NombreCompleto = ''
            Descripcion = 'PC del salon'
            Password = ''
            PasswordNuncaExpira = $true
            Activo = $true
            Grupos = @(
                'Usuarios'
            )
        }
    )
    CuentasMicrosoft = @(
        @{
            Nombre = 'pedro'
            NombreCompleto = 'Pedro Ejemplo'
            Grupos = @(
                'Usuarios'
            )
        }
    )
    GruposSid = @{
        Administradores = 'S-1-5-32-544'
        Usuarios = 'S-1-5-32-545'
    }
}
