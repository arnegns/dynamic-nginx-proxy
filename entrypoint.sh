#!/bin/sh
set -e

ROUTES_CONFIG=""

# Safe environment lookup: returns empty string for unset vars without failing
# under `set -e`.
get_env() {
    eval "printf '%s' \"\${$1-}\""
}

# collect all environment variables named ROUTE_<number>_PATH and generate
# a corresponding nginx `location` block for each.

for var in $(env | grep -oE '^ROUTE_[0-9]+_PATH' | sort); do
    index=$(echo "$var" | grep -oE '[0-9]+')

    path=$(get_env ROUTE_${index}_PATH)
    dest=$(get_env ROUTE_${index}_DEST)
    redirect=$(get_env ROUTE_${index}_REDIRECT)
    redirect_code=$(get_env ROUTE_${index}_REDIRECT_CODE)

    if [ -z "$path" ] || { [ -z "$dest" ] && [ -z "$redirect" ]; }; then
        echo "Route $index incomplete (PATH missing or neither DEST nor REDIRECT set)"
        continue
    fi

    if [ -z "$redirect_code" ]; then
        redirect_code="302"
    fi

    if [ -n "$redirect" ]; then
        echo "Generating route $index: $path -> redirect($redirect_code) $redirect"
        block="
        location $path {
                return $redirect_code $redirect;
        }
        "

        ROUTES_CONFIG="$ROUTES_CONFIG
$block"
        continue
    fi

    echo "Generating route $index: $path -> $dest"

    block="
        location $path {
                proxy_pass $dest;
    "

    for kv in $(env | grep -oE "^ROUTE_${index}_[A-Z0-9_]+" | sort); do
        key=$(echo "$kv" | sed -E "s/ROUTE_${index}_//")
        val=$(get_env "$kv")

        case "$key" in
            DEST|PATH|REDIRECT|REDIRECT_CODE)
                ;; # already handled

            HEADERS)
                # e.g. "X-Foo bar, X-Bar baz"
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
                rewrite ^$path$ / break;
                rewrite ^$path/(.*)$ /\$1 break;"
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

            PROXY_SSL_VERIFY)
                block="$block
                proxy_ssl_verify $val;"
                ;;

            PROXY_SSL_SERVER_NAME)
                block="$block
                proxy_ssl_server_name $val;"
                ;;

            PROXY_SSL_NAME)
                block="$block
                proxy_ssl_name $val;"
                ;;

            HOST)
                block="$block
                proxy_set_header Host $val;"
                ;;

            *)
                directive=$(echo "$key" | tr 'A-Z' 'a-z')
                block="$block
                # custom $directive
                $directive $val;"
                ;;
        esac
    done

    block="$block
        }
        "

    ROUTES_CONFIG="$ROUTES_CONFIG
$block"
done

# set global defaults if not defined
: "${GLOBAL_PORT:=8080}"
: "${GLOBAL_MAX_BODY_SIZE:=20m}"
: "${GLOBAL_READ_TIMEOUT:=60s}"
: "${GLOBAL_CONNECT_TIMEOUT:=10s}"
: "${DEBUG:=false}"

# render template
tmpfile=/tmp/routes.conf
printf '%s' "$ROUTES_CONFIG" > "$tmpfile"

sed \
    -e "s|\${GLOBAL_PORT}|${GLOBAL_PORT}|g" \
    -e "s|\${GLOBAL_MAX_BODY_SIZE}|${GLOBAL_MAX_BODY_SIZE}|g" \
    -e "s|\${GLOBAL_READ_TIMEOUT}|${GLOBAL_READ_TIMEOUT}|g" \
    -e "s|\${GLOBAL_CONNECT_TIMEOUT}|${GLOBAL_CONNECT_TIMEOUT}|g" \
    /etc/nginx/templates/nginx.conf.tpl > /etc/nginx/nginx.conf.tmp

# insert routes file in place of marker and delete marker line
sed -i "/##ROUTES##/{r $tmpfile
d}" /etc/nginx/nginx.conf.tmp

mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf

# clean up temporary file(s)
rm -f "$tmpfile"

if [ "${DEBUG}" = "true" ] ; then
    echo "===== Generated configuration ====="
    cat /etc/nginx/nginx.conf
    echo "===================================="
fi

exec nginx -g "daemon off;"