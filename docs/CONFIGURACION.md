# Archivos de configuración

Todos los archivos son `.psd1` (formato de datos de PowerShell):

- `@{ ... }` es una tabla de `Clave = Valor`.
- `@( ... )` es una lista; cada elemento va en su línea.
- `$true` / `$false` para sí/no. Textos entre comillas simples `'texto'` (una comilla dentro se escribe doble: `'O''Brien'`).
- `#` comenta el resto de la línea: sirve para **desactivar un elemento de una lista** sin borrarlo.

Si un archivo tiene un error de formato, el script indica el archivo y la línea. Puedes comprobarlos todos con `.\pruebas\Probar-Sintaxis.ps1`.

Hay ejemplos con datos ficticios en [`ejemplos/`](../ejemplos/).

---

## `perfil.psd1` — qué módulos se ejecutan

```powershell
@{
    DirConfig = 'config'
    Modulos = @{
        Ajustes     = @{ Extraer = $false; Aplicar = $true }
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
| `DirConfig` | Carpeta de la configuración extraída (relativa a OptimizarHP2 o absoluta). |
| `Modulos.<M>.Extraer` | Si el módulo se ejecuta al extraer. |
| `Modulos.<M>.Aplicar` | Si el módulo se ejecuta al aplicar. |

`-Solo` y `-Omitir` tienen prioridad sobre este archivo. En el menú se puede cambiar la selección antes de ejecutar.

---

## `ajustes.psd1` — ajustes de Windows

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
| | `DeshabilitarWidgets` | Directiva de equipo: el panel de Widgets no arranca. |
| | `OcultarSpotlightEscritorio` | Quita el icono "Descubre más sobre esta imagen". |
| | `QuitarRecomendadosInicio` | Quita "Recomendados" del menú Inicio. |
| | `OcultarOneDriveNavegacion` | Quita OneDrive del panel lateral. |
| | `DesanclarCarpetas` | Lista de carpetas a desanclar de Inicio: `Desktop`, `MyPictures`, `MyMusic`, `MyVideos`, `MyDocuments`… (solo usuario actual). |
| | `DesanclarGaleria`, `AnclarCarpetaPersonal` | Solo usuario actual. |
| `Energia` | `PlanAltoRendimiento` | Activa Alto Rendimiento (lo crea si el fabricante lo oculta). |
| | `SinSuspensionUSB`, `DiscoNuncaApagar` | Ajustes del plan. |
| | `SinPowerThrottling` | No limita la CPU de procesos en segundo plano. |
| | `EfectosVisualesRendimiento` | Efectos visuales: mejor rendimiento. |
| | `SinGameModeNiGameDVR` | Desactiva Game Mode y grabación en segundo plano. |
| | `SinHibernacion` | Borra `hiberfil.sys` (también desactiva el inicio rápido). |

> La sección `Energia` está pensada para **equipos de sobremesa**. En un portátil desactiva `PlanAltoRendimiento`, `SinSuspensionUSB` y `SinHibernacion`.

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

## `config\paquetes.psd1`

```powershell
Winget     = @{ Activo = $true; Paquetes = @( 'Git.Git' ... ) }
Npm        = @{ Activo = $true; Paquetes = @( ... ) }
Pip        = @{ Activo = $true; Paquetes = @( ... ) }
DotnetTool = @{ Activo = $true; Paquetes = @( ... ) }
PowerShell = @{ Activo = $true; Paquetes = @( ... ) }
```

- `Activo = $false` desactiva el gestor entero.
- Comenta con `#` los paquetes que no quieras.
- Los identificadores de winget son los de `winget search` (columna *Id*).
- Se instala siempre la última versión.

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

## `config\unigetui.psd1`

| Campo | Descripción |
|---|---|
| `Gestores` | `NombreGestor = $true/$false` (activo/desactivado en UniGetUI). |
| `OpcionesActivadas` | Opciones marcadas de UniGetUI (cada una es un archivo vacío en su configuración). |
| `ArchivosDeValor` | Opciones con valor; se copian desde `config\unigetui\Configuration\`. |
| `OpcionesInstalacion` | `$true` copia las opciones de instalación por paquete (`config\unigetui\InstallationOptions\`). |

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
