CREATE TABLE IF NOT EXISTS provenance
(
  username       	VARCHAR(30) NOT NULL,
  projectname    	VARCHAR(40) NOT NULL,
  workflowname   	VARCHAR(40) NOT NULL,
	workflownumber	INT(6) NOT NULL,
  samplename      VARCHAR(40) NOT NULL,

	appname			    VARCHAR(40) NOT NULL,
	appnumber		    INT(6) NOT NULL,
	
  package         VARCHAR(40) NOT NULL,
  version         VARCHAR(40) NOT NULL,
	installdir		  VARCHAR(255) NOT NULL,
	location		    VARCHAR(255) NOT NULL,

	host			      VARCHAR(40) NOT NULL,
	ipaddress		    VARCHAR(40) NOT NULL,
	status			    VARCHAR(40) NOT NULL,
	time			      datetime,
	stdout			    TEXT,
	stderr			    TEXT,
 
  PRIMARY KEY  (username, projectname, workflowname, workflownumber, samplename, appname, appnumber, status, time)
);
