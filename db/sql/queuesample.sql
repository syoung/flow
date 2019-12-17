CREATE TABLE IF NOT EXISTS queuesample
(
  username       	VARCHAR(30) NOT NULL,
  projectname     VARCHAR(40) NOT NULL,
  workflowname    VARCHAR(40) NOT NULL,
	workflownumber	INT(8) NOT NULL,
  sample         	VARCHAR(40) NOT NULL,
	status			    VARCHAR(40) NOT NULL,
 
  PRIMARY KEY  (username, projectname, workflowname, workflownumber, sample)
);
