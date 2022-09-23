#!/bin/bash
#check if script is called as root
if (( $EUID == 0 )); then
#Update the host
echo "we are searching and installing the latest updates, please wait!"
sleep 2
apt update && apt -y upgrade && apt -y full-upgrade && apt -y install curl unzip sudo
echo "Done!"
sleep 2
#Ask if MariaDB/MySQL is installed
read -p "Do You have MariaDB/MySQL installed? [Y/N] " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Nn]$ ]]
then
	echo "This script only works with MariaDB/MYSQL!"
	echo "installing ...!"
	sleep 2
	apt -y install mariadb-server mariadb-client
	echo
	#securing MariaDB/MySQL installation
	echo "Securing MariaDB/MySQL installation!"
	mysql_secure_installation
	echo "installed MariaDB/MYSQL, moving along!"
	sleep 5
else
	echo "You use MariaDB/MYSQL, moving along!"
	echo # (optional) move to a new line
fi
#securing MariaDB/MySQL installation
mysql_secure_installation
#Ask if Apache2 is installed
read -p "Do You have apache2 installed? [Y/N] " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Nn]$ ]]
then
	echo "This script only works with apache2!"
	echo "installing ...!"
	sleep 2
	apt -y install apache2
	echo
	echo "installed apache2, moving along!"
	sleep 5
else
	echo "You use apache2, moving along!"
	echo # (optional) move to a new line
fi
#Ask if remote root login is allowed on the Instance
read -p "Is remote root login via SSH allowed on the Instance? [Y/N] " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Nn]$ ]]
then
	echo "This script only works if remote SSH login for root is allowed!"
	echo "We will enable remote login for root!"
	sleep 10
	sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
	systemctl restart sshd
	echo "remote login enabled!"
else
	echo "remote login for root is allowed, moving along!"
	echo # (optional) move to a new line
fi
#install dependencies for the script
echo "we are now going to install some dependencies, please wait!"
echo #optional, new line
apt -y install sshpass
#install further dependencies for NC
apt -y install php-bcmath php-gmp php-imagick libmagickcore-6.q16-6-extra
#clean up old stuff
apt -y autoremove
#set the default root to root
rootusr='root'
# Ask the user for Data of new Instance
echo
echo "Please put in the root Password of the new Instance"
read newrootpw
echo # (optional) move to a new line
echo "Please put in the db name of the new Instance"
read dbnew
echo # (optional) move to a new line
echo "Please put in the db root passwort of the new Instance"
read dbrootnewpw
echo # (optional) move to a new line
echo "Please put in the nextcloud data path of the new Instance (e.g. /var/www/nextcloud)"
read ncpathnew
echo # (optional) move to a new line
#Ask if crontab is being used for maintenace Jobs. If not move along with the script
#NB: If You are not using cron (highly recommended) make sure that you have setup webcron or that AJAX is working correctly!
read -p "Do You use cron to execute maintenace Jobs on the Nextcloud? [Y/N] " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	#setup crontab for cron.php
	echo -e "*/5 * * * * sudo -u www-data php -f $ncpathnew/cron.php \n" >> /etc/crontab
else
	echo "You do not use cron, moving along!"
	echo "If You are not using cron (highly recommended) make sure that you set up webcron or that AJAX is working correctly!"
	echo # (optional) move to a new line
fi
#set up MariaDB/MySQL
#ensure password is required to access MySQL CLI as root user
mysql -u root -e "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE User = 'root'"
mysql -u root -e "FLUSH PRIVILEGES"
#create Nextcloud database and user
mysql -u $rootusr -p$dbrootnewpw -e "CREATE DATABASE nextcloud"
echo "Please type the password for the new nextcloud db user (username: nextcloud)"
echo #optional (new line)
read dbuserncnew
mysql -u $rootusr -p$dbrootnewpw -e "CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '$dbuserncnew'"
mysql -u $rootusr -p$dbrootnewpw -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost'"
mysql -u $rootusr -p$dbrootnewpw -e "FLUSH PRIVILEGES"
#install php and dependencies
echo "installing php and dependencies"
sleep 2
apt -y install php php-{cli,xml,zip,curl,gd,cgi,mysql,mbstring}
apt -y install libapache2-mod-php
echo "Done!"
echo
sleep 2
#Set PHP variables to suit your use
echo "Set PHP variables to suit your use"
sleep 5
echo "Set your Timezone e.g. Africa/Nairobi"
read timezone
echo "Set the php memory limit e.g. 512M"
read memlimit
echo "Set the max upload size e.g. 512M"
read upldsize
echo "Set the max size of POST data e.g. 512M"
read pstdata
echo "Set the max execution Time for scripts (in seconds) e.g. 300"
read exectime
sleep 2
echo "setting up php.ini!"
sleep 5
echo -e "date.timezone = $timezone \n" >> /etc/php/*/apache2/php.ini
sed -i "s/memory_limit = 128M/memory_limit = $memlimit/g" /etc/php/*/apache2/php.ini
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = $upldsize/g" /etc/php/*/apache2/php.ini
sed -i "s/post_max_size = 8M/post_max_size = $pstdata/g" /etc/php/*/apache2/php.ini
sed -i "s/max_execution_time = 30/max_execution_time = $exectime/g" /etc/php/*/apache2/php.ini
sleep 2
echo "Done seting up php!"
echo
sleep 2
#Set up caching
#Ask if the New instance should use Caching	
read -p "Do You want to use caching on the Nextcloud? (Highly recommended!) [Y/N] " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then	
apt -y install php-apcu
echo -e "apc.enable_cli=1 \n" >> /etc/php/*/mods-available/apcu.ini
echo -e ";enable APCu \napc.enable_cli=1 \n" >> /etc/php/*/apache2/php.ini
echo "Please add the following MANUALLY to your Nextcloud config.php!"
echo "'memcache.local' => '\\OC\\Memcache\\APCu',"
sleep 10
else
	echo "You do not use caching, moving along!"
	echo "Please note! It is highly recommended to use caching!"
	echo "If You decide to enable caching, please check the nextcloud documentation!"
	echo # (optional) move to a new line
fi
#download and unpack the latest Nextcloud release
echo "Downloading the latest Nextcloud Release"
curl -o nextcloud.zip https://download.nextcloud.com/server/releases/latest-22.zip
unzip nextcloud.zip
echo "Done!"
sleep 2
#'install' nextcloud
echo "'Installing' nextcloud ..."
sleep 2
mkdir $ncpathnew
cp -r ./nextcloud/* $ncpathnew
chown -R www-data:www-data $ncpathnew
chmod -R 755 $ncpathnew
echo
echo "Done installing ..."
sleep 2
#Prompt user to run the initial Setup Wizard on the Instance.
echo "Please go ahead and run the inital Web Wizard!"
echo "If You need help running the Wizard, please find the Nextcloud Manual"
sleep 2
echo "Waiting for 30 Seconds before first check!"
sleep 30
while [[ "$REPLY" == "n" ]]
do
  echo 
  read -p "Please type 'Y' if the Wizard has been completed or 'N' if did not yet complete the Wizard " -n 1 -r
  echo
  echo "Waiting for 10 seconds before the next check! "
  sleep 10
done
#inform user that installation has been finished
echo 
echo "You answered 'Y', assuming the Wizard has been completed!"
sleep 5
echo "Congratulations, You are finished!"
sleep 2
echo "exiting!"
sleep 10
exit
else
echo "Please run as root"
    exit
fi