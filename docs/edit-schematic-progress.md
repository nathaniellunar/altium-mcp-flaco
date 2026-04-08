# Progreso: herramienta `edit_schematic`

Documento de estado de la herramienta MCP **edit schematic** y de sus **acciones** (submodos). Útil para roadmap, depuración y alineación entre capa Node (MCP) y capa DelphiScript (Altium).

## Arquitectura

| Capa | Rol |
|------|-----|
| **Cursor / MCP** | Herramienta única `edit_schematic`; valida entrada con Zod (`src/tools/editSchematic.ts`). |
| **Node bridge** | `AltiumBridge.executeCommand("schematic_edit", params, { timeoutMs: 240_000 })` en `src/index.ts` (timeout largo frente a arranque lento de AD). |
| **DelphiScript** | Comando `schematic_edit` en `Altium_API.pas` → `SchematicEditMain` en `altium-scripts/schematic_edit.pas`. |

El workspace MCP mantiene una copia espejo de `altium-scripts` bajo `workspace/AltiumScript/`; el bridge lanza Altium con `Altium_API.PrjScr`.

## Identificación de la hoja (obligatorio vía MCP)

La validación Zod exige **una** de estas formas de apuntar al `.SchDoc`:

- **`schematic_full_path`**: ruta absoluta al `.SchDoc` (recomendado).
- **`schematic_sheet_file_name`**: solo nombre de archivo (p. ej. `Sheet1.SchDoc`), con proyecto enfocado en Altium o **`project_full_path`**.

En Delphi, la resolución final y los errores de hoja están en `SchEditResolveSheet` (ver tabla de errores más abajo).

## Acciones implementadas

Todas las acciones listadas están implementadas en **Node** (enum + `superRefine`) y en **Pascal** (`SchematicEditMain`).

### Resumen

| `action` | Propósito | Parámetros clave (además de la hoja) |
|----------|-----------|--------------------------------------|
| `set_component_transform` | Mover y/o rotar un símbolo por designator | `designator`; al menos uno de `x_mils`, `y_mils`, `rotation_deg` |
| `set_component_parameters` | Actualizar o añadir parámetros de componente | `designator`, `parameter_names[]`, `parameter_values[]` (misma longitud) |
| `place_component` | Colocar un componente desde librería o fábrica | `lib_reference`, `designator`, `x_mils`, `y_mils`; opc. `rotation_deg`, `sch_library_path` |
| `add_text` | Texto libre en la hoja | `text`, `x_mils`, `y_mils` |
| `add_net_label` | Etiqueta de red | `net_name`, `x_mils`, `y_mils`; opc. `rotation_deg` |
| `add_wire` | Polilínea ortogonal por segmentos | `wire_points_csv` |
| `place_wire` | Alias de `add_wire` (misma implementación) | `wire_points_csv` |
| `place_net_label` | Alias de `add_net_label` | `net_name`, `x_mils`, `y_mils`; opc. `rotation_deg` |
| `add_bus` | Polilínea de **bus** (`eBus`), mismo CSV que `add_wire` | `wire_points_csv` |
| `add_bus_entry` | Un segmento de **bus entry** (`eBusEntry`) | `wire_points_csv` con **exactamente** cuatro números `x1,y1,x2,y2` (mils) |
| `place_power_port` | **Power port** (`ePowerObject` / `ISch_PowerObject`) | `power_port_style`, `x_mils`, `y_mils`; opc. `net_name`, `rotation_deg`, `show_net_name` |
| `place_gnd` | Atajo: estilo por defecto **gnd_power** | mismos opcionales que power port salvo estilo obligatorio en `place_power_port` |
| `place_vcc` | Atajo: estilo por defecto **arrow** | idem |

### Detalle por acción

#### `set_component_transform`

- **MCP**: `designator` obligatorio; al menos una de posición o rotación.
- **Altium**: Coordenadas en **mils**; rotación en grados, habitualmente alineada a 0/90/180/270 según API.
- **Errores Delphi frecuentes**: `COMPONENT_NOT_FOUND`.

#### `set_component_parameters`

