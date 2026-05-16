#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# backup-system.sh — Captura toda a camada de sistema do Arch Atômico
#
# Coleta:
#   • Layout btrfs (subvolumes, opções de montagem)
#   • /etc/fstab
#   • Configuração do GRUB (/etc/default/grub + temas)
#   • Parâmetros do kernel (mkinitcpio, cmdline)
#   • zram-generator
#   • Módulos blacklistados (intel_powerclamp, etc.)
#   • Otimizações sysctl (/etc/sysctl.d/)
#   • Serviços systemd customizados
#   • Regras udev customizadas
#   • Suporte a microfone por cabo (scripts/serviços relacionados)
#   • Resumo de hardware para referência
#
# Uso: sudo bash ~/dotfiles/scripts/backup-system.sh
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
B='\033[38;5;39m'; G='\033[38;5;82m'; Y='\033[38;5;220m'
R='\033[0m';        E='\033[1;31m';    W='\033[1;37m'

info()    { echo -e "${B}  →${R} $*"; }
success() { echo -e "${G}  ✔${R} $*"; }
warn()    { echo -e "${Y}  ⚠${R} $*"; }
skip()    { echo -e "     ${R}(não encontrado — pulando)"; }
section() {
    echo -e "\n${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
    echo -e "${W}   $*${R}"
    echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
}

# ── Verificações ──────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
    echo -e "${E}Este script precisa de sudo para ler configs de sistema.${R}"
    echo "Rode: sudo bash ~/dotfiles/scripts/backup-system.sh"
    exit 1
fi

# Detecta o usuário real (quem chamou o sudo)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
DOTFILES="$REAL_HOME/dotfiles"
SYSDIR="$DOTFILES/system"

if [ ! -d "$DOTFILES/.git" ]; then
    echo -e "${E}Repositório não encontrado em $DOTFILES${R}"
    exit 1
fi

# Cria estrutura de diretórios
mkdir -p "$SYSDIR"/{btrfs,grub,kernel,zram,modules,sysctl,services,udev,mic,hardware}

clear
echo -e "\n${B}  Arch Atômico — Backup de Sistema 🔧${R}\n"

# ══════════════════════════════════════════════════════════════════════════════
# BTRFS — subvolumes e layout de partições
# ══════════════════════════════════════════════════════════════════════════════

section "BTRFS"

info "Capturando layout de subvolumes..."

# Lista todos os subvolumes montados com suas opções completas
{
    echo "# Gerado por backup-system.sh em $(date)"
    echo "# Subvolumes btrfs ativos"
    echo ""
    btrfs subvolume list / 2>/dev/null || true
} > "$SYSDIR/btrfs/subvolumes.txt"
success "subvolumes.txt"

# Captura opções de montagem reais de cada ponto btrfs
{
    echo "# Montagens btrfs ativas (findmnt)"
    echo ""
    findmnt -t btrfs --output TARGET,SOURCE,FSTYPE,OPTIONS -n 2>/dev/null
} > "$SYSDIR/btrfs/mounts-active.txt"
success "mounts-active.txt"

# Informações do filesystem (UUIDs, labels, tamanho)
{
    echo "# Informações dos dispositivos btrfs"
    echo ""
    for dev in $(findmnt -t btrfs -n -o SOURCE | sort -u); do
        echo "=== $dev ==="
        btrfs filesystem show "$dev" 2>/dev/null || true
        echo ""
    done
} > "$SYSDIR/btrfs/filesystem-info.txt"
success "filesystem-info.txt"

# Uso por subvolume
{
    echo "# Uso de espaço por subvolume"
    echo ""
    btrfs filesystem df / 2>/dev/null || true
    echo ""
    btrfs filesystem usage / 2>/dev/null || true
} > "$SYSDIR/btrfs/usage.txt"
success "usage.txt"

# ══════════════════════════════════════════════════════════════════════════════
# FSTAB
# ══════════════════════════════════════════════════════════════════════════════

section "FSTAB"

cp /etc/fstab "$SYSDIR/btrfs/fstab"
success "/etc/fstab salvo"

