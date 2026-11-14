# Plan NNN — <Nombre de la feature>

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Borrador → Planificado |

## 1. Enfoque

<Resumen del diseño en pocas líneas y por qué este y no la alternativa principal.>

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/components/<x>.gd` | Nuevo | <…> |

## 3. Contratos

```gdscript
# Firmas públicas, señales y recursos. Sin cuerpo.
class_name Example
extends Node

signal something_happened(value: int)

func do_thing(amount: float) -> void
```

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `<X>Data` | <…> | `BALANCE.md §…` |

## 5. Verificación

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-NNN-01 | `unit/test_<x>.gd::test_r_nnn_01_<caso>` |

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P2 Una fuente de verdad | ✅ / ⚠️ | <…> |
| P3 Lógica separada | | |
| P4 Estado por jugador | | |
| P6 Señales | | |
| P7 Tipado | | |
| P8 Plataforma | | |
| P11 i18n | | |
| P12 Presupuesto móvil | | |
| P13 Test primero | | |

Solo se listan los principios que la feature toca; cualquier ⚠️ lleva justificación.

## 7. Riesgos y alternativas descartadas

- <Riesgo → mitigación.>
