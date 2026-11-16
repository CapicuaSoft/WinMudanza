# Desarrollo

## Estructura

```
OptimizarHP2/
  OptimizarHP2.ps1      Entrada: parámetros, menú, selección de módulos, ejecución y resumen
  perfil.psd1           Qué módulos se ejecutan en Extraer/Aplicar
  ajustes.psd1          Valores del módulo Ajustes
  lib/
    Comun.psm1          Estado, mensajes/log, Invoke-Cambio, Set-RegValor, perfiles, cuentas, utilidades
    Psd1.psm1           Serializador a .psd1 (la lectura es Import-PowerShellDataFile)
    Vdf.psm1            VDF de Steam: binario (shortcuts.vdf) y texto (localconfig.vdf)
  ajustes/NN_*.ps1      Un archivo por grupo de ajustes (los ejecuta el módulo Ajustes)
  modulos/*.ps1         Un archivo por módulo
  pruebas/              Comprobación de sintaxis y lanzador de Windows Sandbox
  ejemplos/             .psd1 de ejemplo con datos ficticios
  docs/                 Documentación
  config/  logs/        Generados en ejecución (excluidos de git)
```

## Flujo

1. `OptimizarHP2.ps1` importa `lib\*.psm1` (globales), lee `perfil.psd1` y ejecuta cada archivo de `modulos\`, que **devuelve una tabla** describiendo el módulo.
2. Calcula la selección (`perfil.psd1` → `-Solo` → `-Omitir` → menú).
3. `Initialize-OHP2` crea el estado (simulación, log, contadores, pendientes).
4. Por cada módulo seleccionado, en orden de `Orden`, invoca `Extraer` o `Aplicar` con un objeto `$Ctx`.
5. Compara contadores de errores/avisos antes y después para el resumen.

## Contrato de un módulo

```powershell
# modulos\MiModulo.ps1
@{
    Nombre        = 'MiModulo'          # nombre para -Solo / -Omitir / perfil.psd1
    Descripcion   = 'Texto corto'
    Orden         = 70                  # posición en la ejecución
    DependeDe     = @('Usuarios')       # informativo: se avisa si no se ejecuta a la vez
    ArchivoConfig = 'mimodulo.psd1'     # si falta en config\, Aplicar lo omite. $null si no usa config\
    Extraer = {
        param($Ctx)                     # $Ctx.Raiz, .DirConfig, .Simular, .Accion, .Version, .Seleccion
        $datos = [ordered]@{ ... }
        Write-Psd1 -Ruta (Join-Path $Ctx.DirConfig 'mimodulo.psd1') -Datos $datos -Cabecera @('Explicacion de campos')
    }
    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'mimodulo.psd1')
        $null = Invoke-Cambio 'Descripcion del cambio' { <# accion con -ErrorAction Stop #> }
    }
}
```

Después añádelo a `perfil.psd1` y documéntalo en `docs\MODULOS.md` y `docs\CONFIGURACION.md`, con un ejemplo en `ejemplos\`.

## Contrato de un ajuste

```powershell
# ajustes\06_MiAjuste.ps1
@{
    Clave   = 'MiAjuste'                # nombre de la sección en ajustes.psd1
    Nombre  = 'Texto corto'
    Aplicar = { param($Cfg, $Ctx) ... } # $Cfg = sección de ajustes.psd1
}
```

Se ejecuta si `ajustes.psd1` tiene `MiAjuste = @{ Activo = $true; ... }`.

## Reglas para que la simulación sea segura

**Todo cambio en el sistema debe pasar por `Invoke-Cambio` o `Set-RegValor`.** En modo simulación esas funciones solo muestran `SIM ...`. Cualquier otra escritura directa se ejecutaría también en simulación.

- `Set-RegValor -Ruta -Nombre -Valor [-Tipo] [-FalloComoAviso]`: crea la clave solo si no existe (nunca la recrea ni borra valores). Devuelve `$true/$false` y solo muestra errores; el llamador decide el `Write-Ok`.
- `Invoke-Cambio 'Descripcion' { ... } [-Silencioso] [-FalloComoAviso]`: dentro usa `-ErrorAction Stop` en cmdlets y comprueba `$LASTEXITCODE` (con `throw`) en comandos externos.
- Leer el sistema (Get-*, Test-Path, `winget export` a un temporal) está permitido en simulación.
- Lo ya aplicado debe detectarse y mostrarse con `Write-Omitido` (módulos repetibles).

## Ajustes de usuario en todos los perfiles

```powershell
Invoke-EnPerfiles {
    param($P)   # $P.Nombre, .Sid, .Ruta, .EsDefault, .HKCU, .Clases
    Set-RegValor -Ruta "$($P.HKCU)\Software\..." -Nombre X -Valor 1
    if ($P.Clases) { Set-RegValor -Ruta "$($P.Clases)\CLSID\..." ... }
    else { Set-RunOnce $P.HKCU 'OHP2_X' 'reg.exe add "HKCU\Software\Classes\..." ...' }
}
```

`HKCU` apunta al registro del perfil (cargado con `reg load` si no tiene sesión abierta). `Clases` es su `HKCU\Software\Classes` (`UsrClass.dat`); en Default es `$null` porque esas claves no se heredan, de ahí el RunOnce.

## Mensajes

`Write-Ok`, `Write-Omitido`, `Write-Aviso` (cuenta aviso), `Write-Fallo` (cuenta error), `Write-Info`, `Write-Simulado`, `Add-Pendiente` (aparece en el resumen). Todos escriben también en el log.

## Convenciones

- **UTF-8 con BOM** en todos los `.ps1`, `.psm1` y `.psd1` (Windows PowerShell 5.1 lee sin BOM como ANSI).
- Compatibilidad con **Windows PowerShell 5.1**: sin `??`, `?:`, `-AsHashtable`, `&&`.
- Mensajes de consola sin tildes (evita problemas de página de códigos); la documentación sí lleva tildes.
- Nada específico de un equipo en el código: nombres, rutas y cuentas salen de la configuración.
- Al extraer, cuentas en formato portable (`ConvertTo-CuentaPortable`); al aplicar, `Resolve-Cuenta`.

## Pruebas

```powershell
.\pruebas\Probar-Sintaxis.ps1                                    # sintaxis, BOM y lectura de .psd1
.\OptimizarHP2.ps1 -Accion Extraer -DirConfig $env:TEMP\ohp2    # extracción (solo lee)
.\OptimizarHP2.ps1 -Accion Aplicar -WhatIf -DirConfig .\ejemplos # simulación con los ejemplos
.\pruebas\Abrir-Sandbox.ps1                                     # aplicar de verdad en Windows Sandbox
```

Antes de dar por buena una versión: sintaxis OK, extracción sin errores, simulación sin errores y, en Sandbox, una aplicación real seguida de una segunda ejecución que debe mostrar todo como `--` (ya aplicado).
