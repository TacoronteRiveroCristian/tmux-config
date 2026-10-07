# Guía de tmux

El mapa completo de atajos está al principio (docs/CHEATSHEET.md). Esta guía
explica cómo usarlos, paso a paso.

## 1. Qué es tmux

tmux mantiene tus terminales vivas en el servidor. Si se corta el SSH o cierras
la ventana, todo sigue corriendo y puedes volver a entrar.

Se organiza en tres niveles:

    sesión          un proyecto o tarea (p. ej. "datadis")
    └─ window       una pestaña dentro de la sesión (p. ej. "editor", "logs")
       └─ pane      una división de la window

## 2. Empezar: crear una sesión

Desde la shell, fuera de tmux:

    tmux new -A -s trabajo

Entra en la sesión "trabajo" y, si no existe, la crea. Es el único comando que
necesitas recordar para empezar.

La terminal se ve igual que antes, con una barra verde abajo:

    [trabajo] 1:bash*

    [trabajo]       nombre de la sesión
    1:bash*         window 1, ejecutando bash (el * marca la window actual)

Si "tmux ls" dice "no server running", no pasa nada: significa que todavía no
hay ninguna sesión.

Lo configurado solo existe aquí dentro: zsh con su config en los panes, neovim
al escribir vi o vim (y en git commit, crontab -e, sudoedit) y tmux-guia (estos
dos, en los panes con zsh). Fuera de tmux el servidor sigue exactamente como
estaba, salvo que lo instalaras con --global (README del repo).

## 3. Dos tipos de atajo

Día a día: Alt + tecla, a la vez, como en Kitty con Ctrl+Shift.

    Alt+Enter           nuevo pane

Ocasional: Ctrl+B, soltar las dos teclas, y luego la tecla de la acción.

    Ctrl+B $            renombrar la sesión

## 4. Panes: dividir la pantalla

Pulsa Alt+Enter varias veces: cada pane nuevo divide el lado más largo del
actual y se abre en el mismo directorio. Muévete con Alt+flechas.

Para ordenarlos:

    Alt+l               prueba distribuciones (pulsa varias veces); los panes
                        nuevos se colocan siguiendo la que elijas
    Alt+Shift+flechas   lleva el pane actual hacia ese lado
    Alt+z               maximiza un pane para trabajar en él; otra vez, restaura

Para cambiar tamaños pulsa Alt+r: la barra de abajo mostrará REDIMENSIONAR.
Las flechas mueven el borde del pane actual, las veces que quieras; = iguala
los tamaños. Esc, Enter o q terminan (cualquier otra tecla también sale del
modo, y esa tecla no se escribe). Con el ratón: arrastra un borde.

Para cerrar: Alt+w (confirma con y), o escribe "exit" en el pane.

## 5. Windows: varios entornos en la misma sesión

Cada window es una pestaña de la barra de abajo: "1:bash 2:logs".

    Alt+t               nueva window
    Alt+Shift+t         ponerle nombre (p. ej. "logs"); el nombre se queda fijo
                        aunque cambie el programa que ejecutas en ella
    Alt+1 .. 9          saltar a una window
    Alt+n / Alt+p       la siguiente / la anterior
    Alt+Shift+n / p     cambiarla de sitio en la barra
    Alt+q               cerrarla con todos sus panes (confirma con y)

## 6. Salir y volver (lo más importante)

    Alt+Shift+q         salir de tmux SIN cerrar nada (detach)

Tu trabajo sigue corriendo en el servidor. Para volver:

    tmux ls                   ver las sesiones que hay
    tmux new -A -s trabajo    volver a "trabajo" (o crearla si no existe)

Si se corta el SSH es como salir con Alt+Shift+q: vuelve a conectarte y entra
otra vez. En un servidor sin esta configuración, sal con Ctrl+B d.

Las sesiones NO sobreviven a un reinicio del servidor.

## 7. Varias sesiones

Una sesión por proyecto. Dentro de tmux:

    Alt+Shift+s         crear otra sesión (pide el nombre)
    Alt+s               lista de sesiones: flechas y Enter para saltar; con →
                        despliegas sus windows
    Ctrl+B $            renombrar la sesión actual ($ = Shift+4)

Si cierras la última window de una sesión, tmux te lleva a otra sesión en vez
de salir.

## 8. Scroll y búsqueda

    rueda del ratón     scroll directo
    Alt+RePág           modo scroll: RePág/AvPág, flechas; g inicio, G final
    Alt+/               buscar un texto hacia atrás (p. ej. "error"):
                        n salta al siguiente resultado, N al anterior
    q                   salir del modo scroll

Mientras estás en modo scroll, arriba a la derecha aparece tu posición en el
historial.

Para seleccionar y copiar texto como siempre, mantén Shift mientras arrastras
con el ratón. Sin Shift, la selección la hace tmux y no tu terminal.

## 9. Cerrar

    Alt+w / Alt+q                  cerrar el pane / la window
    tmux kill-session -t trabajo   cerrar una sesión entera desde fuera
    tmux kill-server               cerrar TODAS las sesiones

## 10. Problemas típicos

"no server running on /tmp/tmux-1000/default"
    No hay sesiones. Crea una: tmux new -A -s trabajo

"sessions should be nested with care, unset $TMUX to force"
    Ya estás dentro de tmux. No abras tmux dentro de tmux: usa Alt+Shift+s
    para otra sesión o Alt+t para una window nueva.

Un atajo Alt no hace nada, o hace algo de mi terminal
    Tu terminal se lo queda: mira "Si un atajo Alt no hace nada" en el mapa.

No puedo copiar texto con el ratón
    Mantén Shift mientras seleccionas.

La configuración no se aplica
    ¿Estás en byobu? Byobu no carga esta configuración: usa "tmux".
    Si has cambiado .tmux.conf: Ctrl+B R para recargar.

Fuera de tmux no tengo mi zsh, ni neovim, ni tmux-guia
    Es lo de por defecto: solo existen dentro de tmux. Entra con
    tmux new -A -s trabajo. Para tenerlos también fuera:
    ./install --global zsh vim (en la carpeta del repo).

## 11. Más ayuda

    Alt+h               esta guía, dentro de tmux
    tmux-guia           esta guía, en un pane con zsh (./install zsh)
    Ctrl+B ?            todos los atajos de tmux (q para salir)

Para cambiar atajos o la configuración: README.md del repo, sección
"Personalizar".
