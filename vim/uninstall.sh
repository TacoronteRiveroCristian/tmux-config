#!/usr/bin/env bash
# vim/uninstall.sh — quita neovim, su configuración y lo que instaló ./install vim.
#
#   ./uninstall vim
#
# Qué hace (enseña la lista y pide confirmación antes):
#   1. Quita ~/.config/tmux-config-nvim/init.lua si es un enlace a este repo (si
#      es otra cosa, no la toca), y el directorio si queda vacío: tu local.lua
#      y los backups se quedan.
#   2. Quita el neovim oficial que instaló (~/.local/opt/tmux-config/nvim-*), sus
#      comandos (nvim, vi, vim, view y vimdiff en ~/.local/opt/tmux-config/bin) y
#      sus plugins y servidores LSP (~/.local/share/tmux-config-nvim).
#   3. Lo mismo con lo que dejaba en $HOME la versión anterior, si es de este
#      repo: ~/.vimrc, ~/.config/nvim/init.lua, ~/.local/bin/nvim y el neovim al
#      que apunta, y ~/.local/share/nvim/tmux-config.
#   4. Desinstala los paquetes que instaló ./install vim (los apuntados en
#      ~/.local/state/tmux-config/vim.paquetes; también vim, si lo instaló la
#      versión anterior); los que ya estaban, no. apt/dnf enseña qué más se
#      quita y vuelve a confirmar.
# No borra el historial de deshacer (~/.local/state/tmux-config-nvim,
# ~/.local/state/nvim) ni los backups *.bak.<fecha>.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_SRC="$REPO_DIR/nvim/init.lua"

. "$REPO_DIR/lib/comun.sh"

APPNAME=tmux-config-nvim   # el NVIM_APPNAME de vim/install.sh
NVIM_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
BIN="$TC_DIR/bin"
# Lo de la versión anterior, en $HOME
VIEJO_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
VIEJO_LINK="$HOME/.local/bin/nvim"

enlaces=()
link_is_ours "$INIT_SRC" "$NVIM_CONF/init.lua" && enlaces+=("$NVIM_CONF/init.lua")
link_is_ours "$REPO_DIR/vim/vimrc" "$HOME/.vimrc" && enlaces+=("$HOME/.vimrc")
link_is_ours "$INIT_SRC" "$VIEJO_CONF/init.lua" && enlaces+=("$VIEJO_CONF/init.lua")
# Los comandos: nvim al neovim de ~/.local/opt/tmux-config, vi y vim a nvim,
# view y vimdiff al repo
[[ "$(readlink "$BIN/nvim" 2>/dev/null || true)" == "$TC_DIR"/nvim-v*/bin/nvim ]] && enlaces+=("$BIN/nvim")
for n in vi vim; do link_is_ours nvim "$BIN/$n" && enlaces+=("$BIN/$n"); done
for n in view vimdiff; do link_is_ours "$REPO_DIR/bin/$n" "$BIN/$n" && enlaces+=("$BIN/$n"); done

# El neovim oficial: los de ~/.local/opt/tmux-config (todo es de este repo) y,
# de la versión anterior, solo aquel al que apunta ~/.local/bin/nvim
nvim_dirs=()
for d in "$TC_DIR"/nvim-v*; do
    [ -d "$d" ] && nvim_dirs+=("$d")
done
t="$(readlink "$VIEJO_LINK" 2>/dev/null || true)"
if [[ "$t" == "$HOME"/.local/opt/nvim-v*/bin/nvim ]]; then
    enlaces+=("$VIEJO_LINK")
    [ ! -d "${t%/bin/nvim}" ] || nvim_dirs+=("${t%/bin/nvim}")
fi

# Plugins y servidores LSP (y la caché que regenera neovim); el de la versión
# anterior, con su lazy-lock
datos=()
for d in "${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME" "${XDG_CACHE_HOME:-$HOME/.cache}/$APPNAME" \
         "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/tmux-config" \
         "${XDG_STATE_HOME:-$HOME/.local/state}/nvim/tmux-config-lazy-lock.json"; do
    [ -e "$d" ] && datos+=("$d")
