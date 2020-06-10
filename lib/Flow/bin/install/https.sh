# install.sh

# 1. COPY FILES TO /etc

cd /a/bin/install/resources/agua
sudo cp etc/init.d/https /etc/init.d
sudo cp etc/init/https.conf /etc/init
sudo cp etc/default/https /etc/default


# 2. COPY EXCUTEABLE TO /usr/bin

ln -s /a/bin/daemon/https /usr/bin/https


# 3. RUN SERVICE

service https start

