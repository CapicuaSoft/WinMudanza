# EJEMPLO. El archivo real lo genera Extraer en config\caracteristicas.psd1.
#
# Activar: se activan las que falten en el equipo nuevo. NUNCA se desactiva ninguna.
# Para no activar una, comenta su linea con # o borrala.
#
#   Nombre                                             Descripcion
#   Containers-DisposableClientVM                      Espacio aislado de Windows
#   Microsoft-Hyper-V-All                              Hyper-V
#   Microsoft-Windows-Subsystem-Linux                  Subsistema de Windows para Linux
#   NetFx3                                             .NET Framework 3.5
#   VirtualMachinePlatform                             Plataforma de maquina virtual

@{
    Activar = @(
        'Containers-DisposableClientVM'
        'Microsoft-Hyper-V-All'
        'Microsoft-Windows-Subsystem-Linux'
        'NetFx3'
        'VirtualMachinePlatform'
    )
}
