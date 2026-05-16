#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# restore.sh — Restaura o Arch Atômico completo em uma máquina nova
#
# Uso: bash restore.sh
#
# O que este script faz, em ordem:
#   1. Instala dependências base (git, stow, zsh, distrobox, etc.)
#   2. Clona o repositório dotfiles
#   3. Aplica os symlinks via GNU Stow
#   4. Instala Oh My Zsh + Powerlevel10k
#   5. Reinstala pacotes do host (pacman)
#   6. Cria os containers distrobox
#   7. Reinstala pacotes dentro dos containers
#   8. Instala just
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── CONFIGURAÇÃO — edite antes de usar ───────────────────────────────────────
GITHUB_USER="SEU_USUARIO_AQUI"
REPO_NAME="dotfiles"
DOTFILES="$HOME/dotfiles"
# ─────────────────────────────────────────────────────────────────────────────

B='\033[38;5;39m'; G='\033[38;5;82m'; Y='\033[38;5;220m'
R='\033[0m';        E='\033[1;31m';    W='\033[1;37m'

info()    { echo -e "${B}  →${R} $*"; }
success() { echo -e "${G}  ✔${R} $*"; }
warn()    { echo -e "${Y}  ⚠${R} $*"; }
error()   { echo -e "${E}  ✖${R} $*"; exit 1; }
section() { echo -e "\n${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"; \
            echo -e "${W}   $*${R}"; \
            echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"; }

# ── Banner ────────────────────────────────────────────────────────────────────

clear
echo -e "\n${B}  Arch Atômico — Restauração Completa 🎮${R}"
echo -e "  github.com/$GITHUB_USER/$REPO_NAME\n"

# ── Validações ────────────────────────────────────────────────────────────────

if [[ "$GITHUB_USER" == "SEU_USUARIO_AQUI" ]]; then
    error "Edite a variável GITHUB_USER no topo do script antes de continuar."
fi

if ! ping -c 1 archlinux.org &>/dev/null; then
    error "Sem conexão com a internet. Conecte-se e tente novamente."
fi

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 1 — Dependências base
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 1/8 — Dependências base"

PKGS_BASE=(
    git
    stow
    zsh
    just
    distrobox
    podman           # backend do distrobox
    fastfetch
    base-devel       # necessário para yay dentro do container
    wget
    curl
    unzip
)

info "Atualizando sistema..."
sudo pacman -Syu --noconfirm

info "Instalando pacotes base..."
sudo pacman -S --needed --noconfirm "${PKGS_BASE[@]}"
success "Dependências base instaladas"

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 2 — Clonar dotfiles
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 2/8 — Clonando dotfiles"

if [ -d "$DOTFILES/.git" ]; then
    warn "Repositório já existe em $DOTFILES — atualizando..."
    git -C "$DOTFILES" pull
else
    info "Clonando github.com/$GITHUB_USER/$REPO_NAME..."
    git clone "https://github.com/$GITHUB_USER/$REPO_NAME.git" "$DOTFILES"
fi
success "Dotfiles prontos em $DOTFILES"

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 3 — Aplicar symlinks via GNU Stow
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 3/8 — Aplicando symlinks (GNU Stow)"

bash "$DOTFILES/scripts/stow-all.sh"

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 4 — Oh My Zsh + Powerlevel10k
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 4/8 — Oh My Zsh + Powerlevel10k + Plugins"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Instalando Oh My Zsh..."
    # RUNZSH=no evita que o instalador abra um novo shell e pare o script
    RUNZSH=no CHSH=no \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "Oh My Zsh instalado"
else
    warn "Oh My Zsh já instalado — pulando"
fi

OMZ_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Powerlevel10k
if [ ! -d "$OMZ_CUSTOM/themes/powerlevel10k" ]; then
    info "Instalando tema Powerlevel10k..."
    git clone --depth=1 \
        https://github.com/romkatv/powerlevel10k.git \
        "$OMZ_CUSTOM/themes/powerlevel10k"
    success "Powerlevel10k instalado"
else
    warn "Powerlevel10k já existe — pulando"
fi

# zsh-autosuggestions
if [ ! -d "$OMZ_CUSTOM/plugins/zsh-autosuggestions" ]; then
    info "Instalando zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$OMZ_CUSTOM/plugins/zsh-autosuggestions"
    success "zsh-autosuggestions instalado"
fi

# zsh-syntax-highlighting
if [ ! -d "$OMZ_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    info "Instalando zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "$OMZ_CUSTOM/plugins/zsh-syntax-highlighting"
    success "zsh-syntax-highlighting instalado"
fi

# Define zsh como shell padrão
if [ "$SHELL" != "$(command -v zsh)" ]; then
    info "Definindo zsh como shell padrão..."
    chsh -s "$(command -v zsh)"
    success "Shell padrão: zsh"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 5 — Reinstalar pacotes do host
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 5/8 — Pacotes do host (pacman)"

PKGLIST="$DOTFILES/packages/pkglist-host.txt"

if [ -f "$PKGLIST" ]; then
    TOTAL=$(wc -l < "$PKGLIST")
    info "Reinstalando $TOTAL pacotes do host..."
    # --needed evita reinstalar o que já existe
    sudo pacman -S --needed --noconfirm - < "$PKGLIST" 2>&1 \
        | grep -E "^(installing|warning|error)" || true
    success "Pacotes do host restaurados"
else
    warn "pkglist-host.txt não encontrado — pulando"
fi

# Flatpaks
FLATPAK_LIST="$DOTFILES/packages/pkglist-flatpak.txt"
if [ -f "$FLATPAK_LIST" ] && command -v flatpak &>/dev/null; then
    info "Reinstalando Flatpaks..."
    while IFS= read -r app; do
        [ -z "$app" ] && continue
        flatpak install --noninteractive flathub "$app" 2>/dev/null \
            && success "Flatpak: $app" \
            || warn "Flatpak não encontrado: $app"
    done < "$FLATPAK_LIST"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 6 — Criar containers distrobox
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 6/8 — Containers distrobox"

# Garante que o podman/distrobox está funcional
if ! command -v distrobox &>/dev/null; then
    error "distrobox não encontrado. Verifique a etapa 1."
fi

bash "$DOTFILES/distrobox/create-containers.sh"

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 7 — Reinstalar pacotes nos containers
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 7/8 — Pacotes dos containers"

# Arch-base: pacman
ARCH_LIST="$DOTFILES/packages/pkglist-arch-base.txt"
if [ -f "$ARCH_LIST" ]; then
    info "Instalando pacotes no Arch-base..."
    # Remove pacotes que são base do sistema e já vêm instalados
    PKGS_ARCH=$(grep -vE "^(base|linux|filesystem|glibc|bash|coreutils)$" \
        "$ARCH_LIST" | tr '\n' ' ')
    distrobox enter Arch-base -- bash -c \
        "sudo pacman -S --needed --noconfirm $PKGS_ARCH" 2>&1 \
        | tail -5 || warn "Alguns pacotes do Arch-base falharam"
    success "Pacotes Arch-base restaurados"
fi

# Arch-base: AUR (yay precisa estar instalado antes)
AUR_LIST="$DOTFILES/packages/pkglist-aur.txt"
if [ -f "$AUR_LIST" ] && [ -s "$AUR_LIST" ]; then
    info "Instalando pacotes AUR no Arch-base..."
    PKGS_AUR=$(tr '\n' ' ' < "$AUR_LIST")
    distrobox enter Arch-base -- bash -c \
        "yay -S --needed --noconfirm $PKGS_AUR" 2>&1 \
        | tail -5 || warn "Alguns pacotes AUR falharam"
    success "Pacotes AUR restaurados"
fi

# Subsistema: apt
UBUNTU_LIST="$DOTFILES/packages/pkglist-subsistema.txt"
if [ -f "$UBUNTU_LIST" ]; then
    info "Instalando pacotes no subsistema..."
    PKGS_UBUNTU=$(grep -vE "^(base-files|bash|coreutils|apt|dpkg)$" \
        "$UBUNTU_LIST" | tr '\n' ' ')
    distrobox enter subsistema -- bash -c \
        "sudo apt-get update -qq && sudo apt-get install -y $PKGS_UBUNTU" 2>&1 \
        | tail -5 || warn "Alguns pacotes do subsistema falharam"
    success "Pacotes subsistema restaurados"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 8 — Configurações finais
# ══════════════════════════════════════════════════════════════════════════════

section "ETAPA 8/8 — Ajustes finais"

# Reconstruir cache de fontes
if command -v fc-cache &>/dev/null; then
    info "Reconstruindo cache de fontes..."
    fc-cache -fv > /dev/null 2>&1
    success "Cache de fontes atualizado"
fi

# ~/.local/bin no PATH
if [ ! -d "$HOME/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
fi

# Permissões SSH
if [ -d "$HOME/.ssh" ]; then
    chmod 700 "$HOME/.ssh"
    [ -f "$HOME/.ssh/config" ] && chmod 600 "$HOME/.ssh/config"
fi

# ── Resumo Final ──────────────────────────────────────────────────────────────

echo ""
echo -e "${B}╔══════════════════════════════════════════════════════╗${R}"
echo -e "${B}║${R}  ${G}✔  Arch Atômico restaurado com sucesso!${R}            ${B}║${R}"
echo -e "${B}╚══════════════════════════════════════════════════════╝${R}"
echo ""
echo -e "${W}Próximos passos manuais:${R}"
echo ""
echo -e "  ${B}1.${R} Faça logout e login para aplicar os temas do KDE"
echo -e "  ${B}2.${R} Abra o terminal e rode: ${B}source ~/.zshrc${R}"
echo -e "  ${B}3.${R} Verifique os containers: ${B}just status${R}"
echo -e "  ${B}4.${R} Re-exporte seus apps: ${B}just pac <app>${R} / ${B}just aur <app>${R}"
echo -e "  ${B}5.${R} Para KDE: System Settings → Global Theme para reaplicar"
echo ""
echo -e "${Y}⚠  Chaves SSH e GPG precisam ser copiadas manualmente.${R}"
echo ""
