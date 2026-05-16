# ══════════════════════════════════════════════════════════════════════════════
# ~/.justfile — Arch Atômico Task Runner
# Porta fiel de todas as funções do .zshrc para o just
#
# Instalação: sudo pacman -S just
# Adicione ao .zshrc: export JUST_JUSTFILE="$HOME/.justfile"
#                     alias ujust='just --unstable'
# Uso:        just          → lista todos os comandos
#             just pac htop → instala htop via pacman
# ══════════════════════════════════════════════════════════════════════════════

# Variáveis globais
CONTAINER_ARCH  := "Arch-base"
CONTAINER_UBUNTU := "subsistema"
LOCAL_BIN       := env_var("HOME") / ".local/bin"
APPS_DIR        := env_var("HOME") / ".local/share/applications"

# Shell padrão: bash (mais portável que zsh para receitas)
set shell := ["bash", "-euo", "pipefail", "-c"]

# ── Padrão: exibe ajuda ────────────────────────────────────────────────────────
[group('ajuda')]
default:
    @just --list --unsorted

# ══════════════════════════════════════════════════════════════════════════════
# INSTALAÇÃO DE PACOTES
# ══════════════════════════════════════════════════════════════════════════════

# Instala pacote via pacman no Arch-base + exporta binários e atalhos
[group('pacotes')]
[doc('ex: just pac firefox')]
pac pkg:
    #!/usr/bin/env bash
    set -euo pipefail
    CONTAINER="{{CONTAINER_ARCH}}"
    PKG="{{pkg}}"
    DBOX=$(command -v distrobox)

    echo -e "⚡ \033[1;36mForjando '$PKG' no $CONTAINER...\033[0m"

    "$DBOX" enter "$CONTAINER" -- sudo pacman -S --noconfirm "$PKG"

    echo -e "🚀 \033[1;32mInstalado! Iniciando Extração Interna...\033[0m"

    # Truque mestre: exporta binários e atalhos de DENTRO do container
    "$DBOX" enter "$CONTAINER" -- sh -c '
        PACOTE="$1"

        echo -e "🔗 Extraindo binários:"
        for BIN in $(pacman -Ql "$PACOTE" 2>/dev/null | awk "/\/usr\/bin\// {print \$2}"); do
            if [ -f "$BIN" ]; then
                NOME=$(basename "$BIN")
                echo -e "   -> $NOME"
                distrobox-export --bin "$BIN" --export-path ~/.local/bin > /dev/null 2>&1
            fi
        done

        echo -e "🖥️  Extraindo atalhos gráficos:"
        for DESKTOP in $(pacman -Ql "$PACOTE" 2>/dev/null | awk "/\/usr\/share\/applications\/.*\.desktop\$/ {print \$2}"); do
            if [ -f "$DESKTOP" ]; then
                APP=$(basename "$DESKTOP" .desktop)
                echo -e "   -> $APP"
                distrobox-export --app "$APP" > /dev/null 2>&1
            fi
        done
    ' -- "$PKG"

    # Remove o sufixo "(on Arch-base)" dos atalhos exportados
    find {{APPS_DIR}} -name "*.desktop" \
        -exec sed -i "s/ (on $CONTAINER)//g" {} + 2>/dev/null || true

    echo -e "✅ \033[1;32mIntegração Extrema concluída!\033[0m"

# Instala pacote via AUR (yay) no Arch-base + exporta binários e atalhos
[group('pacotes')]
[doc('ex: just aur vesktop')]
aur pkg:
    #!/usr/bin/env bash
    set -euo pipefail
    CONTAINER="{{CONTAINER_ARCH}}"
    PKG="{{pkg}}"
    DBOX=$(command -v distrobox)

    echo -e "⚡ \033[1;35mForjando '$PKG' no $CONTAINER via AUR (yay)...\033[0m"

    # yay não aceita sudo — roda como usuário normal dentro do container
    "$DBOX" enter "$CONTAINER" -- yay -S --noconfirm "$PKG"

    echo -e "🚀 \033[1;32mInstalado! Iniciando Extração Interna...\033[0m"

    "$DBOX" enter "$CONTAINER" -- sh -c '
        PACOTE="$1"

        echo -e "🔗 Extraindo binários:"
        for BIN in $(pacman -Ql "$PACOTE" 2>/dev/null | awk "/\/usr\/bin\// {print \$2}"); do
            if [ -f "$BIN" ]; then
                NOME=$(basename "$BIN")
                echo -e "   -> $NOME"
                distrobox-export --bin "$BIN" --export-path ~/.local/bin > /dev/null 2>&1
            fi
        done

        echo -e "🖥️  Extraindo atalhos gráficos:"
        for DESKTOP in $(pacman -Ql "$PACOTE" 2>/dev/null | awk "/\/usr\/share\/applications\/.*\.desktop\$/ {print \$2}"); do
            if [ -f "$DESKTOP" ]; then
                APP=$(basename "$DESKTOP" .desktop)
                echo -e "   -> $APP"
                distrobox-export --app "$APP" > /dev/null 2>&1
            fi
        done
    ' -- "$PKG"

    find {{APPS_DIR}} -name "*.desktop" \
        -exec sed -i "s/ (on $CONTAINER)//g" {} + 2>/dev/null || true

    echo -e "✅ \033[1;35mIntegração AUR concluída!\033[0m"

