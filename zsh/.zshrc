# =============================================================================
# zsh — configuración personal
#
# Requiere zsh >= 5.8 (probada en 5.8, 5.8.1 y 5.9). Se instala con ./install zsh.
# zsh arranca en los panes de tmux (.tmux.conf lo detecta) con
# ZDOTDIR=~/.local/opt/tmux-config/zsh, donde está enlazado este fichero. Fuera
# de tmux, en "ssh host comando", como root y para los demás usuarios, todo
# sigue en bash, y "zsh" tecleado fuera no carga esta config; salvo con
# ./install zsh --global: zsh pasa a ser tu shell de login y ~/.zshenv
# (zsh/zshenv) le pone el mismo ZDOTDIR.
#
# Probar cambios sin tocar la config instalada:
#   ZDOTDIR="$PWD/zsh" zsh
#
# Lo propio de cada máquina (alias, PATH, variables) va en ~/.zshrc.local,
# que se carga al final y no está en el repo.
# =============================================================================

# --- Historial ---------------------------------------------------------------

HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt share_history        # lo escrito en un pane aparece en los demás (Ctrl+R, flechas)
setopt hist_ignore_dups     # no guardar el mismo comando dos veces seguidas
setopt hist_ignore_space    # empezar con un espacio = no se guarda (tokens, contraseñas)
setopt hist_reduce_blanks

# --- Comportamiento de bash al pegar comandos --------------------------------
#
# Para que los comandos y runbooks pensados para bash funcionen igual al pegarlos.

setopt interactive_comments # admitir "# comentario" en la línea (zsh lo rechaza por defecto)
unsetopt nomatch            # un * o ? sin coincidencias se pasa tal cual (URLs con ?)
unsetopt beep

# --- Teclado: emacs, como bash -------------------------------------------------
#
# Sin esto, zsh elige el modo vi si $EDITOR o $VISUAL contienen "vi". Alt+b/f/.
# hacen lo mismo que en bash, y Alt+d busca en todo el disco (en "Plugins"): por
# eso tmux no los usa.

bindkey -e
bindkey '^U' backward-kill-line          # como bash: borrar hasta el principio
bindkey '^[[H' beginning-of-line         # Inicio / Fin: zsh no las trae para todos
bindkey '^[[F' end-of-line               # los terminales (sin esto escriben ~)
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char              # Supr
bindkey '^[[3;3~' kill-word              # Alt+Supr / Ctrl+Supr: borrar la palabra de
bindkey '^[[3;5~' kill-word              # delante (sin esto escriben 3~ o 5~)
bindkey '^[[1;5D' backward-word          # Ctrl+← / Ctrl+→
bindkey '^[[1;5C' forward-word

# Flechas ↑ ↓: historial filtrado por lo ya escrito ("git" + ↑ = último git)
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# Ctrl+X Ctrl+E: el comando que estás escribiendo, en el editor ($EDITOR); al
# guardar y salir vuelve a la línea, sin ejecutarse (bash sí lo ejecuta)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Alt+h y tmux-guia: el mapa de atajos y la guía (bin/tmux-guia del repo de este
# fichero), también fuera de tmux con zsh global. Dentro de tmux, Alt+h la abre
# tmux en una ventana flotante y no llega aquí. Quita run-help (el man del comando)
_tc_guia=${${(%):-%x}:A:h:h}/bin/tmux-guia
alias tmux-guia=${(q)_tc_guia}
_tc_ver_guia() { $_tc_guia </dev/tty; zle reset-prompt }
zle -N _tc_ver_guia
bindkey '^[h' _tc_ver_guia

# --- Completado (Tab) ----------------------------------------------------------

# En Debian/Ubuntu /etc/zsh/zshrc ya lo inicializa: hacerlo dos veces solo retrasa
# el arranque. -i: sin preguntar si hay directorios inseguros (pasa con sudo -s).
if (( ! $+functions[compdef] )); then
    autoload -Uz compinit
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
    compinit -i -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump-$ZSH_VERSION"
fi
zstyle ':completion:*' menu select                  # Tab repetido: menú con flechas
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' # minúsculas encuentran mayúsculas
zstyle ':completion:*' list-colors ''

# --- Prompt ---------------------------------------------------------------------
#
#   usuario@host ~/ruta (rama) [código si falló] %
#
# Sin iconos: con Nerd Font o sin ella, desde cualquier terminal, se ve igual.
# usuario@host en rojo si eres root. La rama va en psvar (%1v) y no con
# prompt_subst, para que un nombre de rama con $(...) no se ejecute nunca.

autoload -Uz vcs_info add-zsh-hook
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' (%b)'
zstyle ':vcs_info:git:*' actionformats ' (%b|%a)'
_prompt_rama() { vcs_info; psvar[1]=$vcs_info_msg_0_ }
add-zsh-hook precmd _prompt_rama

PROMPT='%(!.%F{red}.%F{green})%n@%m%f %F{blue}%~%f%F{yellow}%1v%f %(?..%F{red}[%?]%f )%# '

# --- Alias y colores (los mismos que el ~/.bashrc de Ubuntu) ---------------------

if (( $+commands[dircolors] )); then
    eval "$(dircolors -b)"
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias grep='grep --color=auto'

