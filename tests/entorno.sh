#!/usr/bin/env bash
# shellcheck disable=SC2016  # comillas simples: se expanden dentro de "su -c"
# tests/entorno.sh — una máquina de punta a punta, dentro del contenedor.
#
#   PERFIL=pi-trixie|pi-bookworm|ubuntu-server|ubuntu-2204|migracion
#   DESDE=<commit>   instala esa versión y luego "git pull && ./actualizar",
#                    como quien ya lo tenía; vacío: instalación nueva
#
# Comprueba: install/actualizar, que un paquete que choca con uno del repo
# BLOQUEA y no se quita, un pane nuevo de tmux (zsh, vim = neovim del repo, z),
# fuera de tmux nada del repo, Alt+d (buscar en todo el disco) con fd y bat, un .py en neovim (resaltado, pyright), los
# servidores LSP en la versión del registro fijado, que sudoedit no deja su
# historial de deshacer en el HOME, tldr, que bash no se toca, --global (zsh de
# login y neovim en ~/.bashrc, también fuera de tmux, con Alt+h; el aviso de lo
# de ~/.bashrc que zsh no leerá, "ssh host comando" como bash, el ~/.zshenv de
# antes que se migra y el repo movido) y --solo-tmux, que lo
# deja como estaba, y que uninstall no deja nada, deshace --global, respeta lo
# que ya había y no cierra un tmux abierto.
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
    # En español, como las máquinas de verdad: apt cambia su salida ("Candidato:").
    # La imagen no instala traducciones: se quita su exclusión y se reinstala apt
    ubuntu-2204)
        rm -f /etc/dpkg/dpkg.cfg.d/excludes
        apt-get -yqq install locales >/dev/null 2>&1 && apt-get -yqq install --reinstall apt >/dev/null 2>&1
        locale-gen es_ES.UTF-8 >/dev/null && update-locale LANG=es_ES.UTF-8
        U=u ;;
    *)             U=u ;;
esac
. /etc/os-release
echo "=== $PERFIL: $PRETTY_NAME ($(uname -m)), usuario $U${DESDE:+, desde $DESDE}"
echo "    node $(node -v 2>/dev/null || echo -) · npm $(npm -v 2>/dev/null || echo -) · tmux previo: $(command -v tmux || echo -) · vim previo: $(command -v vim || echo -)"
# Lo que ya estaba: uninstall no lo quita
antes="$(dpkg-query -W -f='${Package} ${Status}\n' tmux vim nodejs bash-completion zoxide tealdeer fd-find bat ncdu 2>/dev/null | awk '/install ok installed/ {print $1}' | tr '\n' ' ')"
hay_tldr=0; LC_ALL=C apt-cache policy tealdeer 2>/dev/null | grep 'Candidate: [^(]' >/dev/null && hay_tldr=1

upstream
mkuser "$U"; H=/home/$U
[ "$PERFIL" = ubuntu-2204 ] && check "el usuario tiene apt en español" has "Candidato:" "$(as "$U" 'apt-cache policy tmux')"
bashfiles() { (cd "$H" && sha256sum .bashrc .profile .bash_logout .bash_profile 2>/dev/null); }
b0="$(bashfiles)"
clonar "$U"

if [ -n "$DESDE" ]; then
    paso "lo que ya tenía: $DESDE + ./install tmux zsh vim"
    as "$U" "git -C $D reset -q --hard $DESDE"
    # Sin terminal, las versiones con plan piden -y; las anteriores no lo entienden
    y=""; grep -q -- '--yes' "$H/GitHub/personal/tmux-config/install" && y="-y "
    out="$(as "$U" "cd $D && ./install ${y}tmux zsh vim")"; r=$?
    check "install de $DESDE" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
    has "Missing key" "$out" && echo "      (sale el aviso de la clave de gh y sigue)"
    paso "actualizar: git pull && ./actualizar -y"
    out="$(as "$U" "cd $D && git pull && ./actualizar -y")"; r=$?; inst="$out"
    echo "$out" | grep -E '^==> (instalados|---)|quitado el enlace|AVISO|ERROR' | sangra ""
    check "git pull && ./actualizar" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
    check "queda en lo último de main" [ "$(as "$U" "git -C $D rev-parse HEAD")" = "$(git -C /srv/src rev-parse HEAD)" ]
