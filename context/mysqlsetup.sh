#!/bin/bash

. /mnt/context.sh

## setting the network for NFS 
echo 0 > /proc/sys/net/ipv4/tcp_sack 

echo 0 > /proc/sys/net/ipv4/tcp_timestamps

# Add entries to fstab
if ( ! grep  "NFS Mount Points Added" /etc/fstab); then

     # Create mount points
     mkdir -p /db/mysql_data
     mkdir -p /db/mysql_binlog
     mkdir -p /db/mysql_config
     mkdir -p /db/mysql_tranlog

     cat >>/etc/fstab <<MNTTAB

# NFS Mount Points Added
#

$NFSDATA  /db/mysql_data nfs _netdev,rw,bg,hard,rsize=32768,wsize=32768,nointr,timeo=600,proto=tcp,nolock,noatime,tcp,vers=3
$LOGMNT  /db/mysql_binlog nfs _netdev,rw,bg,hard,rsize=32768,wsize=32768,nointr,timeo=600,proto=tcp,nolock,noatime,tcp,vers=3
$CONFIGMNT  /db/mysql_config nfs _netdev,rw,bg,hard,rsize=32768,wsize=32768,nointr,timeo=600,proto=tcp,nolock,noatime,tcp,vers=3
$TRANLOG  /db/mysql_tranlog nfs _netdev,rw,bg,hard,rsize=32768,wsize=32768,nointr,timeo=600,proto=tcp,nolock,noatime,tcp,vers=3
MNTTAB

fi

if (! mount -a ); then
     echo "Failed to mount all filesystems listed in /etc/fstab">&2
     if (! mountpoint -q /db/mysql_data); then
         echo "Failed to mount $NFSDATA">&2
     fi
     if (! mountpoint -q /db/mysql_binlog); then
         echo "Failed to mount $LOGMNT">&2
     fi
     if (! mountpoint -q /db/mysql_config); then
         echo "Failed to mount $CONFIGMNT">&2
     fi
     if (! mountpoint -q /db/mysql_tranlog); then
         echo "Failed to mount $TRANLOG">&2
     fi
     wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_FAIL 2> /dev/null
fi


if [ ! -d /db/mysql_config/$HOSTNAME ]; then
	mkdir /db/mysql_data/$HOSTNAME
        mkdir /db/mysql_binlog/$HOSTNAME
        mkdir /db/mysql_config/$HOSTNAME
	mkdir /db/mysql_tranlog/$HOSTNAME
	

	#copy the configuration files
	rm /etc/mysql/my.cnf

	mv /etc/mysql/*	/db/mysql_config/$HOSTNAME/
	
	cp /mnt/my.cnf /db/mysql_config/$HOSTNAME/

	echo "slow_query_log_file    = /db/mysql_tranlog/$HOSTNAME/mysql-slow.log" >> /db/mysql_config/$HOSTNAME/my.cnf
	echo "log_error              = /db/mysql_tranlog/$HOSTNAME/mysql-error.log" >> /db/mysql_config/$HOSTNAME/my.cnf
	echo "log_bin                = /db/mysql_binlog/$HOSTNAME/master-bin" >> /db/mysql_config/$HOSTNAME/my.cnf
	echo "log-bin-index          = /db/mysql_binlog/$HOSTNAME/master-bin" >> /db/mysql_config/$HOSTNAME/my.cnf
	echo "general_log_file       = /db/mysql_tranlog/$HOSTNAME/mysql.log" >> /db/mysql_config/$HOSTNAME/my.cnf
	echo "datadir         = /db/mysql_data/$HOSTNAME/mysql" >> /db/mysql_config/$HOSTNAME/my.cnf
	echo "bind-address       = $IP" >> /db/mysql_config/$HOSTNAME/my.cnf
		
	ln -s /db/mysql_config/$HOSTNAME/my.cnf /etc/mysql/my.cnf
	ln -s /db/mysql_config/$HOSTNAME/debian-start /etc/mysql/debian-start
	ln -s /db/mysql_config/$HOSTNAME/debian.cnf /etc/mysql/debian.cnf
        ln -s /db/mysql_config/$HOSTNAME/conf.d /etc/mysql/conf.d

	#copy the mysql files

	cp -R /var/lib/mysql /db/mysql_data/$HOSTNAME/mysql	
	rm /db/mysql_data/$HOSTNAME/mysql/ib_logfile0
	rm /db/mysql_data/$HOSTNAME/mysql/ib_logfile1

        # Setup permissions
        chown -R mysql:mysql /db/mysql_data/$HOSTNAME
        chown -R mysql:mysql /db/mysql_binlog/$HOSTNAME
        chown -R mysql:mysql /db/mysql_config/$HOSTNAME
	chown -R mysql:mysql /db/mysql_tranlog/$HOSTNAME

	if [ ! -d /var/run/mysqld ]; then
	   mkdir /var/run/mysqld
	   chown mysql:mysql /var/run/mysqld
	fi

        if [ -f /etc/init/mysql.override ]; then
		rm /etc/init/mysql.override
        fi


	#start up mysql
	
	/etc/init.d/mysql start	
	
        #set the root password
	/usr/bin/mysqladmin -u root password $DBPWD

 else
	#remove the configuration files
        rm -rf /etc/mysql/*
	#make the link
	ln -s /db/mysql_config/$HOSTNAME/my.cnf /etc/mysql/my.cnf
        ln -s /db/mysql_config/$HOSTNAME/debian-start /etc/mysql/debian-start
        ln -s /db/mysql_config/$HOSTNAME/debian.cnf /etc/mysql/debian.cnf
        ln -s /db/mysql_config/$HOSTNAME/conf.d /etc/mysql/conf.d


	
	if [ ! -d /var/run/mysqld ]; then
           mkdir /var/run/mysqld
           chown mysql:mysql /var/run/mysqld
        fi

        if [ -f /etc/init/mysql.override ]; then
                rm /etc/init/mysql.override
        fi

       #start up mysqld	
        /etc/init.d/mysql start

 fi
 
wget http://$CARINA_IP/cgi-bin/updateappstatus.sh?service=$SERVICE_NAME\&vmid=$VMID\&envid=$ENVID\&status=MASTER_INIT_DONE 2> /dev/null
