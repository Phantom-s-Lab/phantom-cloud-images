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

chown tenant:tenant /home/tenant
chmod 700 /home/tenant

exec /usr/sbin/sshd -D -e
