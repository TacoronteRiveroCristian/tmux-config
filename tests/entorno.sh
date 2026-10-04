#!/usr/bin/env bash
# shellcheck disable=SC2016  # comillas simples: se expanden dentro de "su -c"
# tests/entorno.sh — una máquina de punta a punta, dentro del contenedor.
#
#   PERFIL=pi-trixie|pi-bookworm|ubuntu-server|ubuntu-2204|migracion
#   DESDE=<commit>   instala esa versión y luego "git pull && ./actualizar",
#                    como quien ya lo tenía; vacío: instalación nueva
#
# Comprueba: install/actualizar, un pane nuevo de tmux (zsh, vim = neovim del
# repo, z), fuera de tmux nada del repo, un .py en neovim (resaltado, pyright),
# tldr, que bash no se toca y que uninstall no deja nada y respeta lo que ya había.
. /tests/comun.sh
PERFIL="${PERFIL:?}"; DESDE="${DESDE:-}"
arm=0; [ "$(uname -m)" = aarch64 ] && arm=1
espera() { [ $arm -eq 1 ] && echo "$2" || echo "$1"; }   # x86 · arm64 (emulado tarda más)

base
case "$PERFIL" in
    pi-trixie)
        # Como la Pi: repo de Raspberry Pi con su clave de verdad, gh con la clave
        # caducada (índices viejos: avisa y sigue), nodejs de NodeSource y el vim
        # de la distro
        curl -fsSL -o /tmp/rpi-keyring.deb http://archive.raspberrypi.com/debian/pool/main/r/raspberrypi-archive-keyring/raspberrypi-archive-keyring_2025.1+rpt1_all.deb
        dpkg -i /tmp/rpi-keyring.deb >/dev/null
        echo "deb [signed-by=/usr/share/keyrings/raspberrypi-archive-keyring.pgp] http://archive.raspberrypi.com/debian/ trixie main" > /etc/apt/sources.list.d/raspi.list
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
        apt-get update -qq >/dev/null 2>&1
        cp /usr/share/keyrings/raspberrypi-archive-keyring.pgp /usr/share/keyrings/githubcli-archive-keyring.gpg
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
        apt-get -yqq install nodejs vim >/dev/null 2>&1
        U=rasp3 ;;
    pi-bookworm)   U=rasp3 ;;
    # Ubuntu Server trae tmux, vim y bash-completion
    ubuntu-server) apt-get -yqq install tmux vim bash-completion >/dev/null 2>&1; U=u ;;
    *)             U=u ;;
esac
. /etc/os-release
echo "=== $PERFIL: $PRETTY_NAME ($(uname -m)), usuario $U${DESDE:+, desde $DESDE}"
echo "    node $(node -v 2>/dev/null || echo -) · npm $(npm -v 2>/dev/null || echo -) · tmux previo: $(command -v tmux || echo -) · vim previo: $(command -v vim || echo -)"
# Lo que ya estaba: uninstall no lo quita
antes="$(dpkg-query -W -f='${Package} ${Status}\n' tmux vim nodejs bash-completion zoxide tealdeer 2>/dev/null | awk '/install ok installed/ {print $1}' | tr '\n' ' ')"
hay_tldr=0; apt-cache policy tealdeer 2>/dev/null | grep 'Candidate: [^(]' >/dev/null && hay_tldr=1

upstream
mkuser "$U"; H=/home/$U
bashfiles() { (cd "$H" && sha256sum .bashrc .profile .bash_logout .bash_profile 2>/dev/null); }
b0="$(bashfiles)"
clonar "$U"

if [ -n "$DESDE" ]; then
    paso "lo que ya tenía: $DESDE + ./install tmux zsh vim"
    as "$U" "git -C $D reset -q --hard $DESDE"
    out="$(as "$U" "cd $D && ./install tmux zsh vim")"; r=$?
    check "install de $DESDE" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
    has "Missing key" "$out" && echo "      (sale el aviso de la clave de gh y sigue)"
    paso "actualizar: git pull && ./actualizar"
    out="$(as "$U" "cd $D && git pull && ./actualizar")"; r=$?; inst="$out"
    echo "$out" | grep -E '^==> (instalados|---)|quitado el enlace|AVISO|ERROR' | sangra ""
    check "git pull && ./actualizar" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
    check "queda en lo último de main" [ "$(as "$U" "git -C $D rev-parse HEAD")" = "$(git -C /srv/src rev-parse HEAD)" ]
else
    paso "./install tmux zsh vim"
    out="$(as "$U" "cd $D && ./install tmux zsh vim")"; r=$?; inst="$out"
    echo "$out" | grep -E 'AVISO|ERROR' | sangra ""
    check "install" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
    paso "./actualizar"
    out="$(as "$U" "cd $D && ./actualizar")"; r=$?
    check "actualizar" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
fi
check "actualizar detecta tmux zsh vim" has "instalados: tmux zsh vim" "$out"
check "sin enlaces de la versión anterior" bash -c "[ ! -L $H/.zshrc ] && [ ! -L $H/.vimrc ] && [ ! -L $H/.config/nvim/init.lua ] && [ ! -L $H/.local/bin/nvim ]"

paso "pane nuevo de tmux"
cat > "$H/probe" <<'P'
{ echo "shell=${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}"; command -v vim; vim --version | head -1; echo "EDITOR=$EDITOR"
  cd ~/GitHub/personal/tmux-config; cd /; z tmux-config >/dev/null 2>&1; echo "z=$PWD"; } > ~/pane.txt 2>&1
