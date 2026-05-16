#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# backup.sh — Coleta todas as configs do Arch Atômico para o repositório dotfiles
#
# Uso: bash ~/dotfiles/scripts/backup.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

DOTFILES="$HOME/dotfiles"
B='\033[38;5;39m'
G='\033[38;5;82m'
Y='\033[38;5;220m'
R='\033[0m'
E='\033[1;31m'

info()    { echo -e "${B}  →${R} $*"; }
success() { echo -e "${G}  ✔${R} $*"; }
warn()    { echo -e "${Y}  ⚠${R} $*"; }
error()   { echo -e "${E}  ✖${R} $*"; }
section() { echo -e "\n${B}━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"; }

# ── Verificações iniciais ─────────────────────────────────────────────────────

if [ ! -d "$DOTFILES/.git" ]; then
    error "Repositório git não encontrado em $DOTFILES"
    error "Inicialize com: cd ~/dotfiles && git init"
    exit 1
fi

section "ZSH + JUST"

info "Copiando .zshrc..."
cp "$HOME/.zshrc" "$DOTFILES/zsh/.zshrc"
success ".zshrc salvo"

if [ -f "$HOME/.p10k.zsh" ]; then
    info "Copiando .p10k.zsh (tema Powerlevel10k)..."
    cp "$HOME/.p10k.zsh" "$DOTFILES/zsh/.p10k.zsh"
    success ".p10k.zsh salvo"
fi

if [ -f "$HOME/.zsh_history" ]; then
    warn ".zsh_history ignorado (muito grande e pessoal)"
fi

info "Copiando .justfile..."
if [ -f "$HOME/.justfile" ]; then
    cp "$HOME/.justfile" "$DOTFILES/just/.justfile"
    success ".justfile salvo"
else
    warn ".justfile não encontrado em ~/"
fi

# ── KDE ───────────────────────────────────────────────────────────────────────

section "KDE PLASMA"

KDE_CONFIGS=(
    ".config/plasma-org.kde.plasma.desktop-appletsrc"   # layout do desktop/widgets
    ".config/plasmashrc"                                  # configuração do shell plasma
    ".config/plasmarc"                                    # configs gerais do plasma
    ".config/kwinrc"                                      # KWin (gerenciador de janelas)
    ".config/kwinrulesrc"                                 # regras de janelas KWin
    ".config/kdeglobals"                                  # tema global KDE
    ".config/kcminputrc"                                  # mouse e touchpad
    ".config/kxkbrc"                                      # layout de teclado
    ".config/kglobalshortcutsrc"                          # atalhos globais
    ".config/khotkeysrc"                                  # atalhos personalizados
    ".config/klaunchrc"                                   # animação de lançamento
    ".config/spectaclerc"                                 # Spectacle (screenshot)
    ".config/dolphinrc"                                   # Dolphin (gerenciador de arquivos)
    ".config/katerc"                                      # Kate (editor)
    ".config/konsolerc"                                   # Konsole (terminal)
    ".config/yakuakerc"                                   # Yakuake (terminal dropdown)
    ".config/breezerc"                                    # decoração de janelas Breeze
    ".config/kscreenlockerrc"                             # tela de bloqueio
    ".config/powermanagementprofilesrc"                   # perfis de energia
    ".config/kded5rc"                                     # daemons KDE
    ".config/Trolltech.conf"                              # Qt global
    ".config/gtk-3.0/settings.ini"                        # tema GTK3
    ".config/gtk-4.0/settings.ini"                        # tema GTK4
    ".gtkrc-2.0"                                          # tema GTK2
)

mkdir -p "$DOTFILES/kde/.config/gtk-3.0"
mkdir -p "$DOTFILES/kde/.config/gtk-4.0"

for cfg in "${KDE_CONFIGS[@]}"; do
    src="$HOME/$cfg"
    dst="$DOTFILES/kde/$cfg"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        success "$cfg"
    else
        warn "$cfg não encontrado (pulando)"
    fi
done

