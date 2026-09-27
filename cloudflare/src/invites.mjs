// Friend codes and honest park presence.
//
// A code is eight characters from an alphabet without look-alikes (no 0/O,
// 1/I/L), shown as XXXX-XXXX: about 40 bits, behind per-creature attempt
// quotas and the IP and user rate limits. Sharing a code is its owner's
// consent and entering it is the other owner's, so a redeemed code makes the
// two creatures friends directly. It stays valid for a week so it can be
// shared with a few people; a new code replaces it at once.

const DAY = 86400;
const ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
const CODE = new RegExp(`^[${ALPHABET}]{8}$`);
export const INVITE_DAYS = 7;

export function normalizeCode(raw) {
  const code = String(raw ?? '').toUpperCase().replace(/[\s-]/g, '');
  return CODE.test(code) ? code : '';
}

export function formatCode(code) { return code.slice(0, 4) + '-' + code.slice(4); }

function randomCode() {
  let out = '';
  while (out.length < 8) {
    // Rejection sampling keeps every character equally likely.
    for (const byte of crypto.getRandomValues(new Uint8Array(16))) {
      if (byte < 248 && out.length < 8) out += ALPHABET[byte % 31];
    }
  }
  return out;
}

export async function presence(db, pid, now, window) {
  const row = await db.prepare(`SELECT
      (SELECT count(*) FROM pets WHERE id!=? AND banned=0 AND seen>?) AS week,
      (SELECT count(*) FROM pets WHERE id!=? AND banned=0 AND discover=1 AND seen>?) AS here`)
    .bind(pid, now - 7 * DAY, pid, now - window).first();
  const mine = await db.prepare('SELECT expires FROM invites WHERE pid=? AND expires>?').bind(pid, now).first();
  return {
    park: {week: Number(row?.week || 0), now: Number(row?.here || 0)},
    invite: mine ? {expires: mine.expires} : null
  };
}

// Returns a message, or {message, extra} when the response carries more than
// the snapshot. `fail(message, status)` throws; `quota` and `hash` come from
// the worker so limits and hashing stay in one place.
export async function inviteAction(db, pid, kind, data, now, {fail, quota, hash, makeVisit}) {
  if (kind === 'invite-revoke') {
    await db.prepare('DELETE FROM invites WHERE pid=?').bind(pid).run();
    return 'Friend code turned off.';
  }

  if (kind === 'invite-create') {
    await quota(db, 'invite-new:' + pid, 10, now);
    const code = randomCode();
    const expires = now + INVITE_DAYS * DAY;
    await db.prepare(`INSERT INTO invites(code_hash,pid,created,expires) VALUES(?,?,?,?)
      ON CONFLICT(pid) DO UPDATE SET code_hash=excluded.code_hash,created=excluded.created,expires=excluded.expires`)
      .bind(await hash(code), pid, now, expires).run();
    return {message: 'Your friend code is ready.', extra: {invite: {code: formatCode(code), expires}}};
  }

  if (kind === 'invite-accept') {
    const code = normalizeCode(data.code);
    if (!code) fail('A friend code has eight letters and numbers, like K7QF-M2XD.');
    // Counted before the lookup, so guessing costs attempts whether or not it hits.
    await quota(db, 'invite-try:' + pid, 20, now);
    const owner = await db.prepare(`SELECT p.id,p.name FROM invites i JOIN pets p ON p.id=i.pid
      WHERE i.code_hash=? AND i.expires>? AND p.banned=0`).bind(await hash(code), now).first();
    if (!owner) fail('That friend code is not valid. It may have expired or been replaced.', 404);
    if (owner.id === pid) fail('That is your own friend code. Share it with a friend instead.', 409);
    const [lo, hi] = owner.id < pid ? [owner.id, pid] : [pid, owner.id];
    const result = await db.prepare(`INSERT INTO relations(lo,hi,src,status)
      SELECT ?,?,?,'friends'
      WHERE NOT EXISTS (SELECT 1 FROM blocks WHERE (src=? AND dst=?) OR (src=? AND dst=?))
      AND (SELECT count(*) FROM relations WHERE (lo=? OR hi=?) AND NOT (lo=? AND hi=?))<100
      AND (SELECT count(*) FROM relations WHERE (lo=? OR hi=?) AND NOT (lo=? AND hi=?))<100
      ON CONFLICT(lo,hi) DO UPDATE SET status='friends'`)
      .bind(lo, hi, owner.id, pid, owner.id, owner.id, pid, pid, pid, lo, hi, owner.id, owner.id, lo, hi).run();
    if (!result.meta.changes) fail('This friendship is unavailable.', 403);
    // Meet at the gate straight away when both creatures are free; otherwise
    // the friendship waits for the first invitation.
    const met = await makeVisit(db, pid, owner.id, now).catch(() => null);
    return met ? `You and ${owner.name} are friends! Your creatures ${met}.` : `You and ${owner.name} are friends now.`;
  }

  return null;
}
