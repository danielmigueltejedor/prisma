# Apple Intelligence local en Prisma

## Resumen

Apple expone el modelo on-device de **Apple Intelligence** a apps de terceros mediante el framework **`FoundationModels`** (iOS 26+, iPadOS 26+, macOS 26+). No requiere API key, no factura por token y el procesamiento ocurre en el dispositivo (Neural Engine). Los datos no salen del teléfono salvo que el desarrollador opte explícitamente por **Private Cloud Compute (PCC)**.

Documentación oficial: https://developer.apple.com/documentation/foundationmodels

## Requisitos para el usuario

| Requisito | Detalle |
|-----------|---------|
| **Hardware** | iPhone 15 Pro o posterior, iPad/Mac con chip M1+ |
| **Software** | iOS/iPadOS 26+ con Apple Intelligence activado en Ajustes |
| **Región** | Apple Intelligence solo en regiones soportadas |
| **Descarga** | El modelo se descarga en segundo plano (`modelNotReady` hasta completar) |

## API principal

```swift
import FoundationModels

let model = SystemLanguageModel.default

switch model.availability {
case .available:
  let session = LanguageModelSession(model: model)
  let response = try await session.respond(to: "Resume este artículo...")
case .unavailable(.deviceNotEligible):
  // Dispositivo no compatible
case .unavailable(.appleIntelligenceNotEnabled):
  // Pedir activar Apple Intelligence en Ajustes
case .unavailable(.modelNotReady):
  // Modelo descargándose
case .unavailable:
  break
}
```

Propiedades útiles:
- `SystemLanguageModel.default.isAvailable` → `Bool` rápido
- `SystemLanguageModel(useCase: .contentTagging)` → clasificación / etiquetado

## Salida estructurada (@Generable)

Ideal para resúmenes y clusters sin parsear JSON a mano:

```swift
@Generable
struct ArticleSummaryOutput {
  @Guide(description: "Resumen en 2-3 párrafos en español")
  var summary: String
  @Guide(description: "3-5 puntos clave")
  var keyPoints: [String]
}

let result = try await session.respond(
  to: prompt,
  generating: ArticleSummaryOutput.self
)
```

## Herramientas (Tool calling)

El modelo puede invocar herramientas Swift durante la generación (buscar en SwiftData, refrescar feeds, etc.). Ver `Tool` en la documentación.

## Private Cloud Compute (opcional, no gratuito para todos)

- `PrivateCloudComputeLanguageModel` — modelo más capaz en servidores Apple con privacidad cifrada
- Requiere entitlement `com.apple.developer.private-cloud-compute`
- Pequeños desarrolladores (<2M descargas): acceso sin coste de API cloud según Apple (WWDC 2026)
- **Prisma+** puede usar PCC para clustering avanzado; la capa local cubre lo básico gratis

## Modelo de producto sugerido para Prisma

| Función | Gratis (Apple Intelligence local) | Prisma+ |
|---------|-----------------------------------|---------|
| Resumen de artículo | ✅ On-device | PCC / backend si hace falta más contexto |
| Clasificación / tags | ✅ `contentTagging` | — |
| Contexto del artículo | ✅ On-device | — |
| Comparar fuentes | ⚠️ Limitado (contexto pequeño) | Backend / PCC |
| Clustering multi-fuente | ⚠️ Básico local | Backend |
| Briefing diario | ⚠️ Básico local | Backend |

## Arquitectura en el código

```
AIService (protocolo)
├── FoundationModelsAIService   ← iOS 26+, Apple Intelligence disponible
├── MockAIService               ← simulador / dispositivos sin IA
└── RemoteAIService             ← Prisma+ backend futuro

CompositeAIService
  → elige FoundationModels si isAvailable, si no Mock
```

Archivos:
- `Prisma/AI/AppleIntelligenceAvailability.swift`
- `Prisma/AI/FoundationModelsAIService.swift` (condicional `#if canImport(FoundationModels)`)
- `Prisma/AI/AIServiceFactory.swift`

## Integración con PrismaPlusGate

Opciones:
1. **IA local gratis para todos** en dispositivos compatibles; Prisma+ desbloquea PCC/backend.
2. Mantener paywall solo para funciones que requieran servidor.

Recomendación: opción 1 — alinea con “local-first” y diferencia Prisma+ por síntesis multi-fuente y briefing avanzado.

## Deployment target

- Prisma sigue en **iOS 17** como mínimo.
- Código Foundation Models envuelto en `#if canImport(FoundationModels)` + `@available(iOS 26.0, *)`.
- En iOS 17–25: MockAIService o heurísticas locales existentes.

## Xcode / simulador

- **Xcode 26+** incluye el SDK de FoundationModels.
- En simulador, Apple Intelligence suele **no estar disponible** → verás fallback a Mock.
- Probar en **iPhone 15 Pro+ físico** o simulador con IA habilitada (iOS 26.5+).

## Recursos Apple

- [Generating content with Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- WWDC25: Meet the Foundation Models framework (286), Deep Dive (301)
- WWDC26: What's new in Foundation Models (241)

## Próximos pasos de implementación

1. ✅ Disponibilidad + factory + servicio base
2. Conectar resumen/contexto del lector a `FoundationModelsAIService`
3. Quitar paywall de resumen si `AppleIntelligenceAvailability.isReady`
4. UI: banner si IA desactivada con enlace a Ajustes
5. Evaluar `@Generable` para clusters estructurados
6. Prisma+: PCC o `RemoteAIService` para comparación multi-fuente
