#!/usr/bin/env bash
# tmux/uninstall.sh — deshace tmux/install.sh y desinstala el tmux que instaló.
#
#   ./uninstall tmux
#
# Qué hace (enseña la lista y pide confirmación antes):
#   1. Quita ~/.tmux.conf y ~/.local/opt/tmux-config/bin/tmux-guia si son
#      enlaces a este repo (si son otra cosa, no los toca), y ~/.local/bin/tmux-guia
#      si lo es (lo enlazaba la versión anterior).
#   2. Desinstala el paquete tmux si lo instaló ./install tmux (apuntado en
#      ~/.local/state/tmux-config/tmux.paquetes); el que ya estaba, no. apt/dnf
#      enseña qué más se quita y vuelve a pedir confirmación.
# No cierra los servidores tmux en marcha (ni lo que corre dentro): siguen con
# sus sesiones y la config que cargaron hasta que los cierres.
# No borra los backups ~/.tmux.conf.bak.* que dejó tmux/install.sh.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/.tmux.conf"
CONF_DST="$HOME/.tmux.conf"
GUIA_SRC="$REPO_DIR/bin/tmux-guia"

. "$REPO_DIR/lib/comun.sh"
GUIA_DST="$TC_DIR/bin/tmux-guia"
GUIA_VIEJO="$HOME/.local/bin/tmux-guia"   # donde la enlazaba la versión anterior

# sudo solo para el gestor de paquetes, y solo si no somos root
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null || die "hace falta sudo (o ejecutar como root) para desinstalar tmux"
    SUDO="sudo"
fi

deb_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }

# El paquete tmux es nuestro solo si lo apuntó ./install tmux. Las versiones
# anteriores no lo apuntaban: ese tmux se queda (no se sabe si ya estaba)
tmux_nuestro() { pkg_installed tmux && grep -qsx tmux "$(state_file tmux)"; }

conf_is_ours() { [ -L "$CONF_DST" ] && [ "$(readlink "$CONF_DST")" = "$CONF_SRC" ]; }
guia_is_ours() { [ -L "$GUIA_DST" ] && [ "$(readlink "$GUIA_DST")" = "$GUIA_SRC" ]; }
guia_vieja_is_ours() { [ -L "$GUIA_VIEJO" ] && [ "$(readlink "$GUIA_VIEJO")" = "$GUIA_SRC" ]; }

# Servidores tmux en marcha de este usuario: no se cierran, solo se avisa (antes
# de quitar el paquete, que se lleva el comando tmux)
vivos="$(tmux_sockets | wc -l)"

# --- Resumen y confirmación ---------------------------------------------------

if ! conf_is_ours && ! guia_is_ours && ! guia_vieja_is_ours && ! tmux_nuestro; then
    info "nada que desinstalar"
    exit 0
fi

echo "Se va a:"
conf_is_ours && echo "  - quitar el enlace ~/.tmux.conf -> $CONF_SRC"
guia_is_ours && echo "  - quitar el enlace ~/.local/opt/tmux-config/bin/tmux-guia -> $GUIA_SRC"
guia_vieja_is_ours && echo "  - quitar el enlace ~/.local/bin/tmux-guia -> $GUIA_SRC"
tmux_nuestro && echo "  - desinstalar el paquete tmux (lo instaló ./install tmux)"
pkg_installed tmux && ! tmux_nuestro && echo "  (el paquete tmux se queda: no lo instaló ./install tmux)"
read -r -p "¿Continuar? [s/N] " answer
[[ "$answer" =~ ^[sS]$ ]] || { info "cancelado, no se ha tocado nada"; exit 0; }

# --- Desinstalar ----------------------------------------------------------------

if conf_is_ours; then
    rm "$CONF_DST"
    info "enlace ~/.tmux.conf quitado"
elif [ -e "$CONF_DST" ]; then
    info "~/.tmux.conf no es de este repo: no se toca"
fi

if guia_is_ours; then
    rm "$GUIA_DST"
    info "enlace ~/.local/opt/tmux-config/bin/tmux-guia quitado"
fi
if guia_vieja_is_ours; then
    rm "$GUIA_VIEJO"
    info "enlace ~/.local/bin/tmux-guia quitado"
fi
# los directorios que hayan quedado vacíos (los demás componentes usan los mismos)
for d in "$TC_DIR/bin" "$TC_DIR" "$(dirname "$TC_DIR")" "$(dirname "$GUIA_VIEJO")"; do
    [ -d "$d" ] && rmdir "$d" 2>/dev/null && info "quitado ${d/#$HOME/\~} (vacío)"
done

if tmux_nuestro; then
    if command -v apt-get >/dev/null; then
        had_meta=0
        deb_installed ubuntu-server && had_meta=1
        $SUDO apt-get purge tmux
        # ubuntu-server depende de tmux: apt lo quita con él
        if [ "$had_meta" -eq 1 ] && ! deb_installed ubuntu-server; then
            info "AVISO: se ha quitado el metapaquete ubuntu-server; tras ./install tmux recupéralo con: sudo apt install ubuntu-server"
        fi
    elif command -v dnf >/dev/null; then
        $SUDO dnf remove tmux
    else
        die "gestor de paquetes no soportado (apt o dnf): desinstala tmux a mano"
    fi
    info "paquete tmux desinstalado"
    state_set tmux
elif pkg_installed tmux; then
    case "$(pkg_manager)" in apt) quitar="sudo apt purge tmux" ;; *) quitar="sudo dnf remove tmux" ;; esac
    info "el paquete tmux se queda: no lo instaló ./install tmux (ya estaba, o lo instaló una versión anterior, que no lo apuntaba). Para quitarlo: $quitar"
fi

[ "$vivos" -eq 0 ] || info "los tmux en marcha ($vivos) siguen abiertos, con sus sesiones y la config que cargaron, hasta que los cierres"
ls "$HOME"/.tmux.conf.bak.* >/dev/null 2>&1 && info "backups de configs anteriores (no se tocan): $(ls "$HOME"/.tmux.conf.bak.*)"
info "listo"
