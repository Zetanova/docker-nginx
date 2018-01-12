FROM bitnami/minideb-extras:jessie-r13
MAINTAINER Bitnami <office@zetanova.eu>

#https://modpagespeed.com/doc/release_notes
#https://nginx.org/en/download.html

ENV NOVA_IMAGE_VERSION=1.0.0 \
    BITNAMI_APP_NAME=nginx-mod \
    PATH=/opt/bitnami/nginx/sbin:$PATH \
    NGINX_VERSION="1.11.12" \    
    NPS_VERSION="1.13.35.2-beta" \
    NGINX_HEADERS_MORE_VERSION="0.32" \
    NGINX_SET_MISC_VERSION="0.31" \
    NGINX_DEVEL_KIT_VERSION="0.3.0"
        
# System packages required
RUN install_packages libc6 libpcre3 libssl1.0.0 zlib1g 

#build libmodsecurity
RUN apt-get update && apt-get install -yqq libxml2 libpcre3 libyajl2 \
	git g++ curl libtool flex bison doxygen libyajl-dev libgeoip-dev dh-autoreconf libcurl4-openssl-dev  libpcre++-dev libxml2-dev libpcre3-dev && \
	`# build` && \ 
	cd ~ && \ 
	git clone https://github.com/SpiderLabs/ModSecurity && \
	cd ModSecurity/ && \
	git checkout -b v3/master origin/v3/master && \
	sh build.sh && \
	git submodule init && \
	git submodule update `#[for bindings/python, others/libinjection, test/test-cases/secrules-language-tests]` && \
	./configure && \
	make && \
	make install && \
	`# clean` && \ 
	cd && \
	rm -dR ~/* && \
	apt-get remove -yqq build-essential zlib1g-dev libpcre3-dev libssl-dev unzip wget && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# build nginx
RUN apt-get update && apt-get install -yqq \
	build-essential zlib1g-dev libpcre3-dev libssl-dev unzip wget && \
	`# module pagespeed` && \ 
	cd && \ 
	wget https://github.com/pagespeed/ngx_pagespeed/archive/v${NPS_VERSION}.zip && \
	unzip v${NPS_VERSION}.zip && \
	nps_dir="incubator-pagespeed-ngx-${NPS_VERSION}" && \
	cd "$nps_dir" && \
	NPS_RELEASE_NUMBER=${NPS_VERSION/-beta/} && \
	psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_RELEASE_NUMBER}.tar.gz && \
	[ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL) && \
	wget ${psol_url} && \
	tar -xzvf $(basename ${psol_url}) `# extracts to psol/` && \
	`# module devel kit` && \
       cd && \ 
	wget https://github.com/simpl/ngx_devel_kit/archive/v${NGINX_DEVEL_KIT_VERSION}.tar.gz && \
	tar -xzvf v${NGINX_DEVEL_KIT_VERSION}.tar.gz && \
       `# module set misc` && \
       cd && \ 
	wget https://github.com/openresty/set-misc-nginx-module/archive/v${NGINX_SET_MISC_VERSION}.tar.gz && \
	tar -xzvf v${NGINX_SET_MISC_VERSION}.tar.gz && \
       `# module headers more` && \
       cd && \ 
       wget https://github.com/openresty/headers-more-nginx-module/archive/v${NGINX_HEADERS_MORE_VERSION}.tar.gz && \
	tar -xzvf v${NGINX_HEADERS_MORE_VERSION}.tar.gz && \
	`# build` && \ 
	cd && \
	wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
	tar -xvzf nginx-${NGINX_VERSION}.tar.gz && \
	cd nginx-${NGINX_VERSION}/ && \
	./configure --prefix=/opt/bitnami/nginx \
		--with-http_stub_status_module --with-http_gzip_static_module --with-http_realip_module --with-http_v2_module --with-http_ssl_module --with-http_sub_module \
		--with-mail --with-mail_ssl_module \
		--add-dynamic-module=$HOME/$nps_dir \
		--add-dynamic-module=$HOME/headers-more-nginx-module-${NGINX_HEADERS_MORE_VERSION} \
		--add-dynamic-module=$HOME/ngx_devel_kit-${NGINX_DEVEL_KIT_VERSION} \
		--add-dynamic-module=$HOME/set-misc-nginx-module-${NGINX_SET_MISC_VERSION} \
		${PS_NGX_EXTRA_FLAGS} && \
	make -j2 && \   
	make install && \
    `# clean` && \ 
	cd && \
	rm -dR ~/* && \
	apt-get remove -yqq build-essential zlib1g-dev libpcre3-dev libssl-dev unzip wget && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /opt/bitnami/nginx/pgsp_tmp && \
	chown nobody:root /opt/bitnami/nginx/pgsp_tmp && \
       chmod u+rwx /opt/bitnami/nginx/pgsp_tmp

RUN mkdir /opt/bitnami/nginx/cache_tmp && \
	chown nobody:root /opt/bitnami/nginx/cache_tmp && \
       chmod u+rwx /opt/bitnami/nginx/cache_tmp

RUN ln -sf /opt/bitnami/nginx/html /app

COPY rootfs/ /

ENV NGINX_HTTP_PORT=80 \
    NGINX_HTTPS_PORT=443

VOLUME ["/bitnami/nginx"]

WORKDIR /app

EXPOSE 80 443

ENTRYPOINT ["/app-entrypoint.sh"]

CMD ["/run.sh"]