# Temas locais de plasma (Look and Feel)
if [ -d "$HOME/.local/share/plasma/look-and-feel" ]; then
    info "Copiando temas Look and Feel..."
    mkdir -p "$DOTFILES/kde/.local/share/plasma/look-and-feel"
    cp -r "$HOME/.local/share/plasma/look-and-feel/." \
        "$DOTFILES/kde/.local/share/plasma/look-and-feel/"
    success "Temas Look and Feel salvos"
fi

# Layouts de plasma salvos
if [ -d "$HOME/.local/share/plasma/plasmoids" ]; then
    info "Copiando plasmoids locais..."
    mkdir -p "$DOTFILES/kde/.local/share/plasma/plasmoids"
    cp -r "$HOME/.local/share/plasma/plasmoids/." \
        "$DOTFILES/kde/.local/share/plasma/plasmoids/"
    success "Plasmoids salvos"
fi

# Wallpapers salvos localmente
if [ -d "$HOME/.local/share/wallpapers" ]; then
    info "Copiando wallpapers locais..."
    mkdir -p "$DOTFILES/kde/.local/share/wallpapers"
    cp -r "$HOME/.local/share/wallpapers/." \
        "$DOTFILES/kde/.local/share/wallpapers/"
    success "Wallpapers salvos"
fi

# Esquemas de cores
if [ -d "$HOME/.local/share/color-schemes" ]; then
    info "Copiando esquemas de cores..."
    mkdir -p "$DOTFILES/kde/.local/share/color-schemes"
    cp -r "$HOME/.local/share/color-schemes/." \
        "$DOTFILES/kde/.local/share/color-schemes/"
    success "Esquemas de cores salvos"
fi

# Fontes locais
if [ -d "$HOME/.local/share/fonts" ]; then
    info "Copiando fontes locais..."
    mkdir -p "$DOTFILES/kde/.local/share/fonts"
    cp -r "$HOME/.local/share/fonts/." \
        "$DOTFILES/kde/.local/share/fonts/"
    success "Fontes salvas"
fi

# Temas de cursor
if [ -d "$HOME/.local/share/icons" ]; then
    info "Copiando ícones/cursores locais..."
    mkdir -p "$DOTFILES/kde/.local/share/icons"
    cp -r "$HOME/.local/share/icons/." \
        "$DOTFILES/kde/.local/share/icons/"
    success "Ícones/cursores salvos"
fi

# Scripts do KDE
if [ -d "$HOME/.local/share/kservices5" ]; then
    mkdir -p "$DOTFILES/kde/.local/share/kservices5"
    cp -r "$HOME/.local/share/kservices5/." \
        "$DOTFILES/kde/.local/share/kservices5/"
fi

# Konsole profiles
if [ -d "$HOME/.local/share/konsole" ]; then
    info "Copiando perfis do Konsole..."
    mkdir -p "$DOTFILES/kde/.local/share/konsole"
    cp -r "$HOME/.local/share/konsole/." \
        "$DOTFILES/kde/.local/share/konsole/"
    success "Perfis Konsole salvos"
fi

# ── Pacotes ───────────────────────────────────────────────────────────────────

section "LISTA DE PACOTES"

info "Exportando pacotes explícitos do host (pacman)..."
pacman -Qqe > "$DOTFILES/packages/pkglist-host.txt"
success "pkglist-host.txt ($(wc -l < "$DOTFILES/packages/pkglist-host.txt") pacotes)"

info "Exportando pacotes do Arch-base (container)..."
if distrobox enter Arch-base -- pacman -Qqe > "$DOTFILES/packages/pkglist-arch-base.txt" 2>/dev/null; then
    success "pkglist-arch-base.txt ($(wc -l < "$DOTFILES/packages/pkglist-arch-base.txt") pacotes)"
else
    warn "Container Arch-base inacessível — pulando"
fi

info "Exportando pacotes do subsistema (container)..."
if distrobox enter subsistema -- dpkg-query -W -f='${Package}\n' \
    > "$DOTFILES/packages/pkglist-subsistema.txt" 2>/dev/null; then
    success "pkglist-subsistema.txt ($(wc -l < "$DOTFILES/packages/pkglist-subsistema.txt") pacotes)"