- **MCP**: `parameter_names` y `parameter_values` obligatorios, no vacíos, misma longitud.
- **Errores Delphi**: `COMPONENT_NOT_FOUND`, `PARAMETER_ARRAY_MISMATCH`.

#### `place_component`

- **MCP**: `lib_reference`, `designator`, `x_mils`, `y_mils` obligatorios; `rotation_deg` opcional (Pascal usa 0 si no se envía).
- **`sch_library_path`**: ruta absoluta a `.SchLib` opcional; sin ella se usa resolución por `LibReference` y rutas del proyecto.
- **Errores Delphi**: `LIB_REFERENCE_OR_DESIGNATOR_MISSING`, `SCH_LIBRARY_NOT_FOUND`, `PLACE_SCH_COMPONENT_FAILED`, `PLACED_COMPONENT_NOT_FOUND`, `FACTORY_SCH_COMPONENT_FAILED`.

#### `add_text`

- **MCP**: `text`, `x_mils`, `y_mils` obligatorios.
- **Errores Delphi**: `TEXT_EMPTY`, `FACTORY_LABEL_FAILED`.

#### `add_net_label`

- **MCP**: `net_name`, `x_mils`, `y_mils` obligatorios; `rotation_deg` opcional.
- **Errores Delphi**: `NET_NAME_EMPTY`, `FACTORY_NETLABEL_FAILED`.

#### `add_wire`

- **MCP**: `wire_points_csv` obligatorio (cadena CSV de números en mils).
- **Formato**: pares consecutivos definen vértices de segmentos ortogonales, p. ej. `0,0,1000,0,1000,500` → dos segmentos.
- **Errores Delphi**: `WIRE_POINTS_CSV_REQUIRED`, `WIRE_POINTS_NEED_AT_LEAST_FOUR_NUMBERS`, `WIRE_POINTS_ODD_COUNT`, `FACTORY_WIRE_FAILED`.

#### `place_wire` / `place_net_label`

- **MCP**: Misma validación que `add_wire` / `add_net_label`.
- **Pascal**: Se normalizan a `add_wire` / `add_net_label` antes del dispatcher; el JSON de respuesta incluye el `action` **original** enviado por el cliente (`ReportAction`).

#### `add_bus`

- **MCP**: Mismo `wire_points_csv` que `add_wire`.
- **Pascal**: `SchEditAddWireOrBusSegments(..., True)` usando `eBus` e `ISch_Bus`.
- **Errores Delphi**: `BUS_POINTS_CSV_REQUIRED`, mismos de puntos inválidos que wire, `FACTORY_BUS_FAILED`.

#### `add_bus_entry`

- **MCP**: Exactamente **cuatro** valores numéricos en `wire_points_csv` (un solo segmento).
- **Pascal**: `SchEditAddBusEntrySegment` con `eBusEntry` e `ISch_BusEntry` (`Location` / `Corner` como cable).
- **Errores Delphi**: `BUS_ENTRY_POINTS_CSV_REQUIRED`, `BUS_ENTRY_POINTS_NEED_EXACTLY_FOUR_NUMBERS`, `FACTORY_BUS_ENTRY_FAILED`.

#### `place_power_port` / `place_gnd` / `place_vcc`

- **MCP**: `power_port_style` obligatorio solo en `place_power_port` (enum: `circle`, `arrow`, `bar`, `wave`, `gnd_power`, `power_ground`, `gnd_signal`, `signal_ground`, `gnd_earth`, `earth`). `x_mils` y `y_mils` obligatorios. `net_name` opcional (si se omite, el bridge usa GND para estilos de tierra y VCC para el resto). `show_net_name` opcional (por defecto verdadero en Pascal).
- **Pascal**: `SchObjectFactory(ePowerObject, eCreate_Default)` → `ISch_PowerObject`: `Text`, `Location`, `Orientation`, `SetState_Style` (`TPowerObjectStyle`), `SetState_ShowNetName`. `place_gnd` sin estilo → `ePowerGndPower`; `place_vcc` sin estilo → `ePowerArrow`.
- **Errores Delphi**: `POWER_PORT_STYLE_REQUIRED`, `POWER_PORT_STYLE_INVALID`, `FACTORY_POWER_OBJECT_FAILED`, `X_Y_MILS_REQUIRED`.

