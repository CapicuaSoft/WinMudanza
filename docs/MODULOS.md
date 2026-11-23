# Módulos

Orden de ejecución al aplicar: **Ajustes → Wifi → Características → Usuarios → Carpetas → Compartidas → Unidades de red → Impresoras → Hosts → Paquetes → Office → Menús → Entorno → Desarrollo → UniGetUI → Navegadores → Outlook → Tareas → Inicio → Steam**.

Los módulos que tienen bloque `Revisar` (Usuarios, Carpetas, Compartidas, Outlook, Tareas, Steam) participan en la **revisión antes de formatear** (`-Accion Revisar` y al final de Extraer).

Todos los módulos son **repetibles**: lo que ya está aplicado se salta, así que se pueden volver a ejecutar para completar pendientes.

---

## Ajustes

**Extrae:** nada (los valores están en `ajustes.psd1`).
**Aplica:** 7 grupos de ajustes de la carpeta `modulos\Ajustes\`, cada uno activable por separado.

| Ajuste | Ámbito | Qué cambia |
|---|---|---|
| 01 Menú clásico | Usuario (todos los perfiles) | `HKCU\Software\Classes\CLSID\{86ca1aa0-…}\InprocServer32` |
| 02 Terminales | Equipo | Verbos en `HKLM\SOFTWARE\Classes\Directory\shell`, `Directory\Background\shell`, `.ps1`, `cmdfile`, `batfile` |
| 03 Edge | Equipo | Directivas en `HKLM\SOFTWARE\Policies\Microsoft\Edge` (o `\Recommended`) |
| 04 Explorador | Usuario + equipo | `Explorer\Advanced` (y `TaskbarDeveloperSettings`), `CabinetState`, `Search`, directivas `Dsh`, `CloudContent`, `Explorer`; anclados con Shell COM |
| 05 Energía | Equipo + usuario | `powercfg`, `PowerThrottling`, `VisualEffects`, `GameBar`, `GameConfigStore` |
| 06 PowerShell | Equipo (galería: usuario que ejecuta) | Directiva de ejecución (`ShellIds\Microsoft.PowerShell`, y PowerShell 7 si está), NuGet + PSGallery de confianza, TLS 1.2 en .NET (`SchUseStrongCrypto`, `SystemDefaultTlsVersions`), doble clic en `.ps1` (`Microsoft.PowerShellScript.1\Shell`) |
| 07 Escritorio remoto | Equipo | Permite conexiones (`Terminal Server\fDenyTSConnections = 0`), exige NLA (`WinStations\RDP-Tcp\UserAuthentication = 1`), activa las reglas del Firewall del grupo Escritorio remoto (por su recurso: vale en cualquier idioma) y, si `TermService` está deshabilitado, lo pone en Manual |
| 08 Rutas largas | Equipo | `FileSystem\LongPathsEnabled = 1`: rutas de más de 260 caracteres en los programas que lo admiten (npm, pip, PowerShell 7, .NET…). El Explorador sigue limitado. Git usa `core.longpaths` (Paquetes) |

**Cómo llega a todos los usuarios:**
- Perfiles con sesión abierta: se escribe en su registro cargado.
- Perfiles sin sesión: se carga su `NTUSER.DAT` (y `UsrClass.dat`) temporalmente con `reg load`.
- Perfil **Default** (plantilla de usuarios nuevos): se escribe en su `NTUSER.DAT`. Las claves de *Classes* (menú clásico, OneDrive y Galería en el panel lateral) no se heredan de Default, así que se programan con **RunOnce** para el primer inicio de sesión de cada usuario nuevo.

**Limitaciones:**
- Windows 11 24H2+ protege algunas claves de la barra de tareas (`TaskbarDa`, a veces `SearchboxTaskbarMode`). Si falla, se muestra un aviso y se continúa.
- Anclar/desanclar carpetas en Inicio solo funciona para el usuario que ejecuta el script.
- 06 PowerShell: una directiva de grupo de ejecución tiene prioridad (se avisa). Si un usuario eligió un programa para abrir `.ps1` ("Abrir con…"), su elección gana al doble clic. La confianza en PowerShell Gallery es por usuario.
- 07 Escritorio remoto: Windows Home no puede recibir conexiones (se avisa y no cambia nada). Los administradores pueden conectarse; el resto de usuarios necesita el grupo *Usuarios de escritorio remoto* (módulo Usuarios). Con cuenta Microsoft se entra con el email y su contraseña (no el PIN).
- Edge muestra *"Administrado por tu organización"* mientras haya directivas. En equipos sin dominio, Edge puede ignorar las directivas **obligatorias** de página de inicio y buscador: compruébalo en `edge://policy` y, si aparecen con error, usa `TipoDirectiva = 'Recomendada'`.
- Los perfiles de usuarios con sesión abierta en otra sesión pueden no poder cargarse: se avisa y se omiten.