else
    # Un paquete tuyo que choca con uno del repo: apt-get -y lo quitaría sin
    # preguntar. El plan lo para (BLOQUEA) y no se toca
    paso "un paquete que choca con zsh"
    mkdir -p /tmp/choca/DEBIAN
    printf 'Package: choca-con-zsh\nVersion: 1.0\nArchitecture: all\nMaintainer: t <t@t>\nConflicts: zsh\nDescription: prueba\n' > /tmp/choca/DEBIAN/control
    dpkg-deb -b /tmp/choca /tmp/choca.deb >/dev/null && dpkg -i /tmp/choca.deb >/dev/null
    out="$(as "$U" "cd $D && ./install --check zsh")"; r=$?
    echo "$out" | grep -A1 'BLOQUEA' | sangra ""
    check "--check: BLOQUEA, apt quitaría choca-con-zsh" bash -c "[ $r -ne 0 ] && grep -q 'BLOQUEA *quitaría choca-con-zsh' <<<\"\$1\"" _ "$out"
    out="$(as "$U" "cd $D && ./install -y zsh")"; r=$?
    check "-y: no instala nada y choca-con-zsh sigue" bash -c "[ $r -ne 0 ] && dpkg-query -W -f='\${Status}' choca-con-zsh | grep -q 'install ok installed' && ! dpkg-query -W -f='\${Status}' zsh 2>/dev/null | grep -q 'install ok installed'"
    dpkg --purge choca-con-zsh >/dev/null
    # Lo que cambia el sistema, para ver que --check y un install cancelado no lo tocan
    sistema() { dpkg-query -W -f='${Package} ${Status}\n' | sort; ls -A "$H"; }
    s0="$(sistema)"
    paso "./install --check tmux zsh vim"
    out="$(as "$U" "cd $D && ./install --check tmux zsh vim")"; r=$?
    echo "$out" | grep -E '^  (instalar|sin|BLOQUEA|backup)|^ {13}arreglo|^==> (sin --check|AVISO)' | sangra ""
    check "--check termina bien" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
    check "--check no usa sudo ni toca nada" bash -c "[ \"\$1\" = \"\$2\" ] && ! grep -q 'apt-get update' <<<\"\$3\"" _ "$s0" "$(sistema)" "$out"
    paso "./install sin terminal y sin -y"
    out="$(as "$U" "cd $D && ./install tmux zsh vim")"; r=$?
    check "no pregunta: falla, pide -y y no toca nada (ni sudo)" bash -c "[ $r -ne 0 ] && grep -q 'repite con -y' <<<\"\$1\" && ! grep -q 'apt-get update:' <<<\"\$1\" && [ \"\$2\" = \"\$3\" ]" _ "$out" "$s0" "$(sistema)"
    paso "./install -y tmux zsh vim"
    out="$(as "$U" "cd $D && ./install -y tmux zsh vim")"; r=$?; inst="$out"
    echo "$out" | grep -E 'AVISO|ERROR|^==> resumen' | sangra ""
    check "install" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
    paso "./actualizar"
    out="$(as "$U" "cd $D && ./actualizar")"; r=$?
    check "actualizar" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
    # tealdeer y nodejs, si los repos no los dan, siguen faltando: no por eso sudo
    check "repetir no pide sudo (ni apt-get update)" bash -c "grep -q 'nada que confirmar' <<<\"\$1\" && ! grep -q 'apt-get update' <<<\"\$1\"" _ "$out"
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

# Alt+d en un pane de verdad: "echo ", Alt+d, buscar un fichero, Enter cuando
# fzf lo enseña (escribe su ruta en la línea) y ejecutarlo. Y lo que encuentra,
# con fd y sin él (find): todo el disco, con los ocultos, sin /proc, /sys, /dev,
# /run, /snap ni _tc_ruido
paso "zsh: Alt+d, fd, bat, Ctrl+X Ctrl+E y Alt+Supr"
mkdir -p "$H/proyecto/node_modules/x" "$H/proyecto/.git" "$H/proyecto/__pycache__" "$H/proyecto/.cache"
touch "$H/proyecto/aguja-unica.txt" "$H/proyecto/.env" "$H/proyecto/node_modules/x/aguja-unica-ruido" "$H/proyecto/.git/aguja-unica-git" \
      "$H/proyecto/__pycache__/aguja-unica-pyc" "$H/proyecto/.cache/aguja-unica-cache"
