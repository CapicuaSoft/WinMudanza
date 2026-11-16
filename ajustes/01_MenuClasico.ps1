# 01 - Restaura el menu contextual clasico de Windows 10 (elimina "Mostrar mas opciones").
# Ajuste de usuario: se aplica a todos los perfiles. En el perfil Default (usuarios futuros)
# se programa con RunOnce porque las claves de clases del usuario no se heredan.

@{
    Clave  = 'MenuClasico'
    Nombre = 'Menu contextual clasico'
    Aplicar = {
        param($Cfg, $Ctx)
        $clsid = 'CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        Invoke-EnPerfiles {
            param($P)
            if ($P.Clases) {
                $ok = Set-RegValor -Ruta "$($P.Clases)\$clsid" -Nombre '(Default)' -Valor '' -Tipo String
            } else {
                $ok = Set-RunOnce $P.HKCU 'OHP2_MenuClasico' "reg.exe add `"HKCU\Software\Classes\$clsid`" /ve /d `"`" /f"
            }
            if ($ok -and -not (Test-Simulacion)) {
                if ($P.Clases) { Write-Ok "Menu clasico: $($P.Nombre)" }
                else { Write-Ok "Menu clasico: $($P.Nombre) (se aplicara en su primer inicio de sesion)" }
            }
        }
    }
}