# Instala pacote via apt no subsistema Ubuntu + exporta atalho
[group('pacotes')]
[doc('ex: just apt obs-studio')]
apt pkg:
    #!/usr/bin/env bash
    set -euo pipefail
    PKG="{{pkg}}"

    echo -e "📦 Buscando e instalando \033[1;32m$PKG\033[0m no subsistema..."

    distrobox enter {{CONTAINER_UBUNTU}} -- bash -c \
        "sudo apt-get update -qq > /dev/null 2>&1 && sudo apt install -y '$PKG'"

    echo -e "✅ \033[1;32m$PKG\033[0m instalado com sucesso!"

    # Tenta exportar o app (pode falhar se for só CLI — tudo bem)
    distrobox enter {{CONTAINER_UBUNTU}} -- \
        distrobox-export --app "$PKG" > /dev/null 2>&1 || true

# Instala um arquivo .deb local no subsistema + exporta atalho
[group('pacotes')]
[doc('ex: just deb ~/Downloads/app.deb')]
deb arquivo:
    #!/usr/bin/env bash
    set -euo pipefail
    DEB_FILE=$(realpath "{{arquivo}}")

    if [ ! -f "$DEB_FILE" ]; then
        echo -e "❌ \033[1;31mArquivo não encontrado:\033[0m $DEB_FILE"
        exit 1
    fi

    echo -e "📦 Instalando \033[1;33m$(basename $DEB_FILE)\033[0m no subsistema..."

    distrobox enter {{CONTAINER_UBUNTU}} -- bash -c \
        "sudo apt update -qq && sudo apt install -y '$DEB_FILE'"

    # Descobre o nome real do pacote para exportar o atalho
    PKG_NAME=$(distrobox enter {{CONTAINER_UBUNTU}} -- \
        dpkg-deb -W --showformat='${Package}' "$DEB_FILE" 2>/dev/null || true)

    if [ -n "$PKG_NAME" ]; then
        echo -e "🚀 Criando atalho do \033[1;36m$PKG_NAME\033[0m para o menu..."
        distrobox enter {{CONTAINER_UBUNTU}} -- \
            distrobox-export --app "$PKG_NAME" > /dev/null 2>&1 \
            && echo -e "✅ \033[1;32mSucesso!\033[0m Aplicativo disponível no menu." \
            || echo -e "⚠️  Instalado, mas sem atalho. Se for CLI: just bin $PKG_NAME"
    else
        echo -e "⚠️  Não foi possível detectar o nome do pacote para exportar o atalho."
    fi

# ══════════════════════════════════════════════════════════════════════════════
# EXPORTAÇÃO DE BINÁRIOS
# ══════════════════════════════════════════════════════════════════════════════

# Exporta binário do subsistema Ubuntu para ~/.local/bin
[group('exportação')]
[doc('ex: just bin node')]
bin cmd:
    #!/usr/bin/env bash
    set -euo pipefail
    CMD="{{cmd}}"

    echo -e "🔍 Localizando \033[1;36m$CMD\033[0m no subsistema..."

    # 1. Tenta localizar via which
    BIN_PATH=$(distrobox enter {{CONTAINER_UBUNTU}} -- which "$CMD" 2>/dev/null | tr -d '\r' || true)

    # 2. Fallback: caminhos conhecidos
    if [ -z "$BIN_PATH" ]; then
        for P in /usr/local/bin /usr/bin; do
            if distrobox enter {{CONTAINER_UBUNTU}} -- test -f "$P/$CMD" 2>/dev/null; then
                BIN_PATH="$P/$CMD"
                break
            fi
        done
    fi

    if [ -z "$BIN_PATH" ]; then
        echo -e "❌ \033[1;31mErro:\033[0m '$CMD' não encontrado em /usr/bin ou /usr/local/bin."
        echo -e "Dica: verifique com \033[1;36mdistrobox enter subsistema\033[0m"
        exit 1
    fi

    echo -e "🚀 Exportando de \033[1;32m$BIN_PATH\033[0m..."
    distrobox enter {{CONTAINER_UBUNTU}} -- \
        distrobox-export --bin "$BIN_PATH" --export-path ~/.local/bin > /dev/null 2>&1

    echo -e "✅ Comando \033[1;36m$CMD\033[0m integrado! Teste com: \033[1;32m$CMD\033[0m"

