#!/usr/bin/env bash
# tmux/install.sh — instala o actualiza tmux y enlaza su configuración.
#
# Se lanza desde la raíz del repo y se puede ejecutar tantas veces como se quiera:
#   ./install tmux               instalar (sudo solo si falta tmux) y enlazar
#   ./install tmux --actualizar  además, actualizar tmux a la última versión de la distro
#   git pull && ./install tmux   traer cambios del repo y aplicarlos
#
# Qué hace:
#   1. Instala tmux si falta (o lo actualiza con --actualizar).
#   2. Comprueba que .tmux.conf carga sin errores con esa versión de tmux.
#   3. Enlaza ~/.tmux.conf a este repo (con backup de la config anterior).
#   4. Enlaza el comando tmux-guia en ~/.local/bin.
#   5. Aplica la config a los tmux que ya estén en marcha, sin cerrar sesiones.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/.tmux.conf"
CONF_DST="$HOME/.tmux.conf"
GUIA_SRC="$REPO_DIR/bin/tmux-guia"
GUIA_DST="$HOME/.local/bin/tmux-guia"

. "$REPO_DIR/lib/comun.sh"

case "${1:-}" in
    "")           ACTUALIZAR=0 ;;
    --actualizar) ACTUALIZAR=1 ;;
    *)            die "uso: ./install tmux [--actualizar]" ;;
esac

install_tmux() {
    # sudo solo para el gestor de paquetes, y solo si no somos root
    local SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null || die "hace falta sudo (o ejecutar como root) para instalar tmux"
        SUDO="sudo"
    fi
    if command -v apt-get >/dev/null; then
        $SUDO apt-get update -qq
        # install también actualiza si ya está instalado y hay versión nueva
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tmux
    elif command -v dnf >/dev/null; then
        if rpm -q tmux >/dev/null 2>&1; then
            $SUDO dnf upgrade -y -q tmux
        else
            $SUDO dnf install -y -q tmux
        fi
    else
        die "gestor de paquetes no soportado (apt o dnf): instala tmux a mano y vuelve a ejecutar"
    fi
}

# Carga la config en un servidor tmux aislado: no toca las sesiones en marcha
check_conf() {
    local sock="install-check-$$"
    tmux -L "$sock" -f /dev/null new-session -d
    if ! tmux -L "$sock" source-file "$CONF_SRC"; then
        tmux -L "$sock" kill-server
        die "$CONF_SRC no carga con $(tmux -V); no se ha enlazado nada"
    fi
    tmux -L "$sock" kill-server
}

link_conf() {
    if [ -L "$CONF_DST" ] && [ "$(readlink "$CONF_DST")" = "$CONF_SRC" ]; then
        info "~/.tmux.conf ya apunta a este repo"
        return
    fi
    if [ -e "$CONF_DST" ] || [ -L "$CONF_DST" ]; then
        local backup
        backup="$CONF_DST.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$CONF_DST" "$backup"
        info "config anterior guardada en $backup"
    fi
    ln -s "$CONF_SRC" "$CONF_DST"
    info "~/.tmux.conf -> $CONF_SRC"
}

link_guia() {
    if [ -L "$GUIA_DST" ] && [ "$(readlink "$GUIA_DST")" = "$GUIA_SRC" ]; then
        info "tmux-guia ya apunta a este repo"
    elif [ -e "$GUIA_DST" ] || [ -L "$GUIA_DST" ]; then
        info "AVISO: $GUIA_DST ya existe y no es de este repo: no se toca"
        return
    else
        mkdir -p "$(dirname "$GUIA_DST")"
        ln -s "$GUIA_SRC" "$GUIA_DST"
        info "tmux-guia -> $GUIA_SRC"
    fi
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) info "AVISO: ~/.local/bin no está en el PATH: abre una sesión SSH nueva o añádelo" ;;
    esac
}

if ! command -v tmux >/dev/null; then
    info "instalando tmux"
    install_tmux
elif [ "$ACTUALIZAR" -eq 1 ]; then
    info "actualizando tmux"
    install_tmux
else
    info "tmux ya instalado (para actualizarlo: ./install tmux --actualizar)"
fi
info "$(tmux -V) instalado"

check_conf
info "config válida con $(tmux -V)"

link_conf
link_guia

# tmux carga /etc/tmux.conf antes que la del usuario: rompería el mapa único
[ -e /etc/tmux.conf ] && info "AVISO: existe /etc/tmux.conf y se carga antes que ~/.tmux.conf"

tmux_reload
info "listo"
