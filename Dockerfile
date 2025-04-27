ARG PHP_VERSION=invalid
FROM php:${PHP_VERSION}-apache
RUN echo "PHP_VERSION is set to $PHP_VERSION"
RUN if [ "$PHP_VERSION" = "invalid" ]; then echo "Error: PHP_VERSION is set to 'invalid'. Please provide a valid PHP version." && exit 1; fi

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

COPY docker/apache/*.conf /etc/apache2/conf-available/

# Aktivieren von rewrite, deflate (gzip Kompression) und http2
RUN a2enmod rewrite deflate http2 && a2enconf gzip http2


# Installiere notwendige Pakete für PHP-Erweiterungen sowie mysqldump
RUN apt update && apt install -y libzip-dev libpq-dev zlib1g-dev libonig-dev mariadb-client\
    && docker-php-ext-install pdo pdo_mysql sysvsem && \
    apt install -y libzip-dev libpq-dev zlib1g-dev libonig-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

    # LATEX Insallation
WORKDIR /tmp/latex_install
ARG SCHEME=minimal
# choose minimal installation
# … but disable documentation and source files when asked to stay slim
# furthermore we want our symlinks in the system binary folder to avoid
# fiddling around with the PATH

# TeX Live Installer holen
RUN apt update && apt install -y wget perl xz-utils fontconfig && \
    wget http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    tar -xzf install-tl-unx.tar.gz && \
    cd install-tl-* && \
    echo "selected_scheme scheme-$SCHEME" > install.profile && \
    echo "tlpdbopt_install_docfiles 0" >> install.profile && \
    echo "tlpdbopt_install_srcfiles 0" >> install.profile && \
    echo "tlpdbopt_autobackup 0" >> install.profile && \
    echo "tlpdbopt_sys_bin /usr/bin" >> install.profile && \
    # actually install TeX Live
    ./install-tl --no-interaction --scheme install.profile && \
    # remove installer
    cd /tmp && \
    rm -rf /tmp/latex_install && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Dynamisch das bin-Verzeichnis finden und in PATH setzen
    TEXBIN=$(find /usr/local/texlive/ -type d -path "*/bin/*" -print -quit) && \
    echo "export PATH=$TEXBIN:\$PATH" >> /etc/profile.d/texlive.sh && \
    $(find /usr/local/texlive -name tlmgr) path add && \
    # TeX Live Manager (tlmgr) konfigurieren
    # Installation von Dokumentation und SrcFiles deaktiviert und Backups deaktiviert
    tlmgr option docfiles 0 && \
    tlmgr option srcfiles 0 && \
    tlmgr option autobackup 0 && \
    tlmgr install latex latex-bin koma-script babel-german makecell ragged2e eurosym xcolor multirow lastpage tcolorbox pdfcol tikzfill && \
    TEXLIVE_DISTPATH=$(find /usr/local/texlive/ -type d -path "*/texmf-dist" -print -quit) && \
    # remove documentation and source files
    rm -rf $TEXLIVE_DISTPATH/doc $TEXLIVE_DISTPATH/source
    
ENV ENV="/etc/profile"


WORKDIR /var/www/html

# Kopiere ein Startskript in den Container
COPY docker/init_container.sh /usr/local/bin/init_container.sh
RUN chmod +x /usr/local/bin/init_container.sh
RUN apt remove -y $PHPIZE_DEPS && apt autoremove -y

# Setze das Startskript als Entrypoint
ENTRYPOINT ["/usr/local/bin/init_container.sh"]