## Respuesta esperada

- **Éxito**: JSON con propiedades como `action`, `sheet` y `details` (objeto/modo según la acción), generado en Pascal (`BuildJSONObject`).
- **Fallo controlado en Delphi**: cadena devuelta con prefijo `ERROR: ...` (también puede ir dentro del flujo MCP como resultado parseado).
- **Excepción no tipada en Pascal**: `ERROR: SCHEMATIC_EDIT_EXCEPTION` (el runtime de script no usa `on E: Exception` por compatibilidad con DelphiScript de Altium).
- **Capa superior** (`Altium_API.pas`): ante excepciones globales del script puede devolverse el mensaje genérico de ejecución al bridge.

## Errores de resolución de hoja (`SchEditResolveSheet`)

| Código (prefijo `ERROR:`) | Significado aproximado |
|---------------------------|-------------------------|
| `NO_WORKSPACE` | Sin workspace de Altium |
| `SHEET_REQUIRED` | Falta `schematic_full_path` y `schematic_sheet_file_name` en la petición al bridge |
| `SCHEMATIC_NOT_IN_OPEN_PROJECTS` | Hoja no encontrada entre proyectos abiertos |
| `PROJECT_NOT_FOUND` | `project_full_path` no coincide con un proyecto abierto |
| `SCHEMATIC_SHEET_NOT_FOUND` | Nombre/ruta de hoja no coincide |
| `NO_FOCUSED_PROJECT` | Sin proyecto enfocado cuando hace falta |
| `SCH_DOCUMENT_NOT_OPEN` | Documento no abierto |
| `NOT_A_SCHEMATIC_SHEET` | El documento no es esquemático |

## Errores comunes en el dispatcher (`SchematicEditMain`)

| Código | Cuándo |
|--------|--------|
| `ACTION_REQUIRED` | Falta `action` en el JSON de petición |
| `DESIGNATOR_REQUIRED` | Acciones que exigen designator |
| `X_Y_MILS_REQUIRED` | `add_text` / `add_net_label` sin coordenadas |
| `WIRE_POINTS_CSV_REQUIRED` | `add_wire` / `place_wire` sin CSV |
| `BUS_POINTS_CSV_REQUIRED` | `add_bus` sin CSV |
| `BUS_ENTRY_POINTS_CSV_REQUIRED` | `add_bus_entry` sin CSV |
| `UNKNOWN_ACTION` | `action` no reconocida |
| `POWER_PORT_STYLE_REQUIRED` | `place_power_port` sin `power_port_style` |
| `POWER_PORT_STYLE_INVALID` | token de estilo no reconocido |
| `FACTORY_POWER_OBJECT_FAILED` | `SchObjectFactory(ePowerObject)` devolvió nil |

## Herramientas relacionadas

- **`get_schematic_data`**: lectura de componentes de la misma hoja; conviene llamarla después de editar para verificar.
- **`get_workspace_projects`**: descubrir `project_full_path` y `fullPath` de `.SchDoc` abiertos.

## Limitaciones y notas operativas

- **Guardado**: el bridge no fuerza guardar el `.SchDoc`; el usuario puede guardar manualmente en Altium.
- **Depurador / breakpoints**: si el IDE de scripts está en pausa, no se escribe `response.json` → **TIMEOUT** en el cliente MCP. Quitar breakpoints o ejecutar sin depurador.
- **Bloqueo `.bridge.lock`**: si un proceso muere a mitad de un comando, el lock puede quedarse; el servidor intenta eliminar locks obsoletos (PID inexistente). Si persiste, borrar `.bridge.lock` en la carpeta del workspace MCP.
- **Versiones de Altium**: detalles de API (interfaces SCH) pueden variar ligeramente entre versiones mayores de AD. En DelphiScript (p. ej. **AD 26.4**), `ISch_Wire`, `ISch_Bus` e `ISch_BusEntry` suelen **no** declarar `Location`/`Corner`; el código asigna ambos extremos vía **`ISch_GraphicalObject`** (`Gr := W` / `Gr := Bus` / `Gr := BE`) y registra el objeto concreto en el contenedor. `MaxInt` no suele existir en el scripting de Altium: en `Altium_API.pas` se usa `Length(Data)` en `Copy` al parsear `ERROR:`.
- **Depuración MCP**: ante `success: false`, Altium escribe `bridge_last_error.txt` en el workspace y el servidor Node concatena ese texto al campo `error` de la herramienta. Los errores de **compilación** del script no pasan por el bridge: pegar el panel Messages en `bridge_user_reported_error.txt` y llamar `get_server_status` para que el agente los lea (`bridgeUserReportedError`).