---

## Wifi

**Extrae:** `netsh wlan export profile key=clear` → `config\wifi\*.xml` (perfiles de Windows con la contraseña **en claro**; necesita Administrador para incluirla). Si el equipo no usa Wi-Fi (servicio `wlansvc` detenido), no extrae nada.

**Aplica:** `netsh wlan add profile user=all` de las redes que falten (para todos los usuarios). Va pronto para tener internet antes de Paquetes y Office.

**Limitaciones:** redes empresariales (802.1X con certificado) pueden necesitar el certificado o volver a iniciar sesión en la red.

---

## Características

Módulo `Caracteristicas`: las de *Activar o desactivar las características de Windows*.

**Extrae:** las características activadas (`Win32_OptionalFeature`; no necesita Administrador). Se guardan todas, también las que Windows 11 trae activadas de serie.

**Aplica:** activa con `Enable-WindowsOptionalFeature -All -NoRestart` las que falten. **Nunca desactiva** ninguna. Las que ya estén activadas se saltan.

**Pendiente:** reiniciar el equipo si alguna lo necesita (Hyper-V, WSL, Sandbox…).

**Va antes de Paquetes** para que la virtualización esté lista antes de instalar programas que la usan (Docker, distribuciones de WSL).

**Limitaciones:**
- Las que no existen en la edición de destino (p. ej. Hyper-V o Sandbox en Windows Home) se avisan y se saltan.
- .NET Framework 3.5 (`NetFx3`) se descarga de Windows Update: necesita internet.
- Hyper-V y Sandbox necesitan la virtualización activada en la BIOS/UEFI.
- No incluye las *características opcionales* de Configuración (OpenSSH, Paint, idiomas…) ni las distribuciones de WSL.

---

## Usuarios

**Extrae:** usuarios locales (nombre, nombre completo, descripción, activo, caducidad de contraseña, grupos). Omite cuentas del sistema (Administrador integrado, Invitado, DefaultAccount, WDAGUtilityAccount, WsiAccount).
**Aplica:** crea los usuarios que no existan y añade los grupos que falten.

**Limitaciones:**
- **Windows no permite extraer contraseñas.** Hay que escribirlas en `usuarios.psd1`; un usuario con `'CAMBIAR'` no se crea (error).
- **Cuentas Microsoft** (inicio de sesión con email): no se pueden crear por script. Se listan como pendientes; cuando alguien inicia sesión con ellas, volver a ejecutar asigna sus grupos.
- Si el usuario ya existe no se cambia su contraseña.
- Los grupos de Windows se buscan por SID, por lo que funciona aunque el equipo nuevo esté en otro idioma.

---

## Carpetas

**Extrae:** de cada perfil, las carpetas personales (Escritorio, Documentos, Descargas, Música, Imágenes, Vídeos, Favoritos) que apuntan **fuera** de la carpeta del usuario, por ejemplo Descargas en `D:\Downloads`. Las que están en su sitio por defecto o en OneDrive no se guardan (OneDrive las vuelve a mover él solo al iniciar sesión).

**Aplica:** escribe la nueva ubicación en `User Shell Folders` del perfil (los dos valores que usa Windows para cada carpeta) y crea la carpeta de destino si falta. **No mueve archivos.** El usuario lo ve al volver a iniciar sesión.

**Depende de:** Usuarios (el usuario debe tener perfil).

