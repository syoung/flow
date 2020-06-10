# install.sh

# 1. COPY FILES TO /etc

cd /a/bin/install/resources/agua
sudo cp etc/init.d/balancer /etc/init.d
sudo cp etc/init/balancer.conf /etc/init
sudo cp etc/default/balancer /etc/default


# 2. COPY EXCUTEABLE TO /usr/bin

ln -s /a/bin/daemon/balancer /usr/bin/balancer


# 3. RUN SERVICE

service balancer start

