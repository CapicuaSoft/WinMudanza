# EJEMPLO. El archivo real lo genera Extraer en config\paquetes.psd1.
#
# Activo = $false desactiva un gestor completo.
# Para no instalar un paquete, comenta su linea con # o borrala.
# Se instala la ultima version disponible. Los que ya esten instalados se saltan.
# Orden al aplicar: Winget -> Npm -> Pip -> DotnetTool -> PowerShell

@{
    Winget = @{
        Activo = $true
        Paquetes = @(
            '7zip.7zip'
            'Git.Git'
            'Mozilla.Firefox'
            # 'Spotify.Spotify'          <- comentado: no se instala
            'OpenJS.NodeJS.LTS'
            'Python.Python.3.14'
            'VideoLAN.VLC'
        )
    }
    Npm = @{
        Activo = $true
        Paquetes = @(
            'typescript'
        )
    }
    Pip = @{
        Activo = $true
        Paquetes = @(
            'requests'
        )
    }
    DotnetTool = @{
        Activo = $false
        Paquetes = @()
    }
    PowerShell = @{
        Activo = $true
        Paquetes = @(
            'PSReadLine'
        )
    }
}