# Gera também uma versão comentada com os subvolumes explicados
{
    echo "# /etc/fstab — $(hostname) — backup $(date '+%Y-%m-%d')"
    echo "# UUID dos dispositivos:"
    blkid | grep -E "(btrfs|vfat|ext4)" | while read -r line; do
        echo "#   $line"
    done
    echo ""
    cat /etc/fstab
} > "$SYSDIR/btrfs/fstab-annotated"
success "fstab-annotated (com UUIDs comentados)"

# ══════════════════════════════════════════════════════════════════════════════
# GRUB
# ══════════════════════════════════════════════════════════════════════════════

section "GRUB"

info "Salvando /etc/default/grub..."
cp /etc/default/grub "$SYSDIR/grub/grub-default"
success "grub-default"

# grub.cfg gerado (referência — não usado diretamente no restore)
if [ -f /boot/grub/grub.cfg ]; then
    cp /boot/grub/grub.cfg "$SYSDIR/grub/grub.cfg.bak"
    success "grub.cfg.bak (referência)"
fi

# /etc/grub.d/ — scripts customizados
if ls /etc/grub.d/??_custom* /etc/grub.d/??_arch* 2>/dev/null | grep -q .; then
    info "Salvando scripts customizados de /etc/grub.d/..."
    mkdir -p "$SYSDIR/grub/grub.d"
    for f in /etc/grub.d/??_custom* /etc/grub.d/??_arch*; do
        [ -f "$f" ] && cp "$f" "$SYSDIR/grub/grub.d/" && success "$(basename $f)"
    done
else
    warn "Nenhum script customizado em /etc/grub.d/"
fi

# Tema GRUB (se existir)
GRUB_THEME=$(grep "^GRUB_THEME=" /etc/default/grub | cut -d'"' -f2 || true)
if [ -n "$GRUB_THEME" ] && [ -d "$(dirname "$GRUB_THEME")" ]; then
    info "Salvando tema GRUB: $GRUB_THEME..."
    mkdir -p "$SYSDIR/grub/theme"
    cp -r "$(dirname "$GRUB_THEME")/." "$SYSDIR/grub/theme/"
    success "Tema GRUB salvo"
fi

# ══════════════════════════════════════════════════════════════════════════════
# KERNEL — mkinitcpio, cmdline, hooks
# ══════════════════════════════════════════════════════════════════════════════

section "KERNEL"

info "Salvando mkinitcpio.conf..."
cp /etc/mkinitcpio.conf "$SYSDIR/kernel/mkinitcpio.conf"
success "mkinitcpio.conf"

