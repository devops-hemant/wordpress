FROM wordpress

RUN  mkdir -p /wp-content/uploads/

COPY . /wp-content/uploads/ 

WORKDIR /wp-content/uploads/

ENV APACHE_DOCUMENT_ROOT /wp-content/uploads/

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf

RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
