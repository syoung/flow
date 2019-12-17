CREATE TABLE IF NOT EXISTS stageparameter
(
  owner           VARCHAR(30) NOT NULL,
  username        VARCHAR(30) NOT NULL,
  projectname     VARCHAR(20) NOT NULL,
  workflowname    VARCHAR(20) NOT NULL,
  workflownumber  INT(12),

  appname         VARCHAR(40),
  appnumber       VARCHAR(10),
  paramname       VARCHAR(40) NOT NULL default '',
  paramnumber     VARCHAR(10),

  ordinal         INT(6) NOT NULL,
  locked          INT(1) NOT NULL default 0,
  paramtype       VARCHAR(40) NOT NULL default '',
  category        VARCHAR(40) NOT NULL default '',
  valuetype       VARCHAR(20) NOT NULL default '',
  argument        VARCHAR(255) NOT NULL default '',
  value           TEXT,
  discretion      VARCHAR(10) NOT NULL default '',
  format          VARCHAR(40),
  description     TEXT, 
  args            TEXT,
  inputParams     TEXT,
  paramFunction   TEXT,

  chained         INT(1),
  
  PRIMARY KEY  (username, projectname, workflowname, workflownumber, appnumber, paramname, paramnumber, paramtype, ordinal)
);
