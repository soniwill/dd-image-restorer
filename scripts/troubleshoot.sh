#!/bin/bash
# Script para diagnosticar e corrigir problemas comuns nos serviços

echo "===== Iniciando diagnóstico dos serviços ====="

# Verificar se os principais diretórios existem e têm permissões corretas
echo "Verificando diretórios e permissões..."
for dir in /var/tftpboot /nfsshare /var/lib/nfs; do
    if [ ! -d "$dir" ]; then
        echo "Criando diretório $dir"
        mkdir -p "$dir"
    fi
    echo "Ajustando permissões para $dir"
    chmod -R 777 "$dir"
done

# Verificar se o NFS está funcionando
echo "Verificando status do NFS..."
if ! rpcinfo -p localhost | grep -q nfs; then
    echo "NFS não está rodando. Tentando reiniciar..."
    
    # Tentar carregar módulos do kernel
    modprobe nfs 2>/dev/null || echo "Aviso: Não foi possível carregar o módulo nfs"
    modprobe nfsd 2>/dev/null || echo "Aviso: Não foi possível carregar o módulo nfsd"
    
    # Montar nfsd se necessário
    if [ ! -f /proc/fs/nfsd/exports ]; then
        mkdir -p /proc/fs/nfsd 2>/dev/null || true
        mount -t nfsd nfsd /proc/fs/nfsd 2>/dev/null || echo "Não foi possível montar nfsd"
    fi
    
    # Iniciar serviços NFS manualmente
    rpcbind
    /sbin/rpc.statd --no-notify
    exportfs -ra
    /usr/sbin/rpc.nfsd 8
    /usr/sbin/rpc.mountd --debug all
    
    echo "NFS reiniciado. Verificando novamente..."
    rpcinfo -p localhost
else
    echo "NFS está rodando."
    rpcinfo -p localhost | grep nfs
fi

# Verificar se o TFTP está funcionando
echo "Verificando status do TFTP..."
if ! ps aux | grep -v grep | grep -q in.tftpd; then
    echo "TFTP não está rodando. Tentando reiniciar..."
    killall in.tftpd 2>/dev/null || true
    /usr/sbin/in.tftpd --listen --foreground --user nobody --address 0.0.0.0:69 --secure /var/tftpboot &
    echo "TFTP reiniciado."
else
    echo "TFTP está rodando."
    ps aux | grep -v grep | grep in.tftpd
fi

# Verificar se o DNSMASQ está funcionando
echo "Verificando status do DNSMASQ..."
if ! ps aux | grep -v grep | grep -q dnsmasq; then
    echo "DNSMASQ não está rodando. Tentando reiniciar..."
    killall dnsmasq 2>/dev/null || true
    dnsmasq -k --conf-file=/etc/dnsmasq.conf --log-facility=/var/log/dnsmasq.log &
    echo "DNSMASQ reiniciado."
else
    echo "DNSMASQ está rodando."
    ps aux | grep -v grep | grep dnsmasq
fi

# Verificar se todos os arquivos necessários estão presentes
echo "Verificando arquivos boot.ipxe..."
for file in /var/tftpboot/boot.ipxe /www/boot.ipxe; do
    if [ ! -f "$file" ]; then
        echo "AVISO: $file não encontrado!"
    else
        echo "$file encontrado."
    fi
done

echo "===== Diagnóstico concluído ====="
