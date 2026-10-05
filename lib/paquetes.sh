# shellcheck shell=bash
# lib/paquetes.sh — los paquetes de apt/dnf que pone ./install, sacados de la
# tabla de cada componente (<componente>/paquetes). planificar decide qué hay,
# qué falta, qué no se puede instalar y qué se pierde sin ello, sin tocar nada
# (salvo apt-get update); mostrar_paquetes lo enseña y aplicar_paquetes lo hace.
# Lo carga ./install tras lib/comun.sh, y usa sus CHECK, SI (-y) y ACTUALIZAR.
#
# La tabla, una fila por paquete (# empieza un comentario):
#   apt  dnf  comando  mínimo  con  sin él
#   apt, dnf  su nombre en cada gestor (- = ahí no lo hay). El de apt es también
#             su nombre en la columna "con"
#   comando   si ya está en el PATH, venga de donde venga, no se instala el
#             paquete (- = mirar solo si está el paquete)
#   mínimo    versión mínima (- = cualquiera): la del comando, si la fila lo
#             tiene y está; si no, la del paquete
#   con       solo si se queda este otro paquete, de una fila de más arriba
#             (- = sin condición)
#   sin él    el resto de la línea: "bloquea" (sin él no se instala nada) o qué
#             se pierde
# Y cómo tenerlo si el gestor no lo da (el plan lo sugiere; nunca lo ejecuta):
#   arreglo  <nombre en apt>  <apt|dnf>  <orden...>

GESTOR="$(pkg_manager)"

# Una fila por paquete de los componentes elegidos, en arrays paralelos (el
# mismo índice en todos): componente, nombre en apt, nombre en este gestor y el
# resto de columnas. Lo que ya está: F_HAY (1 si está y vale) y F_TIENES (la
# versión que tienes, si es más vieja que el mínimo). Y lo que decide
# planificar: F_EST (ya, instalar, actualizar, dentro: lo trae el paquete de la
# fila "con", sin o bloquea), F_POR (por qué
# no se instala; vacío en una fila "con", que la explica la otra) y F_VER (la
# versión que hay o la que entrará).
F_COMP=() F_ID=() F_PKG=() F_CMD=() F_MIN=() F_CON=() F_SIN=()
F_HAY=() F_TIENES=() F_EST=() F_POR=() F_VER=()
ARREGLOS=()   # "componente<TAB>nombre en apt<TAB>gestor<TAB>orden"
PAQ_INSTALAR=() PAQ_ACTUALIZAR=()
APT_TOTAL=""  # con apt, los que entrarían contando sus dependencias

cargar_tabla() {
    local comp="$1" linea apt dnf cmd min con sin id gestor orden
    while IFS= read -r linea || [ -n "$linea" ]; do
        read -r apt dnf cmd min con sin <<<"$linea"
        case "${apt:-#}" in
            \#*) continue ;;
            arreglo)
                read -r _ id gestor orden <<<"$linea"
                ARREGLOS+=("$comp"$'\t'"$id"$'\t'"$gestor"$'\t'"$orden")
                continue ;;
        esac
        [ -n "$sin" ] || die "$comp/paquetes: a la fila de $apt le faltan columnas"
        F_COMP+=("$comp") F_ID+=("$apt") F_CMD+=("$cmd") F_MIN+=("$min") F_CON+=("$con") F_SIN+=("$sin")
        case "$GESTOR" in
            apt) F_PKG+=("$apt") ;;
            dnf) F_PKG+=("$dnf") ;;
            *)   F_PKG+=(-) ;;
        esac
        F_HAY+=("") F_TIENES+=("") F_EST+=("") F_POR+=("") F_VER+=("")
    done < "$REPO_DIR/$comp/paquetes"
}

# version_de TEXTO: la versión con la que empieza, sin epoch ni revisión:
# "1:3.2a-4ubuntu1" -> 3.2a · "tmux 3.4" -> 3.4 · "v18.19.1" -> 18.19.1
version_de() { sed -nE '1{s/^[0-9]+://; s/^[^0-9]*//; s/^([0-9]+(\.[0-9]+)*[a-z]?).*/\1/p}' <<<"$1"; }

# ver_ge A B: A es B o posterior
ver_ge() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" = "$2" ]; }

# La del comando (tmux no tiene --version, sino -V)
version_cmd() { version_de "$({ "$1" --version || "$1" -V; } 2>/dev/null | head -n 1)"; }

