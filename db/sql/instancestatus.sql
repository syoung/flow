CREATE TABLE instancestatus
(
  username        VARCHAR(30) NOT NULL,
  projectname     VARCHAR(20) NOT NULL,
  workflowname    VARCHAR(20) NOT NULL,
  stagename       VARCHAR(20) NOT NULL,
  status          VARCHAR(30),
  started         DATETIME NOT NULL,
  stopped         DATETIME NOT NULL,
  terminated      DATETIME NOT NULL,
  polled          DATETIME NOT NULL,
  hours           INT(12),
  
  PRIMARY KEY ( username, projectname, workflowname, stagename )
);
