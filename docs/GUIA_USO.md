# Guía de uso

## 1. Arrancar WinMudanza

La forma más sencilla es **doble clic en `WinMudanza.cmd`**: pide permisos de Administrador y abre el menú sin tener que cambiar la directiva de ejecución de PowerShell (sirve en un Windows recién instalado). Acepta los mismos parámetros que el script:

```bat
WinMudanza.cmd -Accion Aplicar -WhatIf
```

Desde una PowerShell como Administrador también se puede usar directamente:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd D:\WinMudanza
.\WinMudanza.ps1
```

Si la carpeta viene de internet o de un ZIP, desbloquéala una vez: `Get-ChildItem -Recurse | Unblock-File`.

## 2. Proceso completo de migración

### En el equipo actual

#### Extraer

```powershell
.\WinMudanza.ps1 -Accion Extraer
```

Se crea `config\` con:

| Archivo | Contenido |
|---|---|
| `wifi.psd1` + `wifi\` | Redes Wi-Fi con su contraseña |
| `caracteristicas.psd1` | Características de Windows activadas |
| `usuarios.psd1` | Usuarios locales, grupos, cuentas Microsoft (pendientes) |
| `compartidas.psd1` | Recursos compartidos y permisos |
| `unidadesred.psd1` | Unidades de red mapeadas |
| `impresoras.psd1` | Impresoras de red / IP y la predeterminada |
| `hosts.psd1` | Entradas personalizadas de `hosts` |
| `paquetes.psd1` | Listas de winget, npm, pip, dotnet tool, PowerShell |
| `paquetes_no_reinstalables.txt` | Mensajes de winget: programas que no podrá reinstalar |
| `office.psd1` | Instalación de Microsoft 365 / Office |
| `entorno.psd1` | Variables de entorno y PATH |
| `desarrollo.psd1` + `desarrollo\` | `.gitconfig`, `.ssh`, perfiles de PowerShell, Terminal, VS Code |
| `unigetui.psd1` + `unigetui\` | Configuración de UniGetUI |
| `steam.psd1` + `steam\` | Configuración de Steam (imágenes, colecciones) |

Extraer **no cambia nada** en el equipo. Funciona sin Administrador, pero entonces pueden faltar permisos de carpetas compartidas y las contraseñas de Wi-Fi: usa `WinMudanza.cmd`.

#### Revisar lo que se perdería

Al terminar, Extraer hace una **revisión antes de formatear** (también disponible sola con `-Accion Revisar` u opción 2 del menú). Avisa con `!!` de lo que la configuración necesita y está en C:, por ejemplo:

- carpetas compartidas en C: (se recrearán vacías);
- juegos no-Steam en C: (hay que copiarlos y restaurarlos en la misma ruta);
- la propia configuración, si no se ha copiado fuera de C:.

WinMudanza **no copia tus documentos, fotos, escritorio ni descargas**: haz copia de seguridad de esos datos aparte.

#### Copiar fuera de C:

Si `CopiarA` (en `config\perfil.psd1`) tiene una ruta, Extraer copia allí WinMudanza con su configuración al terminar (por defecto `D:\WinMudanza`). También se puede copiar a mano:

```powershell
.\WinMudanza.ps1 -Accion Copiar -Destino E:\WinMudanza    # p. ej. un USB
```

La copia incluye todo menos `logs\`. Por seguridad, no se sobrescribe una carpeta que tenga otros datos y no sea una copia de WinMudanza.

#### Editar (opcional)

1. `config\usuarios.psd1`: puedes escribir las contraseñas donde ponga `'CAMBIAR'`; si no, se pedirán al aplicar.
2. Comenta con `#` lo que no quieras restaurar (paquetes, redes, entradas…).
3. Ajusta rutas en `compartidas.psd1` o `steam.psd1` si en el equipo nuevo serán otras.
4. En `perfil.psd1` desactiva módulos que no quieras aplicar (por ejemplo `Steam`).
5. En `ajustes.psd1` activa/desactiva ajustes de Windows.

Todos los campos están explicados en [CONFIGURACION.md](CONFIGURACION.md).

### En el equipo nuevo

1. Instala Windows 11 y crea el primer usuario (puede ser tu cuenta Microsoft).
2. Abre Microsoft Store una vez y deja que se actualice "Instalador de aplicación" (es winget).
3. Doble clic en `D:\WinMudanza\WinMudanza.cmd`.
4. Opción **5) Simulación**: las líneas `SIM` son lo que haría. No se cambia nada.
5. Opción **4) Aplicar**. Las contraseñas de los usuarios que estén en `'CAMBIAR'` se piden por pantalla.
6. Si un módulo necesita reiniciar (p. ej. al activar WSL o Hyper-V), Aplicar se detiene, pregunta si reiniciar y **continúa sola** al volver a iniciar sesión con el mismo usuario (los módulos restantes aparecen en el resumen como `TRAS REINICIO`). Se desactiva con `ContinuarTrasReinicio = $false` en `perfil.psd1` o `-SinReiniciar`.
7. **Reinicia** al terminar.
8. Opción **6) Comparar**: lista lo que aún difiere de la configuración (debería salir todo `AL DIA` salvo lo pendiente).

### Completar lo pendiente

El resumen final lista lo que hay que hacer a mano. Lo habitual:

- **Cuentas Microsoft**: inicia sesión con ellas en el equipo nuevo. Después, vuelve a ejecutar para asignar grupos, permisos y ajustes a sus perfiles:
  ```powershell
  .\WinMudanza.ps1 -Accion Aplicar -Solo Usuarios,Compartidas,Ajustes
  ```
