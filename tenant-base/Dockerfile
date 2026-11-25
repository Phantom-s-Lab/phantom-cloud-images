FROM alpine:3.24.4

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk add --no-cache openssh-server \
    && adduser -D -u 1000 -s /bin/sh tenant \
    && echo 'tenant:*' | chpasswd -e \
    && rm -f /etc/ssh/ssh_host_*_key*

COPY sshd_config /etc/ssh/sshd_config
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 2222
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
