CREATE TABLE heartbeat
(
  host      VARCHAR(40),
  time      DATETIME,
  ipaddress VARCHAR(40),
  cpu       TEXT,
  io        TEXT,
  disk      TEXT,
  memory    TEXT,
  
  PRIMARY KEY (host, time)
);
