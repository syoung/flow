INSTALL

# 1. Dependencies

## 1.1 Applications

### Ubuntu:
apt-get -y install cpanminus
apt-get -y install perl-doc
apt-get -y install unzip
apt-get -y install wget
apt-get -y install time

### Centos:
yum install -y perl-Pod-Perldoc.noarch
yum install -y cpanminus
yum -y install unzip
yum -y install wget
yum -y install time

## 1.2 Perl modules
cpanm install JSON
cpanm install Term::ReadKey


# 2. Installation

** Clone flow from Github **

git clone https://github.com/syoung/flow.git


# 3. Configuration

Run the following commands applications in order:

** Enter package directory **

```bash
cd flow
```

** Run installer **

```bash
./install.pl
```

This will configure the embedded perl, create database and config files, and set environment variables.

** Show usage **

Run the flow command to display usage instructions

```bash
flow
```