cat > "$H/probe2" <<'P'
{ bindkey '^[d'; bindkey '^X^E'; bindkey '^[[3;3~'; bindkey '^[[3;5~'; echo "ctrlt=$FZF_CTRL_T_COMMAND"; echo "bat=$_tc_bat"; } > ~/teclas.txt 2>&1
_tc_rutas > ~/rutas-fd.txt 2>&1
( _tc_fd=; _tc_rutas ) > ~/rutas-find.txt 2>&1
: > ~/probe2.ok
P
chown -R "$U:" "$H/proyecto" "$H/probe2"
# espera_a CONDICIÓN: hasta 3 min (bajo QEMU, recorrer el disco tarda)
espera_a='for i in $(seq 180); do eval "$1" && break; sleep 1; done'
as "$U" "esp() { $espera_a; }
         tmux new-session -d -s b -x 150 -y 40; sleep $w; tmux send-keys -t b '. ~/probe2' Enter; esp '[ -e ~/probe2.ok ]'
         tmux send-keys -t b 'echo ' M-d; sleep $w; tmux send-keys -t b -l \"'aguja-unica\"
         esp 'tmux capture-pane -p -t b | grep -q proyecto/aguja-unica.txt'; tmux send-keys -t b Enter; sleep $w
         tmux send-keys -t b -l ' > ~/alt-d.txt'; tmux send-keys -t b Enter; esp '[ -s ~/alt-d.txt ]'; tmux kill-server" >/dev/null
k="$(cat "$H/teclas.txt" 2>/dev/null)"; sangra "pane: " <<<"$k"
check "Alt+d, Ctrl+X Ctrl+E y Alt+Supr / Ctrl+Supr puestos" bash -c "grep -qF '\"^[d\" _tc_buscar_todo' <<<\"\$1\" && grep -qF '\"^X^E\" edit-command-line' <<<\"\$1\" && grep -qF '\"^[[3;3~\" kill-word' <<<\"\$1\" && grep -qF '\"^[[3;5~\" kill-word' <<<\"\$1\"" _ "$k"
check "Ctrl+T busca con fd, con vista previa de bat" bash -c "grep -q '^ctrlt=/usr/bin/fdfind ' <<<\"\$1\" && grep -q '^bat=/usr/bin/batcat' <<<\"\$1\"" _ "$k"
for b in fd find; do
    r="$H/rutas-$b.txt"; echo "      Alt+d con $b: $(wc -l < "$r") rutas"
    check "Alt+d con $b: todo el disco, con los ocultos" bash -c "grep -qx /etc/passwd '$r' && grep -qx '$H/proyecto/.env' '$r' && grep -qx '$H/proyecto/aguja-unica.txt' '$r'"
    check "Alt+d con $b: sin /proc, /sys, /dev, /run, /snap ni .git, node_modules, __pycache__ o .cache" \
        bash -c "! grep -qE '^/(proc|sys|dev|run|snap)(/|\$)|/(\.git|node_modules|__pycache__|\.cache)(/|\$)' '$r'"
done
check "Alt+d escribe la ruta completa en la línea" [ "$(cat "$H/alt-d.txt" 2>/dev/null)" = "$H/proyecto/aguja-unica.txt" ]

paso "tldr"
if [ $hay_tldr -eq 1 ]; then
    t="$(as "$U" 'tldr tar')"; r=$?
    check "tldr tar enseña ejemplos" bash -c "[ $r -eq 0 ] && grep -q 'tar' <<<\"\$1\" && [ \$(wc -l <<<\"\$1\") -gt 5 ]" _ "$t"
