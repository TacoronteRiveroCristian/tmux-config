#!/usr/bin/env bash
# vim/uninstall.sh — quita la config de vim/neovim y lo que instaló ./install vim.
#
#   ./uninstall vim
#
# Qué hace (enseña la lista y pide confirmación antes):
#   1. Quita ~/.vimrc y ~/.config/nvim/init.lua si son enlaces a este repo (si
#      son otra cosa, no los toca).
#   2. Quita el neovim oficial que instaló (~/.local/opt/nvim-*, ~/.local/bin/nvim)
#      y sus plugins y servidores LSP (~/.local/share/nvim/tmux-config).
#   3. Desinstala los paquetes que instaló ./install vim (los apuntados en
#      ~/.local/state/tmux-config/vim.paquetes); los que ya estaban, no.
#      apt/dnf enseña qué más se quita y vuelve a confirmar.
# No borra el historial de deshacer (~/.local/state/vim, ~/.local/state/nvim)
# ni los backups *.bak.<fecha>.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIMRC_SRC="$REPO_DIR/vim/vimrc"
INIT_SRC="$REPO_DIR/nvim/init.lua"
NVIM_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_LINK="$HOME/.local/bin/nvim"
DATOS="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/tmux-config"

. "$REPO_DIR/lib/comun.sh"

enlaces=()
link_is_ours "$VIMRC_SRC" "$HOME/.vimrc" && enlaces+=("$HOME/.vimrc")
link_is_ours "$INIT_SRC" "$NVIM_CONF/init.lua" && enlaces+=("$NVIM_CONF/init.lua")

# neovim oficial: sus directorios y el enlace si apunta a uno de ellos
nvim_dirs=()
for d in "$HOME"/.local/opt/nvim-v*; do
    [ -d "$d" ] && nvim_dirs+=("$d")
done
nvim_link=0
[[ "$(readlink "$NVIM_LINK" 2>/dev/null || true)" == "$HOME/.local/opt/nvim-"* ]] && nvim_link=1

quitar=()
while read -r p; do
    [ -n "$p" ] && pkg_installed "$p" && quitar+=("$p")
done < <(state_list vim)

# --- Resumen y confirmación ---------------------------------------------------

if [ ${#enlaces[@]} -eq 0 ] && [ ${#nvim_dirs[@]} -eq 0 ] && [ "$nvim_link" -eq 0 ] &&
   [ ! -d "$DATOS" ] && [ ${#quitar[@]} -eq 0 ]; then
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
[ "$nvim_link" -eq 0 ] || echo "  - quitar el enlace ~/.local/bin/nvim"
[ ! -d "$DATOS" ] || echo "  - quitar los plugins y servidores LSP de neovim (${DATOS/#$HOME/\~}, $(du -sh "$DATOS" | cut -f1))"
[ ${#quitar[@]} -eq 0 ] || echo "  - desinstalar los paquetes que instaló ./install vim: ${quitar[*]}"
read -r -p "¿Continuar? [s/N] " answer
[[ "$answer" =~ ^[sS]$ ]] || { info "cancelado, no se ha tocado nada"; exit 0; }

# --- Desinstalar ----------------------------------------------------------------

for f in ${enlaces[@]+"${enlaces[@]}"}; do
    rm "$f"
    info "enlace ${f/#$HOME/\~} quitado"
done
if [ "$nvim_link" -eq 1 ]; then
    rm "$NVIM_LINK"
    info "enlace ~/.local/bin/nvim quitado"
fi
for d in ${nvim_dirs[@]+"${nvim_dirs[@]}"}; do
    rm -rf "$d"
    info "neovim oficial quitado: ${d/#$HOME/\~}"
done
if [ -d "$DATOS" ]; then
    rm -rf "$DATOS"
    info "plugins y servidores LSP quitados"
fi

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
[ "${EDITOR:-}" != "$NVIM_LINK" ] ||
    info "en los panes ya abiertos EDITOR sigue apuntando a neovim: abre uno nuevo (o unset EDITOR VISUAL)"
info "listo"
