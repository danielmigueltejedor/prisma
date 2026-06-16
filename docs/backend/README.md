# Prisma+ Backend (futuro)

API ligera para funciones Prisma+ que requieren IA o procesamiento en servidor.

## Principios

- La app gratuita **no depende** de este backend.
- Solo se contacta cuando el usuario tiene Prisma+ activo.
- Se envía metadata mínima (título, extracto, URL, fuente) — nunca historial completo sin consentimiento.
- Resúmenes cacheados por hash de URL para reducir costes.

## Stack sugerido

- **Runtime:** Node.js + pnpm
- **Framework:** Fastify o Hono
- **DB:** PostgreSQL o libSQL
- **Cache:** Redis (opcional)
- **Workers:** cola para clustering y briefing diario

## Autenticación

1. Sign in with Apple → JWT de sesión, o
2. Token anónimo vinculado a `original_transaction_id` de StoreKit (validado server-side con App Store Server API).

## Endpoints

Ver `openapi.yaml` en esta carpeta.

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/v1/summarize` | Resumen de artículo |
| POST | `/v1/classify` | Clasificación temática |
| POST | `/v1/cluster` | Agrupación de noticias |
| POST | `/v1/compare` | Comparación entre fuentes |
| POST | `/v1/briefing` | Portada diaria |
| POST | `/v1/context` | Contexto del artículo |
| GET | `/v1/quota` | Cuota restante del usuario |

## Cuotas sugeridas (Prisma+)

- 100 resúmenes/día
- 10 briefings/día
- 50 comparaciones/día

## Despliegue MVP backend

```bash
pnpm install
pnpm dev
```

Variables de entorno:

- `DATABASE_URL`
- `OPENAI_API_KEY` o `ANTHROPIC_API_KEY`
- `APPLE_SHARED_SECRET` (validación suscripciones)

## Cliente iOS

`RemoteAIService` en `Prisma/AI/RemoteAIService.swift` implementa el protocolo `AIService` y apunta a esta API.

Para activarlo, sustituir `MockAIService()` por:

```swift
RemoteAIService(
  baseURL: URL(string: "https://api.prisma.app")!,
  networkClient: networkClient,
  apiToken: userSessionToken
)
```
