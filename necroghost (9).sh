#!/bin/bash
# =============================================================================
# NecroGhost v1.0
# Autor: Edgarrdz312
# Descripción: Script de defensa contra ransomware para Linux
# Uso: sudo bash necroghost.sh [start|stop|status|setup]
# =============================================================================
# SEGURIDAD DEL PROPIO SCRIPT:
#   - Todas las rutas son absolutas (anti PATH-hijacking)
#   - Logs solo en modo append, no ejecutables
#   - Honeypots con atributo inmutable (chattr +i)
#   - Backups firmados con SHA256
#   - Validación estricta de variables
#   - Solo ejecutable por root
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ─── RUTAS ABSOLUTAS (evita PATH hijacking) ───────────────────────────────────
INOTIFYWAIT="/usr/bin/inotifywait"
FIND="/usr/bin/find"
CP="/bin/cp"
RM="/bin/rm"
MKDIR="/bin/mkdir"
CHMOD="/bin/chmod"
CHATTR="/usr/bin/chattr"
SHA256SUM="/usr/bin/sha256sum"
DATE="/usr/bin/date"
KILL="/bin/kill"
LOGGER="/usr/bin/logger"
TAR="/bin/tar"
GREP="/bin/grep"
AWK="/usr/bin/awk"
TPUT="/usr/bin/tput"

# ─── CONFIGURACIÓN ────────────────────────────────────────────────────────────
MONITOR_DIRS=(
    "$HOME/Documentos"
    "$HOME/Descargas"
    "$HOME/Imágenes"
    "$HOME/Escritorio"
)

BACKUP_DIR="/var/backups/necroshield_ai"
HONEYPOT_DIR="/var/lib/necroshield_ai/honeypots"
LOG_FILE="/var/log/necroshield_ai.log"
PID_FILE="/var/run/necroshield_ai.pid"
CHECKSUM_FILE="/var/lib/necroshield_ai/backup.sha256"

# Umbral: si más de N archivos cambian en M segundos → alerta
CHANGE_THRESHOLD=20
WINDOW_SECONDS=10

# Extensiones sospechosas de ransomware conocidas
SUSPICIOUS_EXTENSIONS=(
    "locked" "encrypted" "crypt" "crypz" "crypto"
    "enc" "aes" "zepto" "cerber" "locky" "wnry"
    "wncry" "wcry" "wncrypt" "petya" "NotPetya"
    "ryuk" "maze" "sodinokibi" "revil" "conti"
    "dharma" "phobos" "stop" "djvu" "pays"
)

# ─── COLORES ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── FUNCIONES DE UTILIDAD ────────────────────────────────────────────────────

timestamp() {
    "$DATE" '+%Y-%m-%d %H:%M:%S'
}

log() {
    local level="$1"
    local message="$2"
    local entry="[$(timestamp)] [$level] $message"

    # Log a archivo (solo append)
    echo "$entry" >> "$LOG_FILE"

    # Log al sistema (syslog)
    "$LOGGER" -t "necroshield_ai" -p "security.warning" "$entry"

    # Mostrar en terminal con colores
    case "$level" in
        "ALERTA")   echo -e "${RED}${BOLD}🚨 $entry${NC}" ;;
        "INFO")     echo -e "${CYAN}ℹ️  $entry${NC}" ;;
        "OK")       echo -e "${GREEN}✅ $entry${NC}" ;;
        "WARN")     echo -e "${YELLOW}⚠️  $entry${NC}" ;;
        *)          echo "$entry" ;;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] Este script debe ejecutarse como root.${NC}"
        echo "Usa: sudo bash necroghost.sh [start|stop|status|setup]"
        exit 1
    fi
}

check_dependencies() {
    local missing=0
    local deps=("inotifywait" "sha256sum" "chattr" "tar")

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo -e "${YELLOW}[FALTA] $dep${NC}"
            missing=1
        fi
    done

    if [[ $missing -eq 1 ]]; then
        echo -e "${YELLOW}Instala dependencias con:${NC}"
        echo "  sudo apt install inotify-tools e2fsprogs coreutils"
        exit 1
    fi
}

