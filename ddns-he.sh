#!/bin/sh
# Определяем директорию, где лежит скрипт
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/ddns-he.log"
# Функция логирования
log() {
    echo "$(date '+%d-%m-%Y %H:%M:%S') - $*" >> "$LOG_FILE"
    logger -t "DDNS-HE" "$*"  # также отправляем в системный лог
}
log "=== Запуск обновления DDNS для HE.net ==="
# Настройки HE.net
TunnelID="00000000"     		# Замените Tunnel ID
USERNAME="login"               # Логин
PASSWORD="password"     # Update Key из панели HE.net
# Получаем внешний IP
WAN_IP=$(nvram get wan0_ipaddr)
[ -z "$WAN_IP" ] && WAN_IP=$(nvram get wan_ipaddr)
if [ -z "$WAN_IP" ] || ! echo "$WAN_IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    log "Ошибка: не удалось определить внешний IP-адрес"
    exit 1
fi
log "Текущий внешний IP: $WAN_IP"
# Файл для хранения последнего отправленного IP (в той же папке)
IP_FILE="$SCRIPT_DIR/ddns-he-last-ip"
# Проверяем, изменился ли IP
if [ -f "$IP_FILE" ]; then
    LAST_IP=$(cat "$IP_FILE")
    if [ "$LAST_IP" = "$WAN_IP" ]; then
        log "IP не изменился. Обновление не требуется."
        exit 0
    else
        log "IP изменился: был $LAST_IP, стал $WAN_IP"
    fi
else
    log "Файл с предыдущим IP не найден. Будет выполнено первое обновление."
fi
# Отправляем запрос к HE.net
RESPONSE=$(curl -s -m 15 --retry 2 "https://ipv4.tunnelbroker.net/nic/update?username=$USERNAME&password=$PASSWORD&hostname=$TunnelID&&myip=$WAN_IP")
log "Ответ от HE.net: $RESPONSE"
# Анализируем ответ
case "$RESPONSE" in
    *"good"*)
        echo "$WAN_IP" > "$IP_FILE"
        log "Успешно обновили IP на $WAN_IP"
        ;;
    *"nochg"*)
        echo "$WAN_IP" > "$IP_FILE"
        log "IP уже актуален на стороне HE.net (nochg)"
        ;;
    *"badauth"*)
        log "Ошибка авторизации! Проверьте USERNAME и PASSWORD (Update Key)."
        ;;
    *"notfqdn"*)
        log "Ошибка: hostname не является полным доменным именем (notfqdn)."
        ;;
    *"nohost"*)
        log "Ошибка: указанный hostname не существует или не принадлежит учётной записи."
        ;;
    *"abuse"*)
        log "Ошибка: запрос заблокирован из-за частых попыток (abuse)."
        ;;
    *)
        log "Неизвестный ответ или ошибка: '$RESPONSE'"
        ;;
esac
log "=== Завершение обновления ==="