pkg_version() {
    case "$GESTOR" in
        apt) version_de "$(dpkg-query -W -f='${Version}' "$1" 2>/dev/null)" ;;
        dnf) version_de "$(rpm -q --qf '%{VERSION}' "$1" 2>/dev/null)" ;;
    esac
}

# La versión que instalaría el gestor; vacío si no está en los repos activos.
# Con apt, la de los índices que haya (tras apt-get update, la de verdad). La
# salida de apt, siempre en inglés (LC_ALL=C): en español dice "Candidato:"
pkg_candidate() {
    case "$GESTOR" in
        apt) version_de "$(LC_ALL=C apt-cache policy "$1" 2>/dev/null | sed -n 's/^ *Candidate: //p')" ;;
        dnf) version_de "$(dnf -q repoquery --latest-limit 1 --qf '%{version}' "$1" 2>/dev/null | head -n 1)" ;;
    esac
}

# pkg_provee PAQUETE OTRO: la versión que instalaría de PAQUETE trae OTRO
# dentro. El nodejs de NodeSource trae npm y choca con el de la distro:
# instalar los dos juntos falla (apt sale con 100)
pkg_provee() {
    local v
    case "$GESTOR" in
        apt) v="$(LC_ALL=C apt-cache policy "$1" 2>/dev/null | sed -n 's/^ *Candidate: //p')"
             LC_ALL=C apt-cache show "$1=$v" 2>/dev/null | sed -n '1,/^$/s/^Provides: //p' |
                 tr ',' '\n' | awk '{print $1}' | grep -x "$2" >/dev/null ;;
        dnf) dnf -q repoquery --latest-limit 1 --provides "$1" 2>/dev/null |
                 awk '{print $1}' | grep -x "$2" >/dev/null ;;
        *)   return 1 ;;
    esac
}

# fila COMPONENTE NOMBRE_APT: su índice
fila() {
    local i
    for i in "${!F_ID[@]}"; do
        if [ "${F_COMP[$i]}" = "$1" ] && [ "${F_ID[$i]}" = "$2" ]; then echo "$i"; return; fi
    done
    die "$1/paquetes: \"con $2\", y $2 no está en la tabla"
}

