#!/bin/sh
set -eu

image="$1"

docker run --rm --entrypoint sh "$image" -c '
    set -eu
    if ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
        echo "FAIL: host keys baked into image"; exit 1
    fi
    echo "ok: no host keys in image"

    if command -v sudo >/dev/null; then
        echo "FAIL: sudo installed"; exit 1
    fi
    echo "ok: no sudo"

    ssh-keygen -A >/dev/null
    /usr/sbin/sshd -t
    echo "ok: sshd -t"

    cfg="$(/usr/sbin/sshd -T)"
    for want in "port 2222" "permitrootlogin no" "passwordauthentication no" \
                "kbdinteractiveauthentication no" "pubkeyauthentication yes" \
                "allowusers tenant"; do
        echo "$cfg" | grep -qx "$want" || { echo "FAIL: $want"; exit 1; }
        echo "ok: $want"
    done
'
