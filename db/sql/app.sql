CREATE TABLE IF NOT EXISTS app (
  owner           VARCHAR(30) NOT NULL,    
  username        VARCHAR(30) NOT NULL,    
  packagename     VARCHAR(40) NOT NULL,
  packageversion  VARCHAR(40) NOT NULL,
  installdir      VARCHAR(255) NOT NULL,
  
  appname         VARCHAR(40) NOT NULL,
  apptype         VARCHAR(40) NOT NULL,
  version         VARCHAR(40) NOT NULL,

  location        VARCHAR(255) NOT NULL default '',
  localonly       INT(1) NOT NULL default 0,
  executor        VARCHAR(40) NOT NULL default '',
  
  description     TEXT,
  notes           TEXT,
  url             TEXT,
  linkurl         TEXT,
  
  PRIMARY KEY  (owner, appname, apptype, packagename, installdir)
);
