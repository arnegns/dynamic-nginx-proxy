# Debian's libc supports runtimes that deny pwritev2 (Alpine/musl 1.2.6 does not).
FROM nginx:1.31.10-trixie@sha256:a786635fd3c7b9a57ea089ab1c0713e510f3b548b65fe699ce3d59e4a926b37e

COPY nginx.conf.tpl /etc/nginx/templates/nginx.conf.tpl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