**Revisar:** avisa si alguna carpeta está en C: fuera del perfil (se borrará al formatear).

**Limitaciones:**
- Un usuario sin perfil todavía (por ejemplo, una cuenta Microsoft que aún no ha iniciado sesión) queda como pendiente: inicia sesión con él una vez y ejecuta `-Solo Carpetas`.
- Si la unidad de destino no existe (por ejemplo, no hay `D:`), da error y no cambia esa carpeta.

---

## Compartidas

**Extrae:** recursos compartidos (excepto los administrativos `C$`, `ADMIN$`, `IPC$`, `print$`…), sus permisos de recurso y los permisos NTFS **explícitos** de cada carpeta.
**Aplica:** crea la carpeta si falta, la comparte (o revisa el recurso existente) y añade los permisos NTFS que falten.

**Depende de:** Usuarios (las cuentas deben existir para darles permisos).

**Limitaciones:**
- Los permisos de cuentas que todavía no existen se omiten con aviso y quedan como pendientes.
- Los permisos NTFS se **añaden**; no se quitan los que ya tenga la carpeta (por ejemplo, entradas huérfanas de la instalación anterior).
- Aplicar permisos en carpetas muy grandes puede tardar (Windows los propaga a todo el contenido).
- Si ya existe un recurso con el mismo nombre pero otra ruta, se da error y no se toca.

---

## Unidades de red

**Extrae:** `HKCU\Network` del usuario que ejecuta (unidades mapeadas persistentes: letra, ruta y usuario).

**Aplica:** escribe esas claves en `HKCU\Network` del usuario que ejecuta; Windows las conecta al iniciar sesión. No se usa `net use` porque, ejecutado como Administrador, crea la unidad solo para la sesión elevada y no se ve en el Explorador.

**Limitaciones:** no guarda contraseñas de los servidores (Windows las pedirá la primera vez). Si la letra ya está en uso o apunta a otro sitio, se avisa y no se cambia.

---

## Impresoras

**Extrae:** impresoras compartidas (`\\servidor\impresora`), impresoras con puerto TCP/IP (dirección, puerto, controlador) y la predeterminada. Las virtuales (PDF, XPS, OneNote, Fax), USB y WSD no se guardan: Windows las detecta solo.

**Aplica:** reconecta las compartidas (usuario que ejecuta), crea puerto + impresora para las de IP (todo el equipo) y fija la predeterminada (usuario que ejecuta; desactiva "Permitir que Windows administre la impresora predeterminada"). Si la Cola de impresión está detenida o deshabilitada, la inicia.

**Limitaciones:** las impresoras IP necesitan su controlador. Se intenta con los incluidos en Windows; si no, queda como pendiente instalarlo.

---

## Hosts

**Extrae:** las líneas útiles (no comentarios) de `C:\Windows\System32\drivers\etc\hosts`.

**Aplica:** añade al final las que falten, con una marca de fecha. Antes guarda `hosts.wmud.bak`. Nunca borra líneas.

**Limitaciones:** Microsoft Defender puede avisar si una entrada redirige dominios de Microsoft.

---

## Paquetes

**Extrae:**

| Gestor | Cómo |
|---|---|
| winget | `winget export --source winget` (solo la fuente *winget*, no Microsoft Store) |
| npm | `npm ls -g --depth=0` |
| pip | `pip list --not-required` (paquetes instalados explícitamente, no sus dependencias) |
| dotnet tool | `dotnet tool list -g` |
| PowerShell | `Get-InstalledModule` (módulos instalados con `Install-Module`) |

**Aplica:** instala en ese orden lo que no esté instalado. Tras winget recarga el `PATH`, así que puede usar Node/Python/.NET recién instalados.

**Para todos los usuarios:** winget instala con `--scope machine`. Si el paquete no tiene instalador para todos los usuarios (error `0x8A150010`), lo instala para el usuario que ejecuta WinMudanza y lo avisa en el resumen. Al extraer se listan los programas que hoy están instalados solo para un usuario. npm y dotnet tool siguen siendo por usuario; los módulos de PowerShell ya se instalan para todos (`-Scope AllUsers`).

