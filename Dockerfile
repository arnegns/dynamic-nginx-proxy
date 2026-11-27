FROM nginx:1.31.10-alpine3.24@sha256:7fc0fb4af7bf006aeb31aea88069976060f8f0a0a86b667126742cc17f4e31ae

COPY nginx.conf.tpl /etc/nginx/templates/nginx.conf.tpl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