## Evolución reciente (contexto de implementación)

- Sincronización del bundle `altium-scripts` → workspace por **huella de contenido** y **espejado in-place** (sin borrar toda la carpeta en cada sync) para no duplicar proyectos de script en Altium.
- Compatibilidad DelphiScript: sin `REPLACEALL` en `schematic_edit.pas` antes de `Altium_API.pas` (uso de flags numéricos `1` en `StringReplace` donde aplica).
- `try/except` en `SchematicEditMain` con cuerpo en `begin`/`end` explícito y `except` simple (sin `Exception` tipada).

---

## Visión: subbloques y subherramientas

### Valoración de la idea

La organización por **bloques funcionales** (cables, alimentación, harness, puertos, parámetros, texto, figuras) encaja muy bien con cómo Altium agrupa comandos en la UI y con cómo un agente razona (“quiero cablear”, “quiero marcar alimentación”). Da **más control** si cada hoja del roadmap se implementa con parámetros explícitos y errores claros.

**Es posible**, con matices:

| Aspecto | Comentario |
|---------|------------|
| **MCP / Cursor** | El protocolo no define “subtools” anidadas. Lo habitual es **una herramienta** `edit_schematic` con un campo **`action`** (o `operation`) por operación atómica, p. ej. `place_bus`, `place_gnd`. Los “subbloques” son **taxonomía y documentación** (y opcionalmente un campo opcional `block` solo informativo para el modelo, sin usarlo en el bridge). |
| **Bridge** | Sigue siendo **un JSON por invocación** (`command: schematic_edit` + payload). Cada subherramienta = nuevo valor de `action` + campos propios en el mismo objeto. |
| **Altium / DelphiScript** | Cada subherramienta nueva exige comprobar en la **API de esquemático** de tu versión de AD (`ISch_*`, `SchServer`, fábricas de objetos). Algunas primitivas son directas; otras (harness, blankets, puertos jerárquicos) son **más frágiles entre versiones** y merecen spike antes de comprometer firma estable. |

**Recomendación de diseño**: mantener **nombres de `action` planos y estables** (`place_net_label`, `place_line`, …) y agruparlos en documentación y en el schema Zod con comentarios o discriminación por `superRefine` por familia. Evita registrar decenas de herramientas MCP distintas (ruido para el cliente y duplicación de descripciones). Si en el futuro alguna familia crece mucho, valorar una **segunda herramienta** MCP solo para ese dominio (p. ej. `edit_schematic_harness`).

### Taxonomía propuesta (referencia)

Árbol orientativo; los nombres en *cursiva* son candidatos a valores de `action` (ajustar a snake_case único en implementación).

```
edit_schematic
├── PLACE COMPONENT     → ya cubierto por place_component (+ transform / parameters)
├── WIRES
│   ├── place_wire      → alinear con add_wire o renombrar con compatibilidad
│   ├── place_bus
│   ├── place_bus_entry
│   └── place_net_label → alinear con add_net_label o renombrar con alias
├── POWER PORT
│   ├── place_gnd
│   └── place_vcc
├── HARNESS
│   ├── place_signal
│   ├── place_connector
│   └── place_entry
├── PORTS
│   ├── place_port
│   └── place_off_sheet
├── PARAMETERS
│   ├── place_parameter_set
│   ├── place_blanket
│   └── place_no_erc
├── TEXT
│   ├── place_text_simple   → alinear con add_text
│   ├── place_text_frame
│   └── place_note
└── FIGURES
    ├── place_arc
    ├── place_full_circle
    ├── place_elliptical_arc
    ├── place_ellipse
    ├── place_line
    ├── place_rectangle
    ├── place_round_rectangle
    ├── place_polygon
    ├── place_bezier
    └── place_graphic
```

