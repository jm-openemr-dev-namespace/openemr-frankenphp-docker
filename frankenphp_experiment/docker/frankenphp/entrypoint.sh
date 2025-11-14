#!/usr/bin/env bash
set -euo pipefail

OE_ROOT="${OPENEMR_ROOT:-/var/www/localhost/htdocs/openemr}"
AUTO_CONFIG="/opt/openemr/auto_configure.php"
SQLCONF_FILE="${OE_ROOT}/sites/default/sqlconf.php"

MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_ROOT_USER="${MYSQL_ROOT_USER:-root}"
MYSQL_ROOT_PASS="${MYSQL_ROOT_PASS:-root}"
MYSQL_USER="${MYSQL_USER:-openemr}"
MYSQL_PASS="${MYSQL_PASS:-openemr}"
MYSQL_DATABASE="${MYSQL_DATABASE:-openemr}"
MYSQL_COLLATION="${MYSQL_COLLATION:-utf8mb4_general_ci}"
OE_USER="${OE_USER:-admin}"
OE_USER_NAME="${OE_USER_NAME:-Administrator}"
OE_PASS="${OE_PASS:-pass}"
MANUAL_SETUP="${MANUAL_SETUP:-no}"

if [ -z "${FRANKENPHP_MAX_WORKERS:-}" ]; then
    if command -v nproc >/dev/null 2>&1; then
        FRANKENPHP_MAX_WORKERS="$(nproc --all 2>/dev/null || nproc)"
    else
        FRANKENPHP_MAX_WORKERS="4"
    fi
fi

if [ -z "${FRANKENPHP_REQUEST_POOL_CAPACITY:-}" ]; then
    if [[ "${FRANKENPHP_MAX_WORKERS}" =~ ^[0-9]+$ ]]; then
        FRANKENPHP_REQUEST_POOL_CAPACITY="$((FRANKENPHP_MAX_WORKERS * 4))"
    else
        FRANKENPHP_REQUEST_POOL_CAPACITY="16"
    fi
fi

export FRANKENPHP_MAX_WORKERS FRANKENPHP_REQUEST_POOL_CAPACITY

wait_for_mysql() {
    local retries=60
    while [ $retries -gt 0 ]; do
        if mariadb \
            --host="${MYSQL_HOST}" \
            --port="${MYSQL_PORT}" \
            --user="${MYSQL_ROOT_USER}" \
            --password="${MYSQL_ROOT_PASS}" \
            --connect-timeout=5 \
            -e "SELECT 1" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
        retries=$((retries-1))
    done
    echo "Timed out waiting for MySQL at ${MYSQL_HOST}:${MYSQL_PORT}" >&2
    return 1
}

is_configured() {
    php -r "if (is_file('${SQLCONF_FILE}')) { require '${SQLCONF_FILE}'; echo isset(\$config) ? \$config : 0; } else { echo 0; }"
}

run_auto_configure() {
    if [ ! -f "${AUTO_CONFIG}" ]; then
        echo "auto_configure.php not found; skipping automated install" >&2
        return 0
    fi

    echo "Running OpenEMR auto configuration..."
    php "${AUTO_CONFIG}" \
        server="${MYSQL_HOST}" \
        port="${MYSQL_PORT}" \
        root="${MYSQL_ROOT_USER}" \
        rootpass="${MYSQL_ROOT_PASS:-BLANK}" \
        login="${MYSQL_USER}" \
        pass="${MYSQL_PASS}" \
        dbname="${MYSQL_DATABASE}" \
        collate="${MYSQL_COLLATION}" \
        iuser="${OE_USER}" \
        iuname="${OE_USER_NAME}" \
        iuserpass="${OE_PASS}" \
        site="default" \
        loginhost="${MYSQL_HOST}"
}

ensure_permissions() {
    chown -R www-data:www-data "${OE_ROOT}"
    chmod 770 "${OE_ROOT}/sites/default/documents"
}

if [ "${MANUAL_SETUP}" != "yes" ]; then
    wait_for_mysql
    CONFIG_STATE=$(is_configured)
    if [ "${CONFIG_STATE}" = "0" ]; then
        run_auto_configure
    fi
fi

ensure_permissions

exec gosu www-data "$@"
