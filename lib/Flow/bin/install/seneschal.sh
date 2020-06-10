# install.sh

# 1. COPY FILES TO /etc

cd /a/bin/install/resources/agua
sudo cp etc/init.d/seneschal /etc/init.d
sudo cp etc/init/seneschal.conf /etc/init
sudo cp etc/default/seneschal /etc/default


# 2. COPY EXCUTEABLE TO /usr/bin

ln -s /a/bin/daemon/seneschal /usr/bin/seneschal


# 3. RUN SERVICE

service seneschal start

