events {}

http {
    server {
        listen ${GLOBAL_PORT};

        # Globale Settings (konfigurierbar per ENV)
        client_max_body_size ${GLOBAL_MAX_BODY_SIZE};
        proxy_read_timeout ${GLOBAL_READ_TIMEOUT};
        proxy_connect_timeout ${GLOBAL_CONNECT_TIMEOUT};

        ##ROUTES##
    }
}