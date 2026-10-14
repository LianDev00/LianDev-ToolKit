# Soporte TI - LianDev

![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)
![Licencia](https://img.shields.io/badge/licencia-MIT-green)

> **EN:** Portable Windows IT support tool in a single executable: a keyboard-driven catalog
> of 58 support commands, plus a hardware and Windows/Office license audit that flags piracy
> activators and produces a self-contained HTML report and a JSON inventory record.

Herramienta portable de soporte técnico en un solo ejecutable. Sin instalación, sin
dependencias, sin suscripción: corre desde un USB en el equipo del cliente.

Dos módulos:

1. **Catálogo de comandos** — 58 comandos de soporte catalogados por área, navegables con
   el teclado, con descripción de qué hacen y cuándo se usan, copiar al portapapeles y
   ejecutar con confirmación para los delicados.
2. **Auditoría de equipo y licencias** — hardware, licencia de Windows, licencia de Office,
   detección de activadores piratas, clasificación A/B/C e **informe HTML** listo para
   entregar al cliente más un **JSON** con los datos crudos.

## Requisitos y descarga

- Windows 10 u 11 con Windows PowerShell 5.1, que ya viene instalado.
- El ejecutable listo para usar está en [Releases](../../releases). El `.exe` no se
  versiona en el repositorio: se genera con `build.ps1`.

## Uso

Doble clic en `Soporte TI - LianDev.exe`, o bien:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\src\SoporteTI-LianDev.ps1
```

En el menú: `A` abre la auditoría, `1`-`8` las categorías de comandos, `/` busca en todo,
`H` la ayuda, `Q` sale.

**Ejecútalo como administrador.** Sin elevación la auditoría funciona, pero no puede leer
las exclusiones de Windows Defender ni las tareas programadas, que es donde se delatan
varios activadores. El informe deja constancia de si corrió elevado o no.

### Desatendido

Para tarea programada, WinRM o un lote de equipos:

```powershell
.\"Soporte TI - LianDev.exe" -Auditoria -SinPausa -RutaSalida C:\Informes
```

No abre menú, no pausa, no abre el navegador: solo deja el `.html` y el `.json`.

### Clasificación

| | Significado |
|---|---|
| **A** | Windows y Office originales |
| **B** | Solo uno de los dos es original |
| **C** | Ambos no originales |

## Archivos opcionales junto al ejecutable

| Archivo | Para qué |
|---|---|
| `plantilla.html` | Reemplaza la plantilla del informe sin recompilar. Si no existe, se usa la embebida. |
| `kms_confiables.txt` | Servidores KMS legítimos de la organización auditada, uno por línea (`#` comenta). Sin esto, cualquier KMS se evalúa como sospechoso. |

## Salidas de la auditoría

`Auditoria_<EQUIPO>_<fecha>.html` — el informe para el cliente. Archivo único, sin
dependencias externas; `Ctrl+P` da un PDF presentable.

`Auditoria_<EQUIPO>_<fecha>.json` — los mismos datos en estructura. Es la semilla del
inventario: juntando los JSON de todos los equipos de un cliente sale el parque completo
(antigüedad, licencias, discos, RAM) sin volver a pasar por cada máquina.

Ambos se escriben en el **Escritorio** del equipo auditado, para que queden a la vista y no
escondidos en el USB. `-RutaSalida` lo sobreescribe cuando se pasa a propósito; si el destino
no acepta escritura, se cae en orden a la carpeta del ejecutable y `%TEMP%`.

## Desarrollo

El ejecutable se arma de partes para que cada pieza se edite sin pelearse con las demás:

```
build/
  part01-cabecera.ps1     marca, parámetros, configuración
  part02-catalogo.ps1     los 58 comandos
  part03-ui.ps1           utilidades, acciones, vistas de lista/detalle/ayuda
  part04-auditoria.ps1    recolección de datos -> objeto $Datos
  part05-informe.ps1      motor de plantilla y escritura de salidas
  plantilla.html          la plantilla del informe (fuente única)
  part07-menu.ps1         menú principal y arranque
build.ps1                 ensambla src\ y compila dist\
src/SoporteTI-LianDev.ps1 GENERADO - no editar a mano
dist/                     el .exe
tests/test-plantilla.ps1  30 comprobaciones del motor de plantilla
```

```powershell
.\build.ps1 -SoloPs1      # solo ensambla y valida sintaxis
.\build.ps1               # ensambla y compila el .exe (requiere ps2exe)
.\tests\test-plantilla.ps1
```

`build.ps1` valida la sintaxis del script ensamblado antes de compilar y aborta si la
plantilla tiene una línea que empiece con `'@`, que cerraría el here-string antes de tiempo.

### Sintaxis de la plantilla

```html
{{Equipo.Nombre}}                               valor, escapado a HTML
{{.}}                                           el elemento actual (listas de texto)
{{#cada Equipo.Discos}} {{Modelo}} {{/cada}}    repite por elemento
{{#si Office.Instalado}} ... {{/si}}            incluye si tiene valor
{{#no Office.Instalado}} ... {{/no}}            incluye si NO tiene valor
```

Todo valor se escapa antes de entrar al HTML: el informe incluye rutas de exclusiones de
Defender y la salida cruda de `slmgr` y `ospp.vbs`, que de otro modo podrían romper la
página o inyectar marcado.

### Dos detalles que ya costaron una vez

- **El `.ps1` ensamblado se escribe con BOM UTF-8.** Sin el BOM, ps2exe se come los
  acentos del informe y de la interfaz.
- **`cscript` escribe en la página de códigos OEM** (850 en Windows en español), no en
  UTF-8, aunque la consola esté en UTF-8. La salida de `slmgr` y `ospp.vbs` se decodifica
  con esa página en `Get-SalidaNativa`; decodificarla como UTF-8 parte los acentos.

## Pendiente

- Firma de código: el ejecutable consulta `slmgr`, lee exclusiones de Defender y busca
  activadores. Es el perfil que SmartScreen y los antivirus marcan. Sin firma vas a dar
  explicaciones en cada cliente.
- Consolidador de inventario: un script que coma los `.json` de varios equipos y saque un
  cuadro por cliente.

## Licencia

[MIT](LICENSE) © 2026 LianDev
