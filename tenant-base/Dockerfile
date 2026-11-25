FROM alpine:3.24.4

LABEL org.opencontainers.image.title="tenant-base" \
      org.opencontainers.image.description="Phantom-cloud tenant SSH base image (public key auth only)"

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk add --no-cache openssh-server \
    && adduser -D -u 1000 -s /bin/sh tenant \
    && echo 'tenant:*' | chpasswd -e \
    && rm -f /etc/ssh/ssh_host_*_key* \
    && install -d -m 755 /etc/ssh/authorized_keys

COPY sshd_config /etc/ssh/sshd_config
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 2222
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