else
    warn "Container subsistema inacessível — pulando"
fi

info "Exportando pacotes AUR (yay)..."
if distrobox enter Arch-base -- yay -Qqm \
    > "$DOTFILES/packages/pkglist-aur.txt" 2>/dev/null; then
    success "pkglist-aur.txt ($(wc -l < "$DOTFILES/packages/pkglist-aur.txt") pacotes AUR)"
else
    warn "yay inacessível — pulando lista AUR"
fi

# Flatpaks instalados no host
if command -v flatpak &>/dev/null; then
    info "Exportando Flatpaks..."
    flatpak list --app --columns=application \
        > "$DOTFILES/packages/pkglist-flatpak.txt" 2>/dev/null
    success "pkglist-flatpak.txt"
fi

# ── Distrobox ─────────────────────────────────────────────────────────────────

section "DISTROBOX"

info "Salvando configuração do distrobox..."
mkdir -p "$DOTFILES/distrobox"

# Exporta a lista de containers ativos
distrobox list --no-color 2>/dev/null \
    > "$DOTFILES/distrobox/containers.txt" || true
success "Lista de containers salva"

# Salva o distrobox.ini se existir
for cfg in \
    "$HOME/.config/distrobox/distrobox.ini" \
    "$HOME/.distroboxrc"; do
    if [ -f "$cfg" ]; then
        cp "$cfg" "$DOTFILES/distrobox/$(basename "$cfg")"
        success "$(basename "$cfg") salvo"
    fi
done

# Salva scripts de criação dos containers (gerado aqui mesmo)
cat > "$DOTFILES/distrobox/create-containers.sh" << 'CONTAINERS_EOF'
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
CONTAINERS_EOF
chmod +x "$DOTFILES/distrobox/create-containers.sh"
success "Script de criação de containers gerado"

# ── Outros arquivos de config ──────────────────────────────────────────────────

section "OUTRAS CONFIGS"

# mic-celular.sh
if [ -f "$HOME/mic-celular.sh" ]; then
    info "Copiando mic-celular.sh..."
    cp "$HOME/mic-celular.sh" "$DOTFILES/scripts/mic-celular.sh"
    chmod +x "$DOTFILES/scripts/mic-celular.sh"
    success "mic-celular.sh salvo"
fi

# Autostart do KDE
if [ -d "$HOME/.config/autostart" ]; then
    info "Copiando entradas de autostart..."
    mkdir -p "$DOTFILES/kde/.config/autostart"
    cp -r "$HOME/.config/autostart/." "$DOTFILES/kde/.config/autostart/"
    success "Autostart salvo"
fi

# SSH config (sem chaves!)
if [ -f "$HOME/.ssh/config" ]; then
    info "Copiando ~/.ssh/config (sem chaves privadas)..."
    mkdir -p "$DOTFILES/ssh"
    cp "$HOME/.ssh/config" "$DOTFILES/ssh/config"
    success "ssh/config salvo (sem chaves privadas)"
fi

# Git config global
if [ -f "$HOME/.gitconfig" ]; then
    info "Copiando .gitconfig..."
    cp "$HOME/.gitconfig" "$DOTFILES/zsh/.gitconfig"
    success ".gitconfig salvo"
fi

# ── Resumo final ──────────────────────────────────────────────────────────────

section "RESUMO"

echo ""
echo -e "${G}Backup concluído!${R} Arquivos salvos em ${B}$DOTFILES${R}"
echo ""
echo "Próximos passos:"
echo -e "  ${B}cd ~/dotfiles${R}"
echo -e "  ${B}git add -A${R}"
echo -e "  ${B}git commit -m \"backup: $(date '+%Y-%m-%d %H:%M')\"${R}"
echo -e "  ${B}git push${R}"
echo ""
echo -e "${Y}⚠  Revise o commit antes de fazer push (nada de senhas/chaves!)${R}"
