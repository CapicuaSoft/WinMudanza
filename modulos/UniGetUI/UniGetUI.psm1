# Funciones del modulo UniGetUI.

# Tareas programadas (de cualquier carpeta) cuya accion ejecuta UniGetUI.exe.
function Get-TareasUniGetUI {
    @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        @($_.Actions | Where-Object { [string]$_.Execute -match 'UniGetUI\.exe|WingetUI\.exe' }).Count -gt 0
    })
}

Export-ModuleMember -Function Get-TareasUniGetUI
