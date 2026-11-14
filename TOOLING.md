# Tooling — Herramientas, servicios y tecnologías

> Documento de referencia sobre programas/tecnologías externas, con pros, contras, coste y fase de implementación recomendada.
> **Objetivo**: elegir la tecnología óptima en el momento justo, sin introducir dependencias antes de tiempo.

---

## 1. Analíticas

| Herramienta | Pros | Contras | Coste | Fase recomendada |
|---|---|---|---|---|
| **Firebase Analytics** (recomendada) | Gratis, integrada con el ecosistema Firebase (Firestore, Auth, Crashlytics). Métricas de retención, sesiones, zonas de muerte, progresión. | Menos métricas específicas de juegos que GameAnalytics. | Gratis (hasta límites altos) | **v1.5** (con co-op asíncrono) |
| **GameAnalytics** | Métricas específicas de juegos móviles (embudo de onboarding, retención por nivel, economía). | Integración adicional. UI más limitada que Firebase. | Gratis | Opcional, v1.5+ |

**Decisión**: empezar con **Firebase Analytics** (gratis, ya integrado). Añadir GameAnalytics solo si se necesitan métricas específicas de juego.

---

## 2. Reporte de errores (crash/errores)

| Herramienta | Pros | Contras | Coste | Fase recomendada |
|---|---|---|---|---|
| **Firebase Crashlytics** (recomendada) | Gratis, reporte automático de crashes, integrada con Firebase. | Menos detalle que Sentry en stack traces custom. | Gratis | **v1.5** |
| **Sentry** | Stack traces más detallados, soporte para muchos lenguajes, breadcrumbs. | Coste si escalas (free tier limitado). Integración adicional. | Gratis hasta límite; de pago al escalar | Opcional, solo si Crashlytics no basta |

**Decisión**: **Firebase Crashlytics** desde el inicio. Sentry solo si se detectan bugs difíciles de reproducir.

---

## 3. Monetización

> **Modelo de negocio (nov 2026)**: demo gratis + desbloqueo único en v1.1, cosméticos opcionales, suscripción online solo si hay coste de servidor, **sin anuncios**. Ver SPECS.md §23.

| Herramienta | Pros | Contras | Coste | Fase recomendada |
|---|---|---|---|---|
| **Facturación de Google Play** (plugin de Godot para Android) | Nativa, necesaria para el desbloqueo de pago en Android. Sin intermediarios. | Hay que gestionar la restauración de compras y probar con compras de test de Play Console. Plugin exacto por verificar en la documentación de Godot. | Comisión de la tienda (~10-15% para desarrolladores pequeños, SPECS.md §23.2) | **v1.1** (desbloqueo), detrás de `IStore` |
| **Facturación de Apple** (StoreKit vía plugin de Godot para iOS) | Equivalente en iOS. | Requiere Mac y Apple Developer. Plugin por verificar. | 15% con el Small Business Program | Cuando se publique iOS |
| **RevenueCat** | Unifica compras y suscripciones de iOS/Android, métricas de ingresos, A/B de precios. | Dependencia extra. No es necesaria para un único desbloqueo. | Gratis hasta 2.500 $ de ingresos mensuales rastreados; 1% después (fuentes de terceros, nov 2026) | Opcional: solo si hay suscripción online o varias plataformas que lo justifiquen |
| ~~AdMob~~ (ads rewarded) | — | — | — | **Descartado** (nov 2026): sin anuncios |

**Decisión**: facturación **nativa** de cada tienda detrás de la clase base `IStore` (PMV.md §4.5), introducida en **v1.1** con el desbloqueo. En el PMV solo existe `LocalStore` (sin compras). RevenueCat es opcional. Sin anuncios.

---

## 4. Backend / Base de datos (para online)

| Herramienta | Pros | Contras | Coste | Fase recomendada |
|---|---|---|---|---|
| **Firebase** (recomendada) | Gratis hasta ~1000 DAU. Realtime DB, Firestore, Auth (Google/Anónimo). Sin servidor que mantener. | Vendor lock-in. Coste crece si escala mucho. | Gratis hasta límites; pago al escalar | **v1.5** (Fase 1 ONLINE) |
| **Supabase** | Open source (PostgreSQL), sin vendor lock-in. Alternativa a Firebase. Plan gratuito con ~50.000 usuarios activos al mes y 500 MB de base de datos por proyecto (fuentes de terceros, nov 2026; verificar en supabase.com/pricing). | El plan gratuito **pausa los proyectos tras una semana sin actividad**; producción seria requiere self-host o plan de pago. | Gratis (plan gratuito o self-host) o plan de pago | Alternativa si se quiere evitar lock-in |

**Decisión**: **Firebase** para Fase 1 (asíncrono). Migrar a servidor propio (Rust/Go) en Fase 3 (PvP), como indica ONLINE.md.

---

## 5. Cloud save / Progresión entre dispositivos

