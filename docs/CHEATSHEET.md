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
    tmux-guia                     esta guía

## En zsh (si instalaste ./install zsh)

    → o Fin               aceptar la sugerencia en gris
    Ctrl+→                aceptar solo una palabra de la sugerencia
    ↑ / ↓                 historial filtrado por lo ya escrito
    Ctrl+R                buscar en el historial (fzf)
    Ctrl+T / Alt+c        insertar un fichero / cambiar de directorio (fzf)
    Tab Tab               menú de completado, flechas para elegir
    " comando"            empezar con espacio: no se guarda en el historial

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