---

## Roadmap por fases (sugerido)

Cada fase debería cerrar con: **spike en AD** (objeto creado a mano + inspección API), **casos en `schematic_edit.pas`**, **Zod + `toolDefinitions` + descriptor MCP**, **prueba manual en un `.PrjPcb` de referencia** y una línea en la tabla “Acciones implementadas” de este documento.

### Fase 0 — Línea base (hecho)

- Herramienta única `edit_schematic` + comando `schematic_edit`.
- Acciones: componente (colocar / transformar / parámetros), texto, etiqueta de red, cable polilínea.
- Validación Zod, timeout de bridge, mirror de scripts, manejo de errores DelphiScript.

### Fase 1 — Familia **WIRES** — **HECHO** (código y docs en repo)

**Objetivo**: completar lo cercano a “cableado” en la UI de Altium.

**Estado (repo)**: Cerrada. Implementado en `schematic_edit.pas` (`SchEditAddWireOrBusSegments`, `SchEditAddBusEntrySegment`, alias `place_wire` / `place_net_label`, `ReportAction` en JSON), `editSchematic.ts` + `toolDefinitions.ts`, tests Vitest en `tests/editSchematic.test.ts`. `WriteResponse` en `Altium_API.pas` recorta el prefijo `ERROR:` con `Trim` tras el literal para mensajes más precisos en el bridge.

**Verificación opcional en tu PC**: conviene probar en Altium Designer que bus y bus entry se crean como esperas en tu versión (el código usa `ISch_GraphicalObject` para extremos; ver notas en “Limitaciones”).

| Paso | Trabajo |
|------|---------|
| 1.1 | ~~Documentar~~ — Tipos `TObjectId`: `eBus`, `eBusEntry`, `eWire` (referencia API Altium). **Hecho** (tablas y sección WIRES en este doc). |
| 1.2 | Probar en **tu** AD que bus / bus entry se comportan bien (no bloquea cierre de fase en repo). |
| 1.3 | ~~`add_bus`, `add_bus_entry` con `wire_points_csv`~~ — **Hecho**. |
| 1.4 | ~~`SchEditAddWireOrBusSegments`, `SchEditAddBusEntrySegment`, ramas en `SchematicEditMain`~~ — **Hecho**. |
| 1.5 | ~~Enum Zod + `superRefine`; descripción MCP~~ — **Hecho**. |
| 1.6 | ~~Alias `place_wire` → `add_wire`, `place_net_label` → `add_net_label`; respuesta JSON con acción enviada por el cliente~~ — **Hecho**. |

**Riesgo**: bajo/medio; si AD falla al compilar interfaces, revisar nombres de tipos en la ayuda de scripting de tu instalación.

### Fase 2 — **POWER PORT** (GND / VCC) — **HECHO** (repo)

**Objetivo**: colocar puertos de alimentación con estilo y red coherentes con el proyecto.

**Estado (repo)**: Implementado: `place_power_port` + atajos `place_gnd` / `place_vcc`; `SchEditPlacePowerPort` en `schematic_edit.pas`; validación Zod + tests Vitest; documentación en `toolDefinitions` + este doc.

| Paso | Trabajo |
|------|---------|
| 2.1 | ~~Objeto SCH: `ePowerObject` / `ISch_PowerObject` (`Text`, `SetState_Style` (`TPowerObjectStyle`), `SetState_ShowNetName`, `Location`, `Orientation`).~~ **Hecho** |
| 2.2 | ~~Una acción principal `place_power_port` con `power_port_style` + atajos `place_gnd` / `place_vcc`.~~ **Hecho** |
| 2.3 | ~~Zod + Pascal + coordenadas / rotación / net opcional / `show_net_name`.~~ **Hecho** |
| 2.4 | **Pendiente en hardware**: probar en tu AD que los estilos coinciden con la librería del proyecto (los nombres de red siguen siendo `Text` del power object). |

