# Cambios

## 3.0.0 — 2026-11-16

### Nuevo
- Acción **Revisar** (y al final de Extraer): avisa de lo que la configuración necesita y está en C: (carpetas compartidas, juegos no-Steam, la propia configuración).
- Acción **Copiar** y `CopiarA` en `perfil.psd1`: copia WinMudanza con su configuración fuera de C: (por defecto `D:\WinMudanza`, automáticamente tras Extraer).
- Acción **Comparar**: diferencias entre la configuración y el equipo (Aplicar simulado).
- **`WinMudanza.cmd`**: lanzador de doble clic que pide Administrador y evita la directiva de ejecución.
- **Continuar tras reiniciar**: si un módulo lo necesita (Características), Aplicar se detiene, programa la continuación y sigue sola al iniciar sesión. `ContinuarTrasReinicio` en `perfil.psd1` y `-SinReiniciar`.
- Usuarios: las contraseñas `'CAMBIAR'` se piden por pantalla al aplicar.
- Módulos **Wifi**, **UnidadesRed**, **Impresoras**, **Hosts**, **Entorno** y **Desarrollo** (`.gitconfig`, `.ssh`, perfiles de PowerShell, Windows Terminal, VS Code).
- Ajuste **06 PowerShell**: directiva `RemoteSigned`, NuGet + PSGallery de confianza, TLS 1.2 en .NET, doble clic en `.ps1` ejecuta.
- `pruebas\Abrir-Sandbox.ps1 -Probar`: prueba automática en Sandbox con `config\sandbox` generado.

### Cambiado
- `Set-RegValor` no escribe si el valor ya es igual (simulación y Comparar muestran solo diferencias reales); en simulación se lee el registro real de los perfiles con sesión abierta.
- Parámetro `-SinConfirmar` ahora tampoco pregunta contraseñas ni reinicio.
- `-Solo`/`-Omitir` aceptan listas separadas por comas en un solo texto (como llegan desde `-File` o el `.cmd`).

## 2.2.0 — 2026-11-16

### Nuevo
- Módulo **Características**: extrae las características de Windows activadas (Hyper-V, WSL, Sandbox, .NET 3.5…) y en el equipo nuevo activa las que falten. Nunca desactiva ninguna. El reinicio queda como pendiente.

### Cambiado
- El proyecto pasa a llamarse **WinMudanza** (antes OptimizarHP2): carpeta, script `WinMudanza.ps1`, prefijos `WMUD_` y copias `*.wmud.bak`.
- La carpeta `ajustes\` pasa a `modulos\Ajustes\`, como hijos del módulo Ajustes.
- `perfil.psd1` y `ajustes.psd1` pasan a `config\` y se versionan en git; lo que genera Extraer sigue excluido. `-DirConfig` solo cambia la carpeta de lo extraído.
- `lib\Vdf.psm1` pasa a `modulos\Steam\Vdf.psm1`: en `lib\` solo queda lo común a varios módulos. Las librerías `modulos\*\*.psm1` se importan automáticamente.

## 2.1.0 — 2026-11-16

### Nuevo
- Módulo **Office**: extrae la instalación de Microsoft 365 / Office (producto, idioma, canal, apps excluidas) y la instala en silencio con la Office Deployment Tool oficial (`setup.exe` verificado por firma). La activación queda como pendiente manual.
- Paquetes no instala `Microsoft.Office` con winget cuando el módulo Office se encarga de él.
- El contexto de los módulos (`$Ctx`) incluye `Seleccion`: los módulos que se ejecutan.

## 2.0.0 — 2026-11-16

Primera versión (entonces llamada OptimizarHP2), reescrita a partir de OptimizarHP (v1).

### Nuevo
- Acciones **Extraer** y **Aplicar** con configuración editable en `.psd1`.
- Módulos: **Usuarios**, **Compartidas** (recurso + NTFS), **Paquetes** (winget, npm, pip, dotnet tool, PowerShell), **UniGetUI**, **Steam** (imágenes, juegos no-Steam, colecciones, opciones de lanzamiento).
- `perfil.psd1` para elegir módulos; parámetros `-Solo`, `-Omitir`, `-WhatIf`, `-DirConfig`, `-SinConfirmar`; menú interactivo.
- Simulación de Aplicar sin cambiar nada.
- Resumen final por módulo con errores, avisos y **pendientes**; log por ejecución en `logs\`.
- Ajustes de usuario aplicados a **todos los perfiles** y al perfil **Default** (RunOnce para claves de clases).
- Edge: opción de directivas **recomendadas**.
- Respaldos `*.wmud.bak` antes de sobrescribir archivos de Steam.
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
