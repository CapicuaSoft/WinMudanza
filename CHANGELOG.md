# Cambios

## 1.0.0 — 2026-11-16

Primera versión. Sustituye a OptimizarHP (v1), que queda solo como referencia.

### Acciones
- **Extraer** (equipo actual → `config\*.psd1` editables) y **Aplicar** (configuración → equipo nuevo).
- **Revisar** (también al final de Extraer): avisa de lo que la configuración necesita y está en C: (carpetas compartidas, juegos no-Steam, la propia configuración).
- **Copiar** y `CopiarA` en `perfil.psd1`: copia WinMudanza con su configuración fuera de C: (por defecto `D:\WinMudanza`, automáticamente tras Extraer).
- **Comparar**: diferencias entre la configuración y el equipo (Aplicar simulado).
- Simulación de Aplicar (`-WhatIf`) sin cambiar nada; `Set-RegValor` solo escribe (y solo muestra) diferencias reales.
- **Continuar tras reiniciar**: si un módulo lo necesita (Características), Aplicar se detiene, programa la continuación y sigue sola al iniciar sesión. `ContinuarTrasReinicio` en `perfil.psd1` y `-SinReiniciar`.

### Módulos
- **Ajustes**: 01 menú contextual clásico, 02 terminales (incluye `.bat`), 03 Edge (con opción de directivas **recomendadas**), 04 Explorador, 05 energía, 06 PowerShell (`RemoteSigned`, NuGet + PSGallery de confianza, TLS 1.2 en .NET, doble clic en `.ps1` ejecuta). Los ajustes de usuario se aplican a **todos los perfiles** y al perfil **Default**.
- **Usuarios**: cuentas locales con sus grupos; las contraseñas `'CAMBIAR'` se piden por pantalla. Las cuentas Microsoft quedan como pendientes.
- **Carpetas**: Descargas, Documentos, Música… de cada usuario que no están en su sitio por defecto (p. ej. en `D:`); se vuelven a apuntar ahí sin mover archivos.
- **Compartidas**: recursos compartidos y permisos NTFS.
- **Características**: activa las características de Windows que falten (Hyper-V, WSL, Sandbox, .NET 3.5…). Nunca desactiva ninguna.
- **Paquetes**: winget, npm, pip, dotnet tool y módulos PowerShell. winget instala para todos los usuarios (`--scope machine`) si el paquete lo permite; si no, para el usuario y avisa. Extraer lista lo instalado solo para un usuario y sugiere comentado el equivalente en winget de lo instalado con Chocolatey o Scoop.
- **Menus**: menús contextuales que winget no añade, solo si el programa está instalado: «Abrir en Claude» (Claude Code), «Abrir con Code», «Buscar con Everything...» y la extensión de WinMerge.
- **Office**: instala Microsoft 365 / Office en silencio con la Office Deployment Tool oficial (`setup.exe` verificado por firma). La activación queda como pendiente manual. Paquetes no instala `Microsoft.Office` con winget si este módulo se encarga.
- **UniGetUI**: su configuración, en todos los perfiles y Default.
- **Steam**: imágenes, juegos no-Steam, colecciones y opciones de lanzamiento, con respaldos `*.wmud.bak`.
- **Wifi**, **UnidadesRed**, **Impresoras**, **Hosts**, **Entorno** (variables y PATH) y **Desarrollo** (`.gitconfig`, `.ssh`, perfiles de PowerShell, Windows Terminal, VS Code).
- **Navegadores**: favoritos de Edge, Chrome, Brave, Vivaldi, Opera y Firefox de cada usuario; se restauran si el perfil del navegador no tiene, y si no, queda un `favoritos.html` para importar.
- **Outlook**: firmas de Outlook clásico; las cuentas de correo (con servidores IMAP/POP) y los `.pst` quedan como pendientes.
- **Tareas**: tareas programadas de `\Personal\` (configurable con `CarpetasTareas`), con las cuentas por nombre para que funcionen en el equipo nuevo.

### Uso
- Menú interactivo y parámetros `-Accion`, `-Solo`, `-Omitir` (también como lista separada por comas), `-WhatIf`, `-DirConfig`, `-SinConfirmar`, `-SinReiniciar`.
- **`WinMudanza.cmd`**: lanzador de doble clic que pide Administrador y evita la directiva de ejecución.
- `config\perfil.psd1` elige los módulos y `config\ajustes.psd1` los ajustes; lo extraído queda fuera de git.
- Resumen final por módulo con errores, avisos y **pendientes**; log por ejecución en `logs\`.
- Documentación en `docs\`, ejemplos en `ejemplos\`, `Get-Help`.
- Pruebas: `pruebas\Probar-Sintaxis.ps1` y `pruebas\Abrir-Sandbox.ps1` (`-Probar`: prueba automática en Sandbox con `config\sandbox` generado).

### Respecto a OptimizarHP (v1)
- Los errores de cada paso llegan al resumen (antes siempre mostraba "OK").
- Ya no se usa `New-Item -Force` sobre claves existentes (borraba directivas de Edge al repetir).
- El plan Alto Rendimiento oculto se crea con su GUID estándar, de modo que se puede activar, y se muestra como activado solo después de activarlo.
- Se eliminan bloatware, servicios, tareas, telemetría, Copilot y seguridad (05 de v1), privacidad de aplicaciones (06 de v1) y los modos Personal / Empresarial.
