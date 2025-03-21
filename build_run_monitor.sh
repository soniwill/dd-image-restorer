#!/bin/bash

CONTAINER_NAME="ipxe-server"

echo "Buildando a imagem sem cache..."
docker build --no-cache -t $CONTAINER_NAME .

docker rm -f ipxe-server 2>/dev/null || true

echo "Iniciando o container..."
docker run -d --name $CONTAINER_NAME --privileged --network host \
    -v $(pwd)/nsfshare:/nfsshare \
    -v ipxe-config:/config \
    $CONTAINER_NAME 
        
docker exec -it $CONTAINER_NAME tail -f /var/log/dnsmasq.log

#echo "Monitorando logs do dnsmasq..."
#docker logs -f $CONTAINER_NAME | grep --line-buffered dnsmasq

./setup-filebrowser.sh
