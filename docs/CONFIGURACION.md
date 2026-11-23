# Archivos de configuración

Todos los archivos son `.psd1` (formato de datos de PowerShell):

- `@{ ... }` es una tabla de `Clave = Valor`.
- `@( ... )` es una lista; cada elemento va en su línea.
- `$true` / `$false` para sí/no. Textos entre comillas simples `'texto'` (una comilla dentro se escribe doble: `'O''Brien'`).
- `#` comenta el resto de la línea: sirve para **desactivar un elemento de una lista** sin borrarlo.

Si un archivo tiene un error de formato, el script indica el archivo y la línea. Puedes comprobarlos todos con `.\pruebas\Probar-Sintaxis.ps1`.

Hay ejemplos con datos ficticios en [`ejemplos/`](../ejemplos/).

Todos están en `config\`:

| Archivo | Quién lo crea | En git |
|---|---|---|
| `perfil.psd1`, `ajustes.psd1` | Se editan a mano | Sí |
| El resto (`usuarios.psd1`, `paquetes.psd1`, `steam\`…) | Extraer | No (datos del equipo y contraseñas) |

`-DirConfig` cambia solo la carpeta de lo extraído; `perfil.psd1` y `ajustes.psd1` se leen siempre de `config\`.

---

## `config\perfil.psd1` — qué módulos se ejecutan

```powershell
@{
    DirConfig = 'config'
    Modulos = @{
        Ajustes     = @{ Extraer = $false; Aplicar = $true }
        Wifi            = @{ Extraer = $true;  Aplicar = $true }
        Caracteristicas = @{ Extraer = $true; Aplicar = $true }
        Usuarios    = @{ Extraer = $true;  Aplicar = $true }
        Compartidas = @{ Extraer = $true;  Aplicar = $true }
        Paquetes    = @{ Extraer = $true;  Aplicar = $true }
        Office      = @{ Extraer = $true;  Aplicar = $true }
        UniGetUI    = @{ Extraer = $true;  Aplicar = $true }
        Steam       = @{ Extraer = $true;  Aplicar = $false }   # p. ej. no restaurar Steam
    }
}
```

| Campo | Descripción |
|---|---|
| `DirConfig` | Carpeta de la configuración extraída (relativa a WinMudanza o absoluta). |
| `Modulos.<M>.Extraer` | Si el módulo se ejecuta al extraer. |
| `Modulos.<M>.Aplicar` | Si el módulo se ejecuta al aplicar. |

`-Solo` y `-Omitir` tienen prioridad sobre este archivo. En el menú se puede cambiar la selección antes de ejecutar.

---

Además, `perfil.psd1` tiene:

| Campo | Descripción |
|---|---|
| `CopiarA` | Carpeta fuera de C: donde Extraer copia WinMudanza con su configuración al terminar, y destino por defecto de `-Accion Copiar` (p. ej. `'D:\WinMudanza'`). Vacío = no copiar. |
| `ContinuarTrasReinicio` | `$true`: si un módulo necesita reiniciar, Aplicar se detiene, programa la tarea `WinMudanza-Continuar` y sigue al volver a iniciar sesión. `$false`: aplica todo seguido y deja el reinicio como pendiente. |
| `CarpetasTareas` | Carpetas del Programador de tareas que guarda y restaura el módulo Tareas. Por defecto `@('\Personal\')`. |

Otros módulos en `Modulos`: `Wifi`, `Carpetas`, `UnidadesRed`, `Impresoras`, `Hosts`, `Menus` (sin Extraer), `Entorno`, `Desarrollo`, `Navegadores`, `Outlook`, `Tareas`, `Inicio`.

---

## `config\ajustes.psd1` — ajustes de Windows

No se extrae: lo defines tú. Cada sección tiene `Activo` y sus opciones. Los ajustes de usuario se aplican a **todos los perfiles** y al perfil **Default** (lo heredan los usuarios nuevos).

| Sección | Campo | Efecto |
|---|---|---|
| (raíz) | `ReiniciarExplorer` | Reinicia el Explorador al terminar. |
| `MenuClasico` | `Activo` | Menú contextual clásico de Windows 10. |
| `Terminales` | `CmdAqui` | "Abrir CMD aquí" (normal y administrador) en carpetas y fondo. |
| | `PowerShellAqui` | "Abrir PowerShell aquí" (normal y administrador). |
| | `Ps1ComoAdmin` | Clic derecho en `.ps1` → ejecutar como administrador. |
| | `CmdComoAdmin` | Clic derecho en `.cmd` / `.bat` → ejecutar como administrador. |
| `Edge` | `TipoDirectiva` | `'Obligatoria'` (el usuario no puede cambiarlo) o `'Recomendada'` (valor inicial modificable). |
| | `PaginaInicio` | URL de inicio y al arrancar. Vacío = no tocar. |
| | `BotonInicio` | Muestra el botón Inicio. |
| | `Buscador.Nombre/Palabra/Url/Sugerir/Icono` | Buscador predeterminado. `Nombre` vacío = no tocar. |
| | `SinFeedNuevaPestana` | Nueva pestaña sin noticias ni sitios sugeridos. |
| | `SinSugerenciasBing` | Quita sugerencias de Bing en la barra de direcciones. |
| | `CerrarEdge` | Cierra Edge para que aplique al reabrir. |
| `Explorador` | `MostrarOcultos`, `MostrarExtensiones`, `MostrarArchivosSistema` | Visibilidad de archivos. |
| | `AbrirEnEsteEquipo`, `VistaCompacta`, `RutaCompletaEnTitulo` | Comportamiento del Explorador. |
| | `IconosCentrados`, `OcultarBotonWidgets`, `OcultarBotonChat`, `OcultarBusquedaBarra`, `SegundosEnReloj` | Barra de tareas. |
| | `FinalizarTareaEnBarra` | Añade «Finalizar tarea» al menú contextual de los programas en la barra de tareas. |
| | `DeshabilitarWidgets` | Directiva de equipo: el panel de Widgets no arranca. |
| | `OcultarSpotlightEscritorio` | Quita el icono "Descubre más sobre esta imagen". |
| | `QuitarRecomendadosInicio` | Quita "Recomendados" del menú Inicio. |
| | `OcultarOneDriveNavegacion` | Quita OneDrive del panel lateral: la cuenta personal y las de trabajo o escuela («OneDrive - Organización»). Todos los perfiles. |
| | `OcultarGaleriaNavegacion` | Quita Galería del panel lateral. Todos los perfiles. |
| | `DesanclarCarpetas` | Lista de carpetas a desanclar de Inicio: `Desktop`, `MyPictures`, `MyMusic`, `MyVideos`, `MyDocuments`… (solo usuario actual). |
| | `DesanclarGaleria`, `AnclarCarpetaPersonal` | Galería fuera de Inicio (la vista de Acceso rápido) y carpeta personal anclada. Solo usuario actual. |
| `Energia` | `PlanAltoRendimiento` | Activa Alto Rendimiento (lo crea si el fabricante lo oculta). |
| | `SinSuspensionUSB`, `DiscoNuncaApagar` | Ajustes del plan. |
| | `SinPowerThrottling` | No limita la CPU de procesos en segundo plano. |
| | `EfectosVisualesRendimiento` | Efectos visuales: mejor rendimiento. |
| | `SinGameModeNiGameDVR` | Desactiva Game Mode y grabación en segundo plano. |
| | `SinHibernacion` | Borra `hiberfil.sys` (también desactiva el inicio rápido). |

> La sección `Energia` está pensada para **equipos de sobremesa**. En un portátil desactiva `PlanAltoRendimiento`, `SinSuspensionUSB` y `SinHibernacion`.

### Sección `PowerShell` (06)

| Campo | Descripción |
|---|---|
| `DirectivaEjecucion` | Directiva de todo el equipo: `RemoteSigned` (recomendada: tus scripts sí, los descargados deben estar firmados o desbloqueados), `AllSigned`, `Unrestricted`, `Bypass`. Vacío = no tocar. Se aplica a Windows PowerShell 5.1 y, si está instalado, a PowerShell 7. |
| `NuGetYGaleria` | Instala el proveedor NuGet y marca PowerShell Gallery como de confianza: `Install-Module` sin preguntas. |
| `Tls12` | .NET Framework usa siempre TLS 1.2+ (evita errores de descarga en PowerShell 5.1). |
| `DobleClicEjecuta` | Doble clic en un `.ps1` lo ejecuta con PowerShell (antes abría el Bloc de notas). *Editar* sigue en el clic derecho. |

### Sección `EscritorioRemoto` (07)

Solo Windows Pro, Enterprise o Education (Home no puede recibir conexiones). Los usuarios que no sean administradores necesitan el grupo *Usuarios de escritorio remoto* en `usuarios.psd1`.

| Campo | Descripción |
|---|---|
| `Permitir` | Acepta conexiones de Escritorio remoto a este equipo. |
| `NLA` | Exige autenticación a nivel de red (recomendado). |
| `Firewall` | Activa las reglas del Firewall de Windows del grupo *Escritorio remoto*. |

### Sección `RutasLargas` (08)

| Campo | Descripción |
|---|---|
| `Activo` | Permite rutas de más de 260 caracteres en Windows (`LongPathsEnabled = 1`), para todos los usuarios. Git usa su propia opción (`Winget.GitConfig` en `paquetes.psd1`). |

### Sección `Menus` (módulo Menus)

La usa el módulo **Menus**, que se ejecuta después de Paquetes. Cada menú se añade solo si el programa está instalado.

| Campo | Descripción |
|---|---|
| `Activo` | `$false` desactiva el módulo entero. |
| `ClaudeCode` | «Abrir en Claude» en carpetas: Claude Code en Windows Terminal (o PowerShell). |
| `VSCode` | «Abrir con Code» en archivos y carpetas. |
| `Everything` | «Buscar con Everything...» en carpetas. |
| `WinMerge` | Extensión del Explorador de WinMerge (comparar archivos y carpetas). |
| `Sourcetree` | «Abrir en Sourcetree» en carpetas: abre el repositorio en Sourcetree. |
| `QuitarAbrirTerminal` | Oculta «Abrir en Terminal» (Windows Terminal) para todos los usuarios. |
| `QuitarGitGui`, `QuitarGitBash` | Ocultan «Open Git GUI here» y «Open Git Bash here». |

---

## `config\wifi.psd1`

```powershell
@{ Redes = @( @{ Nombre = 'MiCasa'; Archivo = 'Wi-Fi-MiCasa.xml' } ) }
```

`Archivo` es el perfil exportado en `config\wifi\` (XML de Windows, con la contraseña en claro). Comenta una red para no añadirla.

---

## `config\caracteristicas.psd1`

```powershell
@{
    Activar = @(
        'Containers-DisposableClientVM'
        'Microsoft-Hyper-V-All'
        'Microsoft-Windows-Subsystem-Linux'
        'NetFx3'
        # 'WindowsMediaPlayer'      <- comentada: no se activa
    )
}
```

- `Activar`: nombres técnicos de las características (la cabecera del archivo extraído incluye la descripción de cada una).
- Solo se activan; quitar una de la lista **no** la desactiva en el equipo nuevo.
- Para ver todas las disponibles: `Get-WindowsOptionalFeature -Online | Sort-Object FeatureName` (como Administrador).

---

## `config\usuarios.psd1`

| Campo | Descripción |
|---|---|
| `Usuarios[].Nombre` | Nombre de usuario. |
| `Usuarios[].NombreCompleto`, `Descripcion` | Datos informativos (descripción: máx. 48 caracteres). |
| `Usuarios[].Password` | **Hay que rellenarla.** `'CAMBIAR'` = sin completar (el usuario no se crea). `''` = sin contraseña. |
| `Usuarios[].PasswordNuncaExpira` | La contraseña no caduca. |
| `Usuarios[].Activo` | `$false` crea la cuenta deshabilitada. |
| `Usuarios[].Grupos` | Grupos locales a los que pertenece. |
| `CuentasMicrosoft[]` | Cuentas que inician sesión con email: no se crean, quedan como pendientes. Si ya existen en el equipo, se les asignan sus grupos. |
| `GruposSid` | SID de los grupos de Windows (para encontrarlos en otro idioma). No editar. |

Si un usuario ya existe, **no se cambia su contraseña**; solo se añaden los grupos que falten.

---

## `config\compartidas.psd1`

| Campo | Descripción |
|---|---|
| `Nombre` | Nombre del recurso compartido (`\\EQUIPO\Nombre`). |
| `Ruta` | Carpeta. Cámbiala si en el equipo nuevo es otra. |
| `Descripcion` | Texto del recurso. |
| `CrearCarpeta` | `$true` crea la carpeta si no existe (vacía). |
| `Acceso[]` | Permisos del recurso: `Cuenta`, `Sid`, `Derecho` (`Full`, `Change`, `Read`), `Tipo` (`Allow`, `Deny`). |
| `NTFS.HerenciaDesactivada` | `$true` si la carpeta no hereda permisos de su carpeta padre. |
| `NTFS.Permisos[]` | Permisos explícitos: `Cuenta`, `Sid`, `Derechos` (`FullControl`, `Modify`, `ReadAndExecute`, `Read`, `Write`… combinables con coma), `Tipo`, `Herencia`, `Propagacion`. |

Las cuentas locales se buscan **por nombre** (su SID cambia al reinstalar). Las de Windows (`Everyone`/`Todos`, `Administradores`, `SYSTEM`…) se buscan por **SID**, así funcionan en cualquier idioma.

---

## `config\unidadesred.psd1`

```powershell
@{ Unidades = @( @{ Letra = 'Z'; Ruta = '\\nas\fotos'; Usuario = '' } ) }
```

`Usuario` vacío = la cuenta de Windows. La contraseña la pide Windows al conectar.

---

## `config\impresoras.psd1`

```powershell
@{
    Impresoras = @(
        @{ Tipo = 'IP';  Nombre = 'Impresora salon'; Direccion = '192.168.1.50'; PuertoTcp = 9100; Controlador = 'Microsoft IPP Class Driver' }
        @{ Tipo = 'Red'; Nombre = '\\servidor\Laser'; Conexion = '\\servidor\Laser' }
    )
    Predeterminada = 'Impresora salon'    # vacío = no cambiar
}
```

---

## `config\carpetas.psd1`

```powershell
@{
    Usuarios = @{
        ana = @{ Descargas = 'D:\Descargas'; Musica = 'D:\Musica' }
    }
}
```

Carpetas válidas: `Escritorio`, `Documentos`, `Descargas`, `Musica`, `Imagenes`, `Videos`, `Favoritos`. Solo se guardan las que no están en su sitio por defecto ni en OneDrive. Al aplicar no se mueve ningún archivo.

---

## `config\tareas.psd1` + `config\tareas\`

```powershell
@{
    Tareas = @(
        @{ Carpeta = '\Personal\'; Nombre = 'Copia nocturna'; Archivo = 'Personal\Copia nocturna.xml'; Cuentas = @('ana'); Activa = $true }
    )
}
```

| Campo | Descripción |
|---|---|
| `Carpeta`, `Nombre` | Dónde se registra la tarea en el Programador de tareas. |
| `Archivo` | XML de la tarea dentro de `config\tareas\` (se puede editar, p. ej. para cambiar la ruta de un programa). |
| `Cuentas` | Usuarios de la tarea, por nombre (informativo: los nombres están dentro del XML). |
| `Activa` | `$false` la registra desactivada. |

Para no restaurar una tarea, borra o comenta su bloque.

---

## `config\inicio.psd1` + `config\inicio\`

```powershell
@{
    Usuarios = @(
        @{
            Usuario     = 'ana'
            MenuInicio  = $true
            BarraTareas = @('File Explorer.lnk', 'Microsoft Edge.lnk')
            Taskband    = @{ ... }     # registro de la barra de tareas (no editar)
            AccesoRapido = @('shell:Downloads', 'D:\Datos', '%USERPROFILE%')
            Favoritos   = @('D:\Datos
otas.txt')
            Escritorio  = @('Absolum Demo.url')
            IconosSistema = @{ ... }   # iconos de Windows visibles (no editar)
            Posiciones  = @{ ... }     # posición de los iconos (no editar)
            AlIniciar   = @('Password Safe.lnk')
        }
    )
    AlIniciarComun  = @()
    EscritorioComun = @('CPUID CPU-Z.lnk')
}
```

| Campo | Descripción |
|---|---|
| `MenuInicio` | `$true` si se guardaron los anclados del menú Inicio. `$false` para no restaurarlos. |
| `BarraTareas` | Accesos anclados a la barra de tareas. `@()` para no restaurar la barra. |
| `Taskband` | Valores del registro de la barra de tareas (binarios en base64). No editar. |
| `AccesoRapido` | Carpetas ancladas a Acceso rápido del Explorador, en orden. `shell:<nombre>` = carpeta conocida del usuario (`shell:Downloads`, `shell:Personal`…); admite `%USERPROFILE%` y otras variables. `@()` para no tocar los anclados de ese usuario. |
| `Favoritos` | Archivos en Favoritos del Explorador (Windows 11), en orden. `@()` para no tocarlos. |
| `Escritorio` | Accesos directos del escritorio del usuario; se copian los que falten. |
| `IconosSistema` | Iconos de Windows que se muestran en el escritorio (registro, no editar). `@{}` para no restaurarlos. |
| `Posiciones` | Posición de los iconos del escritorio (registro, no editar). `@{}` para no restaurarla. |
| `AlIniciar` | Accesos de la carpeta Inicio del usuario; se copian los que falten. |
| `AlIniciarComun` | Accesos de la carpeta Inicio común (todos los usuarios). |
| `EscritorioComun` | Accesos del escritorio público (todos los usuarios). |

Los archivos están en `config\inicio\<usuario>\` (`MenuInicio`, `BarraTareas`, `Escritorio`, `AlIniciar`) y `config\inicio\_Comun\`. El menú Inicio, la barra, los anclados del Explorador, los iconos de Windows y las posiciones se restauran una sola vez por usuario: para volver a restaurarlos, borra la clave `HKCU\Software\WinMudanza\Inicio` de ese usuario.

---

## `config
avegadores.psd1` + `config
avegadores\`

```powershell
@{
    Favoritos = @(
        @{ Usuario = 'ana'; Navegador = 'Edge'; Perfil = 'Default'; Carpeta = 'ana\Edge\Default'; Favoritos = 120 }
        @{ Usuario = 'ana'; Navegador = 'Firefox'; Perfil = 'abcd1234.default-release'; Carpeta = 'ana\Firefoxbcd1234.default-release'; Archivo = 'bookmarks-2026-11-16.jsonlz4' }
    )
}
```

| Campo | Descripción |
|---|---|
| `Usuario` | Usuario de Windows (por nombre). |
| `Navegador` | `Edge`, `Chrome`, `Brave`, `Vivaldi`, `Opera` o `Firefox`. |
| `Perfil` | Perfil del navegador (`Default`, `Profile 1`…). |
| `Carpeta` | Dentro de `config
avegadores\`: `Bookmarks` y `favoritos.html` (o la copia de Firefox). |
| `Favoritos` | Número de favoritos guardados (si el destino tiene menos, se avisa). |

Para no restaurar una entrada, borra o comenta su bloque. `favoritos.html` se puede importar a mano en cualquier navegador.

---

## `config\outlook.psd1` + `config\outlook\`

```powershell
@{
    Usuarios = @(
        @{
            Usuario = 'ana'
            Cuentas = @(
                @{ Perfil = 'Outlook'; Email = 'ana@empresa.com'; Tipo = 'Exchange / Microsoft 365 / Outlook.com' }
                @{ Perfil = 'Outlook'; Email = 'ana@correo.es'; Tipo = 'IMAP'; Entrada = 'imap.correo.es:993 (SSL)'; Salida = 'smtp.correo.es:465 (SSL)' }
            )
            ArchivosPst = @('D:\Correo\Archivo 2020.pst')
            Firmas = $true
        }
    )
}
```

`Cuentas` y `ArchivosPst` son informativos: al aplicar quedan como pendientes. Las firmas se copian desde `config\outlook\<usuario>\Firmas` (solo las que falten).

---

## `config\hosts.psd1`

```powershell
@{ Entradas = @( '192.168.1.10 nas.casa' ) }
```

Se añaden las que falten; quitar una de la lista **no** la borra del equipo.

---

## `config\paquetes.psd1`

```powershell
Winget     = @{ Activo = $true; GitFlow = $true; GitConfig = $true; Paquetes = @( 'Git.Git' ... ) }
Npm        = @{ Activo = $true; Paquetes = @( ... ) }
Pip        = @{ Activo = $true; Paquetes = @( ... ) }
DotnetTool = @{ Activo = $true; Paquetes = @( ... ) }
PowerShell = @{ Activo = $true; Paquetes = @( ... ) }
```

- `Activo = $false` desactiva el gestor entero.
- Comenta con `#` los paquetes que no quieras.
- Los identificadores de winget son los de `winget search` (columna *Id*).
- Se instala siempre la última versión, para todos los usuarios si el paquete lo permite.
- `Winget.GitFlow = $true`: si en la lista está Git (`Git.Git` o `Microsoft.Git`) y `git flow` no funciona, instala git-flow-next (`GitTower.GitFlowNext`). Extraer lo pone a `$true` cuando Git está en la lista; `$false` lo desactiva.
- `Winget.GitConfig = $true`: si en la lista está Git, después de instalarlo pone `git config --system core.autocrlf false` (no cambia los saltos de línea de los archivos) y `core.longpaths true` (rutas largas). Extraer lo pone a `$true` cuando Git está en la lista; `$false` lo desactiva.
- Al final de `Winget` pueden aparecer **comentados** los equivalentes de lo instalado con Chocolatey o Scoop: quita el `#` de los que quieras instalar.

`paquetes_no_reinstalables.txt` es solo informativo.

---

## `config\office.psd1`

```powershell
@{
    Activo          = $true
    Arquitectura    = '64'
    Canal           = 'Current'
    Idiomas         = @( 'es-mx' )
    Productos       = @(
        @{ Id = 'O365HomePremRetail'; Excluir = @( 'Access', 'Publisher', 'OneNote', 'OneDrive', 'Teams', 'Groove', 'Lync' ) }
    )
    Actualizaciones = $true
    Silencioso      = $true
}
```

| Campo | Descripción |
|---|---|
| `Activo` | `$false` = no instalar Office. |
| `Arquitectura` | `'64'` o `'32'`. |
| `Canal` | `Current`, `MonthlyEnterprise`, `SemiAnnual`, `CurrentPreview`, `BetaChannel`. |
| `Idiomas` | Códigos de idioma (`es-mx`, `es-es`, `en-us`…) o `MatchOS` (el de Windows). |
| `Productos` | Uno o varios productos. `Id`: `O365HomePremRetail` (Microsoft 365 Familia/Personal), `O365ProPlusRetail` (Apps para empresa), `ProPlus2024Retail`, `VisioProRetail`… |
| `Productos.Excluir` | Aplicaciones que no se instalan: `Access`, `Excel`, `Groove`, `Lync`, `OneDrive`, `OneNote`, `Outlook`, `OutlookForWindows`, `PowerPoint`, `Publisher`, `Teams`, `Word`, `Bing`. |
| `Actualizaciones` | `$true` = Office se actualiza solo. |
| `Silencioso` | `$true` = sin ventanas; `$false` = muestra el progreso de instalación. |

Equivale al `configuration.xml` de la Office Deployment Tool; el módulo lo genera al aplicar.

---

## `config\entorno.psd1`

```powershell
@{
    Equipo  = @{ Variables = @{ JAVA_HOME = 'C:\Program Files\...' }; Path = @( 'C:\Program Files\Git\cmd' ) }
    Usuario = @{ Variables = @{ JD2_HOME = '%ProgramFiles%\JDownloader' }; Path = @( '%APPDATA%\npm' ) }
}
```

- `Variables`: se crean las que falten; las que ya existen con otro valor no se cambian (se avisa).
- `Path`: carpetas que se añaden al final si faltan y existen.
- `Usuario` se aplica al usuario que ejecuta WinMudanza.

---

## `config\desarrollo.psd1`

```powershell
@{ Elementos = @( @{ Nombre = 'Git'; Ruta = '%USERPROFILE%\.gitconfig'; Archivo = '01_.gitconfig' } ) }
```

- `Archivo`: copia guardada en `config\desarrollo\` (archivo o carpeta).
- `Ruta`: destino; admite `%USERPROFILE%`, `%APPDATA%`, `%LOCALAPPDATA%`… y `{Documentos}` (la carpeta Documentos, aunque esté en OneDrive).
- Para añadir otros archivos de forma permanente, amplía la lista de candidatos en `modulos\Desarrollo.ps1`.

---

## `config\unigetui.psd1`

| Campo | Descripción |
|---|---|
| `Gestores` | `NombreGestor = $true/$false` (activo/desactivado en UniGetUI). |
| `OpcionesActivadas` | Opciones marcadas de UniGetUI (cada una es un archivo vacío en su configuración). |
| `ArchivosDeValor` | Opciones con valor; se copian desde `config\unigetui\Configuration\`. |
| `OpcionesInstalacion` | `$true` copia las opciones de instalación por paquete (`config\unigetui\InstallationOptions\`). |
| `QuitarInicioAutomatico` | `$true` quita el inicio automático de UniGetUI (entrada `Run`, en el equipo y en todos los perfiles) porque lo inicia una tarea programada, por ejemplo como administrador. Extraer lo pone a `$true` si hay una tarea que ejecuta `UniGetUI.exe`. |

---

## `config\steam.psd1`

| Campo | Descripción |
|---|---|
| `RutaSteam` | Carpeta de Steam en el equipo nuevo. Vacío = detectar. |
| `Cuentas[].Id` | Cuenta de Steam de origen (`userdata\<Id>`). |
| `Cuentas[].Destino` | `'auto'` = misma cuenta, o la única existente. O un Id concreto. |
| `Imagenes`, `JuegosNoSteam`, `Colecciones`, `Lanzamiento` | `$false` para no aplicar esa parte. |
| `Accesos[]` | Juegos no-Steam tal como los guarda Steam. Puedes cambiar `AppName`, `Exe`, `StartDir`, `LaunchOptions`. **No cambies `appid`** (es el nombre de sus imágenes). |
| `OpcionesLanzamiento` | `'appid' = 'opciones'` de los juegos de Steam. |
