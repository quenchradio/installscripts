#!/bin/bash
set -e
bpcver=4.1.2 
bpcxsver=0.53
rsyncbpcver=3.0.9.6
apt-get install -q -y apache2 apache2-utils libapache2-mod-perl2 glusterfs-client par2 perl smbclient rsync tar sendmail gcc zlib1g zlib1g-dev libapache2-mod-scgi rrdtool git make perl-doc libarchive-zip-perl libfile-listing-perl libxml-rss-perl libcgi-session-perl
echo -n "Give password or leave empty to generate one: "
read -s PASSWORD
echo
if [[ $PASSWORD == "" ]]; then
  apt-get -qq -y install pwgen
  PASSWORD=`pwgen -s -1 32`
  echo "Generated password: $PASSWORD"
else
  echo "Password given is: $PASSWORD"
fi
echo "$PASSWORD" > /root/password
chmod 600 /root/password
mkdir /srv/backuppc
ln -s /srv/backuppc/ /var/lib/backuppc
adduser --system --home /var/lib/backuppc --group --disabled-password --shell /bin/false backuppc
echo "backuppc:$PASSWORD" | sudo chpasswd backuppc
mkdir -p /var/lib/backuppc/.ssh
chmod 700 /var/lib/backuppc/.ssh
echo -e "BatchMode yes\nStrictHostKeyChecking no" > /var/lib/backuppc/.ssh/config
ssh-keygen -q -t rsa -b 4096 -N '' -C "BackupPC key" -f /var/lib/backuppc/.ssh/id_rsa
chmod 600 /var/lib/backuppc/.ssh/id_rsa
chmod 644 /var/lib/backuppc/.ssh/id_rsa.pub
chown -R backuppc:backuppc /var/lib/backuppc/.ssh

# Fetch latest stable releases
wget https://github.com/backuppc/backuppc-xs/releases/download/$bpcxsver/BackupPC-XS-$bpcxsver.tar.gz
wget https://github.com/backuppc/rsync-bpc/releases/download/$rsyncbpcver/rsync-bpc-$rsyncbpcver.tar.gz
wget https://github.com/backuppc/backuppc/releases/download/$bpcver/BackupPC-$bpcver.tar.gz
tar -zxf BackupPC-XS-$bpcxsver.tar.gz
tar -zxf rsync-bpc-$rsyncbpcver.tar.gz
tar -zxf BackupPC-$bpcver.tar.gz
cd BackupPC-XS-$bpcxsver
perl Makefile.PL
make
make test
make install
cd ../rsync-bpc-$rsyncbpcver
./configure
make
make install
cd ../BackupPC-$bpcver

# To fetch the latest development code instead, replace the above section with:
#git clone https://github.com/backuppc/backuppc.git
#git clone https://github.com/backuppc/backuppc-xs.git
#git clone https://github.com/backuppc/rsync-bpc.git
#cd backuppc-xs
#perl Makefile.PL
#make
#make test
#make install
#cd ../rsync-bpc
#./configure
#make
#make install
#cd ../backuppc
#./makeDist --nosyntaxCheck --releasedate "`date -u "+%d %b %Y"`" --version ${bpcver}git
#tar -zxf dist/BackupPC-${bpcver}git.tar.gz
#cd BackupPC-${bpcver}git

./configure.pl --batch --cgi-dir /var/www/cgi-bin/BackupPC --data-dir /var/lib/backuppc --hostname backuppc --html-dir /var/www/html/BackupPC --html-dir-url /BackupPC --install-dir /usr/local/BackupPC
cp httpd/BackupPC.conf /etc/apache2/conf-available/backuppc.conf
sed -i "/deny\ from\ all/d" /etc/apache2/conf-available/backuppc.conf
sed -i "/deny\,allow/d" /etc/apache2/conf-available/backuppc.conf
sed -i "/allow\ from/d" /etc/apache2/conf-available/backuppc.conf
sed -i "s/export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=backuppc/" /etc/apache2/envvars
sed -i "s/export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=backuppc/" /etc/apache2/envvars
a2enconf backuppc
a2enmod cgid
service apache2 restart
cp systemd/init.d/debian-backuppc /etc/init.d/backuppc
chmod 755 /etc/init.d/backuppc
update-rc.d backuppc defaults
chmod u-s /var/www/cgi-bin/BackupPC/BackupPC_Admin
touch /etc/BackupPC/BackupPC.users
sed -i "s/$Conf{CgiAdminUserGroup}.*/$Conf{CgiAdminUserGroup} = 'backuppc';/" /etc/BackupPC/config.pl
sed -i "s/$Conf{CgiAdminUsers}.*/$Conf{CgiAdminUsers} = 'backuppc';/" /etc/BackupPC/config.pl
chown -R backuppc:backuppc /etc/BackupPC
echo $PASSWORD | htpasswd -i /etc/BackupPC/BackupPC.users backuppc
service backuppc start
