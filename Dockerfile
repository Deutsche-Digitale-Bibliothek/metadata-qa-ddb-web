FROM php:8.3-apache

LABEL maintainer="Péter Király <pkiraly@gwdg.de>"
LABEL description="A web interface of quality assessment tool for Deutsche Digitale Bibliothek metadata."
# the Github repo labels
LABEL org.opencontainers.image.description="A web interface of quality assessment tool for Deutsche Digitale Bibliothek metadata."
LABEL org.opencontainers.image.source=https://github.com/Deutsche-Digitale-Bibliothek/metadata-qa-ddb-web
LABEL org.opencontainers.image.licenses="GNU General Public License v3.0"

# Patch drift is intentional; API-breaking majors stay opt-in.
ARG SMARTY_MAJOR=4
ARG DOMPDF_MAJOR=3

# Patch installed OS packages too; apt-get install alone leaves old baggage.
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
      # install basic OS tools
      apt-utils \
      unzip \
      nano \
      jq \
      curl \
      openssl \
      sqlite3 \
      less \
      libyaml-dev libicu-dev libzip-dev \
      default-mysql-client \
      # php-raphf \
      # php php-mysql php-sqlite3 php-intl \
  && pecl install yaml \
  && docker-php-ext-configure intl \
  && docker-php-ext-install gettext zip intl \
  && docker-php-ext-install pdo pdo_mysql \
  && docker-php-ext-enable yaml intl \
  && rm -rf /var/lib/apt/lists/*

# install composer from its official Docker image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY . /var/www/html/
WORKDIR /var/www/html

# install composer from its official Docker image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN  composer install --prefer-dist --no-dev \
  && composer clear-cache \
  && mkdir -p logs libs/_smarty/templates_c libs/_smarty/configs libs/_smarty/cache \
  && chown www-data logs libs/_smarty/templates_c \
  && chmod g+w logs libs/_smarty/templates_c libs/_smarty/cache

RUN \
  #
  # set configuration
  #
  mv configuration.cnf.template configuration.cnf \
  && sed -i.bak 's,<path to input directory>,/opt/metadata-qa-ddb/input,' configuration.cnf \
  && sed -i.bak 's,<path to output directory>,/opt/metadata-qa-ddb/output,' configuration.cnf \
  && sed -i.bak 's,<MySQL database host>,mqaf-ddb-db,' configuration.cnf \
  && sed -i.bak 's,<MySQL database name>,ddb,' configuration.cnf \
  && sed -i.bak 's,<MySQL user name>,ddb,' configuration.cnf \
  && sed -i.bak 's,<MySQL password>,ddb,' configuration.cnf \
  #
  # set apache
  #
  && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
  && a2disconf other-vhosts-access-log \
  && sed -i.bak 's,</VirtualHost>,        <Directory /var/www/html>\n                Options Indexes FollowSymLinks MultiViews\n                AllowOverride All\n                Order allow\,deny\n                allow from all\n                DirectoryIndex index.php index.html\n        </Directory>\n</VirtualHost>,' /etc/apache2/sites-available/000-default.conf \
  && sed -i 's|^\s*ErrorLog .*|\tErrorLog /proc/self/fd/2|' /etc/apache2/sites-available/000-default.conf \
  && sed -i 's|^\s*CustomLog .*|\tCustomLog /proc/self/fd/1 combined|' /etc/apache2/sites-available/000-default.conf \
  && sed -i 's|^\s*TransferLog .*|\tCustomLog /proc/self/fd/1 combined|' /etc/apache2/sites-available/000-default.conf \
  #
  # set directories
  #
  && mkdir -p /opt/metadata-qa-ddb/input \
  && mkdir -p /opt/metadata-qa-ddb/output \
  && chgrp -R 0 /var/www/html /tmp /opt/metadata-qa-ddb \
  && chmod -R g=u /var/www/html /tmp /opt/metadata-qa-ddb

#
# set php.ini
#
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
  && rm "$PHP_INI_DIR/php.ini-development" \
  && sed -i.bak 's,;error_log = php_errors.log,error_log = /proc/self/fd/2,' "$PHP_INI_DIR/php.ini"

WORKDIR /opt/metadata-qa-ddb

CMD ["apache2-foreground"]
EXPOSE 8080
