# Cambios

## 2.1.0 — 2026-11-16

### Nuevo
- Módulo **Office**: extrae la instalación de Microsoft 365 / Office (producto, idioma, canal, apps excluidas) y la instala en silencio con la Office Deployment Tool oficial (`setup.exe` verificado por firma). La activación queda como pendiente manual.
- Paquetes no instala `Microsoft.Office` con winget cuando el módulo Office se encarga de él.
- El contexto de los módulos (`$Ctx`) incluye `Seleccion`: los módulos que se ejecutan.

## 2.0.0 — 2026-11-16

Primera versión de OptimizarHP2, reescrita a partir de OptimizarHP (v1).

### Nuevo
- Acciones **Extraer** y **Aplicar** con configuración editable en `.psd1`.
- Módulos: **Usuarios**, **Compartidas** (recurso + NTFS), **Paquetes** (winget, npm, pip, dotnet tool, PowerShell), **UniGetUI**, **Steam** (imágenes, juegos no-Steam, colecciones, opciones de lanzamiento).
- `perfil.psd1` para elegir módulos; parámetros `-Solo`, `-Omitir`, `-WhatIf`, `-DirConfig`, `-SinConfirmar`; menú interactivo.
- Simulación de Aplicar sin cambiar nada.
- Resumen final por módulo con errores, avisos y **pendientes**; log por ejecución en `logs\`.
- Ajustes de usuario aplicados a **todos los perfiles** y al perfil **Default** (RunOnce para claves de clases).
- Edge: opción de directivas **recomendadas**.
- Respaldos `*.ohp2.bak` antes de sobrescribir archivos de Steam.
- Documentación completa en `docs\`, ejemplos en `ejemplos\`, `Get-Help`.
- Pruebas: `pruebas\Probar-Sintaxis.ps1` y `pruebas\Abrir-Sandbox.ps1`.

### Conservado de v1 (corregido)
- 01 menú clásico, 02 terminales (añade `.bat`), 03 Edge, 04 Explorador, 05 energía (antes 07).

### Corregido respecto a v1
- Los errores de cada paso llegan al resumen (antes siempre mostraba "OK").
- Ya no se usa `New-Item -Force` sobre claves existentes (borraba directivas de Edge al repetir).
- El plan Alto Rendimiento oculto se crea con su GUID estándar, de modo que se puede activar.
- El plan se muestra como activado solo después de activarlo.

### Eliminado
- Bloatware, servicios, tareas, telemetría, Copilot y seguridad (05 de v1).
- Privacidad de aplicaciones (06 de v1).
- Modos Personal / Empresarial.
