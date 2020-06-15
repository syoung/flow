CREATE TABLE failed
(
  time       DATETIME,
  source     VARCHAR(50),
  message    TEXT,
  
  PRIMARY KEY ( time, source )
);
