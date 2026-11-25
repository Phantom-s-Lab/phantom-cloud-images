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
sudo chown root:root "$keydir" "$homedir"
sudo chmod 755 "$keydir" "$homedir"

sshdir="$(mktemp -d)"
ssh-keygen -q -t ed25519 -N '' -f "$sshdir/id"
srcdir="$(mktemp -d)"
cp "$sshdir/id.pub" "$srcdir/tenant"
sudo chown -R root:root "$srcdir"
sudo chmod 777 "$srcdir"

run_entrypoint() {
    # shellcheck disable=SC2086
    cid="$(docker run -d $caps -p 127.0.0.1:2222:2222 \
        -v "$keydir:/etc/ssh/hostkeys" -v "$homedir:/home/tenant" \
        -v "$srcdir:/etc/ssh/authorized_keys.src:ro" "$image")"
    sleep 3
    if [ "$(docker inspect -f '{{.State.Running}}' "$cid")" != true ]; then
        docker logs "$cid"
        docker rm -f "$cid" >/dev/null
        echo "FAIL: container exited (pod-equivalent capabilities)"; exit 1
    fi
}

stop_entrypoint() {
    docker rm -f "$cid" >/dev/null
}

ssh_opts="-p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5"

fingerprint() {
    docker run --rm -v "$keydir:/etc/ssh/hostkeys" --entrypoint sh "$image" \
        -c 'ssh-keygen -lf /etc/ssh/hostkeys/ssh_host_ed25519_key.pub'
}

run_entrypoint
echo "ok: starts with pod-equivalent capabilities"

# shellcheck disable=SC2086
user="$(ssh $ssh_opts -i "$sshdir/id" tenant@127.0.0.1 'id -un')"
[ "$user" = tenant ] || { docker logs "$cid"; echo "FAIL: public key login"; exit 1; }
echo "ok: public key login (keys mounted from 0777 dir)"

# shellcheck disable=SC2086
if ssh $ssh_opts -o PubkeyAuthentication=no -o PasswordAuthentication=yes tenant@127.0.0.1 true 2>/dev/null; then
    echo "FAIL: login without public key"; exit 1
fi
echo "ok: login without public key rejected"
stop_entrypoint
first="$(fingerprint)"

sudo chown 1000:1000 "$homedir"
sudo chmod 777 "$homedir"
run_entrypoint
stop_entrypoint
second="$(fingerprint)"
echo "ok: restarts with existing volumes"

[ -n "$first" ] && [ "$first" = "$second" ] || { echo "FAIL: host key not persisted"; exit 1; }
echo "ok: host key persisted across restarts"

mode="$(docker run --rm -v "$homedir:/home/tenant" --entrypoint stat "$image" -c '%U %a' /home/tenant)"
[ "$mode" = "tenant 700" ] || { echo "FAIL: home is $mode"; exit 1; }
echo "ok: home owned by tenant with 700 (fixed from tenant 777)"
