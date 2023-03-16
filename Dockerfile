FROM php:8.2-apache

RUN  mkdir -p /var/www/html/wp-content/uploads/

COPY . /var/www/html/wp-content/uploads/ 

WORKDIR /var/www/html/wp-content/uploads/

ENV APACHE_DOCUMENT_ROOT /var/www/html/wp-content/uploads/

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf

RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