# planificar COMPONENTE...: decide con los índices de apt que haya. Solo si así
# va a instalar o actualizar algo, algo BLOQUEA o apt no tiene índices, los pone
# al día con apt-get update, que pide sudo, y vuelve a decidir: repetir
# ./install con algo que los repos no dan (tealdeer en Ubuntu 22.04) no pide sudo
# cada vez. Con --check, nunca; sin terminal ni -y tampoco (no va a instalar
# nada: ./install se para antes de preguntar). Valen los que haya.
planificar() {
    local c i al_dia=1
    for c in "$@"; do cargar_tabla "$c"; done

    # Lo que ya está: el comando en el PATH (si la fila lo tiene) o el paquete.
    # Si es más viejo que el mínimo, cuenta como que falta (F_TIENES lo recuerda).
    for i in "${!F_ID[@]}"; do
        if [ "${F_CMD[$i]}" != - ] && command -v "${F_CMD[$i]}" >/dev/null; then
            [ "${F_MIN[$i]}" = - ] || F_VER[i]="$(version_cmd "${F_CMD[$i]}")"
        elif [ "${F_PKG[$i]}" != - ] && pkg_installed "${F_PKG[$i]}"; then
            [ "${F_MIN[$i]}" = - ] || F_VER[i]="$(pkg_version "${F_PKG[$i]}")"
        else
            continue
        fi
        if [ "${F_MIN[$i]}" = - ] || ver_ge "${F_VER[$i]:-0}" "${F_MIN[$i]}"; then
            F_HAY[i]=1
        else
            F_TIENES[i]="${F_VER[$i]:-?}"
        fi
    done

    decidir
    if [ "$GESTOR" = apt ]; then
        if ! compgen -G '/var/lib/apt/lists/*_Packages*' >/dev/null; then
            al_dia=0
            [ "$CHECK" -eq 0 ] ||
                info "AVISO: apt no tiene índices y --check no usa sudo: lo que falta sale como que no está en los repos (sudo apt-get update)"
        elif [ ${#PAQ_INSTALAR[@]} -gt 0 ] || [ ${#PAQ_ACTUALIZAR[@]} -gt 0 ] ||
             [[ " ${F_EST[*]} " == *" bloquea "* ]]; then
            al_dia=0
        fi
        if [ "$al_dia" -eq 0 ] && [ "$CHECK" -eq 0 ] && [ "$SI" -eq 0 ] && [ ! -t 0 ]; then
            info "sin terminal ni -y no se usa sudo: el plan sale con los índices de apt que hay"
        elif [ "$al_dia" -eq 0 ] && [ "$CHECK" -eq 0 ]; then
            need_sudo "apt-get update"
            info "apt-get update: para ver qué hay en los repos (no instala nada)"
            $SUDO apt-get update -qq
            decidir
        fi
    fi

    # Con apt, cuántos entrarían de verdad, con sus dependencias (simulado, sin sudo)
    if [ "$GESTOR" = apt ] && [ ${#PAQ_INSTALAR[@]} -gt 0 ]; then
        # shellcheck disable=SC2034  # lo usa ./install
        APT_TOTAL="$(LC_ALL=C apt-get install -s --no-install-recommends "${PAQ_INSTALAR[@]}" 2>/dev/null | grep -c '^Inst' || true)"
    fi
}

# decidir: el estado de cada fila (F_EST, F_POR, F_VER) a partir de lo que ya
# está y de lo que dan los repos ahora mismo, y las listas PAQ_*
decidir() {
    local i j cand por
    PAQ_INSTALAR=() PAQ_ACTUALIZAR=()
    for i in "${!F_ID[@]}"; do
        if [ -n "${F_HAY[$i]}" ]; then F_EST[i]=ya; else F_EST[i]=""; fi
        F_POR[i]=""
    done

    # Lo que falta: ¿lo dan los repos, en una versión que valga?
    for i in "${!F_ID[@]}"; do
        [ -z "${F_EST[$i]}" ] || continue
        if [ "${F_CON[$i]}" != - ]; then
            j="$(fila "${F_COMP[$i]}" "${F_CON[$i]}")"
            case "${F_EST[$j]}" in
                ya) ;;
                instalar|actualizar)
                    # lo trae dentro el que va a entrar: instalarlo aparte chocaría
                    if pkg_provee "${F_PKG[$j]}" "${F_PKG[$i]}"; then F_EST[i]=dentro; continue; fi ;;
                *) F_EST[i]=sin; F_POR[i]=""; continue ;;
            esac
        fi
        cand=""
        if [ -n "$GESTOR" ] && [ "${F_PKG[$i]}" != - ]; then cand="$(pkg_candidate "${F_PKG[$i]}")"; fi
        if [ -n "$cand" ] && { [ "${F_MIN[$i]}" = - ] || ver_ge "$cand" "${F_MIN[$i]}"; }; then
            F_VER[i]="$cand"
            if pkg_installed "${F_PKG[$i]}"; then F_EST[i]=actualizar; else F_EST[i]=instalar; fi
            continue
        fi
        if [ -z "$GESTOR" ]; then           por="no hay apt ni dnf: instálalo a mano"
        elif [ "${F_PKG[$i]}" = - ]; then   por="no hay paquete en $GESTOR"
        elif [ -n "${F_TIENES[$i]}" ]; then por="tienes la ${F_TIENES[$i]} y los repos no tienen la ${F_MIN[$i]} o posterior"
        elif [ -n "$cand" ]; then           por="los repos tienen la $cand y hace falta la ${F_MIN[$i]}"
        else                                por="no está en los repos activos"
        fi
        F_POR[i]="$por"
        if [ "${F_SIN[$i]}" = bloquea ]; then F_EST[i]=bloquea; else F_EST[i]=sin; fi
    done

    # Con --actualizar, también los paquetes que ya están (si hay versión nueva)
    if [ "$ACTUALIZAR" -eq 1 ]; then
        for i in "${!F_ID[@]}"; do
            if [ "${F_EST[$i]}" = ya ] && [ "${F_PKG[$i]}" != - ] && pkg_installed "${F_PKG[$i]}"; then
                F_EST[i]=actualizar
            fi
        done
    fi

    for i in "${!F_ID[@]}"; do
        case "${F_EST[$i]}" in
            instalar)   PAQ_INSTALAR+=("${F_PKG[$i]}") ;;
            actualizar) PAQ_ACTUALIZAR+=("${F_PKG[$i]}") ;;
        esac
    done
}

# lista A B C: "A, B, C"
lista() { local s; s="$(printf '%s, ' "$@")"; echo "${s%, }"; }

# paquete I: su nombre en este gestor (o en apt, si aquí no lo hay)
paquete() { if [ "${F_PKG[$1]}" != - ]; then echo "${F_PKG[$1]}"; else echo "${F_ID[$1]}"; fi; }

