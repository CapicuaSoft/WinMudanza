# EJEMPLO. El archivo real lo genera Extraer en config\entorno.psd1.
#
# Variables: se crean las que falten (las existentes con otro valor no se cambian).
# Path: se anaden las carpetas que falten y existan.

@{
    Equipo = @{
        Variables = @{
            JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-21'
        }
        Path = @(
            '%SystemRoot%\system32'
            'C:\Program Files\Git\cmd'
        )
    }
    Usuario = @{
        Variables = @{
            MI_PROYECTO = '%USERPROFILE%\Proyectos'
        }
        Path = @(
            '%APPDATA%\npm'
        )
    }
}
