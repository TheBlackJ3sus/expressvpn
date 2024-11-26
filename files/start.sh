#!/bin/bash

if [[ $AUTO_UPDATE = "on" ]]; then
    DEBIAN_FRONTEND=noninteractive apt update && apt -y -o Dpkg::Options::="--force-confdef" -o \
    Dpkg::Options::="--force-confnew" install -y --only-upgrade expressvpn --no-install-recommends \
    && apt autoclean && apt clean && apt autoremove && rm -rf /var/lib/apt/lists/* && rm -rf /var/log/*.log
fi

if [[ -f "/etc/resolv.conf" ]]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak
    umount /etc/resolv.conf &>/dev/null
    cp /etc/resolv.conf.bak /etc/resolv.conf
    rm /etc/resolv.conf.bak
fi

sed -i 's/DAEMON_ARGS=.*/DAEMON_ARGS=""/' /etc/init.d/expressvpn

output=$(service expressvpn restart)
if echo "$output" | grep -q "failed!" > /dev/null
then
    echo "Service expressvpn restart failed!"
    exit 1
fi

output=$(expect -f /expressvpn/activate.exp "$CODE")
if echo "$output" | grep -q "Please activate your account" > /dev/null || echo "$output" | grep -q "Activation failed" > /dev/null
then
    echo "Activation failed!"
    exit 1
fi

expressvpn preferences set preferred_protocol $PROTOCOL
expressvpn preferences set lightway_cipher $CIPHER
expressvpn preferences set send_diagnostics false
expressvpn preferences set block_trackers true
bash /expressvpn/uname.sh
expressvpn preferences set auto_connect true
expressvpn connect $SERVER || exit

for i in $(echo $WHITELIST_DNS | sed "s/ //g" | sed "s/,/ /g")
do
    iptables -A xvpn_dns_ip_exceptions -d ${i}/32 -p udp -m udp --dport 53 -j ACCEPT
    echo "allowing dns server traffic in iptables: ${i}"
done

if [[ $SOCKS = "on" ]]; then
    SOCKS_CMD="hev-socks5-server /expressvpn/socks_config.yml"

    if [[ -n "$SOCKS_WORKERS" && "$SOCKS_WORKERS" != 4 ]]; then
        sed -i "s/  workers: 4/  workers: $SOCKS_WORKERS/" /expressvpn/socks_config.yml
    fi
    
    if [[ -n "$SOCKS_PORT" && "$SOCKS_PORT" != 1080 ]]; then
        sed -i "s/  port: 1080/  port: $SOCKS_PORT/" /expressvpn/socks_config.yml
    fi

    if [[ -n "$SOCKS_IP" && "$SOCKS_IP" != '::' ]]; then
        sed -i "s/  listen-address: '::'/  listen-address: $SOCKS_IP/" /expressvpn/socks_config.yml
    fi

    if [[ -n "$SOCKS_AUTH" ]]; then
        sed -i "s/#auth:/auth:/" /expressvpn/socks_config.yml
        sed -i "s/#  username:/  username: $(echo $SOCKS_AUTH | cut -d ':' -f 1)/" /expressvpn/socks_config.yml
        sed -i "s/#  password:/  password: $(echo $SOCKS_AUTH | cut -d ':' -f 2)/" /expressvpn/socks_config.yml
    fi

    if [[ -n "$SOCKS_LOGS_LEVEL" && "$SOCKS_LOGS_LEVEL" != 'warn' ]]; then
        sed -i "s/#  log-level: warn/  log-level: $SOCKS_LOGS_LEVEL/" /expressvpn/socks_config.yml
    fi

    cat /expressvpn/socks_config.yml

    
    $SOCKS_CMD &
fi

exec "$@"