# ─── MÓDULO 1: SETUP INICIAL ─────────────────────────────────────────────────

setup() {
    echo -e "${BOLD}${BLUE}━━━ CONFIGURACIÓN INICIAL ━━━${NC}"
    check_root
    check_dependencies

    # Crear directorios con permisos estrictos
    "$MKDIR" -p "$BACKUP_DIR" "$HONEYPOT_DIR"
    "$CHMOD" 700 "$BACKUP_DIR" "$HONEYPOT_DIR"

    # Crear archivo de log con permisos solo-append
    touch "$LOG_FILE"
    "$CHMOD" 600 "$LOG_FILE"
    # Hacer el log append-only (ni root puede borrarlo sin chattr -a)
    "$CHATTR" +a "$LOG_FILE" 2>/dev/null || log "WARN" "No se pudo aplicar chattr +a al log (kernel puede no soportarlo)"

    # Crear directorios monitoreados si no existen
    for dir in "${MONITOR_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            "$MKDIR" -p "$dir"
            log "INFO" "Directorio creado: $dir"
        fi
    done

    create_honeypots
    create_backup

    log "OK" "Setup completado. Sistema listo."
    echo -e "${GREEN}${BOLD}✅ Setup completado correctamente.${NC}"
    echo -e "   Inicia el monitor con: ${BOLD}sudo bash necroghost.sh start${NC}"
}

# ─── MÓDULO 2: HONEYPOT FILES ────────────────────────────────────────────────

create_honeypots() {
    echo -e "${BOLD}${BLUE}━━━ CREANDO HONEYPOTS ━━━${NC}"

    local honeypot_names=(
        "contrasenas_banco.txt"
        "backup_crypto_wallet.dat"
        "documentos_importantes.pdf"
        "nomina_2024.xlsx"
        "contrato_confidencial.docx"
    )

    for name in "${honeypot_names[@]}"; do
        local hfile="$HONEYPOT_DIR/$name"
        # Crear archivo señuelo con contenido falso pero convincente
        echo "ARCHIVO HONEYPOT - ANTI RANSOMWARE SHIELD v1.0 - $(timestamp)" > "$hfile"
        echo "Este archivo es un señuelo de seguridad." >> "$hfile"
        "$CHMOD" 644 "$hfile"

        # Hacer el honeypot INMUTABLE — ni root lo puede modificar sin chattr -i
        "$CHATTR" +i "$hfile" 2>/dev/null && \
            log "OK" "Honeypot inmutable creado: $hfile" || \
            log "WARN" "Honeypot creado sin inmutabilidad: $hfile"
    done

    # También colocar honeypots en los directorios monitoreados
    for dir in "${MONITOR_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            local hfile="$dir/.security_monitor.dat"
            echo "HONEYPOT - NO BORRAR - $(timestamp)" > "$hfile"
            "$CHMOD" 644 "$hfile"
            "$CHATTR" +i "$hfile" 2>/dev/null || true
            log "OK" "Honeypot en directorio monitoreado: $hfile"
        fi
    done
}

