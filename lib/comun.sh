# lib/comun.sh — funciones compartidas por los install.sh / uninstall.sh de
# cada componente. Se carga con:  . "$REPO_DIR/lib/comun.sh"

info() { printf '==> %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# sudo solo para el gestor de paquetes, y solo si no somos root
SUDO=""
need_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null || die "hace falta sudo (o ejecutar como root) para $1"
        SUDO="sudo"
    fi
}

pkg_manager() {
    if command -v apt-get >/dev/null; then echo apt
    elif command -v dnf >/dev/null; then echo dnf
    else echo ""
    fi
}

pkg_installed() {
    if command -v dpkg-query >/dev/null; then
        dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
    elif command -v rpm >/dev/null; then
        rpm -q "$1" >/dev/null 2>&1
    else
        return 1
    fi
}

# ¿Lo ofrece algún repo activo? Con apt, tras apt-get update.
pkg_available() {
    case "$(pkg_manager)" in
        apt) apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [^(]' ;;
        dnf) dnf -q list --available "$1" >/dev/null 2>&1 ;;
        *)   return 1 ;;
    esac
}

# --- Enlaces --------------------------------------------------------------------

link_is_ours() { [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; }

# link_with_backup SRC DST: enlaza DST -> SRC. Si DST ya existía y no era
# nuestro, lo guarda como DST.bak.<fecha>.
link_with_backup() {
    local src="$1" dst="$2" backup
    if link_is_ours "$src" "$dst"; then
        info "${dst/#$HOME/\~} ya apunta a este repo"
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        backup="$dst.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$backup"
        info "config anterior guardada en $backup"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    info "${dst/#$HOME/\~} -> $src"
}

# --- Estado: qué paquetes instaló cada componente -----------------------------
#
# Un fichero por componente con un paquete por línea. uninstall quita solo los
# que aparecen aquí: lo que ya estaba instalado antes no es nuestro.

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-config"

state_file() { echo "$STATE_DIR/$1.paquetes"; }

state_list() {
    local f; f="$(state_file "$1")"
    [ -f "$f" ] && cat "$f" || true
}

# state_add COMPONENTE PAQUETE...
state_add() {
    local comp="$1" f; shift
    f="$(state_file "$comp")"
    mkdir -p "$STATE_DIR"
    { state_list "$comp"; printf '%s\n' "$@"; } | sort -u > "$f.tmp"
    mv "$f.tmp" "$f"
}

# state_set COMPONENTE PAQUETE...: reemplaza la lista (vacía = borra el fichero)
state_set() {
    local comp="$1" f; shift
    f="$(state_file "$comp")"
    if [ $# -eq 0 ]; then
        rm -f "$f"
    else
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$@" | sort -u > "$f"
    fi
}

# --- tmux en marcha -------------------------------------------------------------

# Imprime los sockets de los servidores tmux vivos de este usuario
tmux_sockets() {
    local dir="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)" s
    command -v tmux >/dev/null && [ -d "$dir" ] || return 0
    for s in "$dir"/*; do
        [ -S "$s" ] && tmux -S "$s" ls >/dev/null 2>&1 && echo "$s"
    done
    return 0
}

# Aplica ~/.tmux.conf a los tmux en marcha de este usuario sin cerrar sesiones
# (lo mismo que Ctrl+B R). Solo a los que arrancaron con esa config o sin
# ninguna (tmux ya corría al instalar); los lanzados con otra (-f) no se tocan.
# Un atajo que se quite de la config sigue activo hasta reiniciar tmux.
tmux_reload() {
    local conf="$HOME/.tmux.conf" real s files f ok lista
    [ -e "$conf" ] || return 0
    real="$(readlink -f "$conf")"
    while read -r s; do
        [ -n "$s" ] || continue
        files="$(tmux -S "$s" display -p '#{config_files}' 2>/dev/null)" || continue
        ok=1
        IFS=, read -ra lista <<<"$files"
        for f in ${lista[@]+"${lista[@]}"}; do
            case "$f" in "$real"|/etc/tmux.conf) ;; *) ok=0 ;; esac
        done
        if [ "$ok" -eq 0 ]; then
            info "tmux '$(basename "$s")' arrancó con otra config ($files): no se toca"
        elif tmux -S "$s" source-file "$conf"; then
            info "config aplicada al tmux '$(basename "$s")' en marcha, sin cerrar sus sesiones"
        else
            info "AVISO: no se pudo aplicar la config al tmux '$(basename "$s")'"
        fi
    done < <(tmux_sockets)
}
