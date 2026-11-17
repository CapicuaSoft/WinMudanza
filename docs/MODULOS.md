# Módulos

Orden de ejecución al aplicar: **Ajustes → Wifi → Características → Usuarios → Compartidas → Unidades de red → Impresoras → Hosts → Paquetes → Office → Entorno → Desarrollo → UniGetUI → Steam**.

Los módulos que tienen bloque `Revisar` (Usuarios, Compartidas, Steam) participan en la **revisión antes de formatear** (`-Accion Revisar` y al final de Extraer).

Todos los módulos son **repetibles**: lo que ya está aplicado se salta, así que se pueden volver a ejecutar para completar pendientes.

---

## Ajustes

**Extrae:** nada (los valores están en `ajustes.psd1`).
**Aplica:** 6 grupos de ajustes de la carpeta `modulos\Ajustes\`, cada uno activable por separado.

| Ajuste | Ámbito | Qué cambia |
|---|---|---|
| 01 Menú clásico | Usuario (todos los perfiles) | `HKCU\Software\Classes\CLSID\{86ca1aa0-…}\InprocServer32` |
| 02 Terminales | Equipo | Verbos en `HKLM\SOFTWARE\Classes\Directory\shell`, `Directory\Background\shell`, `.ps1`, `cmdfile`, `batfile` |
| 03 Edge | Equipo | Directivas en `HKLM\SOFTWARE\Policies\Microsoft\Edge` (o `\Recommended`) |
| 04 Explorador | Usuario + equipo | `Explorer\Advanced`, `CabinetState`, `Search`, directivas `Dsh`, `CloudContent`, `Explorer`; anclados con Shell COM |
| 05 Energía | Equipo + usuario | `powercfg`, `PowerThrottling`, `VisualEffects`, `GameBar`, `GameConfigStore` |
| 06 PowerShell | Equipo (galería: usuario que ejecuta) | Directiva de ejecución (`ShellIds\Microsoft.PowerShell`, y PowerShell 7 si está), NuGet + PSGallery de confianza, TLS 1.2 en .NET (`SchUseStrongCrypto`, `SystemDefaultTlsVersions`), doble clic en `.ps1` (`Microsoft.PowerShellScript.1\Shell`) |

**Cómo llega a todos los usuarios:**
- Perfiles con sesión abierta: se escribe en su registro cargado.
- Perfiles sin sesión: se carga su `NTUSER.DAT` (y `UsrClass.dat`) temporalmente con `reg load`.
- Perfil **Default** (plantilla de usuarios nuevos): se escribe en su `NTUSER.DAT`. Las claves de *Classes* (menú clásico, OneDrive) no se heredan de Default, así que se programan con **RunOnce** para el primer inicio de sesión de cada usuario nuevo.

**Limitaciones:**
- Windows 11 24H2+ protege algunas claves de la barra de tareas (`TaskbarDa`, a veces `SearchboxTaskbarMode`). Si falla, se muestra un aviso y se continúa.
- Anclar/desanclar carpetas en Inicio solo funciona para el usuario que ejecuta el script.
- 06 PowerShell: una directiva de grupo de ejecución tiene prioridad (se avisa). Si un usuario eligió un programa para abrir `.ps1` ("Abrir con…"), su elección gana al doble clic. La confianza en PowerShell Gallery es por usuario.
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

**Depende de:** Paquetes (UniGetUI suele instalarse con winget).

**Limitaciones:**
- UniGetUI debe estar **cerrado** (también en la bandeja del sistema).
- Las opciones se añaden; no se desactivan opciones que ya estén activas en destino (salvo los gestores, que se escriben completos).

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