| Herramienta | Pros | Contras | Coste | Fase recomendada |
|---|---|---|---|---|
| **Google Play Games Services** | Cloud save, logros, leaderboards, inicio de sesión. Nativo Android. | Solo Android. Requiere cuenta developer ($25). | Gratis (incluido en developer) | **v1.3** (con Google Play Games; antes v1.2, roadmap reorganizado en nov 2026) |
| **Game Center (iOS)** | Equivalente de Apple: cloud save, logros. | Solo iOS. Requiere Apple Developer ($99/año). | Gratis (incluido en Apple Developer) | iOS (post-PMV) |

**Decisión**: **Google Play Games** en v1.3 (Android primero). Game Center cuando se publique iOS.

---

## 6. A/B testing y configuración remota

| Herramienta | Pros | Contras | Coste | Fase recomendada |
|---|---|---|---|---|
| **Firebase Remote Config** | Testear balances, precios, drop rates sin publicar update. Integrada con Firebase. | Requiere Firebase. | Gratis | **v1.5** |

**Decisión**: **Firebase Remote Config** en v1.5 para ajustar balance sin publicar.

---

## 7. Rendimiento y mejora del juego

| Tecnología | Pros | Contras | Coste | Fase recomendada |
|---|---|---|---|---|
| **Object pooling** | Reutilizar enemigos, proyectiles, partículas. Reduce GC y FPS drops. | Implementación manual. | €0 | **PMV** (desde Fase 0) |
| **LOD (Level of Detail)** | Reduce polígonos en objetos lejanos. | Configuración por modelo. | €0 | **PMV** (optimización) |
| **Texturas comprimidas (ETC2/PVRTC)** | Menos memoria, carga más rápida. | Pérdida de calidad menor. | €0 | **PMV** |
| **Lightmaps** | Luces estáticas precalculadas. Reduce luces dinámicas. | Solo para geometría estática. | €0 | **PMV** |

**Decisión**: técnicas estándar de optimización 3D móvil, todas incluidas en el PMV (ver ACTION_PLAN.md).

---

## 8. CI/CD y testing

| Herramienta | Pros | Contras | Coste | Fase recomendada |
|---|---|---|---|---|
| **GitHub Actions** | CI gratuito. Export automatizado de Godot, build de pruebas. | Configuración inicial. | Gratis (para repo público/privado con límites) | **PMV** (desde Fase 0) |
| **GUT 9.7.1** (addon de tests, rama `godot_4_7`) | Soporte declarado de Godot 4.7.x en versión estable; dobles y stubs; ejecución headless en CI; informe JUnit. | Menos utilidades de escena que gdUnit4. En headless no simula clics sobre `Control` (fuente única, por confirmar). | Gratis (MIT) | **PMV** (Fase 0, spec 001). Decisión: `specs/decisions/0002-test-framework-gut.md` |
| **Play Console testing** | 12 testers durante 14 días (requisito nuevo). Track de pruebas. | Requiere cuenta developer ($25). | $25 (una vez) | **Fase 6** (publicación) |
| **TestFlight (iOS)** | Testing beta en iOS. | Requiere Apple Developer ($99/año). | $99/año | iOS (post-PMV) |

**Decisión**: **GitHub Actions** para CI desde el inicio. Play Console testing en la fase de publicación.

---

## 9. Legal y privacidad

| Herramienta | Pros | Contras | Coste | Fase recomendada |
|---|---|---|---|---|
| **Generador de política de privacidad** (privacypolicygenerator.info) | Rápido, gratis. | Plantilla genérica, puede necesitar ajuste legal. | Gratis | **Fase 6** (antes de publicar) |
| **Asesor legal** | Política a medida, cumplimiento GDPR/COPPA real. | Coste. | $200-1000 | Opcional, antes de publicar |

**Decisión**: generador gratuito para PMV; asesor legal si hay ingresos significativos o usuarios EU.

---

## Resumen de decisiones por fase

| Fase | Herramientas a introducir |
|---|---|
| **PMV (v1.0)** | GitHub Actions (CI), GUT (tests), object pooling, LOD, texturas comprimidas, lightmaps. `IStore` + `LocalStore` (código propio, sin servicio externo) |
| **v1.1** | Facturación de Google Play (desbloqueo único) detrás de `IStore` |
| **v1.3** | Google Play Games (cloud save, logros), página web (React + Firebase Hosting) |
| **v1.5** | Firebase Analytics, Crashlytics, Remote Config, Firebase backend (Fase 1 ONLINE) |
| **v2.0+** | Supabase solo si se evita lock-in; relay solo para co-op por internet (Fase 2B); servidor propio Rust/Go solo en v3.0 |
| **Post-PMV (si hace falta)** | RevenueCat (opcional), Facturación de Apple (con iOS), Sentry (si Crashlytics no basta), asesor legal |
| **Nunca** | AdMob ni ninguna red de anuncios (decisión nov 2026) |

---

*Documento vivo. Revisar al inicio de cada fase. No introducir dependencias antes de la fase en que aportan valor.*