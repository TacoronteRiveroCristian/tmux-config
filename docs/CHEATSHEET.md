# Mapa de atajos tmux

Para moverte: flechas o RePág/AvPág. /texto busca. q sale.
Debajo del mapa está la guía paso a paso.

Día a día: Alt + tecla, a la vez. Son las teclas de Kitty cambiando Ctrl+Shift
por Alt (Alt+Enter, Alt+t, Alt+l, Alt+r, Alt+w, Alt+q...).
Ocasional: Ctrl+B, soltar las dos teclas, y luego la tecla.

## Panes (divisiones de la pantalla)

    Alt+Enter             nuevo pane (divide el lado más largo)
    Alt+← ↑ ↓ →           ir al pane de ese lado
    Alt+Shift+← ↑ ↓ →     mover el pane hacia ese lado
    Alt+z                 maximizar / restaurar el pane
    Alt+l                 siguiente distribución (layout)
    Alt+r                 modo redimensionar: las flechas mueven el borde,
                          = iguala tamaños, Esc sale
    Alt+w                 cerrar el pane (confirma con y)

## Windows (pestañas de la barra de abajo)

    Alt+t                 nueva window
    Alt+Shift+t           renombrar la window
    Alt+1 .. 9            ir a la window N
    Alt+n / Alt+p         siguiente / anterior
    Alt+Shift+n / p       mover la window a la derecha / izquierda
    Alt+q                 cerrar la window con todos sus panes (confirma con y)

## Sesiones (un entorno por proyecto)

    Alt+s                 lista de sesiones (flechas y Enter para saltar)
    Alt+Shift+s           nueva sesión (pide el nombre; si existe, salta a ella)
    Alt+Shift+q           salir de tmux sin cerrar nada (detach)

## Scroll y búsqueda

    Alt+RePág             modo scroll: RePág/AvPág, flechas, g inicio, G final
    Alt+/                 buscar texto hacia atrás: n siguiente, N anterior
    q                     salir del modo scroll
    rueda del ratón       scroll directo
    Shift + arrastrar     seleccionar y copiar como siempre

## Ayuda

    Alt+h                 esta guía (q sale)
    Ctrl+B ?              todos los atajos de tmux (q sale)
    Ctrl+B R              recargar la configuración

## Ocasional con Ctrl+B

    Ctrl+B d              salir sin cerrar nada (sirve en cualquier servidor)
    Ctrl+B $              renombrar la sesión
    Ctrl+B %  /  Ctrl+B " dividir forzando la dirección: derecha / abajo
    Ctrl+B !              sacar el pane a una window propia
    Ctrl+B Ctrl+B         enviar Ctrl+B al programa (o al tmux de dentro)

## Desde la shell

    tmux new -A -s trabajo        entrar en la sesión (la crea si no existe)
    tmux ls                       listar sesiones
    tmux kill-session -t trabajo  eliminar una sesión
    tmux-guia                     esta guía (en un pane de tmux con zsh)

## En zsh (si instalaste ./install zsh)

    → o Fin               aceptar la sugerencia en gris
    Ctrl+→                aceptar solo una palabra de la sugerencia
    ↑ / ↓                 historial filtrado por lo ya escrito
    Ctrl+R                buscar en el historial (fzf)
    Ctrl+T / Alt+c        insertar un fichero / cambiar de directorio (fzf)
    Tab Tab               menú de completado, flechas para elegir
    " comando"            empezar con espacio: no se guarda en el historial
    z texto               ir a una carpeta en la que ya estuviste (z tmux)
    zi                    elegir entre las carpetas aprendidas (fzf)
    tldr comando          ejemplos de uso de un comando (tldr tar)

## En neovim (si instalaste ./install vim)

  Dentro de tmux, vi, vim, view y vimdiff también abren este neovim. Fuera de
  tmux, vi es el de la distro.

  Primeros pasos:

    i  ·  Esc             empezar a escribir · dejar de escribir
    Espacio w  ·  q       guardar · cerrar (:q! sale sin guardar)
    u  ·  Ctrl+R          deshacer · rehacer (también tras cerrar el fichero)
    Espacio (y esperar)   menú con todos los atajos
    Espacio ?             este mapa
    Espacio k             buscar un atajo escribiendo lo que quieres hacer
    para aprender         :Tutor (en inglés)

  Ficheros:

    Espacio e             árbol de ficheros (abrir / cerrar)
    Espacio f             mostrar en el árbol el fichero actual
    Ctrl+P                buscar un fichero por nombre (Enter abre, Esc sale)
    Espacio g             buscar texto en el proyecto
    Espacio b  ·  r       ficheros abiertos · recientes
    Ctrl+h  ·  Ctrl+l     pasar del árbol al fichero y al revés
    gcc  ·  gc            comentar la línea · la selección
    Espacio y             copiar al portapapeles, también por SSH

  En el árbol:

    a crear · r renombrar · d borrar (y + Enter) · c copiar · p pegar
    x cortar · H ocultos · R refrescar · g? ayuda

  Código (LSP de bash, Python, YAML, JSON, Dockerfile, Lua, Markdown):

    Tab                   aceptar el autocompletado (flechas eligen, Esc cierra)
    K  ·  gd              información · ir a la definición
    ]d  ·  [d             siguiente error · anterior
    Espacio cd            ver el error de la línea
    Espacio ca · cr · cf  arreglos rápidos · renombrar · formatear

  Git:

    ]c  ·  [c             siguiente cambio · anterior
    Espacio vp · vr · vb  ver el cambio · deshacerlo · quién cambió la línea

  En tmux, neovim es el editor por defecto: git commit, crontab -e, sudoedit...
  Ficheros del sistema: sudoedit /etc/fichero (con tu config, sin abrir el
  editor como root)

  Si Claude u otro programa cambia un fichero que tienes abierto, neovim lo
  relee solo. Si tú también lo habías cambiado, pregunta: O se queda con lo
  tuyo, L carga lo de fuera.

## Si un atajo Alt no hace nada

Tu terminal se lo queda antes de que llegue a tmux. Por defecto:

    Windows Terminal      Alt+Enter (pantalla completa), Alt+flechas y
                          Alt+Shift+flechas (sus propios paneles)
    GNOME Terminal        Alt+1..9 (cambiar de pestaña)
    macOS / iTerm2        hay que activar "Option como Meta"

Para comprobarlo, fuera de tmux ejecuta "cat -v" y pulsa el atajo: Alt+t debe
mostrar ^[t y Alt+← debe mostrar ^[[1;3D. Si no sale nada, lo intercepta el
terminal. Sal con Ctrl+C.

--------------------------------------------------------------------------------
