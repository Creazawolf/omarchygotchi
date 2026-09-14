CREATE TABLE pets (
  id TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 20),
  seed INTEGER NOT NULL CHECK(seed BETWEEN 0 AND 4294967295),
  stage TEXT NOT NULL CHECK(stage IN ('egg','baby','kid','teen','adult','elder','ghost')),
  seen INTEGER NOT NULL,
  discover INTEGER NOT NULL DEFAULT 0 CHECK(discover IN (0,1)),
  offline_until INTEGER NOT NULL DEFAULT 0,
  auto_roam INTEGER NOT NULL DEFAULT 0 CHECK(auto_roam IN (0,1)),
  last_visit INTEGER NOT NULL DEFAULT 0,
  created INTEGER NOT NULL,
  banned INTEGER NOT NULL DEFAULT 0 CHECK(banned IN (0,1))
);
CREATE INDEX pets_park ON pets(discover, banned, last_visit);
CREATE TABLE relations (
  lo TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  hi TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  src TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK(status IN ('pending','friends')),
  PRIMARY KEY(lo,hi),
  CHECK(lo < hi AND src IN (lo,hi))
);
CREATE INDEX relations_hi ON relations(hi);
CREATE TABLE blocks (
  src TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  dst TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  PRIMARY KEY(src,dst), CHECK(src != dst)
);
CREATE INDEX blocks_dst ON blocks(dst);
CREATE TABLE visits (
  id TEXT PRIMARY KEY,
  a TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  b TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  activity TEXT NOT NULL,
  at INTEGER NOT NULL,
  CHECK(a < b)
);
CREATE INDEX visits_a ON visits(a,at DESC);
CREATE INDEX visits_b ON visits(b,at DESC);
CREATE INDEX visits_at ON visits(at);
CREATE TRIGGER visit_updates_cooldowns AFTER INSERT ON visits BEGIN
  UPDATE pets SET last_visit=NEW.at WHERE id IN (NEW.a,NEW.b);
END;
CREATE TABLE quotas (key TEXT PRIMARY KEY, window INTEGER NOT NULL, count INTEGER NOT NULL);
CREATE INDEX quotas_window ON quotas(window);
