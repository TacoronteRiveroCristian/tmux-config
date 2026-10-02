#!/usr/bin/env bash
# vim/install.sh — instala vim y neovim y enlaza su configuración.
#
# Se lanza desde la raíz del repo y se puede ejecutar tantas veces como se quiera:
#   ./install vim               instalar lo que falte (sudo solo si falta algo) y enlazar
#   ./install vim --actualizar  además, actualizar los paquetes a la última versión de la distro
#
# Qué hace:
#   1. Instala con apt/dnf vim y lo que usa neovim: git, curl, unzip, ripgrep
#      (buscar texto), shellcheck, node y npm (servidores LSP). En Rocky/RHEL
#      ripgrep y shellcheck están en EPEL: sin EPEL avisa y sigue sin ellos.
#      Apunta los que instala en ~/.local/state/tmux-config/vim.paquetes:
#      ./uninstall vim quita esos y no los que ya estaban.
#   2. vim: comprueba que vim/vimrc carga sin errores y enlaza ~/.vimrc.
#   3. neovim: instala la versión oficial fijada abajo en ~/.local/opt (sin
#      root), comprobando su sha256, con el enlace ~/.local/bin/nvim. Las de las
#      distros son demasiado antiguas (0.6 a 0.10) para los plugins.
#   4. Descarga los plugins (fijados a un commit) y los servidores LSP en
#      ~/.local/share/nvim/tmux-config, comprueba que todo carga y enlaza
#      ~/.config/nvim/init.lua (con backup de la config anterior).
#   5. neovim queda como editor por defecto (EDITOR y VISUAL: git commit,
#      crontab -e, sudoedit...) dentro de tmux: lo pone zsh/.zshrc si existe
#      ~/.local/bin/nvim. Fuera de tmux sigue el de la distro; bash no se toca.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIMRC_SRC="$REPO_DIR/vim/vimrc"
VIMRC_DST="$HOME/.vimrc"
INIT_SRC="$REPO_DIR/nvim/init.lua"
NVIM_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

NVIM_VERSION=v0.12.5
NVIM_SHA256_x86_64=bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875
NVIM_SHA256_arm64=1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725
NVIM_DIR="$HOME/.local/opt/nvim-$NVIM_VERSION"
NVIM_LINK="$HOME/.local/bin/nvim"

. "$REPO_DIR/lib/comun.sh"

case "${1:-}" in
    "")           ACTUALIZAR=0 ;;
    --actualizar) ACTUALIZAR=1 ;;
    *)            die "uso: ./install vim [--actualizar]" ;;
esac

case "$(pkg_manager)" in
    apt) PAQUETES=(vim git unzip ripgrep shellcheck nodejs npm) ;;
    dnf) PAQUETES=(vim-enhanced git unzip ripgrep ShellCheck nodejs npm) ;;
    *)   die "gestor de paquetes no soportado (apt o dnf): instala vim a mano" ;;
esac
# curl solo si falta el comando: en Rocky viene curl-minimal, que choca con el paquete curl
command -v curl >/dev/null || PAQUETES+=(curl)