# Exporta binário do Arch-base para ~/.local/bin
[group('exportação')]
[doc('ex: just bin-arch nvim')]
bin-arch cmd:
    #!/usr/bin/env bash
    set -euo pipefail
    CMD="{{cmd}}"
    BIN_PATH="/usr/bin/$CMD"

    echo -e "🔍 Exportando \033[1;36m$CMD\033[0m do Arch-base..."

    distrobox enter {{CONTAINER_ARCH}} -- \
        distrobox-export --bin "$BIN_PATH" --export-path ~/.local/bin > /dev/null 2>&1

    echo -e "✅ \033[1;36m$CMD\033[0m disponível no host."

# ══════════════════════════════════════════════════════════════════════════════
# JAVA — TROCA DE VERSÃO (integração com subsistema)
# ══════════════════════════════════════════════════════════════════════════════
# Como funciona: muda o update-alternatives DENTRO do container,
# depois re-exporta o binário 'java' para ~/.local/bin.

# Muda para Java 8 — Era Clássica / Minecraft 1.12.2
[group('java')]
java8:
    @just _java-switch /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java "Java 8 (Era Clássica / 1.12.2)"

# Muda para Java 17 — Era Moderna / Minecraft 1.18+
[group('java')]
java17:
    @just _java-switch /usr/lib/jvm/java-17-openjdk-amd64/bin/java "Java 17 (Era Moderna / 1.18+)"

# Muda para Java 21 — Era Atual / Minecraft 1.20.5+
[group('java')]
java21:
    @just _java-switch /usr/lib/jvm/java-21-openjdk-amd64/bin/java "Java 21 (Era Atual / 1.20.5+)"

# Muda para Java 25 — Versão Ultra Recente / Minecraft 1.26.1+
[group('java')]
java25:
    @just _java-switch /usr/lib/jvm/java-25-openjdk-amd64/bin/java "Java 25 (Ultra Recente / MC 1.26.1+)"

# Mostra qual Java está ativo agora
[group('java')]
java-current:
    @echo "Versão ativa no host:"
    @{{LOCAL_BIN}}/java -version 2>&1 || java -version 2>&1 || echo "java não encontrado em ~/.local/bin"

# Helper interno — não aparece no just --list
[private]
_java-switch path label:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "🔄 Mudando para {{label}}..."

    # Passo 1: muda o alternatives DENTRO do container
    distrobox enter {{CONTAINER_UBUNTU}} -- \
        sudo update-alternatives --set java "{{path}}"

    # Passo 2: remove wrapper antigo e re-exporta com o novo link
    rm -f "{{LOCAL_BIN}}/java"
    distrobox enter {{CONTAINER_UBUNTU}} -- \
        distrobox-export --bin /usr/bin/java --export-path ~/.local/bin > /dev/null 2>&1

    # Passo 3: confirma a versão ativa
    echo -e "✅ Java trocado! Versão ativa:"
    "{{LOCAL_BIN}}/java" -version 2>&1 || java -version

# ══════════════════════════════════════════════════════════════════════════════
# RAIZ IMUTÁVEL — unlock / lock
# ══════════════════════════════════════════════════════════════════════════════

# Monta a raiz (/) em modo escrita (RW)
[group('sistema')]
unlock:
    #!/usr/bin/env bash
    echo "Tentando desbloquear a raiz (/) para escrita..."
    if sudo mount -o remount,rw /; then
        echo "✅ Raiz desbloqueada com sucesso (RW)."
        echo "⚠️  Lembre-se de rodar 'just lock' ao terminar!"
    else
        echo "❌ Falha ao desbloquear a raiz."
        exit 1
    fi

# Bloqueia a raiz (/) de volta para leitura (RO)
[group('sistema')]
lock:
    #!/usr/bin/env bash
    echo "Bloqueando a raiz (/) para leitura..."
    sync
    sudo systemctl stop \
        systemd-journald.socket \
        systemd-journald-dev-log.socket \
        systemd-journald-audit.socket \
        systemd-journald.service
    if sudo mount -o remount,ro /; then
        sudo systemctl start systemd-journald.service
        echo "✅ Raiz bloqueada com sucesso (RO)."
    else
        sudo systemctl start systemd-journald.service
        echo "❌ Falha ao bloquear a raiz. Tente manualmente:"
        echo "   sudo mount -o remount,ro /"
        exit 1
    fi

# Mostra status atual da raiz (RW ou RO)
[group('sistema')]
root-status:
    #!/usr/bin/env bash
    if findmnt -n -o OPTIONS / | grep -q '\brw\b'; then
        echo -e "\033[1;31m🔓 Raiz em modo ESCRITA (RW)\033[0m — rode 'just lock' ao terminar."
    else
        echo -e "\033[1;32m🔒 Raiz em modo LEITURA (RO)\033[0m — sistema protegido."
    fi

