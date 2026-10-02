#!/usr/bin/env bash
# vim/actualizar-plugins.sh — copia en vim/pack/plugins/start/ los plugins de
# vim/plugins.txt, cada uno en su commit. Solo hace falta al cambiar de versión;
# ./install vim no descarga nada.
#
#   vim/actualizar-plugins.sh
#
# Copia solo lo que vim carga (autoload, plugin, doc...) y la licencia, y genera
# los índices de :help para que vim no tenga que escribirlos dentro del repo.
set -euo pipefail

VIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$VIM_DIR/pack/plugins/start"
RUNTIME=(autoload doc ftplugin lib nerdtree_plugin plugin syntax LICENCE LICENSE)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

grep -v '^\s*\(#\|$\)' "$VIM_DIR/plugins.txt" | while read -r nombre repo commit; do
    echo "==> $nombre @ ${commit:0:10}"
    git -c advice.detachedHead=false clone -q "$repo" "$tmp/$nombre"
    git -C "$tmp/$nombre" checkout -q "$commit"
    rm -rf "${DEST:?}/$nombre"
    mkdir -p "$DEST/$nombre"
    for d in "${RUNTIME[@]}"; do
        [ -e "$tmp/$nombre/$d" ] && cp -r "$tmp/$nombre/$d" "$DEST/$nombre/"
    done
    if [ -d "$DEST/$nombre/doc" ]; then
        vim -u NONE -es -c "helptags $DEST/$nombre/doc" -c 'qa!'
    fi
done
echo "==> listo: revisa 'git status vim/pack' y prueba antes de hacer commit"
