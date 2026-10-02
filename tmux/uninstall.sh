#!/usr/bin/env bash
# tmux/uninstall.sh — deshace tmux/install.sh y desinstala tmux.
#
#   ./uninstall tmux
#
# Qué hace (enseña la lista y pide confirmación antes):
#   1. Cierra los servidores tmux de este usuario, con todas sus sesiones.
#   2. Quita ~/.tmux.conf y ~/.local/opt/tmux-config/bin/tmux-guia si son
#      enlaces a este repo (si son otra cosa, no los toca), y ~/.local/bin/tmux-guia
#      si lo es (lo enlazaba la versión anterior).
#   3. Desinstala el paquete tmux. apt/dnf enseña qué más se quita y vuelve a
#      pedir confirmación.
# No borra los backups ~/.tmux.conf.bak.* que dejó tmux/install.sh.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/.tmux.conf"
CONF_DST="$HOME/.tmux.conf"
GUIA_SRC="$REPO_DIR/bin/tmux-guia"
TC_DIR="$HOME/.local/opt/tmux-config"     # el mismo que lib/comun.sh
GUIA_DST="$TC_DIR/bin/tmux-guia"
GUIA_VIEJO="$HOME/.local/bin/tmux-guia"   # donde la enlazaba la versión anterior

info() { printf '==> %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Cerrar tmux cerraría también la terminal desde la que corre este script
[ -z "${TMUX:-}" ] || die "estás dentro de tmux: ejecútalo desde una terminal fuera de tmux"

# sudo solo para el gestor de paquetes, y solo si no somos root
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null || die "hace falta sudo (o ejecutar como root) para desinstalar tmux"
    SUDO="sudo"
fi

deb_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }

pkg_installed() {
    if command -v dpkg-query >/dev/null; then deb_installed tmux
    elif command -v rpm >/dev/null; then rpm -q tmux >/dev/null 2>&1
    else return 1
    fi
}

conf_is_ours() { [ -L "$CONF_DST" ] && [ "$(readlink "$CONF_DST")" = "$CONF_SRC" ]; }
guia_is_ours() { [ -L "$GUIA_DST" ] && [ "$(readlink "$GUIA_DST")" = "$GUIA_SRC" ]; }
guia_vieja_is_ours() { [ -L "$GUIA_VIEJO" ] && [ "$(readlink "$GUIA_VIEJO")" = "$GUIA_SRC" ]; }

# Servidores tmux vivos de este usuario (los sockets muertos se ignoran)
sockets=()
sock_dir="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
if command -v tmux >/dev/null && [ -d "$sock_dir" ]; then
    for s in "$sock_dir"/*; do
        [ -S "$s" ] && tmux -S "$s" ls >/dev/null 2>&1 && sockets+=("$s")
    done
fi

# --- Resumen y confirmación ---------------------------------------------------

if [ ${#sockets[@]} -eq 0 ] && ! conf_is_ours && ! guia_is_ours && ! guia_vieja_is_ours && ! pkg_installed; then
    info "nada que desinstalar"
    exit 0
fi

echo "Se va a:"
for s in "${sockets[@]}"; do
    echo "  - cerrar el servidor tmux '$(basename "$s")' y sus sesiones:"
    tmux -S "$s" ls | sed 's/^/      /'
done
conf_is_ours && echo "  - quitar el enlace ~/.tmux.conf -> $CONF_SRC"
guia_is_ours && echo "  - quitar el enlace ~/.local/opt/tmux-config/bin/tmux-guia -> $GUIA_SRC"
guia_vieja_is_ours && echo "  - quitar el enlace ~/.local/bin/tmux-guia -> $GUIA_SRC"
pkg_installed && echo "  - desinstalar el paquete tmux"
read -r -p "¿Continuar? [s/N] " answer
[[ "$answer" =~ ^[sS]$ ]] || { info "cancelado, no se ha tocado nada"; exit 0; }

# --- Desinstalar ----------------------------------------------------------------

for s in "${sockets[@]}"; do
    tmux -S "$s" kill-server
    info "servidor tmux '$(basename "$s")' cerrado"
done

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

if pkg_installed; then
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
fi

ls "$HOME"/.tmux.conf.bak.* >/dev/null 2>&1 && info "backups de configs anteriores (no se tocan): $(ls "$HOME"/.tmux.conf.bak.*)"
info "listo"
