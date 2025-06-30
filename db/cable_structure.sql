CREATE TABLE solid_cable_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  channel VARCHAR NOT NULL,
  payload TEXT NOT NULL,
  created_at DATETIME NOT NULL
);
CREATE INDEX index_solid_cable_messages_on_channel 
ON solid_cable_messages (channel)
 /*application='Letter'*/;
CREATE INDEX index_solid_cable_messages_on_created_at 
ON solid_cable_messages (created_at)
 /*application='Letter'*/;