P
w=$(espera 3 10)
as "$U" "tmux new-session -d -s p -x 120 -y 30; sleep $w; tmux send-keys -t p '. ~/probe' Enter; sleep $w; tmux kill-server" >/dev/null
p="$(cat "$H/pane.txt" 2>/dev/null)"; sangra "pane: " <<<"$p"
check "el pane arranca zsh" has "shell=zsh" "$p"
check "vim en tmux es el neovim del repo" bash -c "grep -q '$H/.local/opt/tmux-config/bin/vim' <<<\"\$1\" && grep -q 'NVIM v' <<<\"\$1\"" _ "$p"
check "EDITOR en tmux es ese neovim" has "EDITOR=$H/.local/opt/tmux-config/bin/nvim" "$p"
check "z salta a una carpeta ya visitada" has "z=$H/GitHub/personal/tmux-config" "$p"
f="$(su - "$U" -c 'bash -ic "command -v vim nvim; type z; echo EDITOR=\$EDITOR"' 2>&1)"; grep -v '^bash:'<<<"$f" | sangra "fuera: "
check "fuera de tmux nada del repo (ni vim, ni EDITOR, ni z)" bash -c "! grep -q tmux-config <<<\"\$1\" && ! grep -q 'z is' <<<\"\$1\"" _ "$f"

paso "tldr"
if [ $hay_tldr -eq 1 ]; then
    t="$(as "$U" 'tldr tar')"; r=$?
    check "tldr tar enseña ejemplos" bash -c "[ $r -eq 0 ] && grep -q 'tar' <<<\"\$1\" && [ \$(wc -l <<<\"\$1\") -gt 5 ]" _ "$t"
else
    check "sin tealdeer en los repos: avisa y sigue" has "no están en los repos activos: tealdeer" "$inst"
fi

paso ".py en neovim"
cat > "$H/check.lua" <<L
vim.defer_fn(function()
  local n = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do n[#n + 1] = c.name end
  local hl = (vim.b.current_syntax or '') ~= '' or vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil
  io.stdout:write(('ft=%s resaltado=%s lsp=%s\n'):format(vim.bo.filetype, tostring(hl), table.concat(n, ',')))
  vim.cmd('qa!')
end, $(espera 15000 90000))
L
printf 'import os\nprint(os.getcwd())\n' > "$H/prueba.py"; chown "$U:" "$H/prueba.py" "$H/check.lua"
py="$(as "$U" 'cd ~ && NVIM_APPNAME=tmux-config-nvim ~/.local/opt/tmux-config/bin/nvim --headless prueba.py -c "luafile ~/check.lua"' | tr -d '\r' | grep 'ft=')"
echo "      .py: $py"
check ".py: python con resaltado" has "ft=python resaltado=true" "$py"
node_m="$(node -v 2>/dev/null | sed 's/^v//; s/\..*//')"
if [ "${node_m:-0}" -ge 18 ]; then check ".py: pyright conectado" has "pyright" "$py"
else check ".py: sin node 18 no hay pyright, y lo avisa" has "sin node >= 18" "$inst"; fi
check "bash sin tocar tras instalar" [ "$(bashfiles)" = "$b0" ]

paso "uninstall vim zsh tmux"
for c in vim zsh tmux; do
    out="$(printf 's\nY\n' | as "$U" "cd $D && ./uninstall $c")"; r=$?
    check "uninstall $c" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -15
    [ "$c" = tmux ] && out_tmux="$out"
done
check "sin restos en ~/.local/opt/tmux-config" bash -c "[ -z \"\$(find $H/.local/opt/tmux-config -not -type d 2>/dev/null)\" ]"
check "sin ~/.tmux.conf ni config de neovim del repo" bash -c "[ ! -L $H/.tmux.conf ] && [ ! -e $H/.config/tmux-config-nvim/init.lua ]"
for pk in $antes; do
    check "conserva $pk, que ya estaba" bash -c "dpkg-query -W -f='\${Status}' $pk 2>/dev/null | grep -q 'install ok installed'"
done
for pk in zoxide tealdeer; do
    [[ " $antes " == *" $pk "* ]] && continue
    check "quita $pk, que instaló él" bash -c "! dpkg-query -W -f='\${Status}' $pk 2>/dev/null | grep -q 'install ok installed'"
done
# tmux: lo quita si lo instaló ./install tmux. Si lo instaló una versión
# anterior (DESDE), que no lo apuntaba, se queda y dice cómo quitarlo
if [[ " $antes " != *" tmux "* ]]; then
    if [ -z "$DESDE" ]; then
        check "quita tmux, que instaló él" bash -c "! dpkg-query -W -f='\${Status}' tmux 2>/dev/null | grep -q 'install ok installed'"
    elif dpkg-query -W -f='${Status}' tmux 2>/dev/null | grep 'install ok installed' >/dev/null; then
        check "tmux de una versión anterior: se queda y dice cómo quitarlo" has "purge tmux" "$out_tmux"
    fi
fi
check "sin páginas de tldr" [ ! -e "$H/.cache/tealdeer" ]
[ "$PERFIL" = pi-trixie ] && check "conserva el npm de NodeSource" bash -c "command -v npm >/dev/null"
check "bash sin tocar tras desinstalar" [ "$(bashfiles)" = "$b0" ]
fin