else
    check "sin tealdeer en los repos: lo dice el plan, y el resumen" bash -c "[ \$(grep -c 'tealdeer: no está en los repos activos' <<<\"\$1\") -eq 2 ]" _ "$inst"
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
# Ubuntu 22.04: sus repos traen node 12, que no vale para los servidores LSP
if [ "$PERFIL" = ubuntu-2204 ]; then
    check "node 12 de los repos: ni nodejs ni npm, y sugiere NodeSource" bash -c \
        "! dpkg-query -W -f='\${Status}' nodejs npm 2>/dev/null | grep -q 'install ok installed' && grep -q 'nodejs: los repos tienen la 12' <<<\"\$1\" && grep -q 'arreglo: curl -fsSL https://deb.nodesource.com' <<<\"\$1\"" _ "$inst"
    # El arreglo que sugiere: su nodejs trae npm dentro y choca con el de la distro
    paso "el arreglo del plan: NodeSource y ./install -y vim"
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
    out="$(as "$U" "cd $D && ./install -y vim")"; r=$?
    echo "$out" | grep -E '^  instalar|ERROR' | sangra ""
    check "nodejs de NodeSource con su npm, sin el npm de la distro" bash -c \
        "[ $r -eq 0 ] && grep -q 'npm (viene con nodejs)' <<<\"\$1\" && [ \"\$(node -v | sed 's/^v//; s/\\..*//')\" -ge 18 ] && command -v npm >/dev/null && ! dpkg-query -W -f='\${Status}' npm 2>/dev/null | grep -q 'install ok installed'" _ "$out"
    [ $r -eq 0 ] || echo "$out" | tail -20
fi

# Los servidores LSP, en la versión del registro fijado en plugins.lua: uno en
# otra versión (lo instaló otro registro) vuelve a ella con ./install vim
paso "servidores LSP en la versión del registro fijado"
fijado="$(grep -o "mason-registry@[^']*" "$H/GitHub/personal/tmux-config/nvim/lua/tc/plugins.lua" | cut -d@ -f2)"
mason="$H/.local/share/tmux-config-nvim/tmux-config/mason"
check "registro de mason: el fijado (${fijado:-ninguno})" grep -q "\"version\":\"$fijado\"" "$mason/registries/github/mason-org/mason-registry/info.json"
rec="$mason/packages/marksman/mason-receipt.json"
v="$(grep -o 'marksman@[^"]*' "$rec" | head -1 | cut -d@ -f2)"
sed -i "s/marksman@$v/marksman@0.0.1/g" "$rec"
out="$(as "$U" "cd $D && ./install -y vim")"; r=$?
grep 'marksman' <<<"$out" | sangra ""
check "marksman en otra versión vuelve a la del registro ($v)" bash -c "[ $r -eq 0 ] && grep -q 'cambiando de versión servidor LSP: marksman $v' <<<\"\$1\" && grep -q 'marksman@$v' '$rec'" _ "$out"

# sudoedit edita una copia del fichero de root en /var/tmp: su historial de
# deshacer no debe quedarse en el HOME (el de un fichero normal, sí)
paso "deshacer y sudoedit"
printf '#!/bin/sh\nexec env NVIM_APPNAME=tmux-config-nvim %s/.local/opt/tmux-config/bin/nvim --headless "$@" -c "normal! Gonuevo" -c wq\n' "$H" > "$H/editor"
chmod +x "$H/editor"; echo secreto > /etc/tc-secreto; chmod 600 /etc/tc-secreto
as "$U" 'SUDO_EDITOR=~/editor sudoedit /etc/tc-secreto; ~/editor ~/tc-control.txt' >/dev/null
und="$H/.local/state/tmux-config-nvim/undo"
check "sudoedit con el neovim del repo edita el fichero" grep -q nuevo /etc/tc-secreto
check "deshacer: se guarda el de un fichero normal" bash -c "ls '$und' | grep -q tc-control"
check "deshacer: no se guarda el de sudoedit" bash -c "! ls '$und' | grep -q '^%var%tmp%'"

check "bash sin tocar tras instalar" [ "$(bashfiles)" = "$b0" ]

