# AImesis care-team web app: static Flutter web build served by nginx on Cloud Run.
# Build the app first (the image does NOT run Flutter):
#   flutter build web --release
#   docker build -t aimesis-web .
FROM nginx:1.27-alpine

ENV PORT=8080 \
    API_URL=http://localhost:8080

# nginx's official entrypoint renders /etc/nginx/templates/*.template with envsubst
# into /etc/nginx/conf.d/ (only ${PORT} is substituted, see NGINX_ENVSUBST_FILTER).
ENV NGINX_ENVSUBST_FILTER=^PORT$
RUN rm -f /etc/nginx/conf.d/default.conf
COPY docker/default.conf.template /etc/nginx/templates/default.conf.template
COPY docker/40-write-config-json.sh /docker-entrypoint.d/40-write-config-json.sh
RUN chmod +x /docker-entrypoint.d/40-write-config-json.sh

COPY build/web/ /usr/share/nginx/html/

EXPOSE 8080
# Base image ENTRYPOINT (/docker-entrypoint.sh) runs docker-entrypoint.d/*
# (writes config.json, renders the template) and then CMD.
CMD ["nginx", "-g", "daemon off;"]
