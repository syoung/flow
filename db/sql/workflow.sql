CREATE TABLE IF NOT EXISTS workflow
(
  username       VARCHAR(30) NOT NULL,
  projectname    VARCHAR(20) NOT NULL,
  workflowname   VARCHAR(20) NOT NULL,
  workflownumber INT(12) NOT NULL,
  status         VARCHAR(30) DEFAULT '',
  description    TEXT DEFAULT '',
  notes          TEXT DEFAULT '',
  provenance     TEXT DEFAULT '',
  profiles       TEXT DEFAULT '',

  PRIMARY KEY  (username, projectname, workflowname, workflownumber)
);