- **Office**: abre Word e inicia sesión con la cuenta que tiene la suscripción.
- **Steam**: instálalo (o deja que lo instale winget), inicia sesión, **ciérralo** y ejecuta `-Solo Steam`.
- **Juegos no-Steam / emuladores**: restaura sus carpetas a la misma ruta (o cambia `Exe`/`StartDir` en `steam.psd1`).
- **Desarrollo, unidades de red, impresora predeterminada, variables de usuario**: se aplican al usuario que ejecuta WinMudanza. Para otro usuario, inicia sesión con él y ejecuta `-Solo Desarrollo,UnidadesRed,Impresoras,Entorno`.

Se puede ejecutar todas las veces que haga falta: lo que ya está aplicado se salta (`--  ... ya ...`).

## 3. Menú interactivo

```
   EQUIPO ACTUAL (antes de formatear)
   1) Extraer configuracion de este equipo
   2) Revisar lo que se perderia al formatear C:
   3) Copiar WinMudanza y su configuracion a otra unidad

   EQUIPO NUEVO
   4) Aplicar configuracion a este equipo
   5) Aplicar en modo simulacion (no cambia nada)
   6) Comparar configuracion con este equipo

   7) Ver estado de config\      8) Ayuda      0) Salir
```

Al elegir 1, 4, 5 o 6 se muestra la lista de módulos marcada según `perfil.psd1`. Escribe el número de un módulo para marcarlo o desmarcarlo y pulsa Enter para continuar.

## 4. Parámetros

| Parámetro | Descripción |
|---|---|
| `-Accion Extraer\|Revisar\|Copiar\|Aplicar\|Comparar\|Estado\|Ayuda` | Acción a ejecutar. Sin ella se abre el menú. |
| `-Solo M1,M2` | Ejecuta solo esos módulos (ignora `perfil.psd1`). |
| `-Omitir M1,M2` | Quita esos módulos de la ejecución. |
| `-WhatIf` | Simulación de Aplicar: no cambia nada. |
| `-DirConfig ruta` | Otra carpeta de configuración extraída (por defecto `config`). |
| `-Destino ruta` | Para `Copiar`: carpeta de destino (por defecto `CopiarA` de `perfil.psd1`). |
| `-SinConfirmar` | No pregunta nada: ni confirmación, ni contraseñas (los usuarios en `'CAMBIAR'` darán error), ni reiniciar. |
| `-SinReiniciar` | Aplica todos los módulos seguidos aunque alguno necesite reiniciar. |

Módulos: `Ajustes`, `Wifi`, `Caracteristicas`, `Usuarios`, `Compartidas`, `UnidadesRed`, `Impresoras`, `Hosts`, `Paquetes`, `Office`, `Entorno`, `Desarrollo`, `UniGetUI`, `Steam`.

Ejemplos:

```powershell
.\WinMudanza.ps1 -Accion Aplicar -Omitir Steam
.\WinMudanza.ps1 -Accion Aplicar -Solo Ajustes -WhatIf
.\WinMudanza.ps1 -Accion Comparar -Solo Paquetes
.\WinMudanza.ps1 -Accion Extraer -Solo Paquetes -DirConfig D:\Backup\config
.\WinMudanza.ps1 -Accion Estado
```

## 5. Leer la salida

| Prefijo | Significado |
|---|---|
| `OK ` | Aplicado correctamente |
| `-- ` | Omitido (ya estaba hecho, desactivado o no aplica) |
| `SIM` | Simulación: lo que se haría (en Comparar, cada `SIM` es una diferencia) |
| `!! ` | Aviso: algo no se pudo hacer, pero se continúa |
| `ERR` | Error |
| `PEN` | Pendiente: hay que hacerlo a mano (se repite en el resumen) |

Al final aparece un **resumen** por módulo (`OK`, `CON AVISOS`, `ERROR`, `OMITIDO`, `TRAS REINICIO`; en Comparar `AL DIA` o `DIFERENCIAS`) y la lista de pendientes. El script termina con código de salida `1` si hubo errores.

En simulación y Comparar, los perfiles de usuario sin sesión abierta (incluido Default) no se cargan, así que sus valores aparecen siempre como diferencia.

## 6. Logs

Cada ejecución guarda un log en `logs\AAAA-MM-DD_HHMMSS_<accion>.log` con todo lo mostrado en pantalla y cada valor de registro escrito (`REG`) o que ya estaba (`REG=`). Úsalo para revisar qué se cambió o para diagnosticar errores.

## 7. Probar sin riesgo en Windows Sandbox

Windows Sandbox es un Windows limpio y desechable (incluido en Windows 11 Pro). Para activarlo (una vez, requiere reiniciar):

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All
```

Prueba automática (aplica `config\sandbox` al arrancar y deja el log en `logs\` de tu equipo):

```powershell
.\pruebas\Abrir-Sandbox.ps1 -Probar
.\pruebas\Abrir-Sandbox.ps1 -Probar -Argumentos '-Solo Ajustes,Office'
.\pruebas\Abrir-Sandbox.ps1 -Probar -Preparar     # regenera config\sandbox desde config\
```

`config\sandbox` es una copia de `config\` con contraseñas de prueba (`Prueba-Sandbox-1`) y las rutas de D: cambiadas a `C:\D_Simulado\`. Sin `-Probar` solo abre Sandbox con la carpeta en el escritorio para probar a mano.

Sandbox no tiene winget, ni disco D:, ni tus usuarios, ni permite activar Hyper-V o Sandbox dentro: esos módulos fallarán o avisarán allí, es normal. Al cerrar Sandbox todo se borra.