# Presets de mkinitcpio (linux, linux-lts, etc.)
if ls /etc/mkinitcpio.d/*.preset 2>/dev/null | grep -q .; then
    mkdir -p "$SYSDIR/kernel/mkinitcpio.d"
    cp /etc/mkinitcpio.d/*.preset "$SYSDIR/kernel/mkinitcpio.d/"
    success "Presets de mkinitcpio salvos"
fi

# Parâmetros de cmdline customizados
for f in \
    /etc/kernel/cmdline \
    /etc/cmdline.d/*.conf \
    /proc/cmdline; do
    if [ -f "$f" ]; then
        cp "$f" "$SYSDIR/kernel/$(basename $f).txt" 2>/dev/null || true
        success "$(basename $f)"
    fi
done

# Kernel instalado atualmente
{
    echo "# Kernel ativo: $(uname -r)"
    echo "# Kernels instalados:"
    pacman -Q | grep "^linux" || true
    echo ""
    echo "# Módulos carregados no boot:"
    lsmod | head -50
} > "$SYSDIR/kernel/kernel-info.txt"
success "kernel-info.txt"

# /etc/modules-load.d/ — módulos carregados no boot
if ls /etc/modules-load.d/*.conf 2>/dev/null | grep -q .; then
    mkdir -p "$SYSDIR/kernel/modules-load.d"
    cp /etc/modules-load.d/*.conf "$SYSDIR/kernel/modules-load.d/"
    success "modules-load.d/*.conf salvos"
fi

# ══════════════════════════════════════════════════════════════════════════════
# MÓDULOS BLACKLISTADOS
# ══════════════════════════════════════════════════════════════════════════════

section "MÓDULOS BLACKLISTADOS"

mkdir -p "$SYSDIR/modules"

if ls /etc/modprobe.d/*.conf 2>/dev/null | grep -q .; then
    info "Salvando /etc/modprobe.d/..."
    cp /etc/modprobe.d/*.conf "$SYSDIR/modules/"

    # Lista o que está blacklistado para referência
    {
        echo "# Módulos blacklistados — $(date)"
        echo ""
        grep -h "^blacklist" /etc/modprobe.d/*.conf 2>/dev/null | sort
        echo ""
        echo "# Opções de módulos:"
        grep -h "^options" /etc/modprobe.d/*.conf 2>/dev/null | sort
    } > "$SYSDIR/modules/blacklist-summary.txt"

    success "$(ls /etc/modprobe.d/*.conf | wc -l) arquivo(s) de modprobe salvos"

    # Verifica especificamente o intel_powerclamp
    if grep -r "intel_powerclamp" /etc/modprobe.d/ &>/dev/null; then
        success "intel_powerclamp blacklist confirmado ✔"
    else
        warn "intel_powerclamp não encontrado em modprobe.d"
    fi
else
    warn "Nenhum arquivo em /etc/modprobe.d/"
fi

# ══════════════════════════════════════════════════════════════════════════════
# ZRAM
# ══════════════════════════════════════════════════════════════════════════════

section "ZRAM"

# zram-generator (método moderno)
if [ -f /etc/systemd/zram-generator.conf ]; then
    cp /etc/systemd/zram-generator.conf "$SYSDIR/zram/"
    success "zram-generator.conf salvo"
fi

# zramswap (método alternativo via zramswap.service)
if [ -f /etc/default/zramswap ]; then
    cp /etc/default/zramswap "$SYSDIR/zram/"
    success "zramswap config salvo"
fi

# Status atual do zram para referência
{
    echo "# Status do zram em $(date)"
    echo ""
    echo "## /proc/swaps:"
    cat /proc/swaps 2>/dev/null || echo "(nenhum)"
    echo ""
    echo "## zram devices:"
    ls -la /dev/zram* 2>/dev/null || echo "(nenhum)"
    echo ""
    echo "## zramctl:"
    zramctl 2>/dev/null || echo "(zramctl não disponível)"
    echo ""
    echo "## swapon --show:"
    swapon --show 2>/dev/null || true
} > "$SYSDIR/zram/zram-status.txt"
success "zram-status.txt (referência)"

# ══════════════════════════════════════════════════════════════════════════════
# SYSCTL — otimizações de kernel
# ══════════════════════════════════════════════════════════════════════════════

section "SYSCTL / OTIMIZAÇÕES"

if ls /etc/sysctl.d/*.conf 2>/dev/null | grep -q .; then
    info "Salvando /etc/sysctl.d/..."
    mkdir -p "$SYSDIR/sysctl"
    cp /etc/sysctl.d/*.conf "$SYSDIR/sysctl/"
    success "$(ls /etc/sysctl.d/*.conf | wc -l) arquivo(s) sysctl salvos"
fi

if [ -f /etc/sysctl.conf ]; then
    cp /etc/sysctl.conf "$SYSDIR/sysctl/sysctl.conf"
    success "sysctl.conf salvo"
fi

# Snapshot de todos os valores ativos (para referência/debug)
{
    echo "# Valores sysctl ativos em $(date)"
    echo ""
    sysctl -a 2>/dev/null | sort
} > "$SYSDIR/sysctl/sysctl-active-snapshot.txt"
success "sysctl-active-snapshot.txt (referência)"

# ══════════════════════════════════════════════════════════════════════════════
# SERVIÇOS SYSTEMD CUSTOMIZADOS
# ══════════════════════════════════════════════════════════════════════════════

section "SERVIÇOS SYSTEMD"

mkdir -p "$SYSDIR/services"/{system,user}

# Serviços de sistema customizados (/etc/systemd/system/)
info "Capturando unidades customizadas de /etc/systemd/system/..."
CUSTOM_UNITS=0
for unit in /etc/systemd/system/*.{service,timer,socket,path,mount,target} 2>/dev/null; do
    [ -f "$unit" ] || continue
    # Ignora symlinks para unidades padrão do systemd
    if [ -L "$unit" ]; then
        target=$(readlink -f "$unit")
        if [[ "$target" == /usr/lib/systemd/* ]]; then
            continue  # é só um enable de unidade padrão
        fi
    fi
    cp "$unit" "$SYSDIR/services/system/"
    CUSTOM_UNITS=$((CUSTOM_UNITS + 1))
done
success "$CUSTOM_UNITS unidade(s) customizada(s) de sistema salvas"

# Overrides de serviços (systemctl edit)
if ls /etc/systemd/system/*.d/ 2>/dev/null | grep -q .; then
    info "Salvando overrides (systemctl edit)..."
    for d in /etc/systemd/system/*.d/; do
        [ -d "$d" ] || continue
        dirname=$(basename "$d")
        mkdir -p "$SYSDIR/services/system/$dirname"
        cp "$d"*.conf "$SYSDIR/services/system/$dirname/" 2>/dev/null || true
        success "Override: $dirname"
    done
fi

# Serviços de usuário customizados (~/.config/systemd/user/)
USER_SYSTEMD="$REAL_HOME/.config/systemd/user"
if [ -d "$USER_SYSTEMD" ] && ls "$USER_SYSTEMD"/*.{service,timer} 2>/dev/null | grep -q .; then
    info "Salvando unidades de usuário..."
    cp "$USER_SYSTEMD"/*.service "$SYSDIR/services/user/" 2>/dev/null || true
    cp "$USER_SYSTEMD"/*.timer   "$SYSDIR/services/user/" 2>/dev/null || true
    success "Unidades de usuário salvas"
fi

# Lista de serviços habilitados (para saber o que reativar)
{
    echo "# Serviços habilitados no sistema — $(date)"
    echo ""
    echo "## Serviços de sistema (enabled):"
    systemctl list-unit-files --state=enabled --no-legend 2>/dev/null \
        | grep -v "^$" | sort
    echo ""
    echo "## Serviços de usuário (enabled):"
    sudo -u "$REAL_USER" systemctl --user list-unit-files --state=enabled \
        --no-legend 2>/dev/null | sort || true
} > "$SYSDIR/services/enabled-services.txt"
success "enabled-services.txt"

# ══════════════════════════════════════════════════════════════════════════════
# UDEV — regras customizadas
# ══════════════════════════════════════════════════════════════════════════════

section "UDEV"

mkdir -p "$SYSDIR/udev"

UDEV_COUNT=0
for rules_dir in /etc/udev/rules.d /lib/udev/rules.d; do
    [ -d "$rules_dir" ] || continue
    for f in "$rules_dir"/*.rules; do
        [ -f "$f" ] || continue
        # Salva apenas regras que não são do pacman (customizadas pelo usuário)
        if ! pacman -Qo "$f" &>/dev/null; then
            cp "$f" "$SYSDIR/udev/"
            success "udev: $(basename $f)"
            UDEV_COUNT=$((UDEV_COUNT + 1))
        fi
    done
done

# Regras em /etc/udev sempre são customizadas
for f in /etc/udev/rules.d/*.rules; do
    [ -f "$f" ] || continue
    cp "$f" "$SYSDIR/udev/"
    UDEV_COUNT=$((UDEV_COUNT + 1))
done

[ $UDEV_COUNT -eq 0 ] && warn "Nenhuma regra udev customizada encontrada" \
    || success "$UDEV_COUNT regra(s) udev salva(s)"

# ══════════════════════════════════════════════════════════════════════════════
# MICROFONE POR CABO (suporte a mic de celular via TRRS/USB)
# ══════════════════════════════════════════════════════════════════════════════

section "MICROFONE POR CABO"

mkdir -p "$SYSDIR/mic"

# Script mic-celular.sh
if [ -f "$REAL_HOME/mic-celular.sh" ]; then
    cp "$REAL_HOME/mic-celular.sh" "$SYSDIR/mic/"
    success "mic-celular.sh"
fi

# Configs de PipeWire/PulseAudio relacionadas
for d in \
    "$REAL_HOME/.config/pipewire" \
    "$REAL_HOME/.config/pulse" \
    /etc/pipewire \
    /etc/pulse; do
    if [ -d "$d" ]; then
        name=$(basename "$d")
        mkdir -p "$SYSDIR/mic/$name"
        cp -r "$d/." "$SYSDIR/mic/$name/" 2>/dev/null || true
        success "Config de áudio: $name"
    fi
done

# Regras udev de áudio (TRRS/headset detection)
for f in /etc/udev/rules.d/*audio* /etc/udev/rules.d/*sound* \
         /etc/udev/rules.d/*headset* /etc/udev/rules.d/*mic*; do
    [ -f "$f" ] && cp "$f" "$SYSDIR/mic/" && success "udev: $(basename $f)"
done

# WirePlumber (substituto do PipeWire session manager)
if [ -d "$REAL_HOME/.config/wireplumber" ]; then
    mkdir -p "$SYSDIR/mic/wireplumber"
    cp -r "$REAL_HOME/.config/wireplumber/." "$SYSDIR/mic/wireplumber/"
    success "wireplumber config salvo"
fi

# ALSA config
for f in "$REAL_HOME/.asoundrc" /etc/asound.conf; do
    [ -f "$f" ] && cp "$f" "$SYSDIR/mic/$(basename $f)" && success "$(basename $f)"
done

# Snapshot do estado atual do áudio
{
    echo "# Estado de áudio em $(date)"
    echo ""
    echo "## PipeWire/PulseAudio devices:"
    sudo -u "$REAL_USER" pactl list short sinks 2>/dev/null || true
    echo ""
    sudo -u "$REAL_USER" pactl list short sources 2>/dev/null || true
    echo ""
    echo "## ALSA cards:"
    aplay -l 2>/dev/null || true
    echo ""
    echo "## ALSA capture:"
    arecord -l 2>/dev/null || true
} > "$SYSDIR/mic/audio-state.txt"
success "audio-state.txt (referência)"

# ══════════════════════════════════════════════════════════════════════════════
# HARDWARE — snapshot para referência futura
# ══════════════════════════════════════════════════════════════════════════════

section "HARDWARE (referência)"

{
    echo "# Hardware de $(hostname) — $(date)"
    echo ""
    echo "## CPU:"
    lscpu 2>/dev/null | grep -E "(Model name|Architecture|CPU\(s\)|Thread|Core|Socket|Virtualization|Vendor)"
    echo ""
    echo "## Memória:"
    free -h
    echo ""
    echo "## Discos:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID
    echo ""
    echo "## GPU:"
    lspci | grep -iE "(vga|3d|display|nvidia|amd|intel)" || true
    echo ""
    echo "## PCI devices:"
    lspci 2>/dev/null || true
    echo ""
    echo "## USB devices:"
    lsusb 2>/dev/null || true
    echo ""
    echo "## Kernel:"
    uname -a
} > "$SYSDIR/hardware/hardware-profile.txt"
success "hardware-profile.txt"

# ══════════════════════════════════════════════════════════════════════════════
# RESUMO
# ══════════════════════════════════════════════════════════════════════════════

section "RESUMO"

echo ""
echo -e "${G}Backup de sistema concluído!${R}"
echo ""
echo -e "Arquivos em: ${B}$SYSDIR${R}"
echo ""
find "$SYSDIR" -type f | sort | while read -r f; do
    echo -e "  ${B}·${R} ${f#$DOTFILES/}"
done
echo ""
echo "Próximos passos:"
echo -e "  ${B}cd ~/dotfiles && git add -A${R}"
echo -e "  ${B}git commit -m \"backup: sistema $(date '+%Y-%m-%d')\"${R}"
echo -e "  ${B}git push${R}"