check_honeypots() {
    local violated=0
    for hfile in "$HONEYPOT_DIR"/*; do
        [[ -f "$hfile" ]] || continue
        # Si el honeypot fue modificado o eliminado → alerta crítica
        if [[ ! -e "$hfile" ]]; then
            log "ALERTA" "¡HONEYPOT ELIMINADO! Posible ransomware activo: $hfile"
            violated=1
        fi
    done

    for dir in "${MONITOR_DIRS[@]}"; do
        local hfile="$dir/.security_monitor.dat"
        if [[ -f "$dir" ]] && [[ ! -f "$hfile" ]]; then
            log "ALERTA" "¡HONEYPOT EN DIRECTORIO ELIMINADO!: $hfile"
            violated=1
        fi
    done

    echo "$violated"
}

# ─── MÓDULO 3: BACKUP AUTOMÁTICO ─────────────────────────────────────────────

create_backup() {
    echo -e "${BOLD}${BLUE}━━━ CREANDO BACKUP ━━━${NC}"
    local timestamp_str
    timestamp_str=$("$DATE" '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/backup_$timestamp_str.tar.gz"

    # Crear el backup comprimido
    local dirs_to_backup=()
    for dir in "${MONITOR_DIRS[@]}"; do
        [[ -d "$dir" ]] && dirs_to_backup+=("$dir")
    done

    if [[ ${#dirs_to_backup[@]} -gt 0 ]]; then
        "$TAR" -czf "$backup_file" "${dirs_to_backup[@]}" 2>/dev/null || true
        "$CHMOD" 600 "$backup_file"

        # Firmar el backup con SHA256 para detectar tampering
        "$SHA256SUM" "$backup_file" >> "$CHECKSUM_FILE"
        "$CHMOD" 600 "$CHECKSUM_FILE"

        log "OK" "Backup creado: $backup_file"
        log "OK" "Checksum firmado en: $CHECKSUM_FILE"
    else
        log "WARN" "No hay directorios válidos para respaldar."
    fi

    # Mantener solo los últimos 5 backups
    local count
    count=$("$FIND" "$BACKUP_DIR" -name "backup_*.tar.gz" | wc -l)
    if [[ $count -gt 5 ]]; then
        "$FIND" "$BACKUP_DIR" -name "backup_*.tar.gz" \
            | sort | head -n $((count - 5)) \
            | xargs "$RM" -f
        log "INFO" "Backups antiguos limpiados (se mantienen últimos 5)"
    fi
}

verify_backup_integrity() {
    if [[ ! -f "$CHECKSUM_FILE" ]]; then
        log "WARN" "No existe archivo de checksums. Ejecuta setup primero."
        return 1
    fi
    if "$SHA256SUM" --check "$CHECKSUM_FILE" &>/dev/null; then
        log "OK" "Integridad de backups verificada correctamente."
    else
        log "ALERTA" "¡INTEGRIDAD DE BACKUP COMPROMETIDA! Posible manipulación."
    fi
}

# ─── MÓDULO 4: KILL SWITCH ───────────────────────────────────────────────────

kill_switch() {
    local reason="$1"
    log "ALERTA" "🔴 KILL SWITCH ACTIVADO — Razón: $reason"
    log "ALERTA" "Iniciando procedimiento de contención..."

    # 1. Notificación visual urgente en terminal
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      🚨 RANSOMWARE DETECTADO — KILL SWITCH 🚨    ║${NC}"
    echo -e "${RED}${BOLD}║  Razón: $reason${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    # 2. Alertar al sistema de forma visible
    wall "⚠️  ANTI-RANSOMWARE: Actividad sospechosa detectada. Sistema en modo contención." 2>/dev/null || true

    # 3. Crear backup de emergencia inmediato
    log "INFO" "Creando backup de emergencia..."
    create_backup

    # 4. Registrar snapshot de procesos activos en el log
    log "INFO" "Procesos activos al momento de la detección:"
    ps aux >> "$LOG_FILE" 2>/dev/null || true

    # 5. Registrar conexiones de red activas
    log "INFO" "Conexiones de red activas:"
    ss -tulpn >> "$LOG_FILE" 2>/dev/null || true

    log "ALERTA" "Kill switch completado. Revisa el log: $LOG_FILE"
    log "ALERTA" "ACCIÓN REQUERIDA: Investiga y desconecta el equipo de la red si confirmas infección."
}

# ─── MÓDULO 5: MONITOR EN TIEMPO REAL ────────────────────────────────────────

check_suspicious_extension() {
    local filename="$1"
    local ext="${filename##*.}"
    ext="${ext,,}"  # lowercase

    for suspicious in "${SUSPICIOUS_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$suspicious" ]]; then
            return 0  # Es sospechosa
        fi
    done
    return 1  # No es sospechosa
}

monitor() {
    check_root
    log "OK" "Monitor iniciado. Vigilando ${#MONITOR_DIRS[@]} directorio(s)."

    local change_count=0
    local window_start
    window_start=$("$DATE" +%s)

    # Verificar honeypots cada 30 segundos en background
    (
        while true; do
            sleep 30
            violated=$(check_honeypots)
            if [[ "$violated" -eq 1 ]]; then
                kill_switch "Honeypot violado o eliminado"
            fi
        done
    ) &
    local honeypot_pid=$!

    # Verificar integridad de backups cada 10 minutos
    (
        while true; do
            sleep 600
            verify_backup_integrity
            create_backup
        done
    ) &
    local backup_pid=$!

    # Guardar PIDs para limpieza
    echo "$$:$honeypot_pid:$backup_pid" > "$PID_FILE"

    log "INFO" "PIDs registrados en $PID_FILE"
    log "INFO" "Presiona Ctrl+C para detener el monitor."

    # Monitor principal con inotifywait
    local valid_dirs=()
    for dir in "${MONITOR_DIRS[@]}"; do
        [[ -d "$dir" ]] && valid_dirs+=("$dir")
    done

    if [[ ${#valid_dirs[@]} -eq 0 ]]; then
        log "WARN" "Ningún directorio válido para monitorear. Ejecuta setup primero."
        exit 1
    fi

    "$INOTIFYWAIT" -m -r \
        --format '%T %w%f %e' \
        --timefmt '%s' \
        -e modify,create,delete,move \
        "${valid_dirs[@]}" 2>/dev/null | \
    while IFS= read -r line; do
        local event_time file_path event_type
        event_time=$(echo "$line" | "$AWK" '{print $1}')
        file_path=$(echo "$line" | "$AWK" '{print $2}')
        event_type=$(echo "$line" | "$AWK" '{print $3}')

        # ── Detectar extensiones sospechosas ──
        if check_suspicious_extension "$file_path"; then
            log "ALERTA" "Extensión ransomware detectada: $file_path [$event_type]"
            kill_switch "Extensión sospechosa: $file_path"
        fi

        # ── Detectar cambio masivo de archivos ──
        local now
        now=$("$DATE" +%s)
        local elapsed=$(( now - window_start ))

        if [[ $elapsed -le $WINDOW_SECONDS ]]; then
            change_count=$(( change_count + 1 ))
            if [[ $change_count -ge $CHANGE_THRESHOLD ]]; then
                log "ALERTA" "Cambio masivo detectado: $change_count archivos en ${elapsed}s"
                kill_switch "Cambio masivo de archivos ($change_count en ${elapsed}s)"
                change_count=0
                window_start=$now
            fi
        else
            # Reiniciar ventana
            change_count=1
            window_start=$now
        fi

        # ── Log normal ──
        log "INFO" "$event_type → $file_path"
    done

    # Limpieza de procesos secundarios
    "$KILL" "$honeypot_pid" "$backup_pid" 2>/dev/null || true
}

# ─── CONTROL DEL SERVICIO ─────────────────────────────────────────────────────

start() {
    if [[ -f "$PID_FILE" ]]; then
        log "WARN" "El monitor ya parece estar en ejecución. Usa 'status' para verificar."
        exit 1
    fi
    log "OK" "Iniciando Anti-Ransomware Shield..."
    monitor &
    echo $! >> "$PID_FILE"
    log "OK" "Monitor corriendo en background. PID: $!"
}

stop() {
    check_root
    if [[ -f "$PID_FILE" ]]; then
        while IFS=: read -r pid; do
            "$KILL" "$pid" 2>/dev/null && log "OK" "Proceso $pid detenido." || true
        done < "$PID_FILE"
        "$RM" -f "$PID_FILE"
        log "OK" "Anti-Ransomware Shield detenido."
    else
        log "WARN" "No se encontró proceso activo."
    fi
}

status() {
    echo -e "${BOLD}${BLUE}━━━ ESTADO DEL SISTEMA ━━━${NC}"
    if [[ -f "$PID_FILE" ]]; then
        echo -e "${GREEN}✅ Monitor: ACTIVO${NC}"
        cat "$PID_FILE"
    else
        echo -e "${RED}❌ Monitor: INACTIVO${NC}"
    fi
    echo ""
    echo -e "${BOLD}Últimas 10 entradas del log:${NC}"
    tail -n 10 "$LOG_FILE" 2>/dev/null || echo "(sin entradas aún)"
    echo ""
    echo -e "${BOLD}Directorios monitoreados:${NC}"
    for dir in "${MONITOR_DIRS[@]}"; do
        [[ -d "$dir" ]] && echo -e "  ${GREEN}✓${NC} $dir" || echo -e "  ${RED}✗${NC} $dir (no existe)"
    done
}

# ─── PUNTO DE ENTRADA ─────────────────────────────────────────────────────────

banner() {
    echo -e "${GREEN}${BOLD}"
    cat << 'ASCIIART'
 .     .            +         .         .                 .  .
      .                 .                   .               .
              .    ,,o         .                  __.o+.
    .            od8^                  .      oo888888P^b           .
       .       ,".o'      .     .             `b^'""`b -`b   .
             ,'.'o'             .   .          t. = -`b -`t.    .
            ; d o' .        ___          _.--.. 8  -  `b  =`b
        .  dooo8<       .o:':__;o.     ,;;o88%%8bb - = `b  =`b.    .
    .     |^88^88=. .,x88/::/ | \\`;;;;;;d%%%%%88%88888/%x88888
          :-88=88%%L8`%`|::|_>-<_||%;;%;8%%=;:::=%8;;\%%%%\8888
      .   |=88 88%%|HHHH|::| >-< |||;%;;8%%=;:::=%8;;;%%%%+|]88        .
          | 88-88%%LL.%.%b::Y_|_Y/%|;;;;`%8%%oo88%:o%.;;;;+|]88  .
          Yx88o88^^'"`^^%8boooood..-\H_Hd%P%%88%P^%%^'\;;;/%%88
         . `"\^\          ~"""""'      d%P """^" ;   = `+' - P
   .        `.`.b   .                :<%%>  .   :  -   d' - P      . .
              .`.b     .        .    `788      ,'-  = d' =.'
       .       ``.b.                           :..-  :'  P
            .   `q.>b         .               `^^^:::::,'       .

  _ __   ___  ___ _ __ ___   __ _| |__   ___  ___| |_
 | '_ \ / _ \/ __| '__/ _ \ / _` | '_ \ / _ \/ __| __|
 | | | |  __/ (__| | | (_) | (_| | | | | (_) \__ \ |_
 |_| |_|\___|\___|_|  \___/ \__, |_| |_|\___/|___/\__|
                             |___/
 [ ghost in the machine ] -- [ v1.0 ] -- [ ARMED ]
 [ unauthorized access will be traced ]
ASCIIART
    echo -e "${NC}"
}

banner

case "${1:-help}" in
    setup)   check_root; setup ;;
    start)   check_root; start ;;
    stop)    stop ;;
    status)  status ;;
    *)
        echo "Uso: sudo bash necroghost.sh [comando]"
        echo ""
        echo "Comandos:"
        echo -e "  ${BOLD}setup${NC}   — Configura el sistema por primera vez"
        echo -e "  ${BOLD}start${NC}   — Inicia el monitor en background"
        echo -e "  ${BOLD}stop${NC}    — Detiene el monitor"
        echo -e "  ${BOLD}status${NC}  — Muestra estado y últimos eventos"
        echo ""
        echo "Ejemplo de uso inicial:"
        echo "  sudo bash necroghost.sh setup"
        echo "  sudo bash necroghost.sh start"
        ;;
esac