# --global: zsh pasa a ser la shell de login y neovim entra en ~/.bashrc, así que
# fuera de tmux todo queda como dentro. --solo-tmux lo deshace: vuelve la shell
# de antes y ~/.bashrc queda como estaba
paso "./install -y --global zsh vim"
shell_de() { getent passwd "$U" | cut -d: -f7; }
sh0="$(shell_de)"
st="$H/.local/state/tmux-config"
# Lo que bash lee al entrar (/etc/profile.d): el zsh de login también debe verlo
echo 'export TC_PERFIL_D=si' > /etc/profile.d/tc-prueba.sh
# Lo tuyo en ~/.bashrc, que zsh no leerá: el plan lo avisa, sin valores (un
# secreto), sin lo que trae /etc/skel ni lo que ya está en ~/.zshrc.local
cat >> "$H/.bashrc" <<'B'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
export TC_SECRETO=valor-que-no-debe-salir
alias gs='git status'
B
echo "alias gs='git status'" > "$H/.zshrc.local"; chown "$U:" "$H/.zshrc.local"
b0="$(bashfiles)"
out="$(as "$U" "cd $D && ./install -y --global zsh vim")"; r=$?
echo "$out" | grep -E '^  (cambiar|aviso)|^ {13}~/|AVISO|ERROR' | sangra ""
check "install --global" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
check "el plan dice lo que cambia fuera de tmux" bash -c "grep -q '^  cambiar *tu shell de login: $sh0 → zsh' <<<\"\$1\" && grep -q '^  cambiar *~/.bashrc: un bloque' <<<\"\$1\"" _ "$out"
check "el plan avisa de lo de ~/.bashrc que zsh no leerá, sin valores" bash -c "grep -q 'zsh no leerá esto' <<<\"\$1\" && grep -qE '~/.bashrc:[0-9]+  export NVM_DIR' <<<\"\$1\" && grep -q 'carga \$NVM_DIR/nvm.sh' <<<\"\$1\" && grep -q 'export TC_SECRETO' <<<\"\$1\" && ! grep -qE 'valor-que-no-debe-salir|alias gs|HISTCONTROL' <<<\"\$1\"" _ "$out"
check "la shell de login es zsh" bash -c "[[ \$(getent passwd $U | cut -d: -f7) == */zsh ]]"
check "~/.zshenv es un fichero (no un enlace al repo) que carga zsh/zshenv" bash -c "[ -f $H/.zshenv ] && [ ! -L $H/.zshenv ] && head -1 $H/.zshenv | grep -qx '# ~/.zshenv de tmux-config' && [ \"\$(readlink $H/.local/opt/tmux-config/zsh/zshenv)\" = $H/GitHub/personal/tmux-config/zsh/zshenv ]"
# Lo que se añade debajo de ~/.zshenv (rustup lo hace) se conserva al reinstalar
echo 'export TC_DEBAJO=si' >> "$H/.zshenv"
out="$(as "$U" "cd $D && ./install -y zsh")"; r=$?
check "lo añadido debajo de ~/.zshenv se conserva al reinstalar, y zsh lo lee" bash -c "[ $r -eq 0 ] && tail -1 $H/.zshenv | grep -qx 'export TC_DEBAJO=si' && [ \"\$(su - $U -c 'echo \$TC_DEBAJO')\" = si ]"
# "ssh host comando" (zsh -c sin login, como lo lanza sshd): como bash, un * sin
# coincidencias pasa tal cual, y ~/bin en el PATH
mkdir -p "$H/bin"; chown "$U:" "$H/bin"
f="$(cd / && su "$U" -c 'echo /tmp/noexiste-*; echo "path=$PATH"' 2>&1)"; sangra "ssh comando: " <<<"${f:0:300}"
check "\"ssh host comando\": un * sin coincidencias pasa tal cual, y ~/bin en el PATH" bash -c "grep -qx '/tmp/noexiste-\*' <<<\"\$1\" && grep -q 'path=\(.*:\)\?$H/bin:' <<<\"\$1\"" _ "$f"
# Como al entrar por SSH: la shell de login, interactiva, fuera de tmux
f="$(su - "$U" -c 'exec $SHELL -lic "echo shell=\${ZSH_VERSION:+zsh}; command -v vim; echo EDITOR=\$EDITOR; type z; echo perfil=\$TC_PERFIL_D"' 2>&1)"; sangra "fuera: " <<<"$f"
check "fuera de tmux, zsh con la config del repo (vim, EDITOR y z)" bash -c "grep -q shell=zsh <<<\"\$1\" && grep -q '$H/.local/opt/tmux-config/bin/vim' <<<\"\$1\" && grep -q 'EDITOR=$H/.local/opt/tmux-config/bin/nvim' <<<\"\$1\" && grep -q 'z is' <<<\"\$1\"" _ "$f"
check "el zsh de login lee /etc/profile.d, como bash" has "perfil=si" "$f"
# Alt+h fuera de tmux, en un terminal que no se queda la tecla (un tmux sin config
# y sin TMUX en el pane): abre la guía, y q vuelve a lo que estabas escribiendo
as "$U" "esp() { $espera_a; }
         tmux -L fuera -f /dev/null new-session -d -s f -x 100 -y 30 'env -u TMUX \$SHELL -l'; sleep $w
         tmux -L fuera send-keys -t f -l 'echo hola'; tmux -L fuera send-keys -t f M-h
         esp 'tmux -L fuera capture-pane -p -t f | grep -q \"Mapa de atajos\"' && tmux -L fuera capture-pane -p -t f > ~/alt-h.txt
         tmux -L fuera send-keys -t f q; sleep $w; tmux -L fuera send-keys -t f -l ' > ~/alt-h-linea.txt'; tmux -L fuera send-keys -t f Enter
         esp '[ -s ~/alt-h-linea.txt ]'; tmux -L fuera kill-server" >/dev/null