# Con la versión, en las filas con mínimo
con_version() {
    if [ "${F_MIN[$1]}" != - ] && [ -n "${F_VER[$1]}" ]; then echo "$(paquete "$1") ${F_VER[$1]}"; else paquete "$1"; fi
}

# mostrar_paquetes COMPONENTE: sus líneas del plan (plan_linea, de lib/comun.sh)
mostrar_paquetes() {
    # shellcheck disable=SC2034  # TC_COMP lo lee plan_linea
    local TC_COMP="$1" i a ac aid ag orden ya=() inst=() act=() arr=() epel=0
    for i in "${!F_ID[@]}"; do
        [ "${F_COMP[$i]}" = "$1" ] || continue
        case "${F_EST[$i]}" in
            ya)         ya+=("$(con_version "$i")") ;;
            instalar)   inst+=("$(con_version "$i")") ;;
            dentro)     inst+=("$(paquete "$i") (viene con ${F_CON[$i]})") ;;
            actualizar) act+=("$(con_version "$i")") ;;
        esac
    done
    [ ${#ya[@]} -eq 0 ]   || plan_linea ya "$(lista "${ya[@]}")"
    [ ${#inst[@]} -eq 0 ] || plan_linea instalar "$(lista "${inst[@]}")"
    [ ${#act[@]} -eq 0 ]  || plan_linea actualizar "$(lista "${act[@]}")"

    for i in "${!F_ID[@]}"; do
        [ "${F_COMP[$i]}" = "$1" ] && [ -n "${F_POR[$i]}" ] || continue
        if [ "${F_EST[$i]}" = bloquea ]; then
            plan_linea bloquea "$(paquete "$i"): ${F_POR[$i]}"
            continue
        fi
        arr=()
        for a in ${ARREGLOS[@]+"${ARREGLOS[@]}"}; do
            IFS=$'\t' read -r ac aid ag orden <<<"$a"
            if [ "$ac" = "$1" ] && [ "$aid" = "${F_ID[$i]}" ] && [ "$ag" = "$GESTOR" ]; then arr+=("arreglo: $orden"); fi
        done
        if [ "$GESTOR" = dnf ] && [ ${#arr[@]} -eq 0 ] && [ "${F_POR[$i]}" = "no está en los repos activos" ]; then epel=1; fi
        plan_linea sin "$(paquete "$i"): ${F_POR[$i]} → ${F_SIN[$i]}" ${arr[@]+"${arr[@]}"}
    done
    if [ "$epel" -eq 1 ]; then
        plan_linea aviso "lo que no está en los repos, en Rocky/RHEL viene de EPEL" \
            "arreglo: sudo dnf install epel-release && ./install $1"
    fi
    return 0
}

# aplicar_paquetes: instala y actualiza lo que decidió planificar, y apunta en el
# estado de cada componente los que ha instalado él (./uninstall quita solo esos)
aplicar_paquetes() {
    local i
    [ ${#PAQ_INSTALAR[@]} -gt 0 ] || [ ${#PAQ_ACTUALIZAR[@]} -gt 0 ] || return 0
    need_sudo "instalar paquetes"
    [ ${#PAQ_INSTALAR[@]} -eq 0 ]   || info "instalando $(lista "${PAQ_INSTALAR[@]}")"
    [ ${#PAQ_ACTUALIZAR[@]} -eq 0 ] || info "actualizando $(lista "${PAQ_ACTUALIZAR[@]}") (si hay versión nueva)"
    case "$GESTOR" in
        apt)
            # install también actualiza los que ya están. Sin recomendados: solo lo
            # imprescindible, que no cambie nada de lo que ya había (con ellos, npm
            # traía bash-completion y build-essential)
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
                ${PAQ_INSTALAR[@]+"${PAQ_INSTALAR[@]}"} ${PAQ_ACTUALIZAR[@]+"${PAQ_ACTUALIZAR[@]}"}
            ;;
        dnf)
            [ ${#PAQ_ACTUALIZAR[@]} -eq 0 ] || $SUDO dnf upgrade -y -q "${PAQ_ACTUALIZAR[@]}"
            [ ${#PAQ_INSTALAR[@]} -eq 0 ]   || $SUDO dnf install -y -q "${PAQ_INSTALAR[@]}"
            ;;
    esac
    for i in "${!F_ID[@]}"; do
        if [ "${F_EST[$i]}" = instalar ] && pkg_installed "${F_PKG[$i]}"; then
            state_add "${F_COMP[$i]}" "${F_PKG[$i]}"
        fi
    done
}
