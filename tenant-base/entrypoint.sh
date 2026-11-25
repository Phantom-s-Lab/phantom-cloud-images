#!/bin/sh
set -eu

keydir=/etc/ssh/hostkeys

if [ -d "$keydir" ] && [ -w "$keydir" ]; then
    for type in ed25519 rsa; do
        key="$keydir/ssh_host_${type}_key"
        [ -f "$key" ] || ssh-keygen -q -t "$type" -N '' -f "$key"
    done
fi

if ls "$keydir"/ssh_host_*_key >/dev/null 2>&1; then
    cp "$keydir"/ssh_host_*_key /etc/ssh/
    chmod 600 /etc/ssh/ssh_host_*_key
fi
ssh-keygen -A >/dev/null

if [ -d /etc/ssh/authorized_keys.src ]; then
    install -d -m 755 /etc/ssh/authorized_keys
    for src in /etc/ssh/authorized_keys.src/*; do
        [ -f "$src" ] || continue
        install -m 644 "$src" "/etc/ssh/authorized_keys/$(basename "$src")"
    done
fi

if [ "$(stat -c '%U %a' /home/tenant)" != "tenant 700" ]; then
    chown root /home/tenant
    chmod 700 /home/tenant
    chown tenant:tenant /home/tenant
fi

exec /usr/sbin/sshd -D -e