# ~/.local/bin: ~/.profile lo añade al PATH en bash, zsh no lo lee. Delante, los
# comandos del repo (nvim, vi, vim): dentro de tmux; fuera (zsh
# --global), solo con ./install vim --global, que lo apunta en vim.global
typeset -U path
[[ -d ~/.local/bin ]] && path=(~/.local/bin $path)
if [[ -n $TMUX || -e ${XDG_STATE_HOME:-$HOME/.local/state}/tmux-config/vim.global ]]; then
    [[ -d ~/.local/opt/tmux-config/bin ]] && path=(~/.local/opt/tmux-config/bin $path)

    # Editor por defecto (git commit, crontab -e, sudoedit...): el neovim de
    # ./install vim, con su config aparte (NVIM_APPNAME: ~/.config/tmux-config-nvim,
    # no ~/.config/nvim). Si no, el de la distro. Otro: en ~/.zshrc.local
    if [[ -x ~/.local/opt/tmux-config/bin/nvim ]]; then
        export NVIM_APPNAME=tmux-config-nvim
        export EDITOR="$HOME/.local/opt/tmux-config/bin/nvim" VISUAL="$HOME/.local/opt/tmux-config/bin/nvim"
    fi
fi

# --- Plugins: los paquetes de la distro ------------------------------------------
#
# Cada uno se carga solo si está instalado (en Rocky salen de EPEL: sin EPEL,
# zsh funciona igual, sin sugerencias ni colores).

# fzf: Ctrl+R busca en el historial, Ctrl+T inserta un fichero, Alt+c cambia de
# directorio. La ruta cambia según la distro.
for f in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/shell/key-bindings.zsh; do
    [[ -r $f ]] && { source $f; break }
done
unset f

# fd y bat (en Debian y Ubuntu se llaman fdfind y batcat). Con fd, Ctrl+T y
# Alt+c buscan también los ocultos y lo que ignora git (.env), sin lo que solo
# estorba (_tc_ruido). Con bat, Ctrl+T y Alt+d enseñan el fichero marcado.
_tc_fd=${commands[fdfind]:-${commands[fd]}}
_tc_bat=${commands[batcat]:-${commands[bat]}}
_tc_ruido=(.git node_modules __pycache__ .cache)
if [[ -n $_tc_fd ]]; then
    FZF_CTRL_T_COMMAND="$_tc_fd --hidden --no-ignore --strip-cwd-prefix ${(j: :)${(@)_tc_ruido/#/--exclude=}}"
    FZF_ALT_C_COMMAND="$FZF_CTRL_T_COMMAND --type d"
fi
[[ -n $_tc_bat ]] && FZF_CTRL_T_OPTS="--preview '$_tc_bat --color=always --style=plain --line-range=:200 {} 2>/dev/null || ls -lA {}'"

# Alt+d: buscar en todo el disco y escribir la ruta completa en la línea (Tab
# marca varias). Las rutas salen mientras busca: se puede escribir ya. Sin
# /proc, /sys, /dev, /run ni /snap, ni _tc_ruido; lo que no puedes leer no sale.
# Con fd; sin él, con find (más lento).
_tc_rutas() {
    local -a raices=(/*(N/)) poda=()   # (/): sin /bin, /lib ni /sbin, enlaces a /usr
    local r
    raices=(${raices:#/(proc|sys|dev|run|snap)})
    if [[ -n $_tc_fd ]]; then
        $_tc_fd --hidden --no-ignore --color=never ${_tc_ruido/#/--exclude=} . $raices 2>/dev/null
    else
        for r in $_tc_ruido; do poda+=(-o -name $r); done
        find $raices \( ${poda[2,-1]} \) -prune -o -print 2>/dev/null
    fi
}
_tc_buscar_todo() {
    local -a sel vista=()
    [[ -n $_tc_bat ]] && vista=(--preview "$_tc_bat --color=always --style=plain --line-range=:200 {} 2>/dev/null || ls -lA {}")
    sel=("${(@f)$(_tc_rutas | fzf -m --height=${FZF_TMUX_HEIGHT:-40%} --reverse --prompt='todo el disco> ' $vista)}")
    [[ -n $sel ]] && LBUFFER+="${(j: :)${(@q)sel}} "
    zle reset-prompt
}
zle -N _tc_buscar_todo
bindkey '^[d' _tc_buscar_todo

# Un comando que no existe: dice qué paquete lo trae, si está command-not-found
# (Ubuntu lo trae de serie)
[[ -r /etc/zsh_command_not_found ]] && source /etc/zsh_command_not_found

# zoxide: "z parte-del-nombre" salta a una carpeta en la que ya estuviste; "zi"
# la elige de una lista (fzf). Aprende sola con cada cd.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# Sugerencia en gris según el historial: → o Fin la acepta entera, Ctrl+→ una
# palabra (Alt+→ no: en tmux cambia de pane)
[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Colorea la línea mientras escribes (comando inexistente en rojo). Tiene que ir
# lo último: envuelve los widgets definidos antes.
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- Local -----------------------------------------------------------------------

[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
true  # sin ~/.zshrc.local, el primer prompt no debe salir con [1]