**git-flow:** Git for Windows dejó de incluir git-flow en la versión 2.51.1 (el proyecto original está abandonado). Si en la lista está Git y `git flow` no funciona, después de winget se instala **git-flow-next** (`GitTower.GitFlowNext`), el sustituto que recomienda Git for Windows: un `git-flow.exe` nativo, compatible con los repositorios y la configuración `gitflow.*` de git-flow y git-flow-avh. Git solo reconoce `git flow` si encuentra en el PATH un archivo llamado exactamente `git-flow.exe`; winget lo deja así en `C:\Program Files\WinGet\Links`. Después se comprueba con `git flow version`. Se desactiva con `Winget.GitFlow = $false`.

**Configuración de Git:** si en la lista está Git, después de instalarlo se pone, para todos los usuarios (`git config --system`, en `C:\Program Files\Git\etc\gitconfig`, donde el instalador deja `core.autocrlf = true`):
- `core.autocrlf = false`: Git no cambia los saltos de línea al descargar ni al guardar; los archivos quedan como están en el repositorio.
- `core.longpaths = true`: admite rutas de más de 260 caracteres.

Si el `.gitconfig` de un usuario (copiado por Desarrollo) tiene su propio valor, ese manda. Se desactiva con `Winget.GitConfig = $false`.

> **Repositorios ya clonados con `autocrlf = true`:** sus archivos tienen CRLF en la copia de trabajo y LF en el repositorio. Con `autocrlf = false`, Git los dará por modificados cuando cambie su fecha, aunque solo difiera el salto de línea. Con el repositorio sin cambios pendientes, `git rm --cached -r -q . && git reset --hard` los vuelve a descargar como están en el repositorio.

**Chocolatey y Scoop:** winget ya reconoce muchos programas instalados con ellos (por el registro de programas instalados) y esos entran en la lista normal. Para el resto, Extraer busca el equivalente en winget por nombre y lo escribe **comentado** al final de la lista de winget, con el paquete de origen:

```powershell
# 'Notepad++.Notepad++'    # sugerido para Chocolatey 'notepadplusplus': quita el # para instalarlo
# sin equivalente claro en winget: Scoop 'miherramienta' (busca: winget search "miherramienta")
```

**Limitaciones:**
- Programas que winget no reconoce (juegos, drivers, instaladores manuales) no se reinstalan: quedan en `paquetes_no_reinstalables.txt`.
- Siempre instala la **última versión**.
- Algunos paquetes de winget pueden fallar por hash o por necesitar interacción: se indica el código de error y se continúa.
- En un Windows recién instalado winget puede tardar en estar disponible: abre Microsoft Store y actualiza *Instalador de aplicación*.

---

## Office

**Extrae:** del registro de Office Click-to-Run (`HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration`): productos instalados, arquitectura (32/64 bits), canal de actualización, idioma y aplicaciones excluidas de cada producto. Si Office no está instalado, genera `office.psd1` con `Activo = $false` y valores por defecto.

**Aplica:**
1. Si todos los productos de `office.psd1` ya están instalados, no hace nada (no modifica una instalación existente).
2. Descarga `setup.exe` de la Office Deployment Tool desde el CDN oficial de Microsoft (`officecdn.microsoft.com`) y comprueba que su firma digital es de Microsoft.
3. Genera `configuration.xml` a partir de `office.psd1` e instala los productos que faltan con `setup.exe /configure`, en silencio si `Silencioso = $true`.
4. Comprueba en el registro que quedaron instalados y borra los archivos temporales.

**Relación con Paquetes:** si el módulo Office se ejecuta y su `office.psd1` está activo, Paquetes **no** instala `Microsoft.Office` con winget (lo haría con la configuración por defecto: todas las aplicaciones).

**Pendiente manual:** activar Office. Microsoft 365 se activa iniciando sesión con la cuenta Microsoft (abre Word → *Iniciar sesión*).

**Limitaciones:**
- Necesita internet: descarga unos 3 GB y tarda entre 10 y 30 minutos.
- No cambia una instalación existente (por ejemplo, no añade ni quita aplicaciones excluidas). Para eso, desinstala Office y vuelve a aplicar.
- Las licencias por volumen (KMS/MAK) no se configuran.

