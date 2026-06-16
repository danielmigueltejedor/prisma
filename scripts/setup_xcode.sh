#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Instalando XcodeGen..."
  brew install xcodegen
fi

echo "Generando Prisma.xcodeproj..."
xcodegen generate

echo "Limpiando atributos extendidos..."
xattr -cr Prisma.xcodeproj 2>/dev/null || true

echo "Validando proyecto..."
xcodebuild -project Prisma.xcodeproj -list

echo ""
echo "Listo. Abre con: open Prisma.xcodeproj"
