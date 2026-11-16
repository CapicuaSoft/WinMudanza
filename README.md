# OptimizarHP2

Scripts de PowerShell para dejar a punto un **Windows 11 recién instalado** y **trasladar la configuración** de un equipo a otro.

- **Extraer**: lee la configuración del equipo actual (usuarios, carpetas compartidas, programas, UniGetUI, Steam) y la guarda en archivos `.psd1` que puedes revisar y editar.
- **Aplicar**: en el equipo nuevo, aplica esos archivos y además una serie de ajustes de Windows (menú contextual clásico, terminales, Edge, Explorador y energía).

Todo es configurable: qué módulos se ejecutan, qué ajustes se aplican y qué datos se restauran. Antes de aplicar se puede **simular** para ver qué haría sin cambiar nada.

## Requisitos

- Windows 11 (probado en 24H2 / 25H2, Pro).
- Windows PowerShell 5.1 (viene con Windows) **ejecutado como Administrador**.
- `winget` para reinstalar programas (viene con Windows 11 tras el primer inicio de sesión).

## Inicio rápido

En el **equipo actual**:

```powershell
# PowerShell como Administrador
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\ruta\a\OptimizarHP2
.\OptimizarHP2.ps1 -Accion Extraer
```

1. Revisa `config\` y escribe las contraseñas en `config\usuarios.psd1` (donde ponga `'CAMBIAR'`).
2. Copia la carpeta `OptimizarHP2` completa a un sitio que sobreviva al formateo (otro disco, USB…).
3. Instala Windows en el equipo nuevo.
4. En el **equipo nuevo**, simula y aplica:

```powershell
.\OptimizarHP2.ps1 -Accion Aplicar -WhatIf   # solo muestra lo que haría
.\OptimizarHP2.ps1 -Accion Aplicar           # aplica de verdad
```

5. Revisa el **resumen final**: indica qué falló y qué queda **pendiente** de hacer a mano.

Sin parámetros, `.\OptimizarHP2.ps1` abre un **menú interactivo**.

## Módulos

| Módulo | Extrae | Aplica |
|---|---|---|
| **Ajustes** | — (se configura en `ajustes.psd1`) | Menú clásico, terminales en menú contextual, Edge, Explorador/barra de tareas, energía |
| **Usuarios** | Usuarios locales y grupos | Crea usuarios y asigna grupos |
| **Compartidas** | Recursos compartidos y permisos NTFS | Crea carpetas, las comparte y aplica permisos |
| **Paquetes** | winget, npm, pip, dotnet tool, módulos PowerShell | Los reinstala |
| **UniGetUI** | Gestores activos, opciones, opciones de instalación | Las aplica a todos los usuarios |
| **Steam** | Imágenes, juegos no-Steam, colecciones, opciones de lanzamiento | Las restaura (Steam se instala a mano) |

Detalle de cada uno en [docs/MODULOS.md](docs/MODULOS.md).

## ⚠️ Seguridad

`config\usuarios.psd1` contiene **contraseñas en texto plano**. La carpeta `config\` está excluida de git; no la compartas ni la subas a ningún sitio. Bórrala cuando termines la migración.

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

Ayuda desde PowerShell: `Get-Help .\OptimizarHP2.ps1 -Full`
