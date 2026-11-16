# Módulos

Orden de ejecución al aplicar: **Ajustes → Usuarios → Compartidas → Paquetes → UniGetUI → Steam**.

Todos los módulos son **repetibles**: lo que ya está aplicado se salta, así que se pueden volver a ejecutar para completar pendientes.

---

## Ajustes

**Extrae:** nada (los valores están en `ajustes.psd1`).
**Aplica:** 5 grupos de ajustes de la carpeta `ajustes\`, cada uno activable por separado.

| Ajuste | Ámbito | Qué cambia |
|---|---|---|
| 01 Menú clásico | Usuario (todos los perfiles) | `HKCU\Software\Classes\CLSID\{86ca1aa0-…}\InprocServer32` |
| 02 Terminales | Equipo | Verbos en `HKLM\SOFTWARE\Classes\Directory\shell`, `Directory\Background\shell`, `.ps1`, `cmdfile`, `batfile` |
| 03 Edge | Equipo | Directivas en `HKLM\SOFTWARE\Policies\Microsoft\Edge` (o `\Recommended`) |
| 04 Explorador | Usuario + equipo | `Explorer\Advanced`, `CabinetState`, `Search`, directivas `Dsh`, `CloudContent`, `Explorer`; anclados con Shell COM |
| 05 Energía | Equipo + usuario | `powercfg`, `PowerThrottling`, `VisualEffects`, `GameBar`, `GameConfigStore` |

**Cómo llega a todos los usuarios:**
- Perfiles con sesión abierta: se escribe en su registro cargado.
- Perfiles sin sesión: se carga su `NTUSER.DAT` (y `UsrClass.dat`) temporalmente con `reg load`.
- Perfil **Default** (plantilla de usuarios nuevos): se escribe en su `NTUSER.DAT`. Las claves de *Classes* (menú clásico, OneDrive) no se heredan de Default, así que se programan con **RunOnce** para el primer inicio de sesión de cada usuario nuevo.

**Limitaciones:**
- Windows 11 24H2+ protege algunas claves de la barra de tareas (`TaskbarDa`, a veces `SearchboxTaskbarMode`). Si falla, se muestra un aviso y se continúa.
- Anclar/desanclar carpetas en Inicio solo funciona para el usuario que ejecuta el script.
- Edge muestra *"Administrado por tu organización"* mientras haya directivas. En equipos sin dominio, Edge puede ignorar las directivas **obligatorias** de página de inicio y buscador: compruébalo en `edge://policy` y, si aparecen con error, usa `TipoDirectiva = 'Recomendada'`.
- Los perfiles de usuarios con sesión abierta en otra sesión pueden no poder cargarse: se avisa y se omiten.

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

Antes de sobrescribir guarda copias `*.ohp2.bak`.

**Requisitos:** Steam instalado, haber iniciado sesión al menos una vez con la cuenta y Steam **cerrado** (Steam → Salir).

**Limitaciones:**
- Los programas de los juegos no-Steam (emuladores, etc.) hay que restaurarlos a mano en la misma ruta, o editar `Exe`/`StartDir`. Se avisa si no existen.
- Steam sincroniza las colecciones con su nube: al abrirlo puede imponer la versión guardada en la nube.
- Si `localconfig.vdf` tiene claves duplicadas no se modifica (se perderían datos) y se muestran las opciones para ponerlas a mano.
