#!/bin/bash

# Actualizar repositorios e instalar NFS y PHP 7.4
sudo apt-get update -y
sudo apt-get install -y nfs-kernel-server php7.4 php7.4-fpm php7.4-mysql php7.4-gd php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip php7.4-intl php7.4-ldap unzip

# Crear carpeta compartida para OwnCloud y configurar permisos
sudo mkdir -p /var/www/html
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Configurar NFS para compartir la carpeta
echo "/var/www/html 192.168.56.11(rw,sync,no_subtree_check)" >> /etc/exports
echo "/var/www/html 192.168.56.10(rw,sync,no_subtree_check)" >> /etc/exports

# Reiniciar NFS para aplicar cambios
sudo exportfs -a
sudo systemctl restart nfs-kernel-server

# Descargar y configurar OwnCloud
cd /tmp
wget https://download.owncloud.com/server/stable/owncloud-10.9.1.zip
unzip owncloud-10.9.1.zip
mv owncloud /var/www/html/

# Configurar permisos de OwnCloud
sudo chown -R www-data:www-data /var/www/html/owncloud
sudo chmod -R 755 /var/www/html/owncloud

# Crear archivo de configuración inicial para OwnCloud
cat <<EOF > /var/www/html/owncloud/config/autoconfig.php
<?php
\$AUTOCONFIG = array(
  "dbtype" => "mysql",
  "dbname" => "owncloud",
  "dbuser" => "owncloud",
  "dbpassword" => "1234",
  "dbhost" => "192.168.60.10",
  "directory" => "/var/www/html/owncloud/data",
  "adminlogin" => "DavidSC",
  "adminpass" => "S1234?"
);
EOF

# Modificar el archivo config.php para agregar los dominios de confianza
echo "Añadiendo dominios de confianza a la configuración de OwnCloud..."
php -r "
  \$configFile = '/var/www/html/owncloud/config/config.php';
  if (file_exists(\$configFile)) {
    \$config = include(\$configFile);
    \$config['trusted_domains'] = array(
      'localhost',
      'localhost:8080',
      '192.168.56.10',
      '192.168.56.11',
      '192.168.56.12',
    );
    file_put_contents(\$configFile, '<?php return ' . var_export(\$config, true) . ';');
  } else {
    echo 'No se pudo encontrar el archivo config.php';
  }
"

# Configuración de PHP-FPM para escuchar en la IP del servidor NFS
sed -i 's/^listen = .*/listen = 192.168.56.12:9000/' /etc/php/7.4/fpm/pool.d/www.conf

# Reiniciar PHP-FPM
sudo systemctl restart php7.4-fpm

#Eliminar puerta de enlace por defecto de Vagrant
sudo ip route del default