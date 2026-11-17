# EJEMPLO. El archivo real lo genera Extraer en config\tareas.psd1 (y los XML en config\tareas\).
#
# Cada tarea esta completa en config\tareas\<Archivo> (XML del Programador de tareas).
# Cuentas: usuarios de la tarea, por nombre; al aplicar se usa su SID en el equipo nuevo.
# Se registran las que no existan; las que ya existen no se tocan.

@{
    Tareas = @(
        @{
            Carpeta = '\Personal\'
            Nombre = 'Copia nocturna'
            Archivo = 'Personal\Copia nocturna.xml'
            Cuentas = @(
                'ana'
            )
            Activa = $true
        }
    )
}
