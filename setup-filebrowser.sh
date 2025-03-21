#!/bin/bash

# Detecta a subnet do host (usando a interface principal)
HOST_IP=$(ip route get 1 | awk '{print $7;exit}')
SUBNET="192.168.100.0/24"

echo "IP do host detectado: $HOST_IP"
echo "Subnet detectada: $SUBNET"

# Verifica se a rede já existe
NETWORK_NAME="image_net"
if ! docker network ls | grep -q $NETWORK_NAME; then
    echo "Criando rede Docker $NETWORK_NAME na subnet $SUBNET..."
    docker network create --subnet=$SUBNET $NETWORK_NAME
else
    echo "Rede $NETWORK_NAME já existe."
fi

# Para e remove o container existente, se houver
CONTAINER_NAME="filebrowser"
HOSTNAME="image-server"
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Parando e removendo container existente..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# Inicia o container
echo "Iniciando o container $CONTAINER_NAME com hostname $HOSTNAME..."
docker run -d \
    --name $CONTAINER_NAME \
    --hostname $HOSTNAME \
    -v $(pwd)/nsfshare/images:/srv \
    -v $(pwd)/config/filebrowser.db:/database.db \
    -v $(pwd)/config/.filebrowser.json:/.filebrowser.json \
    -p 8080:80 \
    --network $NETWORK_NAME \
    filebrowser/filebrowser

# Verifica se o container está em execução
echo "Verificando status do container..."
max_attempts=30
attempt=1
container_ready=false

while [ $attempt -le $max_attempts ]; do
    echo "Tentativa $attempt de $max_attempts..."
    
    # Verifica se o container está rodando
    if ! docker ps | grep -q $CONTAINER_NAME; then
        echo "Container não está rodando. Verificando logs..."
        docker logs $CONTAINER_NAME
        echo "Falha ao iniciar o container. Saindo."
        exit 1
    fi
    
    # Tenta executar um comando simples no container para verificar se está respondendo
    if docker exec $CONTAINER_NAME sh -c "echo 'Container está pronto'" &> /dev/null; then
        echo "Container está pronto e respondendo a comandos."
        container_ready=true
        break
    fi
    
    echo "Container ainda não está pronto. Aguardando..."
    sleep 2
    ((attempt++))
done

if [ "$container_ready" = false ]; then
    echo "Tempo esgotado aguardando o container ficar pronto. Verifique os logs:"
    docker logs $CONTAINER_NAME
    exit 1
fi

# Instala o avahi e pacotes necessários no container
echo "Instalando avahi e dependências no container..."
if ! docker exec $CONTAINER_NAME sh -c "apk update && apk add --no-cache avahi dbus avahi-tools"; then
    echo "Falha ao instalar avahi. Verificando se o container usa Alpine Linux..."
    docker exec $CONTAINER_NAME cat /etc/os-release
    echo "Instalação do avahi falhou. Você pode precisar ajustar o comando de instalação para esta distribuição."
    exit 1
fi


# Configura o avahi-daemon.conf
echo "Configurando o avahi-daemon.conf..."
# Copia o arquivo avahi-daemon.conf para dentro do container
echo "Copiando arquivo avahi-daemon.conf para o container..."
docker cp config/avahi-daemon.conf filebrowser:/etc/avahi/avahi-daemon.conf
docker exec filebrowser sh -c "cat /etc/avahi/avahi-daemon.conf"


# Inicia os serviços do avahi
echo "Reiniciando Avahi..."
docker exec filebrowser sh -c "mkdir -p /var/run/dbus && dbus-daemon --system"
docker exec filebrowser sh -c "avahi-daemon -D || true"



# Obtém o IP do container
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_NAME)

# Verifica se o avahi está publicando o serviço
echo "Verificando se o serviço avahi está publicado..."
sleep 5  # Dá tempo para o avahi iniciar e publicar o serviço
docker exec $CONTAINER_NAME sh -c "avahi-browse -a -t" || echo "Aviso: Não foi possível verificar os serviços avahi"

echo "========================================================"
echo "Container $CONTAINER_NAME configurado com sucesso!"
echo "IP do container: $CONTAINER_IP"
echo "Hostname: $HOSTNAME"
echo "Acesse o FileBrowser através de:"
echo "- http://$CONTAINER_IP:80 (direto pelo IP)"
echo "- http://localhost:8080 (via port forwarding)"
echo "- http://$HOSTNAME.local (via avahi/mDNS se suportado pelo seu sistema)"
echo "========================================================"
