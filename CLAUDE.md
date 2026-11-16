# CLAUDE.md

Guía para Claude Code al trabajar en este repositorio.

## Propósito

OptimizarHP2 (v2 de `C:\Proyectos\OptimizarHP`, que queda solo como referencia) configura un Windows 11 recién instalado y traslada configuración entre equipos: **Extraer** (equipo actual → `config\*.psd1` editables) y **Aplicar** (`config\` + `ajustes.psd1` → equipo nuevo). Debe poder usarlo otra persona: nada específico de un equipo en el código.

## Comandos

```powershell
.\pruebas\Probar-Sintaxis.ps1                                  # SIEMPRE tras editar: sintaxis + BOM + .psd1
.\OptimizarHP2.ps1 -Accion Aplicar -WhatIf -DirConfig .\ejemplos
.\OptimizarHP2.ps1 -Accion Extraer -DirConfig <scratchpad>\config   # solo lee el equipo
```

No ejecutar `Aplicar` real en el equipo del usuario: usar `-WhatIf`, o Windows Sandbox (`pruebas\Abrir-Sandbox.ps1`). Al probar módulos con rutas redirigidas (p. ej. `RutaSteam`), **verificar antes de aplicar** que la ruta apunta a la copia de prueba.

## Arquitectura

Ver `docs\DESARROLLO.md`. Resumen:
- `modulos\*.ps1` devuelven una tabla `@{ Nombre; Descripcion; Orden; DependeDe; ArchivoConfig; Extraer = {param($Ctx)}; Aplicar = {param($Ctx)} }`.
- `ajustes\NN_*.ps1` devuelven `@{ Clave; Nombre; Aplicar = {param($Cfg,$Ctx)} }`, activados por `ajustes.psd1`.
- `lib\Comun.psm1`: `Invoke-Cambio`, `Set-RegValor`, `Invoke-EnPerfiles`, mensajes, `Add-Pendiente`, cuentas portables.
- `lib\Psd1.psm1` (escribir .psd1), `lib\Vdf.psm1` (Steam binario/texto).

## Reglas

- **Todo cambio del sistema pasa por `Invoke-Cambio` o `Set-RegValor`** (si no, la simulación lo ejecutaría).
- Nunca `New-Item -Force` sobre una clave de registro existente (la vacía): usar `Set-RegValor`.
- Módulos repetibles: detectar lo ya aplicado y mostrarlo con `Write-Omitido`.
- Windows PowerShell 5.1: sin `??`, `?:`, `&&`, `ConvertFrom-Json -AsHashtable`.
- **UTF-8 con BOM** en `.ps1/.psm1/.psd1`. Tras editar con herramientas que no lo garanticen:
  ```powershell
  Get-ChildItem -Recurse -Include *.ps1,*.psm1,*.psd1 | ? FullName -notmatch '\\(config|logs)\\' |
    % { $t=[IO.File]::ReadAllText($_.FullName,[Text.Encoding]::UTF8); [IO.File]::WriteAllText($_.FullName,$t,(New-Object Text.UTF8Encoding $true)) }
  ```
- Mensajes de consola sin tildes; documentación (`.md`) en español con tildes.
- Cada cambio de funcionalidad se documenta en `docs\` (MODULOS, CONFIGURACION) y `CHANGELOG.md`, con ejemplo en `ejemplos\` si cambia un formato.
- `config\` y `logs\` están en `.gitignore` (contraseñas en texto plano). Commits solo cuando el usuario lo pida.

## Decisiones del usuario (no reabrir sin que lo pida)

- Se conservan los ajustes 01–04 y 07 de v1 (aquí 01–05); se descartaron bloatware/servicios/telemetría (05 v1) y privacidad (06 v1) y los modos Personal/Empresarial.
- Contraseñas de usuarios en texto plano en `usuarios.psd1`. Cuentas Microsoft: pendientes manuales.
- Paquetes: winget (solo fuente winget) + npm, pip, dotnet tool, módulos PowerShell.
- Ajustes de usuario, UniGetUI: todos los perfiles + Default. Steam: cuentas detectadas; Steam y emuladores se instalan a mano.
- Edge: si las directivas obligatorias no aplican sin dominio, usar `TipoDirectiva = 'Recomendada'`.
- Ejecución por menú y por parámetros; formato `.psd1`; git solo local.
