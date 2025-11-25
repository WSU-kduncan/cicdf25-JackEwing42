FROM httpd:2.4
COPY ./web-content/ /usr/local/apache2/htdocs/
