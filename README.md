# Instalación de Owncloud en arquitectura de 3 capas en alta disponibilidad.

## Índice

1. [Introducción](#introducción)  
2. [Requisitos Previos](#requisitos-previos)  
3. [Infraestructura y Direccionamiento IP](#infraestructura-y-direccionamiento-ip)
4. [Estructura](#estructura)  
5. [Vagrantfile](#vagrantfile) 
6. [Instalación y Configuración](#instalación-y-configuración)
    - [Configuración del Balanceador de Carga](#configuración-del-balanceador-de-carga)  
    - [Configuración del Servidor de Base de Datos](#configuración-del-servidor-de-base-de-datos)  
    - [Configuración del Servidor NFS](#configuración-del-servidor-nfs)  
    - [Configuración de los Servidores Web](#configuración-de-los-servidores-web)
7. [Despliegue](#despliegue)  
8. [Conclusión](#conclusión)

## Introducción
En esta práctica, se implementará un entorno virtualizado para la instalación y configuración de OwnCloud, un sistema de almacenamiento y colaboración en la nube. La infraestructura estará compuesta por múltiples máquinas virtuales gestionadas con Vagrant, y cada máquina tendrá un rol específico: balanceador de carga, base de datos, servidor NFS y servidores web. Se utilizarán scripts de configuración automatizada para garantizar la coherencia y reproducibilidad de la instalación.

Se empleará el siguiente direccionamiento IP para la infraestructura:
- **192.168.56.10** y **192.168.60.11**: Servidor web 1
- **192.168.56.11** y **192.168.60.12**: Servidor web 2
- **192.168.56.12**:y **192.168.60.13** Servidor NFS
- **192.168.60.10**: Servidor de base de datos
- **192.168.56.2** e ip pública asignada automáticamente: Balanceador

## Requisitos previos
- Vagrant instalado en la máquina anfritión.
- VirtualBox para proveer las máquinas virtuales.
- Imagen Debian.
- Conexión de internet para poder instalar los paquetes necesarios.

## Infraestructura y Direccionamiento IP
1. **Red** `red_balancer_red`: Conecta el balanceador de carga con los servidores web y el servidor NFS.
2. **Red** `red_sgbd_webs_nfs`: Conecta los servidores web, el servidor NFS y el servidor de base de datos.

Roles en las máquinas:
1. **Balanceador de carga**:  Administra el tráfico entre los servidores web.
2. **Servidores web**: Ejecutan OwnCloud y están configurados para acceder al almacenamiento compartido.
3. **Servidor NFS**: Proporciona almacenamiento compartido para los servidores web.
4. **Servidor de base de datos**: Aloja la base de datos MariaDB necesaria para OwnCloud.

## Estructura
├── balancer.sh      # Script para configurar el balanceador de carga.

├── nfs.sh              # Script para configurar el servidor NFS y el contenido de WordPress.

├── web.sh       # Script para configurar los servidores backend.

├── db.sh              # Script para configurar la base de datos.

├── Vagrantfile              # Archivo principal que define la infraestructura virtualizada.

└── README.md           # Documento técnico y explicativo.


## Vagrantfile
El `Vagrantfile` es el archivo principal que define la infraestructura virtualizada. Aquí está su explicación:
![Vagrantfile](https://github.com/user-attachments/assets/d2cbfbf9-a2c7-4ba1-929b-4558665f5e2c)

### Configuración General

- **`config.vm.box = "debian/bullseye64"`**  
  Define la imagen base que se usará para todas las máquinas virtuales. En este caso, se utiliza Debian Bullseye.

- **`config.vm.define`**  
  Define una máquina virtual con un nombre único, como `SGBDDDavidS` o `Web1DavidS`.

### Configuración de Red

- **`private_network`**  
  Configura una red privada con una IP fija para la máquina virtual.

- **`virtualbox_intnet`**  
  Define el nombre de la red interna utilizada por VirtualBox.

### Configuración de Scripts de Provisión

- **`app.vm.provision "shell", path: "<script>"`**  
  Especifica un script de shell que se ejecutará automáticamente para configurar la máquina virtual.

### Máquinas Definidas

- **`SGBDDDavidS`**  
  Servidor de base de datos, con la IP `192.168.60.10`.

- **`NFSDavidS`**  
  Servidor NFS, con dos IPs: `192.168.60.13` y `192.168.56.12`.

- **`Web1DavidS` y `Web2DavidS`**  
  Servidores web, conectados tanto al balanceador como al servidor NFS.

- **`BalancerDavidS`**  
  Balanceador de carga, con IP pública y privada (`192.168.56.2`).

## Instalación y Configuración

### Configuración del Balanceador de Carga
![balancer image](https://github.com/user-attachments/assets/9435cb74-b4f7-43aa-9448-513f576771b3)

```console
sudo apt-get update -y
```
- **Descripción**: Actualiza la lista de paquetes disponibles en los repositorios configurados en el sistema.
- `y`: Acepta automáticamente las confirmaciones necesarias para la ejecución del comando.

```console
sudo apt-get install -y nginx
```
-  Instala el servidor web Nginx.

```console
cat <<EOF > /etc/nginx/sites-available/default
```
- Crea o sobrescribe el archivo de configuración predeterminado de Nginx en la ruta `/etc/nginx/sites-available/default`. El contenido del archivo será todo lo que se escriba entre `cat <<EOF` y `EOF`.

```console
upstream backend_servers {
    server 192.168.56.10;
    server 192.168.56.11;
}
```
- `upstream backend_servers`: Define un grupo de servidores backend que Nginx utilizará para balancear la carga.
- `server 192.168.56.10;` y `server 192.168.56.11;`: Especifica las direcciones IP de los servidores backend que recibirán las solicitudes.

```console
server {
    listen 80;
    server_name localhost;
```
- `listen 80;`: Configura el servidor para escuchar en el puerto 80 (puerto predeterminado para HTTP).
- `server_name localhost;`: Define el nombre del servidor, en este caso `localhost`.

```console
    location / {
        proxy_pass http://backend_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
```
- `location /`: Especifica que las reglas dentro de este bloque se aplicarán a todas las solicitudes que coincidan con la raíz (`/`) del servidor.
- `proxy_pass http://backend_servers;`: Redirige las solicitudes entrantes al grupo de servidores definido en `upstream backend_servers`.
- `proxy_set_header Host $host;`: Configura el encabezado HTTP Host para que coincida con el valor del host solicitado.
- `proxy_set_header X-Real-IP $remote_addr;`: Añade el encabezado `X-Real-IP` para pasar la dirección IP del cliente al servidor backend.
- `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`: Añade el encabezado `X-Forwarded-For` para incluir la dirección IP del cliente en la solicitud enviada al backend.

```console
EOF
```
- Finaliza la entrada del contenido del archivo que comenzó con `cat <<EOF`.

```console
sudo systemctl restart nginx
```
- Reinicia el servicio Nginx para aplicar los cambios realizados en su configuración.

### Configuración del Servidor de Base de Datos
El servidor de base de datos utiliza MariaDB para gestionar los datos de OwnCloud.
![db image](https://github.com/user-attachments/assets/fc5d2660-df73-456f-87c1-b39bd2a13ec4)

```console
sudo apt-get install -y mariadb-server
```
- Instala el servidor de bases de datos MariaDB.

```console
sed -i 's/bind-address.*/bind-address = 192.168.60.10/' /etc/mysql/mariadb.conf.d/50-server.cnf
```
- Modifica el archivo de configuración de MariaDB para que el servidor escuche únicamente en la dirección IP `192.168.60.10`.
- `-i`: Edita el archivo directamente en su lugar.
- `s/bind-address.*/bind-address = 192.168.60.10/`: Reemplaza la línea que comienza con bind-address por `bind-address = 192.168.60.10`.

```console
sudo systemctl restart mariadb
```
- Reinicia el servicio MariaDB para aplicar los cambios realizados en su configuración.

```console
mysql -u root <<EOF
CREATE DATABASE owncloud;
CREATE USER 'owncloud'@'192.168.60.%' IDENTIFIED BY '1234';
GRANT ALL PRIVILEGES ON owncloud.* TO 'owncloud'@'192.168.60.%';
FLUSH PRIVILEGES;
EOF
```
- `CREATE DATABASE owncloud;`: Crea una base de datos llamada `owncloud`.
- `CREATE USER 'owncloud'@'192.168.60.%' IDENTIFIED BY '1234';`: Crea un usuario llamado `owncloud` con la contraseña `1234`, permitiendo acceso desde cualquier máquina en la subred `192.168.60.*`.
- `GRANT ALL PRIVILEGES ON owncloud.* TO 'owncloud'@'192.168.60.%';`: Otorga todos los privilegios sobre la base de datos `owncloud` al usuario creado.
- `FLUSH PRIVILEGES;`: Recarga los privilegios para asegurarse de que los cambios tengan efecto.

```console
sudo ip route del default
```
- Elimina la puerta de enlace predeterminada configurada por Vagrant. Esto asegura que las rutas de red sean manejadas de manera específica dentro de la infraestructura configurada.

### Configuración del Servidor NFS
El servidor NFS proporciona almacenamiento compartido para los servidores web.
![nfs image 1](https://github.com/user-attachments/assets/0f0c8c2f-6d64-4de5-be0f-fc4d4086f538)
![nfs image 2](https://github.com/user-attachments/assets/d677314f-7074-4f4f-a8f3-08d34b840e2d)

```console
sudo apt-get install -y nfs-kernel-server php7.4 php7.4-fpm php7.4-mysql php7.4-gd php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip php7.4-intl php7.4-ldap unzip
```
- Instala el servidor NFS y varios paquetes necesarios para el funcionamiento de OwnCloud, como PHP y sus módulos.

```console
sudo mkdir -p /var/www/html
```
- Crea el directorio `/var/www/html` si no existe. Este directorio será utilizado para almacenar los archivos de OwnCloud.

```console
sudo chown -R www-data:www-data /var/www/html
```
-  Cambia el propietario y grupo del directorio `/var/www/html` a `www-data`, que es el usuario y grupo predeterminado utilizado por el servidor web (Nginx o Apache).

```console
sudo chmod -R 755 /var/www/html
```
- Establece permisos de lectura, escritura y ejecución para el propietario, y permisos de lectura y ejecución para el grupo y otros usuarios en el directorio `/var/www/html`.

```console
echo "/var/www/html 192.168.56.10(rw,sync,no_subtree_check)" >> /etc/exports
echo "/var/www/html 192.168.56.11(rw,sync,no_subtree_check)" >> /etc/exports
```
- Configura el servidor NFS para compartir el directorio /var/www/html con las máquinas con las IPs `192.168.56.10` y `192.168.56.11`.
- `rw`: Permite lectura y escritura en el directorio compartido.
- `sync`: Asegura que las operaciones de escritura se realicen de manera síncrona.
- `no_subtree_check`: Desactiva la comprobación de subdirectorios, lo que mejora el rendimiento.

```console
sudo exportfs -a
```
- Aplica las configuraciones de exportación de NFS definidas en el archivo `/etc/exports`.

```console
sudo systemctl restart nfs-kernel-server
```
- Reinicia el servicio nfs-kernel-server para aplicar las configuraciones de NFS.

```console
wget https://download.owncloud.com/server/stable/owncloud-10.9.1.zip
```
-  Descarga la última versión estable de OwnCloud desde el sitio oficial.

```console
unzip owncloud-10.9.1.zip
```
- Descomprime el archivo ZIP descargado de OwnCloud.

```console
mv owncloud /var/www/html/
```
- Mueve el directorio descomprimido de OwnCloud a `/var/www/html/`, que es el directorio raíz del servidor web.

```console
sudo chown -R www-data:www-data /var/www/html/owncloud
```
- Cambia el propietario y grupo del directorio `owncloud` a `www-data`, para que el servidor web pueda acceder a los archivos.

```console
sudo chmod -R 755 /var/www/html/owncloud
```
- Establece permisos adecuados para el directorio de OwnCloud, permitiendo que el servidor web lea y escriba en él.

```console
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
```
- Crea un archivo de configuración inicial para OwnCloud (`autoconfig.php`) con la configuración de la base de datos, el directorio de datos y las credenciales de administrador.

```console
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
```
- Añade dominios de confianza a la configuración de OwnCloud, permitiendo que se acceda desde las IPs y nombres de dominio especificados.

```console
sed -i 's/^listen = .*/listen = 192.168.56.12:9000/' /etc/php/7.4/fpm/pool.d/www.conf
```
- Modifica la configuración de PHP-FPM para que escuche en la IP `192.168.56.12` y puerto `9000`, permitiendo que Nginx se comunique con PHP.

```console
sudo systemctl restart php7.4-fpm
```
- Reinicia el servicio PHP-FPM para aplicar los cambios en la configuración.

```console
sudo ip route del default
```
- Elimina la puerta de enlace predeterminada configurada por Vagrant. Esto asegura que las rutas de red sean manejadas de manera específica dentro de la infraestructura configurada.

### Configuración de los Servidores Web
Los servidores web utilizan Nginx y están configurados para acceder al almacenamiento NFS.
![web image 1](https://github.com/user-attachments/assets/905def39-d96b-4276-b795-258551e5f6d7)
![web image 2](https://github.com/user-attachments/assets/4e637424-2e42-4526-b185-5e882f7ca56a)

```console
sudo apt-get install -y nginx nfs-common php7.4 php7.4-fpm php7.4-mysql php7.4-gd php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip php7.4-intl php7.4-ldap mariadb-client
```
- Instala Nginx, el cliente NFS y los paquetes necesarios de PHP y MariaDB.

```console
sudo mkdir -p /var/www/html
```
- Crea el directorio `/var/www/html` si no existe. Este directorio se utilizará para montar el directorio compartido desde el servidor NFS.

```console
sudo mount -t nfs 192.168.56.12:/var/www/html /var/www/html
```
- Monta el directorio `/var/www/html` desde el servidor NFS (con IP `192.168.56.12`) en el directorio local `/var/www/html`. Esto permite que los servidores web accedan al almacenamiento compartido.

```console
echo "192.168.56.12:/var/www/html /var/www/html nfs defaults 0 0" >> /etc/fstab
```
-  Añade una entrada al archivo `/etc/fstab` para que el directorio compartido se monte automáticamente en el arranque del sistema.

```console
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
```
- Crea el archivo de configuración de Nginx para el servidor web, donde se define cómo manejar las solicitudes para OwnCloud.
- `listen 80;`: Configura Nginx para escuchar en el puerto 80 (HTTP).
- `root /var/www/html/owncloud;`: Establece el directorio raíz de Nginx para que apunte a la carpeta de OwnCloud.
- `index index.php index.html index.htm;`: Define los archivos de índice que Nginx buscará cuando se acceda a un directorio.
- `location / { try_files \$uri \$uri/ /index.php?\$query_string; }`: Configura la regla de reescritura para las solicitudes, asegurando que las URLs se resuelvan correctamente.
- `location ~ \.php\$ { ... }`: Configura cómo manejar las solicitudes PHP, pasando las solicitudes PHP a PHP-FPM en el servidor NFS.
- `location ~ ^/(?:\.htaccess|data|config|db_structure\.xml|README) { deny all; }`: Deniega el acceso a archivos sensibles de configuración y datos.

```console
nginx -t
```
- Verifica la sintaxis del archivo de configuración de Nginx para asegurarse de que no haya errores.

```console
sudo systemctl restart nginx
```
-  Reinicia el servicio Nginx para aplicar los cambios realizados en la configuración.

```console
sudo systemctl restart php7.4-fpm
```
-  Reinicia el servicio PHP-FPM para aplicar los cambios realizados en su configuración.

```console
sudo ip route del default
```
- Elimina la puerta de enlace predeterminada configurada por Vagrant. Esto asegura que las rutas de red sean manejadas de manera específica dentro de la infraestructura configurada.

## Despliegue
- **Configurar Vagrantfile** siguiendo los pasos anteriores (importante que las máquinas sigan el siguiente orden en la instalción: base de datos, servidor nfs, servidores webs y balanceador; y que la imagen sea preferiblemente una debian/bullseye64).
- **Ejecutar Vagrant + provisions**: Ejecutamos en nuestra terminal vagrant up --provision o primero vagrant up y posteriormente vagrant provision.
- **Acceder a Owncloud**: Pondremos la ip pública que nos da nuestro balanceador (hacer vagrant ssh a la máquina del balanceador y poner ip a para ver la ip pública); http://ip_pública_balanceador/owncloud y pondremos nuestras credenciales de admin.

## Conclusión
En esta práctica podremos ver cómo configurar un entorno virtualizado para OwnCloud utilizando Vagrant y scripts automatizados. La separación de roles en diferentes máquinas garantiza escalabilidad y flexibilidad, y el uso de almacenamiento compartido centralizado facilita la gestión de datos en múltiples servidores.

