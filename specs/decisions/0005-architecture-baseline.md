# ADR 0005 — Arquitectura base del cliente

| Campo | Valor |
|---|---|
| **Estado** | Aceptada (2026-11-14) |
| **Fecha** | 2026-11-14 |

## Contexto

PMV.md §4 y ONLINE.md fijan principios (componentes, recursos, señales, autoloads, ganchos de §4.5), pero no
cómo se resuelven ocho decisiones que afectan a todas las features: flujo de escenas, interacción, inventario y
piezas, stats, guardado, señales globales, catálogo de datos y UI. Sin decidirlas antes, cada spec las
resolvería a su manera y el código se duplicaría (por ejemplo, la interacción aparece en seis tareas de
ACTION_PLAN). Además, el código debe servir cuando haya cooperativo y servidor.

## Decisión

Se adopta la arquitectura de [`specs/architecture.md`](../architecture.md):

1. Escena raíz persistente con una zona cargada a la vez; el robot persiste entre zonas.
2. `InteractableComponent` + `InteractorComponent` para toda interacción.
3. Inventario de `ItemStack`; las piezas son objetos únicos con durabilidad e `uid`.
4. Stats por modificadores de datos (`StatModifier`) y un cálculo puro.
5. Serialización por componente a JSON con `schema_version` y migraciones; nunca `Resource` en `user://`.
6. Señales locales por defecto y un `EventBus` con una lista cerrada de eventos.
7. `DataRegistry` con un catálogo explícito e ids estables.
8. `UIManager` con pila de pantallas; el HUD se engancha al jugador local por señales.

Transversal: capas con dependencias en un solo sentido, estado con dueño único, cambios por métodos con
parámetros explícitos que devuelven `ActionResult`.

## Alternativas

| Opción | A favor | En contra |
|---|---|---|
| **Arquitectura definida antes del código** (elegida) | Cada spec reutiliza piezas comunes; preparado para cooperativo | Trabajo previo (~1 documento) |
| Decidir en cada spec | Empieza antes | Soluciones distintas para el mismo problema; refactor caro en Fase 2-3 |
| ECS o framework de terceros | Patrones conocidos | Dependencia nueva; Godot ya da nodos, señales y recursos |

## Consecuencias

- Los planos (`plan.md`) citan la sección de arquitectura que aplican y su check de constitución lo revisa.
- ACTION_PLAN 3.1-3.2 guarda la durabilidad y los stats dentro de `PieceData`; con esta arquitectura la
  durabilidad va en la instancia (`ItemStack`) y los stats en modificadores. ACTION_PLAN 3.1-3.2 ya está ajustado.
- v2.0 (cooperativo con anfitrión Godot) reutiliza casi toda la lógica. v3.0 (servidor Rust/Go) reutiliza
  contratos de datos y formatos, pero **reescribe la lógica** (architecture.md §12).
- Añadir un autoload o un evento global exige actualizar `architecture.md`.