---

## Menus

**Extrae:** nada (se activa en la sección `Menus` de `config\ajustes.psd1`).

**Aplica:** después de Paquetes, añade los menús contextuales del Explorador que winget no añade (instala en silencio sin las opciones de menú del instalador). Solo los de los programas que estén instalados:

| Menú | Dónde | Qué hace |
|---|---|---|
| **Abrir en Claude** | Carpeta, fondo de carpeta, unidad | Abre Claude Code (`claude`) en esa carpeta, en Windows Terminal si está instalado y si no en PowerShell |
| **Abrir con Code** | Archivo, carpeta, fondo de carpeta, unidad | Abre VS Code, como el instalador clásico |
| **Buscar con Everything...** | Carpeta, fondo de carpeta, unidad | Abre Everything buscando en esa carpeta |
| **WinMerge** | Archivos y carpetas | Registra la extensión del Explorador de WinMerge (`ShellExtensionX64.dll`) y la activa en todos los perfiles |
| **Abrir en Sourcetree** | Carpeta, fondo de carpeta | Abre esa carpeta en Sourcetree (`SourceTree.exe -f <carpeta>`); vale para la versión Enterprise (`Program Files (x86)\Atlassian`) y la de usuario |

- Programa instalado para todos los usuarios → menú en `HKLM` (todos los usuarios). Instalado solo para el usuario → en su `HKCU`.
- Si ya hay otra entrada que abre ese programa (por ejemplo, la que crea el instalador de Everything), no se duplica.
- Si el usuario tiene una entrada antigua con el mismo nombre que apunta a otra ruta (por ejemplo, un VS Code desinstalado) o que quedó a medias (sin comando), se corrige.

También **oculta** (sin borrar nada) los menús que se elijan. Se hace aquí, después de Paquetes, porque instalar o actualizar Git o Windows Terminal los vuelve a crear:

| Menú | Cómo se oculta |
|---|---|
| **Abrir en Terminal** (`QuitarAbrirTerminal`) | Bloquea la extensión del Explorador de Windows Terminal: valor `{9F156763-7844-4DC4-B2B1-901F640F5155}` en `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked` (todos los usuarios) |
| **Open Git GUI here** (`QuitarGitGui`), **Open Git Bash here** (`QuitarGitBash`) | Valor `LegacyDisable` en los verbos `git_gui` y `git_shell` de `Directory`, `Directory\Background`, `Drive` y `LibraryFolder\background`, en `HKLM` (Git para todos) y en las clases de cada perfil (Git por usuario) |

Para volver a mostrarlos, borra ese valor. Si una actualización de Git los vuelve a crear, ejecuta `-Solo Menus`.

**Depende de:** Paquetes.

**Limitaciones:**
- Con el menú contextual moderno de Windows 11 aparecen en «Mostrar más opciones»; con el menú clásico (ajuste 01), directamente.
- WinMerge: su extensión solo se muestra si `ContextMenuEnabled` está activado en el usuario; se activa en los perfiles que no tengan ese valor y no se cambia si ya existe.

---

## Entorno

**Extrae:** variables de entorno de equipo (`HKLM\...\Session Manager\Environment`) y del usuario que ejecuta (`HKCU\Environment`), sin las que crea Windows, y las carpetas del `PATH` de ambos. Las rutas del perfil se guardan portables (`%USERPROFILE%`, `%APPDATA%`…).

**Aplica:** crea las variables que falten (si ya existen con otro valor **no** las cambia: avisa) y añade al `PATH` las carpetas que falten y existan. Va después de Paquetes para que los programas ya estén instalados. Al terminar avisa a Windows del cambio.

**Limitaciones:** las variables de usuario se aplican al usuario que ejecuta. Rutas con versión (p. ej. `JAVA_HOME` de un JDK concreto) pueden no coincidir tras reinstalar: se avisa.

---

## Desarrollo

