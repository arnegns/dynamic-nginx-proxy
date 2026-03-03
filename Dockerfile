FROM nginx:alpine

RUN apk add --no-cache gettext

COPY nginx.conf.tpl /etc/nginx/templates/nginx.conf.tpl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]