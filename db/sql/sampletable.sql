CREATE TABLE IF NOT EXISTS sampletable (
  username        VARCHAR(30) NOT NULL,    
	projectname			VARCHAR(30) NOT NULL,    
  sampletable     VARCHAR(40) NOT NULL,
    
  PRIMARY KEY  (username, projectname, sampletable)
);
