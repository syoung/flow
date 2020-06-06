# install.sh

# 1. COPY FILES TO /etc

cd /a/bin/install/resources/agua
sudo cp etc/init.d/template  /etc/init.d/template
sudo cp etc/init/template.conf /etc/init/template
sudo cp etc/default/template /etc/default/template


# 2. COPY EXCUTEABLE TO /usr/bin

cp /a/bin/daemon/template /a/bin/daemon/feedback

ln -s /a/bin/daemon/feedback /usr/bin/feedback


# 3. RUN SERVICE

service feedback start