# ══════════════════════════════════════════════════════════════════════════════
# MANUTENÇÃO DOS CONTAINERS
# ══════════════════════════════════════════════════════════════════════════════

# Atualiza tudo: pacman + AUR + apt
[group('manutenção')]
update-all:
    #!/usr/bin/env bash
    echo -e "\033[1;36m→ Atualizando Arch-base (pacman)...\033[0m"
    distrobox enter {{CONTAINER_ARCH}} -- sudo pacman -Syu --noconfirm

    echo -e "\033[1;35m→ Atualizando Arch-base (AUR/yay)...\033[0m"
    distrobox enter {{CONTAINER_ARCH}} -- yay -Syu --noconfirm

    echo -e "\033[1;33m→ Atualizando subsistema (apt)...\033[0m"
    distrobox enter {{CONTAINER_UBUNTU}} -- bash -c \
        "sudo apt-get update -qq && sudo apt-get upgrade -y"

    echo -e "\033[1;32m✅ Todos os containers atualizados!\033[0m"

# Verifica atualizações disponíveis sem instalar
[group('manutenção')]
check-updates:
    #!/usr/bin/env bash
    echo -e "\033[1;36m=== Arch-base (pacman) ===\033[0m"
    distrobox enter {{CONTAINER_ARCH}} -- checkupdates 2>/dev/null \
        || echo "  Nenhuma atualização ou checkupdates não instalado."

    echo -e "\n\033[1;35m=== AUR (yay) ===\033[0m"
    distrobox enter {{CONTAINER_ARCH}} -- yay -Qu 2>/dev/null \
        || echo "  Nenhuma atualização."

    echo -e "\n\033[1;33m=== subsistema (apt) ===\033[0m"
    distrobox enter {{CONTAINER_UBUNTU}} -- bash -c \
        "sudo apt-get update -qq 2>/dev/null; apt list --upgradable 2>/dev/null | grep -v 'Listing'" \
        || echo "  Nenhuma atualização."

# Remove pacote do Arch-base (pacman)
[group('manutenção')]
[doc('ex: just rm-pac firefox')]
rm-pac pkg:
    distrobox enter {{CONTAINER_ARCH}} -- sudo pacman -Rns --noconfirm {{pkg}}
    @echo -e "✅ \033[1;32m{{pkg}}\033[0m removido do Arch-base."

# Remove pacote do Arch-base (yay/AUR)
[group('manutenção')]
[doc('ex: just rm-aur vesktop')]
rm-aur pkg:
    distrobox enter {{CONTAINER_ARCH}} -- yay -Rns --noconfirm {{pkg}}
    @echo -e "✅ \033[1;32m{{pkg}}\033[0m removido (AUR)."

# Remove pacote do subsistema Ubuntu
[group('manutenção')]
[doc('ex: just rm-apt obs-studio')]
rm-apt pkg:
    distrobox enter {{CONTAINER_UBUNTU}} -- sudo apt-get remove -y {{pkg}}
    @echo -e "✅ \033[1;32m{{pkg}}\033[0m removido do subsistema."

# Lista pacotes instalados em todos os containers
[group('manutenção')]
list:
    #!/usr/bin/env bash
    echo -e "\033[1;36m=== Arch-base (pacman/yay) ===\033[0m"
    distrobox enter {{CONTAINER_ARCH}} -- pacman -Qq 2>/dev/null

    echo -e "\n\033[1;33m=== subsistema (apt/dpkg) ===\033[0m"
    distrobox enter {{CONTAINER_UBUNTU}} -- \
        dpkg-query -W -f='${Package}\n' 2>/dev/null

# Inicia os containers em background
[group('manutenção')]
start:
    #!/usr/bin/env bash
    echo "Iniciando containers..."
    distrobox enter {{CONTAINER_ARCH}} -- true &
    distrobox enter {{CONTAINER_UBUNTU}} -- true &
    wait
    echo "✅ Containers prontos."

# Status dos containers distrobox
[group('manutenção')]
status:
    distrobox list

# ══════════════════════════════════════════════════════════════════════════════
# UTILITÁRIOS DO SISTEMA
# ══════════════════════════════════════════════════════════════════════════════

# Exibe informações do sistema (fastfetch)
[group('sistema')]
info:
    @fastfetch

# Recarrega o .zshrc (equivalente ao alias zshreload)
[group('sistema')]
zsh-reload:
    @echo "Execute no terminal: source ~/.zshrc"
    @echo "(just não pode recarregar o shell pai — copie e cole o comando acima)"

# Conecta o microfone do celular
[group('sistema')]
mic:
    @~/mic-celular.sh

# Abre o apx Manager (frontend GTK)
[group('sistema')]
apx-gui:
    @python3 ~/apx_manager.py &
