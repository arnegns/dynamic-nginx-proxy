#!/bin/sh
set -e

ROUTES_CONFIG=""

# Alle ROUTE_<NR>_PATH Variablen finden
for var in $(env | grep -oE '^ROUTE_[0-9]+_PATH' | sort); do
    index=$(echo "$var" | grep -oE '[0-9]+')

    path=$(printenv ROUTE_${index}_PATH)
    dest=$(printenv ROUTE_${index}_DEST)

    if [ -z "$path" ] || [ -z "$dest" ]; then
        echo "⚠ Route $index unvollständig (PATH oder DEST fehlt)"
        continue
    fi

    echo "▶ Generiere Route $index: $path → $dest"

    block="
    location $path {
        proxy_pass $dest;
    "

    # Weitere Optionen für diese Route
    for kv in $(env | grep -oE "^ROUTE_${index}_[A-Z0-9_]+" | sort); do
        key=$(echo "$kv" | sed -E "s/ROUTE_${index}_//")
        val=$(printenv "$kv")

        case "$key" in
            DEST|PATH)
                ;; # schon verarbeitet

            HEADERS)
                # z.B. "X-Foo bar, X-Bar baz"
                for header in $(echo "$val" | tr ',' '\n'); do
                    header_name=$(echo "$header" | awk '{print $1}')
                    header_value=$(echo "$header" | awk '{$1=""; print substr($0,2)}')
                    block="$block
        proxy_set_header $header_name $header_value;"
                done
                ;;

            STRIP_PREFIX)
                if [ "$val" = "true" ]; then
                    block="$block
        rewrite ^$path(.*)$ \$1 break;"
                fi
                ;;

            REWRITE)
                reg=$(echo "$val" | awk '{print $1}')
                rep=$(echo "$val" | awk '{$1=""; print substr($0,2)}')
                block="$block
        rewrite $reg $rep;"
                ;;
            
            TIMEOUT)
                block="$block
        proxy_read_timeout $val;"
                ;;

            *)
                block="$block
        # custom $key
        $key $val;"
                ;;
        esac
    done

    block="$block
    }
    "

    ROUTES_CONFIG="$ROUTES_CONFIG
$block"
done

# Globale Defaults setzen, falls nicht definiert
: "${GLOBAL_PORT:=8080}"
: "${GLOBAL_MAX_BODY_SIZE:=20m}"
: "${GLOBAL_READ_TIMEOUT:=60s}"
: "${GLOBAL_CONNECT_TIMEOUT:=10s}"

# Template rendern
sed \
    -e "s|\${GLOBAL_PORT}|${GLOBAL_PORT}|g" \
    -e "s|\${GLOBAL_MAX_BODY_SIZE}|${GLOBAL_MAX_BODY_SIZE}|g" \
    -e "s|\${GLOBAL_READ_TIMEOUT}|${GLOBAL_READ_TIMEOUT}|g" \
    -e "s|\${GLOBAL_CONNECT_TIMEOUT}|${GLOBAL_CONNECT_TIMEOUT}|g" \
    -e "s|##ROUTES##|${ROUTES_CONFIG}|" \
    /etc/nginx/templates/nginx.conf.tpl > /etc/nginx/nginx.conf

echo "===== Generierte Konfiguration ====="
cat /etc/nginx/nginx.conf
echo "===================================="

exec nginx -g "daemon off;"