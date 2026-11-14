# ADR 0001 — Una base de código: Android como producto, PC como entorno de desarrollo

| Campo | Valor |
|---|---|
| **Estado** | Aceptada |
| **Fecha** | 2026-11-13 |

## Contexto

El PMV es un juego móvil (Android primero, PMV.md §10). Iterar solo en el móvil es lento: cada prueba exige
exportar e instalar. Godot exporta el mismo proyecto a varias plataformas con *export presets* y permite
distinguirlas en ejecución con *feature tags* (`mobile`, `pc`, `android`, `windows`…) y overrides de ajustes de
proyecto por tag ([docs: Feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html)).

## Decisión

- **Un solo proyecto y una sola rama principal** para todas las plataformas. Sin ramas por plataforma.
- **Android**: único producto del PMV.
- **Windows (PC)**: objetivo de desarrollo y test, con teclado/ratón. No se publica ni se pule para PC; si un día
  se quiere publicar, es una decisión de producto que va primero a `PMV.md §9/§10`.

Cómo se aplica (detalle en spec 001 y 002):

| Área | Regla |
|---|---|
| Input | El gameplay lee acciones de InputMap (`move_*`, `run`, `attack`, `interact`…). El joystick virtual y los botones táctiles alimentan las mismas acciones que el teclado |
| UI táctil | Visible en dispositivos táctiles; en PC se puede forzar para probarla con el ratón |
| Pantalla | Apaisada 1920x1080 en ambas (retrato hasta la enmienda del 2026-11-14, spec 001); en PC la ventana se reduce con un override de tamaño de ventana |
| Render | Compatibility (OpenGL ES 3.0) en ambas, para que el PC enseñe lo que verá el móvil |
| Rendimiento | Solo vale la medición en Android real (constitución P12) |
| Código específico | Solo en la capa de input/UI y en overrides de `project.godot`; nunca en gameplay (constitución P8) |

## Alternativas

| Opción | A favor | En contra |
|---|---|---|
| **Una base, PC solo desarrollo** (elegida) | Iteración rápida, cero coste de producto extra, el código queda listo por si algún día se publica en PC | Hay que mantener las dos rutas de input |
| Una base, PC también producto | Más mercado | Añade alcance (UI horizontal, mando, opciones gráficas, tienda): contra el riesgo de scope creep |
| Ramas por plataforma | — | Divergencia, merges constantes, bugs que solo existen en una rama. No lo exige Godot |

## Consecuencias

- Los specs con input o UI incluyen requisitos para táctil y para teclado.
- La Definición de hecho exige probar en Android lo que toque input, UI o rendimiento.
- Los custom feature tags no se aplican al ejecutar desde el editor (docs de Godot), así que la elección táctil /
  teclado se decide en ejecución por capacidad del dispositivo, no por tag de export.
