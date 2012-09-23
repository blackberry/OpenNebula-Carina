#!/bin/bash -x
cd /var/lib/one
mv opennebula-carina  opennebula-carina.old
tar xvf $1
mv ./opennebula-carina/oneenv.conf ./opennebula-carina/oneenv.conf.bak
cp ./opennebula-carina.old/global.rb  ./opennebula-carina/global.rb
SVCLIST="oneenv oneenv1 oneenv2"
PIDLIST=`ps aux | grep oneenvd | awk '{print $2}'`
for pid in $PIDLIST
do
    echo "Killing $pid"
    kill $pid
done
/bin/su - oneenv -c "/var/lib/one/opennebula-carina/misc/start-oneenvd-gs.sh"
for svc in $SVCLIST
do
    /bin/su - $svc -c "/var/lib/one/opennebula-carina/misc/start-oneenvd.sh"
done

