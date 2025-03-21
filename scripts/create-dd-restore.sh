#!/bin/bash
# Script para criar ambiente DD Restore

set -e

# Cria diretório DD Restore em /www
mkdir -p /www/dd-restore

# Cria um arquivo com instruções básicas
cat > /www/dd-restore/README.txt << 'EOF'
DD Restore - Sistema de Restauração de Imagens

Este sistema permite selecionar arquivos .img da pasta /nfsshare/images
e restaurá-los para um disco rígido usando o comando dd com
acompanhamento visual do progresso.

Para adicionar imagens:
1. Coloque seus arquivos .img na pasta /nfsshare/images
2. As imagens aparecerão automaticamente no menu de seleção

Características:
- Visualização do progresso de restauração
- Confirmação antes da restauração
- Verificação de sucesso após restauração
- Reinicialização automática após conclusão
EOF

# Cria a pasta para imagens
mkdir -p /nfsshare/images

# Cria um script de exemplo para gerar uma imagem de teste
cat > /nfsshare/create-test-image.sh << 'EOF'
#!/bin/bash
# Cria uma imagem de teste de 1GB preenchida com zeros
echo "Criando imagem de teste de 1GB..."
dd if=/dev/zero of=/nfsshare/images/test-image-1gb.img bs=1M count=1024 status=progress
echo "Imagem de teste criada com sucesso!"
EOF

chmod +x /nfsshare/create-test-image.sh

# Cria pasta para scripts dd-restore
mkdir -p /nfsshare/dd-restore

echo "Ambiente DD Restore criado com sucesso."
