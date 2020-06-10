# install.sh

# 1. COPY FILES TO /etc

cd /a/bin/install/resources/agua
sudo cp etc/init.d/broadcast /etc/init.d
sudo cp etc/init/broadcast.conf /etc/init
sudo cp etc/default/broadcast /etc/default


# 2. COPY EXCUTEABLE TO /usr/bin

ln -s /a/bin/daemon/broadcast /usr/bin/broadcast


# 3. RUN SERVICE

service broadcast start

