# Prisma

**Prisma — Todas las caras de la noticia.**

Lector RSS premium para iOS. Sin anuncios. Local-first. Prisma+ opcional para IA.

## Requisitos

- Xcode 15+
- iOS 17+
- macOS para compilar

## Abrir el proyecto

El proyecto se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen   # solo la primera vez
xcodegen generate       # regenera Prisma.xcodeproj desde project.yml
open Prisma.xcodeproj
```

Si Xcode muestra *"invalid content"*, regenera el proyecto:

```bash
xcodegen generate
xattr -cr Prisma.xcodeproj
open Prisma.xcodeproj
```

## Estructura

```
Prisma/
├── App/              # Entry point, DI, navegación
├── DesignSystem/     # Tokens y componentes UI
├── Models/           # SwiftData models
├── Persistence/      # Repositorios
├── Networking/       # URLSession
├── Parsing/          # RSS/Atom, OPML, HTML
├── Services/         # Lógica de negocio
├── AI/               # Protocolo + mock + remote stub
├── Paywall/          # StoreKit 2
├── Features/         # Pantallas MVVM
└── Resources/        # Assets, localización, feeds
```

## Funcionalidad MVP

### Real (funciona ya)
- Descarga y parseo RSS/Atom
- Gestión de fuentes (añadir, editar, activar, bloquear)
- Import/export OPML
- Feed cronológico y "Para ti" local
- Lector de artículos con atribución
- Onboarding 4 pantallas
- Paywall Prisma+ (mock en DEBUG)
- Persistencia SwiftData

### Mock (preparado para backend)
- Resúmenes IA
- Clustering
- Portada diaria
- Comparación de fuentes

## Prisma+ en desarrollo

En builds DEBUG, `MockSubscriptionService` permite activar Prisma+ desde Ajustes → "Toggle Prisma+ (Debug)".

Product IDs:
- `com.prisma.plus.monthly` — 1,99 €/mes
- `com.prisma.plus.yearly` — 19,99 €/año

## Backend futuro

Ver `docs/backend/` para OpenAPI y arquitectura del API Prisma+.

## Tests

```bash
xcodebuild test -scheme Prisma -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Filosofía

- Lectura siempre gratis
- Sin scraping ni saltar paywalls
- Sin popups de pago agresivos
- Privacidad local por defecto
