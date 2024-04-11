# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.19

# set version label
ENV TZ=Asia/Shanghai

# install packages
RUN \
  echo "**** install build packages ****" && \
  apk add -t build-dependencies \
    gnupg \
    wget && \
  apk add --no-cache \
    apache2-utils \
    logrotate \
    openssl \
    php83 \
    php83-ctype \
    php83-curl \
    php83-fileinfo \
    php83-fpm \
    php83-iconv \
    php83-json \
    php83-mbstring \
    php83-openssl \
    php83-phar \
    php83-session \
    php83-simplexml \
    php83-xml \
    php83-xmlwriter \
    php83-zip \
    php83-zlib && \
  echo "**** guarantee correct php version is symlinked ****" && \
  if [ "$(readlink /usr/bin/php)" != "php83" ]; then \
    rm -rf /usr/bin/php && \
    ln -s /usr/bin/php83 /usr/bin/php; \
  fi && \
  echo "**** configure php ****" && \
  sed -i "s#;error_log = log/php83/error.log.*#error_log = /config/log/php/error.log#g" \
    /etc/php83/php-fpm.conf && \
  sed -i "s#user = nobody.*#user = abc#g" \
    /etc/php83/php-fpm.d/www.conf && \
  sed -i "s#group = nobody.*#group = abc#g" \
    /etc/php83/php-fpm.d/www.conf && \
  echo "**** install php composer ****" && \
  EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')" && \
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
  ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")" && \
  if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then \
      >&2 echo 'ERROR: Invalid installer checksum' && \
      rm composer-setup.php && \
      exit 1; \
  fi && \
  php composer-setup.php --install-dir=/usr/bin && \
  rm composer-setup.php && \
  ln -s /usr/bin/composer.phar /usr/bin/composer && \
  echo "**** install rainloop ****" && \
  cd /tmp && \
  wget -q https://www.rainloop.net/repository/webmail/rainloop-latest.zip && \
  wget -q https://www.rainloop.net/repository/webmail/rainloop-latest.zip.asc && \
  wget -q https://www.rainloop.net/repository/RainLoop.asc && \
  gpg --import RainLoop.asc && \
  FINGERPRINT="$(LANG=C gpg --verify rainloop-latest.zip.asc rainloop-latest.zip 2>&1 \
  | sed -n "s#Primary key fingerprint: \(.*\)#\1#p")" && \
  if [ -z "${FINGERPRINT}" ]; then echo "ERROR: Invalid GPG signature!" && exit 1; fi && \
  if [ "${FINGERPRINT}" != "${GPG_FINGERPRINT}" ]; then echo "ERROR: Wrong GPG fingerprint!" && exit 1; fi &&\
  mkdir /app/rainloop && unzip -q /tmp/rainloop-latest.zip -d /app/rainloop && \
  find /app/rainloop -type d -exec chmod 755 {} \; && \
  find /app/rainloop -type f -exec chmod 644 {} \; && \
  echo "**** fix logrotate ****" && \
  sed -i "s#/var/log/messages {}.*# #g" \
    /etc/logrotate.conf && \
  sed -i 's#/usr/sbin/logrotate /etc/logrotate.conf#/usr/sbin/logrotate /etc/logrotate.conf -s /config/log/logrotate.status#g' \
    /etc/periodic/daily/logrotate && \
  echo "**** clean ****" && \
  apk del build-dependencies && \
  rm -rf /tmp/* /var/cache/apk/* /root/.gnupg

# add local files
COPY root/ /

# ports and volumes
EXPOSE 9000