done

quitar=()
while read -r p; do
    [ -n "$p" ] && pkg_installed "$p" && quitar+=("$p")
done < <(state_list vim)

# --- Resumen y confirmación ---------------------------------------------------

if [ ${#enlaces[@]} -eq 0 ] && [ ${#nvim_dirs[@]} -eq 0 ] && [ ${#datos[@]} -eq 0 ] && [ ${#quitar[@]} -eq 0 ]; then
    info "nada que desinstalar"
    exit 0
fi

echo "Se va a:"
for f in ${enlaces[@]+"${enlaces[@]}"}; do
    echo "  - quitar el enlace ${f/#$HOME/\~} -> $(readlink "$f")"
done
for d in ${nvim_dirs[@]+"${nvim_dirs[@]}"}; do
    echo "  - quitar el neovim oficial ${d/#$HOME/\~}"
done
for d in ${datos[@]+"${datos[@]}"}; do
    echo "  - quitar ${d/#$HOME/\~} ($(du -sh "$d" | cut -f1))"
done
[ ${#quitar[@]} -eq 0 ] || echo "  - desinstalar los paquetes que instaló ./install vim: ${quitar[*]}"
read -r -p "¿Continuar? [s/N] " answer
[[ "$answer" =~ ^[sS]$ ]] || { info "cancelado, no se ha tocado nada"; exit 0; }

# --- Desinstalar ----------------------------------------------------------------

for f in ${enlaces[@]+"${enlaces[@]}"}; do
    rm "$f"
    info "enlace ${f/#$HOME/\~} quitado"
done
for d in ${nvim_dirs[@]+"${nvim_dirs[@]}"}; do
    rm -rf "$d"
    info "neovim oficial quitado: ${d/#$HOME/\~}"
done
for d in ${datos[@]+"${datos[@]}"}; do
    rm -rf "$d"
    info "quitado ${d/#$HOME/\~}"
done
# los directorios que hayan quedado vacíos (los demás componentes usan los de ~/.local/opt)
rmdir_vacio "$NVIM_CONF" "$BIN" "$TC_DIR" "$(dirname "$TC_DIR")" \
    "$VIEJO_CONF" "$(dirname "$VIEJO_LINK")" "${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
[ ! -d "$NVIM_CONF" ] || info "${NVIM_CONF/#$HOME/\~} se queda: tiene tus ficheros: $(find "$NVIM_CONF" -mindepth 1 -maxdepth 1 -printf '%f ')"

if [ ${#quitar[@]} -gt 0 ]; then
    need_sudo "desinstalar paquetes"
    case "$(pkg_manager)" in
        apt) $SUDO apt-get purge "${quitar[@]}" ;;
        dnf) $SUDO dnf remove "${quitar[@]}" ;;
        *)   die "gestor de paquetes no soportado (apt o dnf): desinstala ${quitar[*]} a mano" ;;
    esac
    info "paquetes desinstalados: ${quitar[*]}"
    [ "$(pkg_manager)" = apt ] && info "lo que instalaron como dependencia (p. ej. los de npm) se quita con: sudo apt autoremove"
fi

restantes=()
while read -r p; do
    [ -n "$p" ] && pkg_installed "$p" && restantes+=("$p")
done < <(state_list vim)
state_set vim ${restantes[@]+"${restantes[@]}"}

# zsh/.zshrc deja de ponerlo en los panes nuevos; los abiertos lo conservan
case "${EDITOR:-}" in
    "$BIN/nvim"|"$VIEJO_LINK")
        info "en los panes ya abiertos EDITOR sigue apuntando a neovim: abre uno nuevo (o unset EDITOR VISUAL)" ;;
esac
info "listo"
