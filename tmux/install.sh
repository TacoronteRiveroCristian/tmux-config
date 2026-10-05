#!/usr/bin/env bash
# tmux/install.sh — instala o actualiza tmux y enlaza su configuración.
#
# Se lanza desde la raíz del repo y se puede ejecutar tantas veces como se quiera:
#   ./install tmux               instalar (sudo solo si falta tmux) y enlazar
#   ./install tmux --actualizar  además, actualizar tmux a la última versión de la distro
#   git pull && ./install tmux   traer cambios del repo y aplicarlos
#
# Qué hace:
#   1. tmux (tabla tmux/paquetes) lo instala antes ./install, si falta, y lo
#      apunta en ~/.local/state/tmux-config/tmux.paquetes: ./uninstall tmux
#      solo quita ese, no el que ya estaba (Ubuntu Server lo trae). Con --plan,
#      este script solo enseña lo suyo del plan: si aparta tu ~/.tmux.conf.
#   2. Comprueba que .tmux.conf carga sin errores con esa versión de tmux.
#   3. Enlaza ~/.tmux.conf a este repo (con backup de la config anterior).
#   4. Enlaza el comando tmux-guia en ~/.local/opt/tmux-config/bin, que solo está
#      en el PATH dentro de tmux (Alt+h la abre por su ruta en el repo). Quita
#      ~/.local/bin/tmux-guia si lo enlazó la versión anterior.
#   5. Aplica la config a los tmux que ya estén en marcha, sin cerrar sesiones.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/.tmux.conf"
CONF_DST="$HOME/.tmux.conf"
GUIA_SRC="$REPO_DIR/bin/tmux-guia"

. "$REPO_DIR/lib/comun.sh"
GUIA_DST="$TC_DIR/bin/tmux-guia"
GUIA_VIEJO="$HOME/.local/bin/tmux-guia"   # donde la enlazaba la versión anterior

MODO=instalar
for a in "$@"; do
    case "$a" in
        --plan)       MODO=plan ;;
        --actualizar) ;;   # los paquetes los actualiza ./install
        *)            die "uso: ./install tmux [--actualizar] [--check] [-y]" ;;
    esac
done

# Lo de este componente en el plan de ./install, sin tocar nada
plan() {
    if { [ -e "$CONF_DST" ] || [ -L "$CONF_DST" ]; } && ! link_is_ours "$CONF_SRC" "$CONF_DST"; then
        plan_linea backup "~/.tmux.conf no es de este repo: se guarda como ~/.tmux.conf.bak.<fecha>"
    fi
    # tmux carga /etc/tmux.conf antes que la del usuario: rompería el mapa único
    if [ -e /etc/tmux.conf ]; then
        plan_linea aviso "existe /etc/tmux.conf y se carga antes que ~/.tmux.conf"
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
        aviso "$GUIA_DST ya existe y no es de este repo: no se toca"
    else
        mkdir -p "$(dirname "$GUIA_DST")"
        ln -s "$GUIA_SRC" "$GUIA_DST"
        info "tmux-guia -> $GUIA_SRC"
    fi
    # ~/.local/bin/tmux-guia la veía también bash, fuera de tmux
    if unlink_old "$GUIA_SRC" "$GUIA_VIEJO"; then
        rmdir_vacio "$(dirname "$GUIA_VIEJO")"
    fi
}

if [ "$MODO" = plan ]; then plan; exit 0; fi

command -v tmux >/dev/null || die "falta tmux: ./install tmux lo instala"
info "$(tmux -V) instalado"

check_conf
info "config válida con $(tmux -V)"

link_conf
link_guia

tmux_reload
info "listo"
