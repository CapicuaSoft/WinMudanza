# Guía de uso

## 1. Preparar PowerShell

Todas las acciones reales necesitan **PowerShell como Administrador** (clic derecho en Inicio → *Terminal (Administrador)*).

Windows bloquea por defecto los scripts descargados. Para permitirlos solo en esta ventana:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\ruta\a\OptimizarHP2
```

Si la carpeta viene de internet o de un ZIP, desbloquéala una vez:

```powershell
Get-ChildItem -Recurse | Unblock-File
```

## 2. Proceso completo de migración

### En el equipo actual: extraer

```powershell
.\OptimizarHP2.ps1 -Accion Extraer
```

Se crea `config\` con:

| Archivo | Contenido |
|---|---|
| `usuarios.psd1` | Usuarios locales, grupos, cuentas Microsoft (pendientes) |
| `compartidas.psd1` | Recursos compartidos y permisos |
| `paquetes.psd1` | Listas de winget, npm, pip, dotnet tool, PowerShell |
| `paquetes_no_reinstalables.txt` | Mensajes de winget: programas que no podrá reinstalar |
| `unigetui.psd1` + `unigetui\` | Configuración de UniGetUI |
| `steam.psd1` + `steam\` | Configuración de Steam (imágenes, colecciones) |

Extraer **no cambia nada** en el equipo. Funciona sin Administrador, pero entonces pueden faltar permisos de carpetas compartidas.

### Revisar y editar

1. **Obligatorio**: abre `config\usuarios.psd1` y cambia cada `Password = 'CAMBIAR'` por la contraseña real (o `''` para sin contraseña).
2. Opcional: comenta con `#` los paquetes que no quieras reinstalar en `paquetes.psd1`.
3. Opcional: ajusta rutas en `compartidas.psd1` o `steam.psd1` si en el equipo nuevo serán otras.
4. Opcional: en `perfil.psd1` desactiva módulos que no quieras aplicar (por ejemplo `Steam`).
5. Opcional: en `ajustes.psd1` activa/desactiva ajustes de Windows.

Todos los campos están explicados en [CONFIGURACION.md](CONFIGURACION.md).

### Guardar

Copia **toda** la carpeta `OptimizarHP2` (con `config\`) a un lugar que sobreviva a la reinstalación: otro disco, un USB, etc.

### En el equipo nuevo

1. Instala Windows 11 y crea el primer usuario (puede ser tu cuenta Microsoft).
2. Abre Microsoft Store una vez y deja que se actualice "Instalador de aplicación" (es winget).
3. Copia la carpeta `OptimizarHP2` al equipo.
4. Simula:
   ```powershell
   .\OptimizarHP2.ps1 -Accion Aplicar -WhatIf
   ```
   Las líneas `SIM` son lo que haría. No se cambia nada.
5. Aplica:
   ```powershell
   .\OptimizarHP2.ps1 -Accion Aplicar
   ```
6. **Reinicia** el equipo.

### Completar lo pendiente

El resumen final lista lo que hay que hacer a mano. Lo habitual:

- **Cuentas Microsoft**: inicia sesión con ellas en el equipo nuevo. Después, vuelve a ejecutar para asignar grupos, permisos y ajustes a sus perfiles:
  ```powershell
  .\OptimizarHP2.ps1 -Accion Aplicar -Solo Usuarios,Compartidas,Ajustes
  ```
- **Steam**: instálalo (o deja que lo instale winget), inicia sesión, **ciérralo** y ejecuta:
  ```powershell
  .\OptimizarHP2.ps1 -Accion Aplicar -Solo Steam
  ```
- **Juegos no-Steam / emuladores**: restaura sus carpetas a la misma ruta (o cambia `Exe`/`StartDir` en `steam.psd1`).

Se puede ejecutar todas las veces que haga falta: lo que ya está aplicado se salta (`--  ... ya ...`).

## 3. Menú interactivo

```powershell
.\OptimizarHP2.ps1
```

```
   1) Extraer configuracion de este equipo
   2) Aplicar configuracion a este equipo
   3) Aplicar en modo simulacion (no cambia nada)
   4) Ver estado de config\
   5) Ayuda
   0) Salir
```

Al elegir 1, 2 o 3 se muestra la lista de módulos marcada según `perfil.psd1`. Escribe el número de un módulo para marcarlo o desmarcarlo y pulsa Enter para continuar.

## 4. Parámetros

| Parámetro | Descripción |
|---|---|
| `-Accion Extraer\|Aplicar\|Estado\|Ayuda` | Acción a ejecutar. Sin ella se abre el menú. |
| `-Solo M1,M2` | Ejecuta solo esos módulos (ignora `perfil.psd1`). |
| `-Omitir M1,M2` | Quita esos módulos de la ejecución. |
| `-WhatIf` | Simulación de Aplicar: no cambia nada. |
| `-DirConfig ruta` | Otra carpeta de configuración (por defecto `config`). |
| `-SinConfirmar` | No pregunta antes de aplicar. |

Módulos: `Ajustes`, `Usuarios`, `Compartidas`, `Paquetes`, `UniGetUI`, `Steam`.

Ejemplos:

```powershell
.\OptimizarHP2.ps1 -Accion Aplicar -Omitir Steam
.\OptimizarHP2.ps1 -Accion Aplicar -Solo Ajustes -WhatIf
.\OptimizarHP2.ps1 -Accion Extraer -Solo Paquetes -DirConfig D:\Backup\config
.\OptimizarHP2.ps1 -Accion Estado
```

## 5. Leer la salida

| Prefijo | Significado |
|---|---|
| `OK ` | Aplicado correctamente |
| `-- ` | Omitido (ya estaba hecho, desactivado o no aplica) |
| `SIM` | Simulación: lo que se haría |
| `!! ` | Aviso: algo no se pudo hacer, pero se continúa |
| `ERR` | Error |
| `PEN` | Pendiente: hay que hacerlo a mano (se repite en el resumen) |

Al final aparece un **resumen** por módulo (`OK`, `CON AVISOS`, `ERROR`, `OMITIDO`) y la lista de pendientes. El script termina con código de salida `1` si hubo errores.

## 6. Logs

Cada ejecución guarda un log en `logs\AAAA-MM-DD_HHMMSS_<accion>.log` con todo lo mostrado en pantalla y cada valor de registro escrito. Úsalo para revisar qué se cambió o para diagnosticar errores.

## 7. Probar sin riesgo en Windows Sandbox

Windows Sandbox es un Windows limpio y desechable (incluido en Windows 11 Pro). Para activarlo (una vez, requiere reiniciar):

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All
```

Después:

```powershell
.\pruebas\Abrir-Sandbox.ps1
```

Dentro de Sandbox abre PowerShell como Administrador y ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\Users\WDAGUtilityAccount\Desktop\OptimizarHP2
.\OptimizarHP2.ps1 -Accion Aplicar -Omitir Paquetes,Steam
```

Sandbox no tiene winget, ni disco D:, ni tus usuarios: esos módulos fallarán o avisarán allí, es normal. Al cerrar Sandbox todo se borra.
