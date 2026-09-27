-- Friend codes: one short code per creature that its owner shares and a
-- friend enters. Only a hash is stored; the owner's client keeps the readable
-- code. A new code replaces the old one, and every code expires after a week.
CREATE TABLE invites (
  code_hash TEXT PRIMARY KEY,
  pid TEXT NOT NULL UNIQUE REFERENCES pets(id) ON DELETE CASCADE,
  created INTEGER NOT NULL,
  expires INTEGER NOT NULL
);
CREATE INDEX invites_expires ON invites(expires);
CREATE INDEX pets_seen ON pets(seen);
