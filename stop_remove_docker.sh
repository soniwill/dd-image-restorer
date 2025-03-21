#!/bin/bash

CONTAINER_NAME="ipxe-server"
CONTAINER_NAME2="filebrowser"

echo "Forçando parada do container..."
docker kill $CONTAINER_NAME 2>/dev/null
docker kill $CONTAINER_NAME2 2>/dev/null

echo "Removendo o container..."
docker rm -f $CONTAINER_NAME 2>/dev/null
docker rm -f $CONTAINER_NAME2 2>/dev/null

echo "Removendo volumes..."
docker volume rm ipxe-tftp ipxe-nfs ipxe-config 2>/dev/null

echo "Processo concluído!"

