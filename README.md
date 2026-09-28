# tmux-config

Configuración personal de tmux, igual en todos los servidores. Un único mapa de
atajos al estilo Kitty: `Alt+tecla` para el día a día y `Ctrl+B` para lo
ocasional. Está en [docs/CHEATSHEET.md](docs/CHEATSHEET.md).

¿Primera vez? Lee la guía paso a paso [docs/GUIA.md](docs/GUIA.md). Una vez
instalado, se abre con `tmux-guia` desde la shell o con `Alt+h` dentro de tmux.

## Instalar / actualizar

```bash
git clone <este-repo> ~/GitHub/personal/tmux-config
cd ~/GitHub/personal/tmux-config
./install.sh
```

`install.sh` se puede ejecutar tantas veces como se quiera:

1. Instala tmux (apt o dnf) si falta. Solo en ese caso usa sudo. Con
   `./install.sh --actualizar` también lo actualiza a la última versión de la
   distro.
2. Comprueba que `.tmux.conf` carga sin errores con esa versión, en un servidor
   tmux aislado que no toca las sesiones en marcha.
3. Enlaza `~/.tmux.conf` a este repo. Si ya había una config, la guarda como
   `~/.tmux.conf.bak.<fecha>`.
4. Enlaza el comando `tmux-guia` en `~/.local/bin`.

Para traer cambios: `git pull && ./install.sh`. Dentro de tmux, `Ctrl+B R`
recarga la config.

## Desinstalar

```bash
./uninstall.sh
```

Se ejecuta **fuera de tmux**. Enseña la lista de lo que va a hacer y pide
confirmación antes de:

1. Cerrar los servidores tmux de tu usuario, con todas sus sesiones.
2. Quitar `~/.tmux.conf` y `~/.local/bin/tmux-guia`, solo si son enlaces a
   este repo.
3. Desinstalar el paquete tmux. apt/dnf vuelve a confirmar y enseña qué más se
   quita.

En Ubuntu Server, apt quita también el metapaquete `ubuntu-server`, porque
depende de tmux. El script lo avisa. Recupéralo tras `./install.sh` con
`sudo apt install ubuntu-server`.

## Requisitos

tmux **3.2 o superior**: Ubuntu 22.04+, Debian 12+, RHEL/Rocky 9+.

Probado en contenedores limpios con Ubuntu 24.04 (3.4), Ubuntu 22.04 (3.2a),
Debian 12 (3.3a) y Rocky 9 (3.2a). En Ubuntu 20.04 (3.0a) y Debian 11 (3.1c) la
config no carga: `install.sh` lo detecta y no enlaza nada.

## Probar cambios sin instalar

```bash
tmux -L prueba -f "$PWD/.tmux.conf" new -s prueba
```

## Archivos

| Archivo | Qué es |
|---|---|
| `.tmux.conf` | La configuración, comentada |
| `docs/CHEATSHEET.md` | El mapa de atajos |
| `docs/GUIA.md` | Guía de uso paso a paso |
| `bin/tmux-guia` | Abre el mapa y la guía en la terminal |
| `install.sh` | Instalación / actualización |
| `uninstall.sh` | Desinstalación |
