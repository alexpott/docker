FROM php:apache

RUN a2enmod rewrite

# install the PHP extensions we need

RUN apt-get update && apt-get install -y gnupg libpng-dev libjpeg-dev libpq-dev mysql-client git libbz2-dev libgmp-dev libxml2-dev
RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h
RUN rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr
RUN docker-php-ext-install gd mbstring pdo pdo_mysql pdo_pgsql zip bcmath bz2 gmp soap

RUN echo 'sendmail_path=/bin/true' > /usr/local/etc/php/conf.d/sendmail.ini

#install phan dependencies
RUN git clone https://github.com/nikic/php-ast.git \
  && cd php-ast \
  && phpize \
  && ./configure \
  && make install \
  && echo 'extension=ast.so' > /usr/local/etc/php/conf.d/ast.ini \
  && cd .. \
  && rm php-ast -rf

#install drush, to use for site and module installs
RUN curl -L -o drush.phar $(curl -s  https://api.github.com/repos/drush-ops/drush/releases/latest | grep drush/releases/download | cut -d '"' -f 4) \
  && chmod +x drush.phar \
  && mv drush.phar /usr/local/bin

# Register the COMPOSER_HOME environment variable
ENV COMPOSER_HOME /composer

# Add global binary directory to PATH and make sure to re-export it
ENV PATH /composer/vendor/bin:$PATH

# Allow Composer to be run as root
ENV COMPOSER_ALLOW_SUPERUSER 1

# Install composer
RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
  && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer && rm -rf /tmp/composer-setup.php

#allows for parallel composer downloads
RUN composer global require "hirak/prestissimo:^0.3"

#drupal console
RUN curl https://drupalconsole.com/installer -L -o drupal.phar \
  && chmod +x drupal.phar \
  && mv drupal.phar /usr/local/bin/drupal

#code standards
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar \
 && chmod +x phpcs.phar \
 && mv phpcs.phar /usr/local/bin/phpcs

RUN composer global require drupal/coder \
  && phpcs --config-set installed_paths /composer/vendor/drupal/coder/coder_sniffer

RUN composer global require phpmd/phpmd

RUN composer global require sebastian/phpcpd

RUN curl -sL https://deb.nodesource.com/setup_8.x -o nodesource_setup.sh \
  && bash nodesource_setup.sh \
  && rm nodesource_setup.sh \
  && apt-get install -y nodejs

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get update && apt-get install yarn

# Install SensioLabs' security advisories checker
RUN curl -sL http://get.sensiolabs.org/security-checker.phar -o security-checker.phar \
  && chmod +x security-checker.phar \
  && mv security-checker.phar /usr/local/bin/security-checker

# Xdebug requires beta to support PHP 7.2.
RUN pecl install xdebug \
    && echo "zend_extension=$(find / -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini

RUN curl -sS https://platform.sh/cli/installer | php
