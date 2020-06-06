# install.sh

# 1. COPY FILES TO /etc

cd /a/bin/install/resources/agua
sudo cp etc/init.d/heartbeat /etc/init.d
sudo cp etc/init/heartbeat.conf /etc/init
sudo cp etc/default/heartbeat /etc/default


# 2. COPY EXCUTEABLE TO /usr/bin

ln -s /a/bin/daemon/heartbeat /usr/bin/heartbeat


# 3. RUN SERVICE

service heartbeat start

