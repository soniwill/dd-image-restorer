#!/bin/bash
# Script para selecionar e restaurar imagens usando dd com barra de progresso

# Configurações
IMAGES_DIR="/nfsshare/images"
TARGET_DISK="/dev/sda"

# Função para listar arquivos .img
list_images() {
    find "$IMAGES_DIR" -maxdepth 1 -name "*.img" -type f | sort
}

# Verifica se existem imagens para restaurar
if [ ! -d "$IMAGES_DIR" ] || [ -z "$(list_images)" ]; then
    echo "Nenhuma imagem .img encontrada em $IMAGES_DIR" > /dev/console
    echo "Por favor, adicione arquivos .img na pasta $IMAGES_DIR" > /dev/console
    echo "Pressione Enter para abrir um shell..." > /dev/console
    read
    exec /bin/bash
fi

# Cria lista de opções para o menu
declare -a options
declare -a image_paths

i=0
while IFS= read -r img_file; do
    filename=$(basename "$img_file")
    filesize=$(du -h "$img_file" | cut -f1)
    options[i]="$filename ($filesize)"
    image_paths[i]="$img_file"
    ((i++))
done < <(list_images)

# Adiciona opção para shell
options[i]="Abrir Shell Bash"
image_paths[i]="shell"

# Função para exibir menu usando dialog
show_menu() {
    local title="Restauração de Imagem DD"
    local prompt="Selecione uma imagem para restaurar em $TARGET_DISK:"
    local choice
    
    choice=$(dialog --clear --backtitle "$title" \
                    --title "$title" \
                    --menu "$prompt" 20 78 15 \
                    $(for i in "${!options[@]}"; do echo "$i" "${options[$i]}"; done) \
                    2>&1 >/dev/tty)
    
    echo "$choice"
}

# Função para confirmar a restauração
confirm_restore() {
    local img="$1"
    local msg="ATENÇÃO: Você está prestes a restaurar:\n\n$img\n\npara o disco $TARGET_DISK\n\nTodos os dados no disco serão perdidos!\n\nDeseja continuar?"
    
    dialog --clear --backtitle "Confirmar Restauração" \
           --title "Confirmar Restauração" \
           --yesno "$msg" 15 60
    
    return $?
}

# Função para mostrar informações do disco
show_disk_info() {
    local disk_info=$(fdisk -l $TARGET_DISK 2>/dev/null)
    local disk_size=$(lsblk -dno SIZE $TARGET_DISK 2>/dev/null)
    
    dialog --clear --backtitle "Informações do Disco" \
           --title "Informações do Disco $TARGET_DISK" \
           --msgbox "Tamanho: $disk_size\n\n$disk_info" 20 78
}

# Loop principal do menu
while true; do
    # Limpa a tela
    clear
    
    # Mostra menu e obtém a escolha
    choice=$(show_menu)
    
    # Se o usuário cancelou (ESC ou Cancel)
    if [ -z "$choice" ]; then
        continue
    fi
    
    selected="${image_paths[$choice]}"
    
    # Verifica se escolheu "shell"
    if [ "$selected" == "shell" ]; then
        clear
        echo "Iniciando shell..."
        exec /bin/bash
    fi
    
    # Mostra informações do disco alvo
    show_disk_info
    
    # Confirma a restauração
    if confirm_restore "${options[$choice]}"; then
        # Realiza a restauração com barra de progresso
        clear
        echo "Iniciando restauração de ${options[$choice]} para $TARGET_DISK..."
        echo "Por favor, aguarde. Este processo pode demorar dependendo do tamanho da imagem."
        echo ""
        
        # Calcula o tamanho do arquivo para a barra de progresso
        file_size=$(stat -c%s "$selected")
        
        # Executa o dd com pv para mostrar o progresso
        (pv -n "$selected" | dd of="$TARGET_DISK" bs=4M conv=fsync status=none) 2>&1 | dialog --gauge "Restaurando ${options[$choice]} para $TARGET_DISK..." 10 70 0
        
        # Verifica se o comando foi bem-sucedido
        if [ ${PIPESTATUS[1]} -eq 0 ]; then
            sync
            dialog --title "Restauração Concluída" --msgbox "A imagem foi restaurada com sucesso!\n\nO sistema será reiniciado em 5 segundos." 10 60
            sleep 5
            reboot
        else
            dialog --title "Erro" --msgbox "Ocorreu um erro durante a restauração.\n\nO sistema entrará em modo shell." 10 60
            exec /bin/bash
        fi
    fi
done