**Riesgo**: medio (convenciones de librería y net name).

### Fase 3 — **TEXT** ampliado

**Objetivo**: marco de texto, nota, posiblemente alineación con estándar de documentación.

| Paso | Trabajo |
|------|---------|
| 3.1 | Mapear API para **text frame** y **note** vs etiqueta simple actual. |
| 3.2 | Añadir `add_text_frame`, `add_note` (o prefijo `place_*`) con parámetros (bounding box mils, contenido, fuente si expuesta). |
| 3.3 | Documentar limitaciones (plantillas, fuentes). |

**Riesgo**: bajo/medio.

### Fase 4 — **FIGURES** (primitivas geométricas)

**Objetivo**: líneas, rectángulos, círculos, arcos, polígonos, bezier según soporte API.

| Paso | Trabajo |
|------|---------|
| 4.1 | Listar tipos `ISch_*` o fábricas por figura en la versión objetivo de AD. |
| 4.2 | Implementar primero las **más usadas y simples**: `place_line`, `place_rectangle` (2 esquinas o ancho/alto), `place_polygon` (lista de puntos). |
| 4.3 | Arcos / elipses / bezier en sub-iteración (parámetros geométricos y snapping). |
| 4.4 | Unificar convención de unidades (mils) y rotación. |

**Riesgo**: medio (muchas variantes y propiedades por objeto).

### Fase 5 — **PORTS** (sheet / off-sheet)

**Objetivo**: puertos de hoja y conectores entre hojas.

| Paso | Trabajo |
|------|---------|
| 5.1 | Spike para **sheet symbol / port** y **off-sheet connector** en tu AD. |
| 5.2 | Definir parámetros mínimos (nombre, orientación, I/O, hoja destino si aplica). |
| 5.3 | Implementar y probar en diseño multi-hoja. |

**Riesgo**: alto (jerarquía, nombres de hoja, reglas de compilación).

### Fase 6 — **PARAMETERS** (directivas esquemáticas)

**Objetivo**: parameter set, blanket, no-ERC.

| Paso | Trabajo |
|------|---------|
| 6.1 | Revisar documentación AD para **directivas** y objetos asociados. |
| 6.2 | Spike: colocar cada uno desde UI y registrar propiedades accesibles por script. |
| 6.3 | Diseñar payload JSON (rectángulos, clases, reglas) acotado al MVP. |

**Riesgo**: alto (semántica de reglas y ERC).

### Fase 7 — **HARNESS**

**Objetivo**: señales, conectores y entradas de harness en esquemático.

| Paso | Trabajo |
|------|---------|
| 7.1 | Confirmar soporte de scripting para harness en la versión de AD (a veces limitado). |
| 7.2 | Spike aislado antes de exponer en MCP. |
| 7.3 | Si el API es estable, añadir `place_harness_signal`, etc., con parámetros mínimos. |

**Riesgo**: muy alto (dependencia de versión y de flujo harness).

### Transversal a todas las fases

- Mantener **retrocompatibilidad** de `action` existentes o periodo de deprecación documentado.
- Añadir códigos `ERROR:` nuevos por familia para facilitar diagnóstico en el agente.
- Tras cambios grandes, ejecutar **`get_schematic_data`** sobre la misma hoja para verificar efectos.
- Actualizar **SKILL / instrucciones MCP** cuando el conjunto de acciones crezca, para no saturar el contexto: resumen por bloque + “ver documentación del repo para lista completa”.

---

*Última revisión alineada con el repositorio: herramienta `edit_schematic` y acciones anteriores implementadas de extremo a extremo (MCP + `schematic_edit.pas`). **Fase 1 (WIRES)** y **Fase 2 (POWER PORT)** marcadas como HECHO en repo (código; pruebas manuales en AD recomendadas). Actualizar tablas y roadmap al cerrar cada fase.*
