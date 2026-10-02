#!/usr/bin/env bash
# zsh/uninstall.sh — quita la config de zsh y los paquetes que instaló ./install zsh.
#
#   ./uninstall zsh
#
# Qué hace (enseña la lista y pide confirmación antes):
#   1. Quita ~/.local/opt/tmux-config/zsh/.zshrc si es un enlace a este repo, y
#      ~/.zshrc si lo es (lo enlazaba la versión anterior); si es otra cosa, no
#      la toca.
#   2. En los tmux en marcha de este usuario, los panes nuevos vuelven a la
#      shell de login.
#   3. Desinstala los paquetes que instaló ./install zsh (los apuntados en
#      ~/.local/state/tmux-config/zsh.paquetes); los que ya estaban, no.
#      zsh se queda si es la shell de login de algún usuario: sin ella no
#      podría entrar. apt/dnf enseña qué más se quita y vuelve a confirmar.
# No borra ~/.zsh_history ni los backups ~/.zshrc.bak.*.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_SRC="$REPO_DIR/zsh/.zshrc"

. "$REPO_DIR/lib/comun.sh"
CONF_DIR="$TC_DIR/zsh"

# Usuarios con zsh como shell de login
login_zsh() { getent passwd | awk -F: '$7 ~ /\/zsh$/ { print $1 }'; }

# Servidores tmux con los panes en zsh (default-command lo pone .tmux.conf)
sockets=()
while read -r s; do
    [ -n "$s" ] || continue
    case "$(tmux -S "$s" show -gv default-command 2>/dev/null)" in
        *"exec zsh"*) sockets+=("$s") ;;
    esac
done < <(tmux_sockets)

quitar=() conservar=()
usuarios="$(login_zsh | paste -sd, -)"
while read -r p; do
    [ -n "$p" ] || continue
    pkg_installed "$p" || continue
    if [ "$p" = zsh ] && [ -n "$usuarios" ]; then conservar+=("$p"); else quitar+=("$p"); fi
done < <(state_list zsh)

# --- Resumen y confirmación ---------------------------------------------------

# El de ahora y el ~/.zshrc de la versión anterior (de este u otro clon)
enlaces=()
link_is_ours "$CONF_SRC" "$CONF_DIR/.zshrc" && enlaces+=("$CONF_DIR/.zshrc")
viejo=0
es_del_repo "$HOME/.zshrc" zsh/.zshrc && viejo=1
# Su directorio, si no tiene un .zshrc que no sea nuestro
quitar_dir=0
if [ -d "$CONF_DIR" ]; then
    if link_is_ours "$CONF_SRC" "$CONF_DIR/.zshrc" || { [ ! -e "$CONF_DIR/.zshrc" ] && [ ! -L "$CONF_DIR/.zshrc" ]; }; then
        quitar_dir=1
    else
        info "${CONF_DIR/#$HOME/\~}/.zshrc no es de este repo: no se toca"
    fi
fi

if [ ${#enlaces[@]} -eq 0 ] && [ "$viejo" -eq 0 ] && [ "$quitar_dir" -eq 0 ] && [ ${#sockets[@]} -eq 0 ] && [ ${#quitar[@]} -eq 0 ]; then
    info "nada que desinstalar"
    [ ${#conservar[@]} -eq 0 ] || info "zsh se queda: es la shell de login de: $usuarios"
    exit 0
fi

echo "Se va a:"
for f in ${enlaces[@]+"${enlaces[@]}"}; do
    echo "  - quitar el enlace ${f/#$HOME/\~} -> $CONF_SRC"
done
[ "$viejo" -eq 0 ] || echo "  - quitar el enlace ~/.zshrc -> $(readlink "$HOME/.zshrc") y devolver tu ~/.zshrc de antes, si hay un backup"
[ "$quitar_dir" -eq 0 ] || echo "  - quitar ${CONF_DIR/#$HOME/\~} (con la caché de completado que zsh deja ahí)"
for s in "${sockets[@]}"; do
    echo "  - en el tmux '$(basename "$s")', que los panes nuevos vuelvan a la shell de login"
done
[ ${#quitar[@]} -eq 0 ] || echo "  - desinstalar los paquetes que instaló ./install zsh: ${quitar[*]}"
[ ${#conservar[@]} -eq 0 ] || echo "  (zsh se queda: es la shell de login de: $usuarios)"
read -r -p "¿Continuar? [s/N] " answer
[[ "$answer" =~ ^[sS]$ ]] || { info "cancelado, no se ha tocado nada"; exit 0; }

# --- Desinstalar ----------------------------------------------------------------

for f in ${enlaces[@]+"${enlaces[@]}"}; do
    rm "$f"
    info "enlace ${f/#$HOME/\~} quitado"
done
[ "$viejo" -eq 0 ] || unlink_old "$CONF_SRC" "$HOME/.zshrc"
# Lo demás de ese directorio lo crea zsh por estar ahí ZDOTDIR (.zcompdump)
if [ "$quitar_dir" -eq 1 ]; then
    rm -f "$CONF_DIR"/.zcompdump*
    rmdir_vacio "$CONF_DIR" "$TC_DIR" "$(dirname "$TC_DIR")"
fi

for s in "${sockets[@]}"; do
    tmux -S "$s" set -gu default-command
    info "tmux '$(basename "$s")': los panes nuevos arrancan en la shell de login"
done

if [ ${#quitar[@]} -gt 0 ]; then
    need_sudo "desinstalar paquetes"
    case "$(pkg_manager)" in
        apt) $SUDO apt-get purge "${quitar[@]}" ;;
        dnf) $SUDO dnf remove "${quitar[@]}" ;;
        *)   die "gestor de paquetes no soportado (apt o dnf): desinstala ${quitar[*]} a mano" ;;
    esac
    info "paquetes desinstalados: ${quitar[*]}"
fi

# Lo que sigue instalado (zsh conservado) se queda apuntado para la próxima vez
restantes=()
while read -r p; do
    [ -n "$p" ] && pkg_installed "$p" && restantes+=("$p")
done < <(state_list zsh)
state_set zsh ${restantes[@]+"${restantes[@]}"}

ls "$HOME"/.zshrc.bak.* >/dev/null 2>&1 && info "backups de configs anteriores (no se tocan): $(ls "$HOME"/.zshrc.bak.*)"
info "listo"