**Extrae** (del usuario que ejecuta, los que existan) a `config\desarrollo\`:

| Elemento | Ruta |
|---|---|
| Git | `%USERPROFILE%\.gitconfig` |
| SSH | `%USERPROFILE%\.ssh` (incluye claves privadas **en claro**) |
| npm | `%USERPROFILE%\.npmrc` (puede tener tokens) |
| WSL | `%USERPROFILE%\.wslconfig` |
| PowerShell 5.1 / 7 | `Documentos\WindowsPowerShell\*profile.ps1`, `Documentos\PowerShell\*profile.ps1` |
| Windows Terminal | `settings.json` (versión normal, Preview y sin empaquetar) |
| VS Code | `%APPDATA%\Code\User\settings.json`, `keybindings.json`, `snippets\` |

**Aplica:** copia cada archivo a su ruta en el perfil del usuario que ejecuta. Si el destino existe y es distinto, guarda antes `<archivo>.wmud.bak`; si es igual, lo salta. A las claves SSH privadas les quita la herencia de permisos y deja solo al usuario (OpenSSH las rechaza si otros pueden leerlas).

**Limitaciones:** solo el usuario que ejecuta. Las extensiones de VS Code no se copian (instálalas con winget o con la sincronización de VS Code).

---

## UniGetUI

**Extrae:** de `%LOCALAPPDATA%\UniGetUI` del usuario actual: gestores activos (`DisabledManagers.json`), opciones activadas (archivos vacíos), opciones con valor (p. ej. hosts de confianza de winget) y `InstallationOptions\`.
No extrae: historial de operaciones, cachés, telemetría, tamaño de ventana ni estado temporal.

**Aplica:** escribe esa configuración en **todos los perfiles** de usuario y en Default.

**Iniciar como administrador:** UniGetUI arranca al iniciar sesión con una entrada `Run` (`WingetUI`), sin elevar. Para que arranque siempre como administrador sin la ventana de UAC, se usa una **tarea programada** en `\Personal\` con disparador «al iniciar sesión», «ejecutar con los privilegios más altos» y acción `"C:\Program Files\UniGetUI\UniGetUI.exe" --daemon`. La tarea la traslada el módulo **Tareas**. Si Extraer encuentra una tarea que ejecuta `UniGetUI.exe`, pone `QuitarInicioAutomatico = $true`, y Aplicar quita la entrada `Run` de UniGetUI en el equipo y en todos los perfiles (la crean UniGetUI y su instalador), para que no arranque dos veces. Si ninguna tarea lo inicia (ni en el equipo ni en `config\tareas\`), avisa.

**Depende de:** Paquetes (UniGetUI suele instalarse con winget).

**Limitaciones:**
- UniGetUI debe estar **cerrado** (también en la bandeja del sistema).
- Las opciones se añaden; no se desactivan opciones que ya estén activas en destino (salvo los gestores, que se escriben completos).
- Si se vuelve a activar «Iniciar UniGetUI al arrancar» en su configuración, se vuelve a crear la entrada `Run`: déjalo desactivado si lo inicia la tarea.

---

## Navegadores

**Extrae:** de cada perfil de Windows, los favoritos de cada perfil de **Edge, Chrome, Brave, Vivaldi y Opera** (archivo `Bookmarks`) a `config\navegadores\<usuario>\<navegador>\<perfil>\`, y al lado un `favoritos.html` que cualquier navegador puede importar. De **Firefox** guarda la última copia de `bookmarkbackups\` (`.jsonlz4`).

**Aplica:** si el navegador está instalado y ese perfil no tiene favoritos, los restaura. Si ya tiene (por ejemplo, porque ha sincronizado la cuenta), **no los toca**; si tiene menos de los guardados, deja como pendiente importar `favoritos.html`. Firefox queda siempre como pendiente, con la ruta del archivo para restaurarlo desde el propio Firefox (Ctrl+Mayús+O > Importar y respaldar > Restaurar).

**Depende de:** Usuarios y Paquetes (el navegador debe estar instalado).

**Limitaciones:**
- Los navegadores deben estar **cerrados**; si uno está abierto, se avisa y se salta.
- Solo favoritos: no historial, contraseñas ni extensiones (para eso, la sincronización de cada navegador).
- Un navegador que no esté instalado, o un usuario sin perfil todavía, queda como pendiente.

---

## Outlook

Outlook clásico (Microsoft 365 / Office 2016 o posterior). Windows no permite trasladar las contraseñas, y copiar el perfil de Outlook del registro a otro equipo no es fiable, así que:

**Extrae:** de cada perfil de Windows, las cuentas de cada perfil de Outlook (email, tipo y, en IMAP/POP, servidores, puertos y SSL), los archivos de datos `.pst` y las **firmas** (`%APPDATA%\Microsoft\Signatures`) a `config\outlook\<usuario>\Firmas`. Los `.ost` no se guardan: son una copia del servidor que Outlook vuelve a descargar.

**Aplica:** copia las firmas que falten y deja como **pendiente** la lista de cuentas para añadirlas en Outlook (Archivo > Agregar cuenta) y los `.pst` para volver a abrirlos. Exchange, Microsoft 365, Outlook.com y Gmail solo piden el email e iniciar sesión.

**Depende de:** Usuarios y Office.

**Revisar:** avisa de los `.pst` que estén en C:.

---

## Tareas

**Extrae:** las tareas programadas de las carpetas del Programador de tareas indicadas en `CarpetasTareas` de `perfil.psd1` (por defecto `\Personal\`). Cada tarea se guarda completa en `config\tareas\<carpeta>\<nombre>.xml`. Las cuentas de usuario (que cambian de SID al reinstalar) se guardan por nombre.

**Aplica:** registra las tareas que no existan, con la cuenta resuelta en el equipo nuevo, y las deja activadas o desactivadas como estaban. Las que ya existen no se tocan.

**Depende de:** Usuarios (la cuenta de la tarea debe existir).

**Revisar:** avisa si una tarea ejecuta un programa que está en C: fuera de Windows y de Archivos de programa (por ejemplo `C:\Tools\...`), porque se borrará al formatear.

**Limitaciones:**
- Si la cuenta de la tarea aún no existe (cuenta Microsoft sin iniciar sesión), queda como pendiente: inicia sesión con ella y ejecuta `-Solo Tareas`.
- Las tareas que se ejecutan «aunque el usuario no haya iniciado sesión» **con contraseña guardada** no se pueden restaurar sin ella: quedan como pendientes, para importarlas a mano desde su `.xml`. Las que no guardan contraseña (opción «No almacenar contraseña») sí se restauran.

---

## Inicio

**Extrae**, de cada usuario:
- **Menú Inicio:** los anclados, es decir, el archivo `start2.bin` (y `start*.bin`) de `AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState`.
- **Barra de tareas:** los accesos de `AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar` y la clave del registro `Explorer\Taskband`, que guarda su orden.
- **Explorador:** las carpetas ancladas a **Acceso rápido** y los archivos en **Favoritos** (Windows 11), en su orden. Se leen de las listas de saltos de `AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations` (`f01b4d95cf55d32a…` y `5f7b5f1e01b83767…`), así que también se extraen los de otros usuarios. Se guardan como rutas editables: las carpetas conocidas como `shell:Downloads`, `shell:Personal`…, lo del perfil con `%USERPROFILE%`. Extraer avisa de cuántos están en C:.
- **Escritorio:** los accesos directos (`.lnk`, `.url`) del escritorio del usuario y del escritorio público (todos los usuarios), qué iconos de Windows se muestran (Este equipo, Papelera, Red, Panel de control, carpeta del usuario) y la posición de los iconos (`Shell\Bags\1\Desktop`). Los documentos y carpetas del escritorio **no** se copian: Extraer avisa si los hay. Si el escritorio está fuera del perfil (por ejemplo en `D:`, con el módulo Carpetas) o en OneDrive, ya se conserva allí y no se copia.
- **Al iniciar sesión:** los accesos de la carpeta Inicio del menú Inicio (`shell:startup`), y también los de la carpeta común de todos los usuarios (`shell:common startup`).

Se guarda en `config\inicio\<usuario>\` (`MenuInicio`, `BarraTareas`, `Escritorio`, `AlIniciar`) y `config\inicio\_Comun\` (`Escritorio`, `AlIniciar`).

**Aplica:**
- Menú Inicio, barra de tareas, anclados del Explorador, iconos de Windows del escritorio y posición de los iconos se restauran **una sola vez por usuario** (queda marcado en `HKCU\Software\WinMudanza\Inicio`), para no deshacer lo que el usuario cambie después. El `start2.bin` anterior se guarda como `start2.bin.wmud.bak`.
- Si es el usuario que ejecuta WinMudanza, se reinicia su Explorador para que se vea el cambio. Los demás lo verán al iniciar sesión.
- Del escritorio y de la carpeta Inicio solo se copian los accesos que falten.
- **Anclados del Explorador:** se desanclan los que tenga el usuario (los de Windows: Escritorio, Documentos, Imágenes…) y se anclan los de la configuración en su orden, con el Shell (`modulos\Inicio\Anclar-Explorador.ps1`). El Shell solo cambia los anclados de su propia sesión: para el usuario que ejecuta WinMudanza se hace al momento; para los demás se copia el script a su `AppData\Local\WinMudanza\` y se programa con **RunOnce** al iniciar sesión (resultado en `Anclados.log`). Los que no existen se avisan y se saltan.

**Depende de:** Usuarios, Paquetes (los programas anclados deben estar instalados) y Carpetas (dónde está el escritorio).

**Limitaciones:**
- Windows 11 no tiene una forma oficial de cambiar los anclados de un usuario ya creado: se copia el archivo tal cual. Funciona entre equipos con Windows 11, pero Microsoft no lo documenta y podría dejar de funcionar en una versión futura.
- Los anclados y accesos de programas que no estén instalados no funcionan hasta instalarlos.
- La posición de los iconos depende de la resolución de la pantalla: con otra distinta, Windows puede recolocarlos.
- Los anclados del Explorador que no existan en el equipo nuevo (archivos o carpetas de C: que no se copiaron, unidades no conectadas) no se anclan. Si el usuario ejecuta Aplicar antes de crear sus carpetas en `D:`, vuelve a anclarlas a mano o borra el valor `Explorador` de la marca y ejecuta `-Solo Inicio`.
- El ajuste 04 `DesanclarCarpetas` desancla antes las carpetas indicadas del usuario actual; si Inicio restaura los anclados del Explorador, manda lo de Inicio.
- Si otro usuario tiene la sesión abierta, se salta (su Explorador sobrescribiría el cambio): cierra su sesión y ejecuta `-Solo Inicio`.
- Si el usuario aún no tiene perfil, queda como pendiente.
- Los programas que se abren al iniciar sesión desde el registro (`Run`) no se copian: la mayoría los vuelve a configurar el propio programa al instalarse.

---

## Steam

**No instala Steam ni juegos.** Solo replica configuración.

| Parte | Origen |
|---|---|
| Imágenes personalizadas | `userdata\<cuenta>\config\grid\` |
| Juegos no-Steam | `userdata\<cuenta>\config\shortcuts.vdf` (binario) |
| Colecciones | `userdata\<cuenta>\config\cloudstorage\` |
| Opciones de lanzamiento | `userdata\<cuenta>\config\localconfig.vdf` |

**Aplica:** en la cuenta destino (misma cuenta, la única existente o la indicada en `Destino`):
- copia las imágenes;
- fusiona los juegos no-Steam con los que ya existan (los de la configuración sustituyen a los que tengan el mismo `appid`; los demás se conservan);
- copia las colecciones;
- escribe las opciones de lanzamiento en `localconfig.vdf`.

Antes de sobrescribir guarda copias `*.wmud.bak`.

**Requisitos:** Steam instalado, haber iniciado sesión al menos una vez con la cuenta y Steam **cerrado** (Steam → Salir).

**Limitaciones:**
- Los programas de los juegos no-Steam (emuladores, etc.) hay que restaurarlos a mano en la misma ruta, o editar `Exe`/`StartDir`. Se avisa si no existen.
- Steam sincroniza las colecciones con su nube: al abrirlo puede imponer la versión guardada en la nube.
- Si `localconfig.vdf` tiene claves duplicadas no se modifica (se perderían datos) y se muestran las opciones para ponerlas a mano.
