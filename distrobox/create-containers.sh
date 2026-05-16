#!/usr/bin/env bash
# Recria os containers distrobox do Arch Atômico
# Gerado automaticamente pelo backup.sh

set -euo pipefail

echo "→ Criando container Arch-base..."
distrobox create \
    --name Arch-base \
    --image archlinux:latest \
    --yes

echo "→ Criando container subsistema..."
distrobox create \
    --name subsistema \
    --image ubuntu:24.04 \
    --yes

echo "✔ Containers criados. Iniciando para configuração inicial..."
distrobox enter Arch-base -- true
distrobox enter subsistema -- true

echo ""
echo "Próximos passos dentro do Arch-base:"
echo "  sudo pacman -Syu"
echo "  sudo pacman -S yay base-devel"
echo ""
echo "Próximos passos dentro do subsistema:"
echo "  sudo apt update && sudo apt upgrade -y"
