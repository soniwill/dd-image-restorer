#!/bin/bash
# Ajustar configuração do dnsmasq com base no IP do container
# Usando grep sem a opção -P (Perl regex)
IP=$(ip -4 addr show eth0 2>/dev/null | grep -o "inet [0-9.]*" | cut -d' ' -f2)
if [ -z "$IP" ]; then
    # Tentar outros interfaces de rede caso eth0 não exista
    IP=$(ip -4 addr | grep -o "inet [0-9.]*" | grep -v "127.0.0.1" | head -n 1 | cut -d' ' -f2)
fi

if [ ! -z "$IP" ]; then
    echo "Detectado IP do servidor: $IP"
    
    # Calcular a subnet a partir do IP
    # Extrair os primeiros três octetos do IP e adicionar .0
    SUBNET=$(echo $IP | cut -d. -f1-3).0
    echo "Subnet calculada: $SUBNET"
    
    # Atualizar a subnet no arquivo de configuração dnsmasq
    sed -i "s/\${subnet}/$SUBNET/g" /config/dnsmasq.conf
    
    # Atualizar o IP no arquivo de configuração dnsmasq
    sed -i "s/192.168.1.2/$IP/g" /config/dnsmasq.conf
    
   
    
    # Atualizar o IP no arquivo boot.ipxe (tanto na pasta TFTP quanto na HTTP)
    if [ -f "/tftpboot/boot.ipxe" ]; then
        echo "Atualizando boot.ipxe em /tftpboot com IP $IP"
        # Substituir ${next-server} por IP hardcoded
        sed -i "s|\${next-server}|$IP|g" /tftpboot/boot.ipxe
    fi
    
    if [ -f "/www/boot.ipxe" ]; then
        echo "Atualizando boot.ipxe em /www com IP $IP"
        sed -i "s|\${next-server}|$IP|g" /www/boot.ipxe
    fi   
else
    echo "AVISO: Não foi possível detectar o IP do servidor. Usando configuração padrão."
fi

# Garantir que pastas existam e tenham permissões

chmod -R 777 /nfsshare

#configurar avahi e dbus

mkdir -p /var/run/dbus

chmod -R 777  /var/run/dbus
chown -R nobody:nobody  /var/run/dbus

# Preparar ambiente TFTP
chmod -R 777 /var/tftpboot
chown -R nobody:nobody /var/tftpboot

# Configuração correta do serviço NFS
echo "Configurando serviços NFS..."
# Garantir que módulos estejam carregados
modprobe nfs 2>/dev/null || true
modprobe nfsd 2>/dev/null || true


# Criar diretórios necessários para NFSv4
mkdir -p /var/lib/nfs/rpc_pipefs
mkdir -p /var/lib/nfs/v4recovery
mkdir -p /proc/fs/nfsd 2>/dev/null || true
mount -t nfsd nfsd /proc/fs/nfsd 2>/dev/null || true

# Atualizar arquivo exports
exportfs -ra

# Configuração TFTP específica
mkdir -p /var/lib/tftpboot
chmod 777 /var/lib/tftpboot
ln -sf /var/tftpboot/* /var/lib/tftpboot/ 2>/dev/null || true

# Garantir que o serviço dnsmasq esteja configurado corretamente
cp /config/dnsmasq.conf /etc/dnsmasq.conf

# Aguardar um momento para garantir que os serviços estejam prontos
sleep 2


# Iniciar supervisord
echo "Iniciando serviços..."
exec supervisord -c /etc/supervisord.conf
