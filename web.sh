#!/bin/bash

# Actualizar repositorios e instalar nginx, nfs-common, PHP 7.4 y cliente mariadb
sudo apt-get update -y
sudo apt-get install -y nginx nfs-common php7.4 php7.4-fpm php7.4-mysql php7.4-gd php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip php7.4-intl php7.4-ldap mariadb-client

# Crear la carpeta compartida por NFS
sudo mkdir -p /var/www/html

# Montar la carpeta desde el servidor NFS
sudo mount -t nfs 192.168.56.12:/var/www/html /var/www/html

# Añadir entrada al /etc/fstab para montaje automático
echo "192.168.56.12:/var/www/html /var/www/html nfs defaults 0 0" >> /etc/fstab

# Configuración de Nginx para servir OwnCloud
cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80;

    root /var/www/html/owncloud;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 192.168.56.12:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ ^/(?:\.htaccess|data|config|db_structure\.xml|README) {
        deny all;
    }
}
EOF

# Verificar la configuración de Nginx
nginx -t

# Reiniciar Nginx para aplicar los cambios
sudo systemctl restart nginx

# Reiniciar PHP-FPM 7.4
sudo systemctl restart php7.4-fpm

# Eliminar puerta de enlace por defecto de Vagrant
sudo ip route del default