# install.sh

INSTALLDIR=$1

# 1. COPY FILES TO /etc
cd $INSTALLDIR/bin/install
cp etc/init.d/worker /etc/init.d
cp etc/init/worker.conf /etc/init
cp etc/default/worker /etc/default

# 2. COPY EXCUTEABLE TO /usr/bin
ln -s $INSTALLDIR/bin/daemon/worker /usr/bin/worker

# 3. RUN SERVICE
. $INSTALLDIR/envars
service worker start

