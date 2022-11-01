#@# vim: set filetype=dockerfile:
FROM alpine:3.15
LABEL maintainer "Takahiro INOUE <github.com/hinata>"

ARG SWISSRE_CA=/home/${USER}/swissre_ca.pem


ENV NGINX_VERSION=1.21.6
ENV https_proxy=http://gate-zrh.swissre.com:9443
ENV http_proxy=http://gate-zrh.swissre.com:8080
ENV REQUESTS_CA_BUNDLE=${SWISSRE_CA}
ENV NODE_EXTRA_CA_CERTS=${SWISSRE_CA}

##
# dependent packages for docker build
##
RUN mkdir -p /usr/local/share/ca-certificates && wget -qP /usr/local/share/ca-certificates http://pki.swissre.com/aia/SwissReRootCA2.crt \
    && wget -qP /usr/local/share/ca-certificates http://pki.swissre.com/aia/SwissReSystemCA22.crt \
    && wget -qP /usr/local/share/ca-certificates http://pki.swissre.com/aia/SwissReSystemCA25.crt \
    && cat /usr/local/share/ca-certificates/SwissReRootCA2.crt  /usr/local/share/ca-certificates/SwissReSystemCA22.crt \
    /usr/local/share/ca-certificates/SwissReSystemCA25.crt > /home/$USER/swissre_ca.pem && \
    cat /home/$USER/swissre_ca.pem >> /etc/ssl/certs/ca-certificates.crt
    # && update-ca-certificates


WORKDIR /tmp

RUN apk update && \
    apk add       \
      alpine-sdk  \
      openssl-dev \
      pcre-dev    \
      zlib-dev

RUN curl -LSs http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -O                                             && \
    tar xf nginx-${NGINX_VERSION}.tar.gz                                                                             && \
    cd     nginx-${NGINX_VERSION}                                                                                    && \
    git clone https://github.com/chobits/ngx_http_proxy_connect_module                                               && \
    patch -p1 < ./ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_102101.patch                             && \
    ./configure                                                                                                         \
      --add-module=./ngx_http_proxy_connect_module                                                                      \
      --sbin-path=/usr/sbin/nginx                                                                                       \
      --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' && \
    make -j $(nproc)                                                                                                 && \
    make install                                                                                                     && \
    rm -rf /tmp/*

##
# application deployment
##

WORKDIR /

COPY ./nginx.conf /usr/local/nginx/conf/nginx.conf

EXPOSE 3128

STOPSIGNAL SIGTERM

CMD [ "nginx", "-g", "daemon off;" ]
