CREATE TABLE IF NOT EXISTS queue
(
  username       	VARCHAR(30) NOT NULL,
  projectname     VARCHAR(40) NOT NULL,
  workflowname    VARCHAR(40) NOT NULL,
	workflownumber	INT(8) NOT NULL,
 
  PRIMARY KEY  (username, projectname, workflowname, workflownumber)
);
