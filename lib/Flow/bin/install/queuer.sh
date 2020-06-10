# install.sh

# 1. COPY FILES TO /etc

cd /a/bin/install/resources/agua
sudo cp etc/init.d/queuer /etc/init.d
sudo cp etc/init/queuer.conf /etc/init
sudo cp etc/default/queuer /etc/default


# 2. COPY EXCUTEABLE TO /usr/bin

ln -s /a/bin/daemon/queuer /usr/bin/queuer


# 3. RUN SERVICE

service queuer start

