#!/bin/sh
set -e

ROUTES_CONFIG=""

# collect all environment variables named ROUTE_<number>_PATH and generate
# a corresponding nginx `location` block for each.

for var in $(env | grep -oE '^ROUTE_[0-9]+_PATH' | sort); do
    index=$(echo "$var" | grep -oE '[0-9]+')

    path=$(printenv ROUTE_${index}_PATH)
    dest=$(printenv ROUTE_${index}_DEST)

    if [ -z "$path" ] || [ -z "$dest" ]; then
        echo "⚠ Route $index incomplete (PATH or DEST missing)"
        continue
    fi

    echo "▶ Generating route $index: $path → $dest"

    block="
    location $path {
        proxy_pass $dest;
    "

    for kv in $(env | grep -oE "^ROUTE_${index}_[A-Z0-9_]+" | sort); do
        key=$(echo "$kv" | sed -E "s/ROUTE_${index}_//")
        val=$(printenv "$kv")

        case "$key" in
            DEST|PATH)
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