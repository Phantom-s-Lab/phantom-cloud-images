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


caps="--cap-drop ALL --cap-add CHOWN --cap-add SETUID --cap-add SETGID --cap-add SYS_CHROOT --cap-add AUDIT_WRITE --cap-add KILL --security-opt no-new-privileges"
keydir="$(mktemp -d)"
homedir="$(mktemp -d)"

run_entrypoint() {
    # shellcheck disable=SC2086
    cid="$(docker run -d $caps -v "$keydir:/etc/ssh/hostkeys" -v "$homedir:/home/tenant" "$image")"
    sleep 3
    if [ "$(docker inspect -f '{{.State.Running}}' "$cid")" != true ]; then
        docker logs "$cid"
        docker rm -f "$cid" >/dev/null
        echo "FAIL: container exited (pod-equivalent capabilities)"; exit 1
    fi
    docker rm -f "$cid" >/dev/null
}

fingerprint() {
    docker run --rm -v "$keydir:/etc/ssh/hostkeys" --entrypoint sh "$image" \
        -c 'ssh-keygen -lf /etc/ssh/hostkeys/ssh_host_ed25519_key.pub'
}

run_entrypoint
first="$(fingerprint)"
echo "ok: starts with pod-equivalent capabilities"

run_entrypoint
second="$(fingerprint)"
echo "ok: restarts with existing volumes"

[ -n "$first" ] && [ "$first" = "$second" ] || { echo "FAIL: host key not persisted"; exit 1; }
echo "ok: host key persisted across restarts"

owner="$(docker run --rm -v "$homedir:/home/tenant" --entrypoint stat "$image" -c %U /home/tenant)"
[ "$owner" = tenant ] || { echo "FAIL: home owner is $owner"; exit 1; }
echo "ok: home owned by tenant"
