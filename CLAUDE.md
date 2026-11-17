# CLAUDE.md

Guía para Claude Code al trabajar en este repositorio.

## Propósito

WinMudanza (antes OptimizarHP2; v2 de `C:\Proyectos\OptimizarHP`, que queda solo como referencia) configura un Windows 11 recién instalado y traslada configuración entre equipos: **Extraer** (equipo actual → `config\*.psd1` editables) y **Aplicar** (`config\` → equipo nuevo). Debe poder usarlo otra persona: nada específico de un equipo en el código.

## Comandos

```powershell
.\pruebas\Probar-Sintaxis.ps1                                  # SIEMPRE tras editar: sintaxis + BOM + .psd1
.\WinMudanza.ps1 -Accion Aplicar -WhatIf -DirConfig .\ejemplos
.\WinMudanza.ps1 -Accion Extraer -DirConfig <scratchpad>\config   # solo lee el equipo
```

No ejecutar `Aplicar` real en el equipo del usuario: usar `-WhatIf`, o Windows Sandbox (`pruebas\Abrir-Sandbox.ps1`). Al probar módulos con rutas redirigidas (p. ej. `RutaSteam`), **verificar antes de aplicar** que la ruta apunta a la copia de prueba.

## Arquitectura

Ver `docs\DESARROLLO.md`. Resumen:
- `modulos\*.ps1` devuelven una tabla `@{ Nombre; Descripcion; Orden; DependeDe; ArchivoConfig; Extraer = {param($Ctx)}; Aplicar = {param($Ctx)} }`.
- `modulos\Ajustes\NN_*.ps1` (hijos del módulo Ajustes) devuelven `@{ Clave; Nombre; Aplicar = {param($Cfg,$Ctx)} }`, activados por `config\ajustes.psd1`.
- `lib\Comun.psm1`: `Invoke-Cambio`, `Set-RegValor`, `Invoke-EnPerfiles`, mensajes, `Add-Pendiente`, cuentas portables.
- `lib\Psd1.psm1` (escribir .psd1). En `lib\` solo lo común a varios módulos.
- Lo que usa un solo módulo va en `modulos\<Módulo>\` (hijos): `modulos\Steam\Vdf.psm1` (VDF binario/texto). Los `modulos\*\*.psm1` se importan automáticamente.

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
- En `config\` solo se versionan `perfil.psd1` y `ajustes.psd1`; lo extraído y `logs\` están en `.gitignore` (contraseñas en texto plano). Nunca usar `git add -f` en `config\`. Commits solo cuando el usuario lo pida.

## Decisiones del usuario (no reabrir sin que lo pida)

- Se conservan los ajustes 01–04 y 07 de v1 (aquí 01–05); se descartaron bloatware/servicios/telemetría (05 v1) y privacidad (06 v1) y los modos Personal/Empresarial.
- Contraseñas de usuarios en texto plano en `usuarios.psd1`. Cuentas Microsoft: pendientes manuales.
- Paquetes: winget (solo fuente winget) + npm, pip, dotnet tool, módulos PowerShell.
- Ajustes de usuario, UniGetUI: todos los perfiles + Default. Steam: cuentas detectadas; Steam y emuladores se instalan a mano.
- Edge: si las directivas obligatorias no aplican sin dominio, usar `TipoDirectiva = 'Recomendada'`.
- Versión 1.0.0 (aún sin publicar; numeración desde 1.0.0). Incluye, a pedido del usuario: Revisar antes de formatear, Copiar fuera de C: (`CopiarA = 'D:\WinMudanza'`), lanzador `.cmd`, continuar tras reiniciar, contraseñas por pantalla, Comparar, Sandbox automático; módulos Wifi, UnidadesRed, Impresoras, Hosts, Entorno, Desarrollo; ajuste 06 PowerShell (RemoteSigned, NuGet+PSGallery, TLS 1.2, doble clic). Wi-Fi y claves SSH en texto plano en `config\` (como las contraseñas).
- Características de Windows: solo activar, nunca desactivar. Sin capacidades (OpenSSH, Paint, idiomas…) ni distribuciones de WSL.
- Office: módulo propio con la Office Deployment Tool, instalación silenciosa; activación manual. `C:\Proyectos\InstalarOffice` queda intacto como referencia.
- Ejecución por menú y por parámetros; formato `.psd1`; git solo local.
- Paquetes: winget con `--scope machine` y, si no hay instalador para todos (`0x8A150010`), por usuario con aviso. npm y dotnet tool se quedan por usuario. Lo de Chocolatey/Scoop que winget no reconoce se sugiere **comentado** en `paquetes.psd1`.
- git-flow: git-flow-next (`GitTower.GitFlowNext`, winget, `--scope machine`) si se instala Git y `git flow` no funciona; interruptor `Winget.GitFlow` en `paquetes.psd1`. Probado en el equipo del usuario: funciona.
- Módulo Menus (tras Paquetes, config en `ajustes.psd1` sección `Menus`): «Abrir en Claude» (Claude Code), VS Code, Everything, WinMerge. Sin menú de Claude Desktop (probado: `claude-desktop.exe` no abre carpetas).
- Módulos Navegadores (favoritos Chromium + Firefox, todos los perfiles; solo se restauran si el perfil del navegador está vacío, si no HTML como pendiente) y Outlook (firmas; cuentas y .pst solo como pendientes: no se copia el perfil ni contraseñas).
- Módulos Carpetas (User Shell Folders fuera del perfil y no OneDrive; no mueve archivos) y Tareas (carpetas de `CarpetasTareas` en `perfil.psd1`, por defecto `\Personal\`; cuentas por nombre).