check "fuera de tmux, Alt+h abre la guía y q vuelve a la línea" bash -c "grep -q '^# Mapa de atajos tmux' $H/alt-h.txt && [ \"\$(cat $H/alt-h-linea.txt 2>/dev/null)\" = hola ]"
f="$(su - "$U" -c 'bash -ic "command -v vim; echo EDITOR=\$EDITOR"' 2>&1)"
check "fuera de tmux, en bash, vim y EDITOR son el neovim del repo" bash -c "grep -q '$H/.local/opt/tmux-config/bin/vim' <<<\"\$1\" && grep -q 'EDITOR=$H/.local/opt/tmux-config/bin/nvim' <<<\"\$1\"" _ "$f"
check "\"ssh host comando\" no saca nada más" [ "$(su - "$U" -c 'echo hola' 2>&1)" = hola ]
# Como quien lo tenía de antes: ~/.zshenv, un enlace al repo. ./actualizar lo
# cambia por el fichero, sin preguntar
as "$U" "ln -sfn $D/zsh/zshenv ~/.zshenv" >/dev/null
out="$(as "$U" "cd $D && ./actualizar -y")"; r=$?
check "./actualizar lo mantiene sin preguntar ni cambiar nada" bash -c "[ $r -eq 0 ] && grep -q 'nada que confirmar' <<<\"\$1\" && [[ \$(getent passwd $U | cut -d: -f7) == */zsh ]] && [ \$(grep -c '^# >>> tmux-config' $H/.bashrc) -eq 1 ]" _ "$out"
check "y cambia el ~/.zshenv de antes (enlace) por el fichero" bash -c "[ -f $H/.zshenv ] && [ ! -L $H/.zshenv ] && ! ls $H/.zshenv.bak.* >/dev/null 2>&1"
# Repo movido: al entrar, zsh lo avisa en vez de abrir el asistente de usuario
# nuevo (y sin config), y "ssh host comando" sigue limpio
mv "$H/GitHub/personal/tmux-config" "$H/GitHub/personal/tmux-config.movido"
check "repo movido: \"ssh host comando\" sigue limpio" [ "$(su - "$U" -c 'echo hola' 2>&1)" = hola ]
as "$U" "tmux -L movido -f /dev/null new-session -d -s m -x 150 -y 20 'env -u TMUX \$SHELL -l'; sleep $w
         tmux -L movido capture-pane -p -t m > ~/movido.txt; tmux -L movido kill-server" >/dev/null
sangra "al entrar: " < <(grep -v '^$' "$H/movido.txt")
check "repo movido: al entrar lo avisa, sin el asistente de zsh" bash -c "grep -q 'no encuentro la config de zsh' $H/movido.txt && ! grep -q 'Z Shell' $H/movido.txt"
mv "$H/GitHub/personal/tmux-config.movido" "$H/GitHub/personal/tmux-config"

