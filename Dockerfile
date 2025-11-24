FROM httpd:2.4

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/* && mkdir /tmp/repo

RUN git clone https://github.com/WSU-kduncan/cicdf25-JackEwing42.git /tmp/repo

COPY /tmp/repo/web-content/ /usr/local/apache2/htdocs

RUN rm -rf /tmp/repo
