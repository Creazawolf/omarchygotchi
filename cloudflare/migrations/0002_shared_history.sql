-- Durable relationship memory is separate from the rolling visit journal.
CREATE TABLE bonds (
  lo TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  hi TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  encounters INTEGER NOT NULL DEFAULT 0,
  first_at INTEGER NOT NULL,
  last_at INTEGER NOT NULL,
  romance_lo INTEGER NOT NULL DEFAULT 0 CHECK(romance_lo IN (0,1)),
  romance_hi INTEGER NOT NULL DEFAULT 0 CHECK(romance_hi IN (0,1)),
  together_at INTEGER NOT NULL DEFAULT 0,
  memory TEXT NOT NULL DEFAULT '',
  keepsake TEXT NOT NULL DEFAULT '',
  PRIMARY KEY(lo,hi), CHECK(lo < hi)
);
CREATE INDEX bonds_hi ON bonds(hi);
ALTER TABLE visits ADD COLUMN scene TEXT;
-- Preserve existing shared history during upgrade.
INSERT INTO bonds(lo,hi,encounters,first_at,last_at,memory)
  SELECT a,b,count(*),min(at),max(at),'Already know their way to each other’s doorstep.' FROM visits GROUP BY a,b;
CREATE TRIGGER visit_remembers AFTER INSERT ON visits BEGIN
  INSERT INTO bonds(lo,hi,encounters,first_at,last_at,memory,keepsake)
    VALUES(NEW.a,NEW.b,1,NEW.at,NEW.at,NEW.activity,coalesce(json_extract(NEW.scene,'$.keepsake'),''))
    ON CONFLICT(lo,hi) DO UPDATE SET encounters=encounters+1,last_at=NEW.at,memory=NEW.activity,keepsake=coalesce(json_extract(NEW.scene,'$.keepsake'),'');
END;
CREATE TABLE families (
  id TEXT PRIMARY KEY,
  a TEXT REFERENCES pets(id) ON DELETE SET NULL,
  b TEXT REFERENCES pets(id) ON DELETE SET NULL,
  proposer TEXT NOT NULL,
  home TEXT NOT NULL,
  name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 20),
  seed INTEGER NOT NULL,
  color_seed INTEGER NOT NULL,
  parents TEXT NOT NULL,
  trait TEXT NOT NULL,
  proposed_at INTEGER NOT NULL,
  accepted_at INTEGER NOT NULL DEFAULT 0,
  CHECK(a < b OR a IS NULL OR b IS NULL), CHECK(home IN (a,b))
);
CREATE INDEX families_a ON families(a);
CREATE INDEX families_b ON families(b);
-- A single growing child (including a pending egg) per household. Limits hold
-- even when two owners submit different proposals concurrently.
CREATE TRIGGER family_capacity BEFORE INSERT ON families BEGIN
  SELECT (CASE WHEN EXISTS(SELECT 1 FROM families f WHERE
    (f.a IN (NEW.a,NEW.b) OR f.b IN (NEW.a,NEW.b)) AND
    (f.accepted_at=0 OR f.accepted_at>NEW.proposed_at-1209600))
    THEN RAISE(ABORT,'household occupied') END);
  SELECT (CASE WHEN (SELECT count(*) FROM families WHERE a=NEW.a OR b=NEW.a)>=12
    OR (SELECT count(*) FROM families WHERE a=NEW.b OR b=NEW.b)>=12
    THEN RAISE(ABORT,'family album full') END);
END;
-- Ending a friendship or blocking stops courtship and cancels an unagreed egg.
CREATE TRIGGER relation_ends_story AFTER DELETE ON relations BEGIN
  UPDATE bonds SET romance_lo=0,romance_hi=0,together_at=0 WHERE lo=OLD.lo AND hi=OLD.hi;
  DELETE FROM families WHERE a=OLD.lo AND b=OLD.hi AND accepted_at=0;
END;
CREATE TRIGGER block_ends_story AFTER INSERT ON blocks BEGIN
  UPDATE bonds SET romance_lo=0,romance_hi=0,together_at=0 WHERE lo=min(NEW.src,NEW.dst) AND hi=max(NEW.src,NEW.dst);
  DELETE FROM families WHERE a=min(NEW.src,NEW.dst) AND b=max(NEW.src,NEW.dst) AND accepted_at=0;
END;

CREATE TRIGGER parent_leaves_before_agreement BEFORE DELETE ON pets BEGIN
  DELETE FROM families WHERE (a=OLD.id OR b=OLD.id) AND accepted_at=0;
END;
