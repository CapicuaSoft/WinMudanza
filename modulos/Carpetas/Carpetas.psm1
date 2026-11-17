# Carpetas personales y sus valores en
# HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders.
# El primero es el que se lee al extraer; al aplicar se escriben todos (Windows usa ambos).

function Get-CarpetasConocidas {
    return [ordered]@{
        Escritorio = @('Desktop', '{754AC886-DF64-4CBA-86B5-F7FBF4FBCEF5}')
        Documentos = @('Personal', '{F42EE2D3-909F-4907-8871-4C22FC0BF756}')
        Descargas  = @('{374DE290-123F-4565-9164-39C4925E467B}', '{7D83EE9B-2244-4E70-B1F5-5393042AF1E4}')
        Musica     = @('My Music', '{A0C69A99-21C8-4671-8703-7934162FCF1D}')
        Imagenes   = @('My Pictures', '{0DDD015D-B06C-45D5-8C4C-F59713854639}')
        Videos     = @('My Video', '{35286A68-3C57-41A1-BBB1-0EAE73D76C95}')
        Favoritos  = @('Favorites')
    }
}

Export-ModuleMember -Function Get-CarpetasConocidas
