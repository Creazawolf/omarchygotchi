import {story, historySnapshot, familyAction} from './stories.mjs';
const STAGES = new Set(['egg','baby','kid','teen','adult','elder','ghost']);
const DAY = 86400;
const PRESENCE = 900;
const COOLDOWN = 300;
const AUTO_COOLDOWN = 6 * 3600;
const nowSeconds = () => Math.floor(Date.now()/1000);
const pair = (a,b) => a < b ? [a,b] : [b,a];
const randomHex = (size=16) => [...crypto.getRandomValues(new Uint8Array(size))].map(x=>x.toString(16).padStart(2,'0')).join('');
export const hash = async text => [...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text)))].map(x=>x.toString(16).padStart(2,'0')).join('');
class Problem extends Error { constructor(message,status=400) { super(message); this.status=status; } }
function reply(data,status=200) {
  return Response.json(data,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'}});
}
function profile(data) {
  if (typeof data.name !== 'string' || !data.name.trim() || [...data.name].length > 20 || /[\p{Cc}\p{Cf}]/u.test(data.name)) throw new Problem('Choose a creature name of 1–20 visible characters.');
  if (!Number.isInteger(data.seed) || data.seed < 0 || data.seed > 4294967295 || !STAGES.has(data.stage)) throw new Problem('Invalid creature appearance or stage.');
  for (const field of ['discover','offlineVisits','autoRoam']) if (data[field] !== undefined && typeof data[field] !== 'boolean') throw new Problem('Invalid community preferences.');
  return {name:data.name.trim(),seed:data.seed,stage:data.stage};
}
function publicPet(row,now) { return {id:row.id,name:row.name,seed:row.seed,stage:row.stage,online:row.seen > now-PRESENCE}; }
function eligible(alias) {
  return `${alias}.discover=1 AND ${alias}.banned=0 AND ${alias}.stage NOT IN ('egg','ghost') AND (${alias}.seen>? OR ${alias}.offline_until>?) AND ${alias}.last_visit<=?`;
}
const NOT_BLOCKED = `NOT EXISTS (SELECT 1 FROM blocks WHERE (src=p.id AND dst=q.id) OR (src=q.id AND dst=p.id))`;
async function limited(binding,key) {
  if (!binding || !(await binding.limit({key})).success) throw new Problem('Please wait before trying again.',429);
}
async function quota(db,key,limit,now,seconds=DAY) {
  const window = Math.floor(now/seconds)*seconds;
  const result = await db.prepare(`INSERT INTO quotas(key,window,count) VALUES(?,?,1)
    ON CONFLICT(key) DO UPDATE SET window=excluded.window,
      count=CASE WHEN quotas.window=excluded.window THEN quotas.count+1 ELSE 1 END
    WHERE quotas.window!=excluded.window OR quotas.count<? RETURNING count`).bind(key,window,limit).first();
  if (!result) throw new Problem('Daily community limit reached. Please try again tomorrow.',429);
}
async function readBody(request) {
  if (!request.headers.get('Content-Type')?.toLowerCase().startsWith('application/json')) throw new Problem('Send a JSON request.',415);
  if (!request.body) throw new Problem('Missing request body.');
  const reader = request.body.getReader();
  let size=0; const chunks=[];
  try {
    while (true) {
      const {done,value} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 4096) { await reader.cancel(); throw new Problem('Request is too large.',413); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(size); let offset=0;
  for (const chunk of chunks) { bytes.set(chunk,offset); offset+=chunk.byteLength; }
  let data;
  try { data=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes)); }
  catch { throw new Problem('Invalid JSON.'); }
  if (!data || typeof data!=='object' || Array.isArray(data)) throw new Problem('Expected a JSON object.');
  return data;
}
async function snapshot(db,pid,now) {
  const [relationships,blocked,visits] = await db.batch([
    db.prepare(`SELECT p.id,p.name,p.seed,p.stage,p.seen,r.src,r.status FROM relations r
      JOIN pets p ON p.id=CASE WHEN r.lo=? THEN r.hi ELSE r.lo END
      WHERE (r.lo=? OR r.hi=?) AND p.banned=0 AND NOT EXISTS
      (SELECT 1 FROM blocks WHERE (src=? AND dst=p.id) OR (src=p.id AND dst=?)) LIMIT 100`).bind(pid,pid,pid,pid,pid),
    db.prepare(`SELECT p.id,p.name,p.seed,p.stage,p.seen FROM blocks b JOIN pets p ON p.id=b.dst WHERE b.src=? LIMIT 200`).bind(pid),
    db.prepare(`SELECT v.id AS visit_id,v.activity,v.at,v.scene,p.id,p.name,p.seed,p.stage,p.seen FROM visits v
      JOIN pets p ON p.id=CASE WHEN v.a=? THEN v.b ELSE v.a END
      WHERE (v.a=? OR v.b=?) AND v.at>? AND p.banned=0
      AND NOT EXISTS (SELECT 1 FROM blocks WHERE (src=? AND dst=p.id) OR (src=p.id AND dst=?))
      ORDER BY v.at DESC,v.id DESC LIMIT 30`).bind(pid,pid,pid,now-30*DAY,pid,pid)
  ]);
  const result = {id:pid,friends:[],incoming:[],outgoing:[],blocked:blocked.results.map(p=>publicPet(p,now)),visits:visits.results.map(v=>({id:v.visit_id,activity:v.activity,at:v.at,creature:publicPet(v,now),scene:v.scene?JSON.parse(v.scene):null,until:v.at+900})),capabilities:{offlineVisits:true,serverRoaming:true,sharedHistory:true,families:true}};
  for (const r of relationships.results) result[r.status==='friends'?'friends':r.src===pid?'outgoing':'incoming'].push(publicPet(r,now));
  return {...result,...await historySnapshot(db,pid,now,publicPet)};
}
async function makeVisit(db,pid,target,now,automatic=false) {
  const cutoff = now-(automatic?AUTO_COOLDOWN:COOLDOWN);
  const extra = automatic ? ' AND p.auto_roam=1 AND q.auto_roam=1' : '';
  // A single conditional INSERT rechecks availability, both cooldowns and blocking.
  // The trigger updates both cooldowns in this same transaction.
  const id=randomHex();
  const [lo,hi]=pair(pid,target);
  const participants=await db.prepare('SELECT * FROM pets WHERE id IN (?,?) ORDER BY id').bind(lo,hi).all();
  if(participants.results.length!==2) return null;
  const bond=await db.prepare('SELECT * FROM bonds WHERE lo=? AND hi=?').bind(lo,hi).first();
  const scene=story(...participants.results.map(p=>publicPet(p,now)),bond,now);
  const activity=scene.activity;
  const result=await db.prepare(`INSERT INTO visits(id,a,b,activity,at,scene)
    SELECT ?,min(p.id,q.id),max(p.id,q.id),?,?,? FROM pets p JOIN pets q ON q.id=?
    WHERE p.id=? AND p.id!=q.id AND ${eligible('p')} AND ${eligible('q')} AND ${NOT_BLOCKED}${extra}`)
    .bind(id,activity,now,JSON.stringify(scene),target,pid,now-PRESENCE,now,cutoff,now-PRESENCE,now,cutoff).run();
  if (!result.meta.changes) return null;
  return activity;
}
async function targetExists(db,pid,target) {
  if (typeof target!=='string' || !/^[a-f0-9]{32}$/.test(target) || target===pid) throw new Problem('Creature not found.',404);
  const found=await db.prepare('SELECT id FROM pets WHERE id=? AND banned=0').bind(target).first();
  if (!found) throw new Problem('Creature not found.',404);
}
async function action(db,me,kind,data,now) {
  const pid=me.id;
  if (kind==='sync') {
    const p=profile(data);
    const discover=data.discover===true && !['egg','ghost'].includes(p.stage);
    await db.prepare(`UPDATE pets SET name=?,seed=?,stage=?,seen=?,discover=?,offline_until=?,auto_roam=? WHERE id=? AND banned=0`)
      .bind(p.name,p.seed,p.stage,now,+discover,discover && data.offlineVisits===true?now+7*DAY:0,+(data.autoRoam===true),pid).run();
    return '';
  }
  if (kind==='offline') {
    await db.prepare('UPDATE pets SET discover=0,seen=0,offline_until=0,auto_roam=0 WHERE id=?').bind(pid).run();
    return 'Disconnected. Your creature stays at home.';
  }
  if (kind==='delete') { await db.prepare('DELETE FROM pets WHERE id=?').bind(pid).run(); return 'Community profile deleted.'; }
  if(['egg-accept','egg-cancel'].includes(kind)) return familyAction(db,pid,kind,data,now,(m,s)=>{throw new Problem(m,s)},randomHex);
  let target=data.target || '';
  if (kind==='visit' && !target) {
    // Bound the candidate set; the final insert remains authoritative under races.
    const rows=await db.prepare(`SELECT q.id FROM pets p JOIN pets q ON q.id!=p.id
      WHERE p.id=? AND ${eligible('p')} AND ${eligible('q')} AND ${NOT_BLOCKED}
      ORDER BY q.last_visit LIMIT 40`).bind(pid,now-PRESENCE,now,now-COOLDOWN,now-PRESENCE,now,now-COOLDOWN).all();
    if (!rows.results.length) throw new Problem('The park is quiet, or your creature is resting between playdates. Try again later.',409);
    target=rows.results[crypto.getRandomValues(new Uint32Array(1))[0]%rows.results.length].id;
  }
  await targetExists(db,pid,target);
  const [lo,hi]=pair(pid,target);
  if (kind==='block') {
    await db.batch([
      db.prepare('INSERT OR IGNORE INTO blocks(src,dst) SELECT ?,? WHERE (SELECT count(*) FROM blocks WHERE src=?)<200').bind(pid,target,pid),
      db.prepare('DELETE FROM relations WHERE lo=? AND hi=? AND EXISTS (SELECT 1 FROM blocks WHERE src=? AND dst=?)').bind(lo,hi,pid,target)
    ]);
    if (!await db.prepare('SELECT 1 FROM blocks WHERE src=? AND dst=?').bind(pid,target).first()) throw new Problem('Block list is full. Remove an old block first.',409);
    return 'Creature blocked.';
  }
  if (kind==='unblock') { await db.prepare('DELETE FROM blocks WHERE src=? AND dst=?').bind(pid,target).run(); return 'Creature unblocked.'; }
  const blocked=await db.prepare('SELECT 1 FROM blocks WHERE (src=? AND dst=?) OR (src=? AND dst=?)').bind(pid,target,target,pid).first();
  if (blocked) throw new Problem('This connection is unavailable.',403);
  if (kind==='romance') {
    if(typeof data.allow!=='boolean') throw new Problem('Choose whether to allow romance.');
    const r=await db.prepare(`UPDATE bonds SET ${pid===lo?'romance_lo':'romance_hi'}=?
      WHERE lo=? AND hi=? AND encounters>=3 AND EXISTS(SELECT 1 FROM relations WHERE lo=? AND hi=? AND status='friends')
      AND (SELECT count(*) FROM pets WHERE id IN (?,?) AND stage IN ('adult','elder') AND banned=0)=2`)
      .bind(+data.allow,lo,hi,lo,hi,lo,hi).run();
    if(!r.meta.changes) throw new Problem('Romance needs adult friends with at least three shared visits.',409);
    await db.batch([
      db.prepare(`UPDATE bonds SET together_at=CASE WHEN romance_lo=1 AND romance_hi=1 THEN CASE WHEN together_at=0 THEN ? ELSE together_at END ELSE 0 END WHERE lo=? AND hi=?`).bind(now,lo,hi),
      db.prepare('DELETE FROM families WHERE a=? AND b=? AND accepted_at=0 AND EXISTS(SELECT 1 FROM bonds WHERE lo=? AND hi=? AND (romance_lo=0 OR romance_hi=0))').bind(lo,hi,lo,hi)
    ]);
    return data.allow?'Romance allowed if both owners choose it.':'Your creatures can keep their friendship.';
  }
  if (kind==='egg-propose') {
    if(data.home!==pid && data.home!==target) throw new Problem('Choose one parent’s primary home.');
    const name=profile({name:data.name,seed:0,stage:'egg'}).name;
    const parents=await db.prepare('SELECT * FROM pets WHERE id IN (?,?) ORDER BY id').bind(lo,hi).all();
    const id=randomHex(), seed=parents.results[0].seed, colorSeed=parents.results[1].seed;
    const r=await db.prepare(`INSERT INTO families(id,a,b,proposer,home,name,seed,color_seed,parents,trait,proposed_at)
      SELECT ?,?,?,?,?,?,?,?,?,?,? WHERE EXISTS(SELECT 1 FROM bonds WHERE lo=? AND hi=? AND encounters>=6 AND together_at>0)
      AND (SELECT count(*) FROM pets WHERE id IN (?,?) AND stage IN ('adult','elder') AND banned=0)=2
      AND NOT EXISTS(SELECT 1 FROM families WHERE (a IN (?,?) OR b IN (?,?)) AND (accepted_at=0 OR accepted_at>?))
      AND (SELECT count(*) FROM families WHERE a=? OR b=?)<12 AND (SELECT count(*) FROM families WHERE a=? OR b=?)<12`)
      .bind(id,lo,hi,pid,data.home,name,seed,colorSeed,JSON.stringify(parents.results.map(p=>publicPet(p,now))),
        parseInt(id.slice(0,2),16)%5===0?'decoration nibbler':['shy','generous','mischievous','outgoing'][seed%4],now,
        lo,hi,lo,hi,lo,hi,lo,hi,now-14*DAY,lo,lo,hi,hi).run();
    if(!r.meta.changes) throw new Problem('An egg needs six visits, mutual romance, and room in both households and albums.',409);
    return 'Egg proposed. The other owner must agree to its primary home before hatching.';
  }
  if (kind==='visit') {
    const activity=await makeVisit(db,pid,target,now);
    if (!activity) throw new Problem('This playdate is unavailable. Creatures need five minutes between visits.',409);
    return `Your creatures ${activity}!`;
  }
  if (kind==='request') {
    await quota(db,'request:'+pid,20,now);
    const result=await db.prepare(`INSERT OR IGNORE INTO relations(lo,hi,src,status)
      SELECT ?,?,?,'pending' WHERE EXISTS (SELECT 1 FROM visits WHERE a=? AND b=? AND at>?)
      AND NOT EXISTS (SELECT 1 FROM blocks WHERE (src=? AND dst=?) OR (src=? AND dst=?))
      AND (SELECT count(*) FROM relations WHERE lo=? OR hi=?)<100
      AND (SELECT count(*) FROM relations WHERE lo=? OR hi=?)<100`)
      .bind(lo,hi,pid,lo,hi,now-30*DAY,pid,target,target,pid,pid,pid,target,target).run();
    if (!result.meta.changes) throw new Problem('Meet in the park first. A request may already exist, or a friend list is full.',409);
    return 'Friend request sent.';
  }
  if (kind==='accept') {
    const result=await db.prepare(`UPDATE relations SET status='friends' WHERE lo=? AND hi=? AND src=? AND status='pending'
      AND NOT EXISTS (SELECT 1 FROM blocks WHERE (src=? AND dst=?) OR (src=? AND dst=?))`)
      .bind(lo,hi,target,pid,target,target,pid).run();
    if (!result.meta.changes) throw new Problem('This request is no longer pending.',409);
    return 'You are now friends!';
  }
  if (kind==='decline') { await db.prepare("DELETE FROM relations WHERE lo=? AND hi=? AND src=? AND status='pending'").bind(lo,hi,target).run(); return 'Request declined.'; }
  if (kind==='remove') { await db.prepare('DELETE FROM relations WHERE lo=? AND hi=?').bind(lo,hi).run(); return 'Connection removed.'; }
  throw new Problem('Unknown community action.',404);
}
export async function fetchHandler(request,env) {
  try {
    const path=new URL(request.url).pathname;
    if (request.method==='GET' && path==='/health') return reply({ok:true,service:'Omarchy Creature Community',version:'3.0.0'});
    if (request.method!=='POST') throw new Problem('Use a JSON POST request.',405);
    const match=/^\/v1\/(register|sync|offline|delete|visit|request|accept|decline|remove|block|unblock|romance|egg-propose|egg-accept|egg-cancel)$/.exec(path);
    if (!match) throw new Problem('Unknown community action.',404);
    const kind=match[1],now=nowSeconds();
    const ip=request.headers.get('CF-Connecting-IP') || 'local';
    await limited(env.IP_LIMIT,ip);
    const data=await readBody(request);
    if (kind==='register') {
      if (env.REGISTRATION_OPEN!=='true') throw new Problem('New registrations are currently closed.',403);
      await limited(env.JOIN_LIMIT,ip);
      const p=profile(data);
      await quota(env.DB,'join:'+await hash(ip),10,now);
      const id=randomHex(),token=randomHex(32);
      const maximum=Math.min(10000,Math.max(1,Number(env.MAX_PROFILES)||1000));
      const inserted=await env.DB.prepare(`INSERT INTO pets(id,token_hash,name,seed,stage,seen,created)
        SELECT ?,?,?,?,?,?,? WHERE (SELECT count(*) FROM pets)<?`)
        .bind(id,await hash(token),p.name,p.seed,p.stage,now,now,maximum).run();
      if (!inserted.meta.changes) throw new Problem('The community has reached its current capacity.',503);
      return reply({id,token});
    }
    const token=request.headers.get('Authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
    if (!token) throw new Problem('Community identity is invalid.',401);
    const digest=await hash(token);
    await limited(env.USER_LIMIT,digest);
    const me=await env.DB.prepare('SELECT id FROM pets WHERE token_hash=? AND banned=0').bind(digest).first();
    if (!me) throw new Problem('Community identity is invalid or disabled.',401);
    const message=await action(env.DB,me,kind,data,now);
    if (kind==='delete') return reply({message});
    return reply({...await snapshot(env.DB,me.id,now),message});
  } catch(error) {
    if (error instanceof Problem) return reply({error:error.message},error.status);
    // Database errors and credentials never reach the client or application logs.
    return reply({error:'Community temporarily unavailable. Please try again later.'},503);
  }
}
export async function scheduledHandler(env,now=nowSeconds()) {
  const rows=await env.DB.prepare(`SELECT p.id FROM pets p WHERE p.auto_roam=1 AND ${eligible('p')}
    ORDER BY p.last_visit LIMIT 40`).bind(now-PRESENCE,now,now-AUTO_COOLDOWN).all();
  const candidates=rows.results.map(p=>p.id);
  let visits=0;
  while(candidates.length>1) {
    const first=candidates.shift();
    // Try at most five partners when blocks exclude a match.
    for(let i=0;i<Math.min(5,candidates.length);i++) {
      const index=crypto.getRandomValues(new Uint32Array(1))[0]%candidates.length;
      if(await makeVisit(env.DB,first,candidates[index],now,true)) { candidates.splice(index,1); visits++; break; }
    }
  }
  await env.DB.batch([
    env.DB.prepare('DELETE FROM visits WHERE at<?').bind(now-30*DAY),
    env.DB.prepare('DELETE FROM quotas WHERE window<?').bind(now-2*DAY),
    env.DB.prepare('DELETE FROM families WHERE accepted_at=0 AND proposed_at<?').bind(now-7*DAY)
  ]);
  return visits;
}
export default {fetch:fetchHandler,scheduled(_event,env,ctx) { ctx.waitUntil(scheduledHandler(env)); }};
