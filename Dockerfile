FROM alpine:latest

# Habilitar repositório community e instalar pacotes necessários
RUN echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories && \
    apk update && apk add --no-cache \
    dnsmasq \
    tftp-hpa \
    nfs-utils \
    syslinux \
    bash \
    curl \
    wget \
    unzip \
    supervisor \
    nginx \
    pv \
    coreutils \
    dialog \
    parted \
    util-linux

# Configurar diretórios

RUN mkdir -p /var/tftpboot/pxelinux.cfg /var/tftpboot/bios /var/tftpboot/efi64 /var/log /config /www/clonezilla /www/clonezilla/scripts

# Garantir permissões corretas para o TFTP
RUN chmod -R 777 /var/tftpboot && chown -R nobody:nobody /var/tftpboot
RUN chmod -R 777 /var/log && chown -R nobody:nobody /var/log
#RUN chmod -R 777 /etc/filebrowser && chown -R nobody:nobody /etc/filebrowser

# Baixar binários iPXE e configurar syslinux para BIOS legacy
RUN wget -O /var/tftpboot/bios/undionly.kpxe https://boot.ipxe.org/undionly.kpxe && \
    wget -O /var/tftpboot/efi64/ipxe.efi https://boot.ipxe.org/ipxe.efi && \
    cp /usr/share/syslinux/pxelinux.0 /var/tftpboot/ && \
    cp /usr/share/syslinux/ldlinux.c32 /var/tftpboot/ && \
    cp /usr/share/syslinux/libutil.c32 /var/tftpboot/ && \
    cp /usr/share/syslinux/menu.c32 /var/tftpboot/ && \
    cp /usr/share/syslinux/vesamenu.c32 /var/tftpboot/
    

# Copiar os arquivos para o diretório HTTP também
RUN cp /var/tftpboot/bios/undionly.kpxe /www/ && \
    cp /var/tftpboot/efi64/ipxe.efi /www/

# Copiar Clonezilla Live do host em vez de fazer download
COPY clonezilla/clonezilla.zip /tmp/clonezilla.zip
RUN unzip /tmp/clonezilla.zip -d /www/clonezilla && \
    rm /tmp/clonezilla.zip
    

# Copiar arquivos de configuração
COPY config/boot.ipxe /var/tftpboot/
COPY config/boot.ipxe /www/
COPY config/default /var/tftpboot/pxelinux.cfg/
COPY config/dnsmasq.conf /config/
COPY config/tftpd-hpa /etc/default/tftpd-hpa
COPY config/exports /etc/exports
COPY config/supervisord.conf /etc/supervisord.conf
COPY config/nginx.conf /etc/nginx/http.d/default.conf

COPY scripts/start.sh /start.sh
COPY scripts/troubleshoot.sh /troubleshoot.sh
COPY scripts/restore-image.sh /www/clonezilla/scripts/restore-image.sh



# Tornar os scripts executáveis
RUN chmod +x /start.sh /troubleshoot.sh /www/clonezilla/scripts/restore-image.sh


# Expor portas necessárias
EXPOSE 67/udp 69/udp 80/tcp 111/tcp 111/udp 2049/tcp 2049/udp 4045/tcp 4045/udp

# Volumes para persistência
VOLUME ["/var/tftpboot", "/nfsshare", "/config", "/www"]

# Comando para iniciar o container
CMD ["/start.sh"]

