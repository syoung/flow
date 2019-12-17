CREATE TABLE profile
(
  username      VARCHAR(20) NOT NULL,
  projectname   VARCHAR(20) NOT NULL,
  projectnumber INT(12),
  profilename   VARCHAR(30) NOT NULL DEFAULT '',
  profilenumber TEXT NOT NULL DEFAULT '',
  
  PRIMARY KEY ( username, projectname, profilename )
);
