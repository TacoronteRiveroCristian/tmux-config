# =============================================================================
# zsh — configuración personal
#
# Requiere zsh >= 5.8 (probada en 5.8, 5.8.1 y 5.9). Se instala con ./install zsh.
# No cambia la shell de login: zsh arranca en los panes de tmux (.tmux.conf lo
# detecta) con ZDOTDIR=~/.local/opt/tmux-config/zsh, donde está enlazado este
# fichero. Fuera de tmux, en "ssh host comando", como root y para los demás
# usuarios, todo sigue en bash; y "zsh" tecleado fuera no carga esta config.
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
# Sin esto, zsh elige el modo vi si $EDITOR o $VISUAL contienen "vi". Alt+b/f/d/.
# hacen lo mismo que en bash (por eso tmux no los usa).

bindkey -e
bindkey '^U' backward-kill-line          # como bash: borrar hasta el principio
bindkey '^[[H' beginning-of-line         # Inicio / Fin: zsh no las trae para todos
bindkey '^[[F' end-of-line               # los terminales (sin esto escriben ~)
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char              # Supr
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
# comandos del repo (nvim, vi, vim, tmux-guia), que solo están en el PATH aquí
typeset -U path
[[ -d ~/.local/bin ]] && path=(~/.local/bin $path)
[[ -d ~/.local/opt/tmux-config/bin ]] && path=(~/.local/opt/tmux-config/bin $path)

# Editor por defecto (git commit, crontab -e, sudoedit...): el neovim de
# ./install vim, con su config aparte (NVIM_APPNAME: ~/.config/tmux-config-nvim,
# no ~/.config/nvim). Fuera de tmux, el de la distro. Otro: en ~/.zshrc.local
if [[ -x ~/.local/opt/tmux-config/bin/nvim ]]; then
    export NVIM_APPNAME=tmux-config-nvim
    export EDITOR="$HOME/.local/opt/tmux-config/bin/nvim" VISUAL="$HOME/.local/opt/tmux-config/bin/nvim"
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
