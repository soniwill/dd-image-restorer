#!/bin/bash

# Script de restauração de imagem simplificado para o Clonezilla
# Recebe o IP do servidor NFS como argumento
# Uso: ./restore-image.sh <IP_DO_SERVIDOR_NFS>

# Verificar se o IP do servidor NFS foi fornecido
if [ -z "$1" ]; then
    echo "Erro: IP do servidor NFS não fornecido."
    echo "Uso: $0 <IP_DO_SERVIDOR_NFS>"
    exit 1
fi


# IP do servidor NFS (recebido como argumento)
NFS_SERVER_IP="$1"

# Definir diretório onde as imagens estão
IMAGES_DIR="/home/partimag/images"

# Verificar se o diretório de imagens existe
if [ ! -d "$IMAGES_DIR" ]; then
    echo "Erro: Diretório de imagens não encontrado em $IMAGES_DIR."
    exit 1
fi

# Criar array com as imagens disponíveis
IMAGES=$(find $IMAGES_DIR -name "*.img" -type f | sort)

# Exibir imagens disponíveis
echo "Imagens disponíveis:"
echo "$IMAGES"

# Criar lista de opções para o menu dialog
OPTIONS=()
i=1
for img in $IMAGES; do
    img_name=$(basename "$img")
    OPTIONS+=("$i" "$img_name")
    i=$((i+1))
done

# Detectar discos disponíveis
DISKS=$(lsblk -d -n -o NAME | grep -v loop | grep -v sr | sort)
DISK_OPTIONS=()
i=1
for disk in $DISKS; do
    size=$(lsblk -d -n -o SIZE /dev/$disk)
    DISK_OPTIONS+=("$i" "/dev/$disk-$size")
    i=$((i+1))
done

# Exibir menu de seleção de imagem
SELECTED_IMG=$(dialog --title "Restauração de Imagem" --menu "Selecione a imagem a ser restaurada:" 15 60 8 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
exit_status=$?
if [ $exit_status -ne 0 ]; then
    echo "Operação cancelada pelo usuário."
    umount $IMAGES_DIR
    exit 1
fi

# Pegar o caminho da imagem selecionada
SELECTED_IMG_PATH=$(echo "$IMAGES" | sed -n "${SELECTED_IMG}p")
SELECTED_IMG_NAME=$(basename "$SELECTED_IMG_PATH")

# Exibir menu de seleção de disco
SELECTED_DISK=$(dialog --title "Restauração de Imagem" --menu "Selecione o disco destino:" 15 60 8 "${DISK_OPTIONS[@]}" 3>&1 1>&2 2>&3)
exit_status=$?
if [ $exit_status -ne 0 ]; then
    echo "Operação cancelada pelo usuário."
    umount $IMAGES_DIR
    exit 1
fi

# Pegar o nome do disco selecionado
SELECTED_DISK_PATH=$(echo "$DISKS" | sed -n "${SELECTED_DISK}p")

# Confirmação final
dialog --title "Confirmação" --yesno "ATENÇÃO: Você está prestes a restaurar a imagem:\n\n$SELECTED_IMG_NAME\n\nPara o disco:\n\n/dev/$SELECTED_DISK_PATH\n\nTodos os dados no disco serão perdidos! Continuar?" 15 60
exit_status=$?
if [ $exit_status -ne 0 ]; then
    echo "Operação cancelada pelo usuário."
    umount $IMAGES_DIR
    exit 1
fi

# Limpar a tela
clear

# Executar DD com barra de progresso usando pv
echo "Restaurando $SELECTED_IMG_NAME para /dev/$SELECTED_DISK_PATH..."
pv "$SELECTED_IMG_PATH" | dd of="/dev/$SELECTED_DISK_PATH" bs=4M conv=fsync

# Verificar se a operação foi bem-sucedida
if [ $? -eq 0 ]; then
    dialog --title "Sucesso" --msgbox "Imagem restaurada com sucesso!" 6 40
else
    dialog --title "Erro" --msgbox "Ocorreu um erro durante a restauração da imagem." 6 40
fi

# Desmontar o compartilhamento NFS
umount $IMAGES_DIR

# Sugerir reinicialização
dialog --title "Reiniciar" --yesno "Deseja reiniciar o sistema agora?" 6 40
if [ $? -eq 0 ]; then
    reboot
fi