paso "./install -y --solo-tmux zsh vim"
echo 'export TC_DEBAJO=si' >> "$H/.zshenv"   # lo de debajo se queda; lo demás, fuera
out="$(as "$U" "cd $D && ./install -y --solo-tmux zsh vim")"; r=$?
echo "$out" | grep -E '^  cambiar|AVISO|ERROR' | sangra ""
check "install --solo-tmux" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -30
check "vuelve la shell de login de antes ($sh0)" [ "$(shell_de)" = "$sh0" ]
check "de ~/.zshenv queda solo lo añadido debajo, y bash como estaba" bash -c "[ \"\$(cat $H/.zshenv)\" = 'export TC_DEBAJO=si' ] && [ ! -L $H/.zshenv ] && [ \"\$1\" = \"\$2\" ]" _ "$(bashfiles)" "$b0"
rm -f "$H/.zshenv"
f="$(su - "$U" -c 'bash -ic "command -v vim nvim; type z; echo EDITOR=\$EDITOR"' 2>&1)"
check "fuera de tmux, otra vez nada del repo" bash -c "! grep -q tmux-config <<<\"\$1\" && ! grep -q 'z is' <<<\"\$1\"" _ "$f"
check "sin marcas de --global" bash -c "[ ! -e $st/zsh.global ] && [ ! -e $st/vim.global ] && [ ! -e $st/bashrc.antes ]"
rm -f /etc/profile.d/tc-prueba.sh
# Otra vez --global, para ver que ./uninstall también lo deshace
out="$(as "$U" "cd $D && ./install -y --global zsh vim")"; r=$?
check "otra vez --global, para el uninstall" bash -c "[ $r -eq 0 ] && [[ \$(getent passwd $U | cut -d: -f7) == */zsh ]] && grep -q '^# >>> tmux-config' $H/.bashrc"

paso "uninstall vim zsh tmux, con un tmux abierto"
# Con una sesión abierta, como en un servidor con trabajos dentro: no se cierra
as "$U" 'tmux new-session -d -s abierta' >/dev/null
tpid="$(as "$U" 'tmux display -p "#{pid}"')"
for c in vim zsh tmux; do
    out="$(printf 's\nY\n' | as "$U" "cd $D && ./uninstall $c")"; r=$?
    check "uninstall $c" [ $r -eq 0 ]; [ $r -eq 0 ] || echo "$out" | tail -15
    [ "$c" = tmux ] && out_tmux="$out"
done
check "uninstall tmux no cierra el tmux abierto, y lo dice" bash -c "kill -0 '$tpid' && grep -q 'siguen abiertos' <<<\"\$1\"" _ "$out_tmux"
kill "$tpid" 2>/dev/null
check "sin restos en ~/.local/opt/tmux-config" bash -c "[ -z \"\$(find $H/.local/opt/tmux-config -not -type d 2>/dev/null)\" ]"
check "sin ~/.tmux.conf ni config de neovim del repo" bash -c "[ ! -L $H/.tmux.conf ] && [ ! -e $H/.config/tmux-config-nvim/init.lua ]"
for pk in $antes; do
    check "conserva $pk, que ya estaba" bash -c "dpkg-query -W -f='\${Status}' $pk 2>/dev/null | grep -q 'install ok installed'"
done
for pk in zoxide tealdeer fd-find bat ncdu; do
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
check "uninstall deshace --global: la shell de antes, sin ~/.zshenv ni marcas" bash -c "[ \"\$(getent passwd $U | cut -d: -f7)\" = '$sh0' ] && [ ! -e $H/.zshenv ] && [ ! -L $H/.zshenv ] && [ ! -e $st/zsh.global ] && [ ! -e $st/vim.global ] && [ ! -e $st/bashrc.antes ]"
# zsh, que instaló él: se va con la shell de login devuelta (si no, se quedaría)
[ -n "$DESDE" ] || check "quita zsh, que instaló él" bash -c "! dpkg-query -W -f='\${Status}' zsh 2>/dev/null | grep -q 'install ok installed'"
[ "$PERFIL" = pi-trixie ] && check "conserva el npm de NodeSource" bash -c "command -v npm >/dev/null"
check "bash sin tocar tras desinstalar" [ "$(bashfiles)" = "$b0" ]
fin
