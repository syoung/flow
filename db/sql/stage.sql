CREATE TABLE IF NOT EXISTS stage (
  owner               VARCHAR(30) NOT NULL,
  package             VARCHAR(40) NOT NULL,
  version             VARCHAR(40) NOT NULL,
  installdir          VARCHAR(255) NOT NULL,

  username            VARCHAR(30) NOT NULL,
  projectname         VARCHAR(20) NOT NULL,
  workflowname        VARCHAR(20) NOT NULL,
  workflownumber      INT(12),
  samplename        	VARCHAR(20) NOT NULL,
  
  appname             VARCHAR(40) NOT NULL default '',
  appnumber           INT(12),
  apptype             VARCHAR(40),

  status              VARCHAR(20),
  ancestor            VARCHAR(3) DEFAULT NULL,
  successor           VARCHAR(3) DEFAULT NULL,
  
  location            VARCHAR(255) NOT NULL default '',
  executor            VARCHAR(255) NOT NULL default '',
  prescript           VARCHAR(255) NOT NULL default '',
  cluster             VARCHAR(20)NOT NULL default '',
  submit              INT(1) NOT NULL DEFAULT 0,

  stderrfile          varchar(255) default NULL,
  stdoutfile          varchar(255) default NULL,

  queued              DATETIME DEFAULT NULL,
  started             DATETIME DEFAULT NULL,
  completed           DATETIME DEFAULT NULL,
  workflowpid         INT(12) DEFAULT NULL,
  stagepid            INT(12) DEFAULT NULL,
  stagejobid          INT(12) DEFAULT NULL,
  
  description         TEXT,
  notes               TEXT,
  
  PRIMARY KEY  (username, projectname, workflowname, workflownumber, appnumber)
);