install_paquetes() {
    local faltan=() instalar=() sin_repo=() ya=() nuevos=() p
    for p in "${PAQUETES[@]}"; do
        pkg_installed "$p" || faltan+=("$p")
    done
    if [ ${#faltan[@]} -eq 0 ] && [ "$ACTUALIZAR" -eq 0 ]; then
        info "paquetes ya instalados (para actualizarlos: ./install vim --actualizar)"
        return
    fi

    need_sudo "instalar paquetes"
    case "$(pkg_manager)" in
        apt)
            $SUDO apt-get update -qq
            # install también actualiza los que ya están si hay versión nueva
            if [ "$ACTUALIZAR" -eq 1 ]; then instalar=("${PAQUETES[@]}"); else instalar=("${faltan[@]}"); fi
            info "instalando ${instalar[*]}"
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${instalar[@]}"
            ;;
        dnf)
            for p in "${faltan[@]}"; do
                if pkg_available "$p"; then instalar+=("$p"); else sin_repo+=("$p"); fi
            done
            if [ "$ACTUALIZAR" -eq 1 ]; then
                for p in "${PAQUETES[@]}"; do pkg_installed "$p" && ya+=("$p"); done
                [ ${#ya[@]} -eq 0 ] || $SUDO dnf upgrade -y -q "${ya[@]}"
            fi
            if [ ${#instalar[@]} -gt 0 ]; then
                info "instalando ${instalar[*]}"
                $SUDO dnf install -y -q "${instalar[@]}"
            fi
            ;;
    esac

    for p in "${faltan[@]}"; do pkg_installed "$p" && nuevos+=("$p"); done
    [ ${#nuevos[@]} -eq 0 ] || state_add vim "${nuevos[@]}"

    if [ ${#sin_repo[@]} -gt 0 ]; then
        info "AVISO: no están en los repos activos: ${sin_repo[*]} (neovim funciona sin ellos)"
        info "       En Rocky/RHEL vienen de EPEL. Si quieres activarlo en esta máquina"
        info "       (Rocky/Alma): sudo dnf install epel-release && ./install vim"
    fi
}

# vim: carga con HOME temporal (no toca tu historial ni ~/.vimrc.local), sin
# errores y con sus plugins
check_vim() {
    local tmp plugins err
    tmp="$(mktemp -d)"
    plugins='if !exists(":NERDTreeToggle") || !exists(":CtrlP") || !exists("g:loaded_commentary") | cquit | endif'
    if ! HOME="$tmp" vim -N -u "$VIMRC_SRC" -i NONE -es \
            -c "redir! > $tmp/mensajes | silent messages | redir END" -c "$plugins" -c 'qa!'; then
        err="$(cat "$tmp/mensajes" 2>/dev/null)"
        rm -rf "$tmp"
        die "$VIMRC_SRC no carga limpio en vim (o faltan sus plugins); no se ha enlazado nada:"$'\n'"$err"
    fi
    rm -rf "$tmp"
}

# neovim oficial en ~/.local/opt/nvim-<versión>, verificado con su sha256.
# Sin build oficial para esta arquitectura deja NVIM_OK=0 y queda solo vim.
NVIM_OK=1
install_nvim() {
    local arch sha url tmp nvim_link_actual
    case "$(uname -m)" in
        x86_64)        arch=x86_64; sha="$NVIM_SHA256_x86_64" ;;
        aarch64|arm64) arch=arm64;  sha="$NVIM_SHA256_arm64" ;;
        *) info "AVISO: no hay neovim oficial para $(uname -m): queda vim"; NVIM_OK=0; return 0 ;;
    esac
    if [ -x "$NVIM_DIR/bin/nvim" ]; then
        info "neovim $NVIM_VERSION ya instalado"
    else
        url="https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-$arch.tar.gz"
        info "descargando neovim $NVIM_VERSION ($arch)"
        tmp="$(mktemp -d)"
        if ! curl -fsSL -o "$tmp/nvim.tar.gz" "$url"; then
            rm -rf "$tmp"; die "no se pudo descargar $url"
        fi
        if ! echo "$sha  $tmp/nvim.tar.gz" | sha256sum -c --status; then
            rm -rf "$tmp"; die "el sha256 de $url no coincide: no se instala"
        fi
        tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
        mkdir -p "$(dirname "$NVIM_DIR")"
        mv "$tmp/nvim-linux-$arch" "$NVIM_DIR"
        rm -rf "$tmp"
    fi
    "$NVIM_DIR/bin/nvim" --version >/dev/null 2>&1 || die "neovim $NVIM_VERSION no arranca en esta máquina"

    # ~/.local/bin/nvim: el nuestro; si hay otro que no es de este repo, no se toca
    nvim_link_actual="$(readlink "$NVIM_LINK" 2>/dev/null || true)"
    if [ -e "$NVIM_LINK" ] && [[ "$nvim_link_actual" != "$HOME/.local/opt/nvim-"* ]]; then
        info "AVISO: $NVIM_LINK ya existe y no es de este repo: no se toca (el nuestro: $NVIM_DIR/bin/nvim)"
    else
        mkdir -p "$(dirname "$NVIM_LINK")"
        ln -sfn "$NVIM_DIR/bin/nvim" "$NVIM_LINK"
        info "~/.local/bin/nvim -> $NVIM_DIR/bin/nvim"
    fi
    # versiones anteriores instaladas por este script
    local d
    for d in "$HOME"/.local/opt/nvim-v*; do
        if [ -d "$d" ] && [ "$d" != "$NVIM_DIR" ]; then
            rm -rf "$d"
            info "neovim anterior quitado: $d"
        fi
    done
}

# Plugins y servidores LSP, y comprobar que todo carga. Con la config del repo
# (-u): si algo falla, ~/.config/nvim no se ha tocado todavía.
setup_nvim() {
    local nvim="$NVIM_DIR/bin/nvim" out
    info "plugins de neovim (la primera vez tarda un poco)"
    if ! out="$("$nvim" --headless -u "$INIT_SRC" '+Lazy! sync' +qa 2>&1)"; then
        die "no se pudieron instalar los plugins de neovim:"$'\n'"$out"
    fi
    "$nvim" --headless -u "$INIT_SRC" -c 'lua require("tc.instalar").lsp()' 2>&1 \
        || die "no se pudieron instalar todos los servidores LSP (vuelve a ejecutar ./install vim)"
    if ! out="$("$nvim" --headless -u "$INIT_SRC" -c 'lua require("tc.instalar").comprobar()' 2>&1)" ||
       ! grep -q '^tc-ok' <<<"$out"; then
        die "la config de neovim no carga limpia; no se ha enlazado:"$'\n'"$out"
    fi
}

link_nvim() {
    local f backup
    # Con init.lua e init.vim a la vez neovim no sabe cuál usar: el que no es nuestro, a backup
    for f in "$NVIM_CONF/init.vim" "$NVIM_CONF/init.lua"; do
        link_is_ours "$INIT_SRC" "$f" && continue
        if [ -e "$f" ] || [ -L "$f" ]; then
            backup="$f.bak.$(date +%Y%m%d-%H%M%S)"
            mv "$f" "$backup"
            info "config anterior de neovim guardada en $backup"
        fi
    done
    link_with_backup "$INIT_SRC" "$NVIM_CONF/init.lua"
}

# EDITOR lo pone zsh/.zshrc: aquí solo se comprueba que va a llegar
editor_nvim() {
    local ed
    if link_is_ours "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"; then
        info "neovim es el editor por defecto en los panes nuevos de tmux (git commit, crontab -e, sudoedit...)"
    else
        info "AVISO: ~/.zshrc no es de este repo: neovim no será el editor por defecto (./install zsh)"
    fi
    # git usa su core.editor antes que EDITOR
    ed="$(git config --global --get core.editor 2>/dev/null || true)"
    [ -z "$ed" ] || info "AVISO: git seguirá abriendo su core.editor ($ed). Para usar neovim: git config --global --unset core.editor"
}

install_paquetes
command -v vim >/dev/null || die "vim no está instalado"
info "$(vim --version | head -n 1) instalado"
check_vim
link_with_backup "$VIMRC_SRC" "$VIMRC_DST"

install_nvim
if [ "$NVIM_OK" -eq 1 ]; then
    setup_nvim
    link_nvim
    editor_nvim
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) info "AVISO: ~/.local/bin no está en el PATH: abre una sesión SSH nueva (o usa $NVIM_LINK)" ;;
    esac
fi

info "aprender: vimtutor es (vim, en español) · :Tutor (neovim) · Espacio ? (mapa de atajos)"
info "ficheros del sistema, en tmux: sudoedit /etc/fichero (neovim con tu config, sin abrirlo como root)"
info "listo"
