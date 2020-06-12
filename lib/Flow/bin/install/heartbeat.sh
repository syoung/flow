# install.sh

INSTALLDIR=$1

# 1. COPY FILES TO /etc
cd $INSTALLDIR/bin/install
cp etc/init.d/heartbeat /etc/init.d
cp etc/init/heartbeat.conf /etc/init
cp etc/default/heartbeat /etc/default

# 2. COPY EXCUTEABLE TO /usr/bin
ln -s $INSTALLDIR/bin/daemon/heartbeat /usr/bin/heartbeat
chmod 755 /usr/bin/heartbeat

PATH=$INSTALLDIR/lib:$PATH

# 3. RUN SERVICE
. $INSTALLDIR/envars
service heartbeat start

