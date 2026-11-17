# WinMudanza

[![Licencia](https://img.shields.io/badge/licencia-LGPL--2.1-blue)](LICENSE)

Scripts de PowerShell para **mudarte de un Windows a otro**: dejar a punto un **Windows 11 recién instalado** con la configuración del equipo anterior.

- **Extraer**: lee la configuración del equipo actual (características de Windows, Wi-Fi, usuarios, carpetas compartidas, unidades de red, impresoras, programas, Office, variables de entorno, configuración de desarrollo, UniGetUI, Steam…) y la guarda en archivos `.psd1` que puedes revisar y editar.
- **Revisar**: antes de formatear, avisa de todo lo que esa configuración necesita y está en C: (y se perdería).
- **Copiar**: guarda WinMudanza con su configuración fuera de C: (otro disco o USB).
- **Aplicar**: en el equipo nuevo, aplica esos archivos y además una serie de ajustes de Windows (menú contextual clásico, terminales, Edge, Explorador, energía y PowerShell). Si hace falta reiniciar a mitad, **continúa sola** al volver a iniciar sesión.
- **Comparar**: muestra qué diferencias quedan entre la configuración y el equipo.

Todo es configurable: qué módulos se ejecutan, qué ajustes se aplican y qué datos se restauran. Antes de aplicar se puede **simular** para ver qué haría sin cambiar nada.

## Requisitos

- Windows 11 (probado en 24H2 / 25H2, Pro).
- Windows PowerShell 5.1 (viene con Windows). `WinMudanza.cmd` lo abre como Administrador.
- `winget` para reinstalar programas (viene con Windows 11 tras el primer inicio de sesión).

## Inicio rápido

En el **equipo actual**, doble clic en `WinMudanza.cmd` (o desde PowerShell):

```powershell
.\WinMudanza.cmd -Accion Extraer
```

1. Lee la **revisión** del final: lo marcado con `!!` está en C: y se perderá al formatear.
2. La configuración se copia sola a `D:\WinMudanza` (`CopiarA` en `config\perfil.psd1`). Si no tienes D:, usa `-Accion Copiar -Destino E:\WinMudanza` con un USB.
3. Instala Windows en el equipo nuevo.
4. En el **equipo nuevo**, doble clic en `D:\WinMudanza\WinMudanza.cmd` → opción **4) Aplicar** (o primero **5) Simulación**).
5. Si pide reiniciar, acepta: al volver a entrar sigue sola.
6. Revisa el **resumen final**: indica qué falló y qué queda **pendiente** de hacer a mano. **6) Comparar** confirma que no queda nada.

Las contraseñas de los usuarios locales se piden por pantalla al aplicar (o puedes escribirlas en `config\usuarios.psd1`).

## Módulos

| Módulo | Extrae | Aplica |
|---|---|---|
| **Ajustes** | — (se configura en `config\ajustes.psd1`) | Menú clásico, terminales en menú contextual, Edge, Explorador/barra de tareas, energía, PowerShell listo para scripts |
| **Wifi** | Redes Wi-Fi guardadas con su contraseña | Las añade para todos los usuarios |
| **Características** | Características de Windows activadas (Hyper-V, WSL, Sandbox, .NET 3.5…) | Activa las que falten (nunca desactiva) |
| **Usuarios** | Usuarios locales y grupos | Crea usuarios y asigna grupos |
| **Carpetas** | Descargas, Documentos, Música… de cada usuario que no están en su sitio (p. ej. en `D:`) | Las vuelve a apuntar ahí (no mueve archivos) |
| **Compartidas** | Recursos compartidos y permisos NTFS | Crea carpetas, las comparte y aplica permisos |
| **UnidadesRed** | Unidades de red mapeadas | Las vuelve a mapear |
| **Impresoras** | Impresoras de red / IP y la predeterminada | Las vuelve a añadir |
| **Hosts** | Entradas personalizadas de `hosts` | Añade las que falten |
| **Paquetes** | winget, npm, pip, dotnet tool, módulos PowerShell; sugiere el equivalente en winget de lo instalado con Chocolatey/Scoop | Los reinstala (winget, para todos los usuarios si se puede) |
| **Office** | Producto, idioma, canal y apps excluidas de Microsoft 365 | Lo instala en silencio con la herramienta oficial de Microsoft |
| **Menus** | — (se configura en `config\ajustes.psd1`) | Menús contextuales que winget no añade: «Abrir en Claude», «Abrir con Code», Everything, WinMerge |
| **Entorno** | Variables de entorno y PATH personalizados | Crea las que falten |
| **Desarrollo** | `.gitconfig`, `.ssh`, perfil de PowerShell, Windows Terminal, VS Code | Los restaura |
| **Navegadores** | Favoritos de Edge, Chrome, Brave, Vivaldi, Opera y Firefox de cada usuario | Los restaura si el navegador no tiene; si no, deja un HTML para importar |
| **Outlook** | Cuentas de correo, archivos `.pst` y firmas de Outlook clásico | Copia las firmas; las cuentas quedan como pendientes (solo piden email) |
| **Tareas** | Tareas programadas de la carpeta `\Personal\` del Programador de tareas | Registra las que falten |
| **UniGetUI** | Gestores activos, opciones, opciones de instalación | Las aplica a todos los usuarios |
| **Inicio** | Anclados del menú Inicio, de la barra de tareas y del Explorador (Acceso rápido y Favoritos), iconos del escritorio y programas de la carpeta Inicio | Los restaura una vez por usuario |
| **Steam** | Imágenes, juegos no-Steam, colecciones, opciones de lanzamiento | Las restaura (Steam se instala a mano) |

Detalle de cada uno en [docs/MODULOS.md](docs/MODULOS.md).

## ⚠️ Seguridad

Lo que genera Extraer contiene **secretos en texto plano**: contraseñas de usuarios (`usuarios.psd1`), de Wi-Fi (`wifi\`) y claves SSH privadas (`desarrollo\`). De `config\` solo se guardan en git `perfil.psd1` y `ajustes.psd1`; lo demás está excluido. No compartas esos archivos ni los subas a ningún sitio, y bórralos cuando termines la migración (también la copia de `CopiarA`).

## Documentación

| Documento | Contenido |
|---|---|
| [docs/GUIA_USO.md](docs/GUIA_USO.md) | Proceso completo paso a paso, menú, parámetros, simulación, logs |
| [docs/CONFIGURACION.md](docs/CONFIGURACION.md) | Todos los archivos `.psd1` campo por campo |
| [docs/MODULOS.md](docs/MODULOS.md) | Qué hace cada módulo, qué cambia y sus limitaciones |
| [docs/PROBLEMAS.md](docs/PROBLEMAS.md) | Errores frecuentes y soluciones |
| [docs/DESARROLLO.md](docs/DESARROLLO.md) | Arquitectura, cómo añadir módulos y ajustes, pruebas |
| [CHANGELOG.md](CHANGELOG.md) | Cambios por versión |
| [ejemplos/](ejemplos/) | Archivos de configuración de ejemplo con datos ficticios |

Ayuda desde PowerShell: `Get-Help .\WinMudanza.ps1 -Full`

## Licencia

Distribuido bajo la licencia **GNU Lesser General Public License v2.1**.  
Consulta el archivo [LICENSE](LICENSE) para más detalles.
