#!/bin/sh
set -eu

if ls /etc/ssh/hostkeys/ssh_host_*_key >/dev/null 2>&1; then
    cp /etc/ssh/hostkeys/ssh_host_*_key /etc/ssh/
    chmod 600 /etc/ssh/ssh_host_*_key
fi
ssh-keygen -A >/dev/null

exec /usr/sbin/sshd -D -e
