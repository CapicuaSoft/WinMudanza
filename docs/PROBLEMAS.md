# Problemas frecuentes

### "No se puede cargar el archivo ... porque la ejecución de scripts está deshabilitada"

Ejecuta en la misma ventana:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Si sigue fallando con archivos copiados de internet o de un ZIP: `Get-ChildItem -Recurse | Unblock-File`.

### "Esta acción requiere PowerShell como Administrador"

Cierra la ventana y abre *Terminal (Administrador)* o *Windows PowerShell (Administrador)*. Solo la simulación (`-WhatIf`) y Extraer funcionan sin serlo.

### Caracteres raros (Ã³, Ã±) en la consola o en los .psd1

Los archivos deben estar en **UTF-8 con BOM**. Si editaste uno con un editor que lo guardó sin BOM, vuelve a guardarlo como "UTF-8 con BOM" (en Notepad++: Codificación → UTF-8-BOM). `.\pruebas\Probar-Sintaxis.ps1` detecta los archivos sin BOM.

### Error al leer un .psd1

El mensaje indica el archivo y la línea. Causas habituales:
- comillas sin cerrar o una comilla simple dentro del texto sin duplicar (`'O''Brien'`);
- llaves `{ }` o paréntesis `( )` desparejados al borrar un bloque;
- usar variables o expresiones: en `.psd1` solo valen textos, números, `$true`, `$false`, `$null`, listas y tablas.

### Usuarios: "falta la contraseña en usuarios.psd1"

Cambia `Password = 'CAMBIAR'` por la contraseña real (o `''` para sin contraseña) y vuelve a ejecutar `-Solo Usuarios`.

### Usuarios: no crea a una persona que inicia sesión con su email

Es una cuenta Microsoft: no se puede crear por script. Inicia sesión con ella una vez y ejecuta `-Solo Usuarios,Compartidas,Ajustes`.

### Compartidas: "la cuenta 'X' no existe aquí"

Ese usuario todavía no está creado (o es una cuenta Microsoft que aún no ha iniciado sesión). Créalo y repite `-Solo Compartidas`.

### Compartidas: "ya existe compartido con otra ruta"

En el equipo nuevo ya hay un recurso con ese nombre apuntando a otra carpeta. Elimínalo (`Remove-SmbShare -Name X`) o cambia `Nombre`/`Ruta` en `compartidas.psd1`.

### Paquetes: "winget no está disponible"

En un Windows recién instalado winget se activa tras el primer inicio de sesión. Abre Microsoft Store → Biblioteca → Actualizar, o instala "Instalador de aplicación". Después abre una ventana nueva de PowerShell.

### Paquetes: un paquete de winget falla con un código 0x8A15…

Prueba a instalarlo a mano para ver el motivo: `winget install --id <Id> -e`. Causas comunes: el hash del instalador cambió (espera unas horas), necesita cerrar un programa o reiniciar, o el paquete ya no existe.

### Paquetes: pip "No hay un Python con pip disponible"

Instala Python con winget (`Python.Python.3.x`) en el mismo paso o antes, y vuelve a ejecutar `-Solo Paquetes`. El alias de Microsoft Store (`python` en *WindowsApps*) se ignora.

### Ajustes: "No se pudo aplicar ... TaskbarDa" u otro aviso de barra de tareas

Windows 11 24H2+ protege algunas claves. Hazlo a mano desde Configuración → Personalización → Barra de tareas.

### Ajustes: "Perfil X: no se pudo cargar su registro"

El usuario tiene la sesión abierta (otra sesión o cambio rápido de usuario) o su perfil está dañado. Cierra su sesión y repite `-Solo Ajustes`.

### Edge: la página de inicio o el buscador no cambian

Abre `edge://policy`. Si las directivas aparecen con error o "ignorada", Edge no acepta esas directivas obligatorias en equipos sin dominio: pon `TipoDirectiva = 'Recomendada'` en `ajustes.psd1` y repite `-Solo Ajustes`.

### Edge: "Administrado por tu organización"

Es normal mientras existan directivas. Para quitarlas todas: borra la clave `HKLM\SOFTWARE\Policies\Microsoft\Edge`.

### Steam: "Steam está abierto"

Ciérralo del todo: menú Steam → Salir (cerrar la ventana no basta). Repite `-Solo Steam`.

### Steam: "no se sabe a qué cuenta aplicarla"

Hay varias cuentas de Steam en el equipo nuevo. Pon en `steam.psd1` el `Destino` con el número de la carpeta `Steam\userdata\<número>` que corresponda.

### Steam: las colecciones no aparecen o vuelven a ser las antiguas

Steam sincroniza las colecciones con su nube y la versión de la nube manda. Normalmente las colecciones ya aparecen solas al iniciar sesión.

### Steam: deshacer cambios

Cada archivo sobrescrito tiene su copia `*.ohp2.bak` (o la carpeta `cloudstorage.ohp2.bak`) en `Steam\userdata\<cuenta>\config\`. Con Steam cerrado, renombra la copia al nombre original.

### ¿Dónde veo qué se cambió exactamente?

En `logs\`: cada ejecución tiene su log con todos los mensajes y cada valor de registro escrito.
