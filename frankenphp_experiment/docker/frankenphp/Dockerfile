# syntax=docker/dockerfile:1.7

ARG FRANKENPHP_IMAGE=docker.io/dunglas/frankenphp:1-php8.3
FROM ${FRANKENPHP_IMAGE} AS base

ARG OPENEMR_ROOT=/var/www/localhost/htdocs/openemr
ENV OPENEMR_ROOT=${OPENEMR_ROOT} \
    COMPOSER_ALLOW_SUPERUSER=1 \
    PATH="${OPENEMR_ROOT}/vendor/bin:${PATH}"

WORKDIR ${OPENEMR_ROOT}
USER root

# Install OS-level packages (mysql client, build tools, node, etc.)
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        git \
        gnupg \
        gosu \
        build-essential \
        python3 \
        libcurl4-openssl-dev \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libldap2-dev \
        libmagickwand-dev \
        libonig-dev \
        libpng-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        libzip-dev \
        mariadb-client \
        nodejs \
        npm \
        rsync \
        unzip; \
    rm -rf /var/lib/apt/lists/*

# Enable the PHP extensions OpenEMR depends on.
RUN install-php-extensions \
        bcmath \
        exif \
        gd \
        intl \
        ldap \
        mysqli \
        opcache \
        pcntl \
        pdo_mysql \
        redis \
        soap \
        sockets \
        zip \
        imagick

# Install Composer (not bundled by default in the FrankenPHP image)
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY docker/frankenphp/php.ini /usr/local/etc/php/conf.d/openemr.ini
COPY docker/frankenphp/Caddyfile /etc/caddy/Caddyfile
COPY docker/frankenphp/entrypoint.sh /usr/local/bin/frankenphp-entrypoint

# Bring in the OpenEMR source as well as the Docker auto_configure helper from the DevOps repo.
COPY openemr ${OPENEMR_ROOT}
COPY devops/docker/openemr/7.0.4/auto_configure.php /opt/openemr/auto_configure.php

RUN chmod +x /usr/local/bin/frankenphp-entrypoint \
    && mkdir -p /tmp/openemr-cache \
    && chmod 666 ${OPENEMR_ROOT}/sites/default/sqlconf.php \
    && chown -R www-data:www-data ${OPENEMR_ROOT}

# Build PHP and JS dependencies in a single layer to keep the final image smaller.
RUN set -eux; \
    composer install --no-dev --optimize-autoloader; \
    npm install --unsafe-perm; \
    npm run build; \
    cd ccdaservice; \
    npm install --unsafe-perm; \
    cd ..; \
    composer dump-autoload --optimize; \
    npm cache clean --force; \
    rm -rf node_modules; \
    chown -R www-data:www-data ${OPENEMR_ROOT}

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/frankenphp-entrypoint"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
