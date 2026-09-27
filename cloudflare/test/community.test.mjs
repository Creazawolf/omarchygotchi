import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fetchHandler,scheduledHandler,hash} from '../src/worker.mjs';

// Real SQLite executes the same parameterized SQL and triggers as D1.
// Wrangler's local runtime is checked separately before deployment.
class D1 {
  constructor() { this.sqlite=new DatabaseSync(':memory:'); this.sqlite.exec('PRAGMA foreign_keys=ON'); for(const file of ['0001_community.sql','0002_shared_history.sql','0003_invites.sql']) this.sqlite.exec(readFileSync(new URL('../migrations/'+file,import.meta.url),'utf8')); }
  prepare(sql) {
    const db=this.sqlite;
    const make=(args=[])=>({bind(...values){return make(values)},
      async first(){return db.prepare(sql).get(...args) ?? null},
      async all(){return {results:db.prepare(sql).all(...args)}},
      async run(){return {meta:{changes:Number(db.prepare(sql).run(...args).changes)}}},
      execute(){if(/^\s*SELECT/i.test(sql)) return {results:db.prepare(sql).all(...args)}; return {meta:{changes:Number(db.prepare(sql).run(...args).changes)}}}
    });
    return make();
  }
  async batch(statements){ this.sqlite.exec('BEGIN'); try { const results=statements.map(s=>s.execute()); this.sqlite.exec('COMMIT'); return results; } catch(e){this.sqlite.exec('ROLLBACK');throw e} }
}
function harness(t) {
  const DB=new D1();t.after(()=>DB.sqlite.close());
  const permit={limit:async()=>({success:true})};
  const env={DB,IP_LIMIT:permit,USER_LIMIT:permit,JOIN_LIMIT:permit,REGISTRATION_OPEN:'true',MAX_PROFILES:'1000'};
  const profile=(name,extra={})=>({name,seed:123,stage:'adult',discover:true,...extra});
  async function call(kind,data={},token='',expected=200) {
    const r=await fetchHandler(new Request('https://example.test/v1/'+kind,{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+token,'CF-Connecting-IP':'203.0.113.1'},body:JSON.stringify(data)}),env);
    const body=await r.json(); assert.equal(r.status,expected,JSON.stringify(body));return body;
  }
  async function join(name,extra={}) { const user=await call('register',profile(name)); user.profile=profile(name,extra); await call('sync',user.profile,user.token); return user; }
  return {DB,env,call,join,profile};
}
test('two creatures meet and only the receiver can accept a friendship',async t=>{
  const {join,call}=harness(t);const a=await join('Pixel'),b=await join('Bean');
  const visit=(await call('visit',{},a.token)).visits[0];assert.equal(visit.creature.id,b.id);
  assert.equal((await call('sync',b.profile,b.token)).visits[0].id,visit.id);
  await call('request',{target:b.id},a.token);
  await call('accept',{target:b.id},a.token,409);
  await call('accept',{target:a.id},b.token);
  assert.equal((await call('sync',a.profile,a.token)).friends[0].id,b.id);
  await call('remove',{target:b.id},a.token);
  assert.deepEqual((await call('sync',b.profile,b.token)).friends,[]);
});
test('concurrent playdate attempts share an atomic cooldown',async t=>{
  const {join,env,DB}=harness(t);const a=await join('Pixel');await join('Bean');await join('Mochi');
  const requests=Array.from({length:8},()=>fetchHandler(new Request('https://example.test/v1/visit',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+a.token},body:'{}'}),env));
  const responses=await Promise.all(requests);assert.equal(responses.filter(r=>r.status===200).length,1);
  assert.equal(DB.sqlite.prepare('SELECT count(*) AS n FROM visits').get().n,1);
  assert.equal(DB.sqlite.prepare('SELECT count(*) AS n FROM pets WHERE last_visit>0').get().n,2);
});
test('blocking is mutual for access but unblock only removes your own block',async t=>{
  const {join,call}=harness(t);const a=await join('Pixel'),b=await join('Bean');
  await call('visit',{},a.token);await call('request',{target:b.id},a.token);
  await call('block',{target:a.id},b.token);
  await call('request',{target:b.id},a.token,403);
  assert.deepEqual((await call('sync',a.profile,a.token)).visits,[]);
  assert.deepEqual((await call('sync',a.profile,a.token)).outgoing,[]);
  await call('block',{target:b.id},a.token);await call('unblock',{target:b.id},a.token);
  await call('visit',{target:b.id},a.token,403);
});
test('scheduled adventures work with both computers off and stop after lease expiry',async t=>{
  const {join,env,DB}=harness(t);await join('Pixel',{offlineVisits:true,autoRoam:true});await join('Bean',{offlineVisits:true,autoRoam:true});
  const now=Math.floor(Date.now()/1000);
  DB.sqlite.exec(`UPDATE pets SET seen=${now-3600}`);
  assert.equal(await scheduledHandler(env,now),1);
  assert.equal(await scheduledHandler(env,now+900),0);
  assert.equal(await scheduledHandler(env,now+21601),1);
  assert.equal(await scheduledHandler(env,now+8*86400),0);
});
test('offline adventures require opt-in, and disconnect withdraws it',async t=>{
  const {join,call,env,DB}=harness(t);const a=await join('Pixel',{autoRoam:true}),b=await join('Bean',{offlineVisits:true,autoRoam:true});
  const now=Math.floor(Date.now()/1000);DB.sqlite.exec(`UPDATE pets SET seen=${now-3600}`);
  assert.equal(await scheduledHandler(env,now),0);
  await call('sync',{...a.profile,offlineVisits:true},a.token);
  await call('offline',{},b.token);
  assert.equal(await scheduledHandler(env,now),0);
  const p=DB.sqlite.prepare('SELECT * FROM pets WHERE id=?').get(b.id);assert.equal(p.offline_until,0);assert.equal(p.auto_roam,0);
});
test('sleeping and egg creatures cannot opt themselves into encounters',async t=>{
  const {join,call}=harness(t);const a=await join('Pixel',{discover:false,offlineVisits:true}),b=await join('Bean');
  await call('visit',{target:b.id},a.token,409);
  await call('sync',{...a.profile,stage:'egg',discover:true},a.token);
  await call('visit',{target:b.id},a.token,409);
});
test('profile deletion cascades through links and journal and revokes auth',async t=>{
  const {join,call,DB}=harness(t);const a=await join('Pixel'),b=await join('Bean');
  await call('visit',{},a.token);await call('request',{target:b.id},a.token);
  await call('delete',{},a.token);await call('sync',a.profile,a.token,401);
  assert.deepEqual((await call('sync',b.profile,b.token)).visits,[]);
  assert.equal(DB.sqlite.prepare('SELECT count(*) AS n FROM relations').get().n,0);
});
test('API rejects forged credentials, invalid routes and oversized or malformed bodies',async t=>{
  const {call,env,profile}=harness(t);
  await call('sync',{},'invalid',401);await call('register',profile('x'.repeat(21)),'',400);
  await call('register',profile('Pixel',{seed:-1}),'',400);
  await call('register',profile('Pixel',{offlineVisits:'true'}),'',400);
  await call('register',profile('Hidden\u202ename'),'',400);
  await call('other',{},'',404);
  for(const [body,expected] of [['x'.repeat(5000),413],['{',400],['[]',400]]) {
    const r=await fetchHandler(new Request('https://example.test/v1/register',{method:'POST',headers:{'Content-Type':'application/json'},body}),env);assert.equal(r.status,expected);
  }
});
test('public profiles never disclose tokens, IPs or desktop activity',async t=>{
  const {join,call,DB}=harness(t);const a=await join('Pixel',{windowTitle:'private'}),b=await join('Bean');
  const result=await call('visit',{},b.token);
  assert.deepEqual(Object.keys(result.visits[0].creature).sort(),['id','name','online','seed','stage']);
  assert.ok(!JSON.stringify(result).includes(a.token));
  assert.equal(DB.sqlite.prepare('SELECT token_hash FROM pets WHERE id=?').get(a.id).token_hash,await hash(a.token));
});
test('daily registration allowance, capacity and closed registration are enforced',async t=>{
  const {call,env,profile}=harness(t);
  env.MAX_PROFILES='1';await call('register',profile('Pixel'));
  await call('register',profile('Bean'),'',503);
  env.MAX_PROFILES='1000';
  for(let i=0;i<8;i++) await call('register',profile('Bean'+i));
  await call('register',profile('One more'),'',429);
  env.REGISTRATION_OPEN='false';await call('register',profile('No'),'',403);
});
test('rate limiter failures deny requests before database access',async t=>{
  const {env}=harness(t);env.IP_LIMIT={limit:async()=>({success:false})};env.DB=null;
  const r=await fetchHandler(new Request('https://example.test/v1/register',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'}),env);assert.equal(r.status,429);
});
test('friend requests require an encounter, can be declined or cancelled, and cannot duplicate',async t=>{
  const {join,call}=harness(t);const a=await join('Pixel'),b=await join('Bean');
  await call('request',{target:b.id},a.token,409);await call('visit',{},a.token);
  await call('request',{target:b.id},a.token);await call('request',{target:a.id},b.token,409);
  await call('decline',{target:a.id},b.token);
  assert.deepEqual((await call('sync',a.profile,a.token)).outgoing,[]);
  await call('request',{target:b.id},a.token);await call('remove',{target:b.id},a.token);
  assert.deepEqual((await call('sync',b.profile,b.token)).incoming,[]);
});
test('banned profiles cannot authenticate or join scheduled encounters',async t=>{
  const {join,call,env,DB}=harness(t);const a=await join('Pixel',{autoRoam:true}),b=await join('Bean',{autoRoam:true});
  DB.sqlite.prepare('UPDATE pets SET banned=1 WHERE id=?').run(a.id);
  await call('sync',a.profile,a.token,401);await call('visit',{target:a.id},b.token,404);
  assert.equal(await scheduledHandler(env),0);
});

async function closeFriends(h) {
  const a=await h.join('Pixel',{seed:4}),b=await h.join('Bean',{seed:2});
  for(let i=0;i<6;i++) {
    h.DB.sqlite.exec('UPDATE pets SET last_visit=0');
    await h.call('visit',{target:b.id},a.token);
    if(i===0) {await h.call('request',{target:b.id},a.token);await h.call('accept',{target:a.id},b.token);}
  }
  return [a,b];
}
test('real participants, visible expiry and personality memory survive journal pruning',async t=>{
  const h=harness(t);const [a,b]=await closeFriends(h);
  const result=await h.call('sync',a.profile,a.token);
  const v=result.visits.find(v=>v.scene.encounter===4);
  assert.equal(v.scene.scene,'radio');assert.match(v.activity,/finally brought a radio/);
  assert.equal(v.until,v.at+900);
  assert.deepEqual(v.scene.participants.map(p=>p.id).sort(),[a.id,b.id].sort());
  assert.equal(result.bonds[0].level,'best friends');
  h.DB.sqlite.exec('DELETE FROM visits');
  assert.equal((await h.call('sync',b.profile,b.token)).bonds[0].encounters,6);
});
test('romance requires mature friends, repeated visits, two private choices and can be withdrawn',async t=>{
  const h=harness(t);const a=await h.join('A'),b=await h.join('B');
  await h.call('romance',{target:b.id,allow:true},a.token,409);
  const [c,d]=await closeFriends(h);
  await h.call('romance',{target:d.id,allow:'yes'},c.token,400);
  await h.call('romance',{target:d.id,allow:true},c.token);
  let theirs=await h.call('sync',d.profile,d.token);
  assert.equal(theirs.bonds[0].romanceAllowed,false);assert.equal(theirs.bonds[0].togetherAt,0);
  await h.call('romance',{target:c.id,allow:true},d.token);
  assert.ok((await h.call('sync',c.profile,c.token)).bonds[0].togetherAt>0);
  await h.call('romance',{target:d.id,allow:false},c.token);
  assert.equal((await h.call('sync',d.profile,d.token)).bonds[0].togetherAt,0);
  await h.call('sync',{...c.profile,stage:'kid'},c.token);
  await h.call('romance',{target:d.id,allow:true},c.token,409);
});
test('one shared child, explicit home consent, inheritance and growth in both albums',async t=>{
  const h=harness(t);const [a,b]=await closeFriends(h);
  await h.call('egg-propose',{target:b.id,home:a.id,name:'Pip'},a.token,409);
  await h.call('romance',{target:b.id,allow:true},a.token);await h.call('romance',{target:a.id,allow:true},b.token);
  await h.call('egg-propose',{target:b.id,home:'c'.repeat(32),name:'Pip'},a.token,400);
  const egg=(await h.call('egg-propose',{target:b.id,home:a.id,name:'Pip'},a.token)).families[0];
  assert.equal(egg.stage,'egg');assert.equal(egg.acceptedAt,0);assert.equal(egg.home,a.id);
  assert.equal(egg.seed,egg.parents[0].seed);assert.equal(egg.colorSeed,egg.parents[1].seed);
  await h.call('egg-accept',{family:egg.id,home:a.id},a.token,409);
  const outsider=await h.join('Outsider');await h.call('egg-accept',{family:egg.id,home:a.id},outsider.token,409);
  await h.call('egg-accept',{family:egg.id,home:b.id},b.token,409);
  await h.call('egg-accept',{family:egg.id,home:a.id},b.token);
  await h.call('egg-accept',{family:egg.id,home:a.id},b.token,409);
  await h.call('egg-propose',{target:b.id,home:a.id,name:'More'},a.token,409);
  const now=Math.floor(Date.now()/1000);
  for(const [days,stage] of [[2,'baby'],[4,'kid'],[8,'teen'],[15,'adult']]) {
    h.DB.sqlite.prepare('UPDATE families SET accepted_at=? WHERE id=?').run(now-days*86400,egg.id);
    const one=(await h.call('sync',a.profile,a.token)).families[0];
    const two=(await h.call('sync',b.profile,b.token)).families[0];
    assert.deepEqual(one,two);assert.equal(one.stage,stage);
    if(days===2) {
      const snapshot=await h.call('sync',a.profile,a.token);
      execFileSync('python3',['-c',"import sys,json; sys.path.insert(0,'../community'); from client import validate_snapshot; validate_snapshot(json.load(sys.stdin),'sync')"],{input:JSON.stringify(snapshot)});
      if(process.env.TAMA_QML_FIXTURE) writeFileSync(process.env.TAMA_QML_FIXTURE,JSON.stringify(snapshot));
    }
  }
  await h.call('delete',{},a.token);
  const survivor=(await h.call('sync',b.profile,b.token)).families[0];
  assert.equal(survivor.id,egg.id);assert.equal(survivor.parents.length,2);
});
test('concurrent proposals cannot create multiple children and blocking cancels pending consent',async t=>{
  const h=harness(t);const [a,b]=await closeFriends(h);
  await h.call('romance',{target:b.id,allow:true},a.token);await h.call('romance',{target:a.id,allow:true},b.token);
  const responses=await Promise.all(Array.from({length:4},()=>fetchHandler(new Request('https://example.test/v1/egg-propose',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+a.token},body:JSON.stringify({target:b.id,home:a.id,name:'Pip'})}),h.env)));
  assert.equal(responses.filter(r=>r.status===200).length,1);
  assert.ok(responses.every(r=>[200,409].includes(r.status)));
  await h.call('block',{target:b.id},a.token);
  assert.equal(h.DB.sqlite.prepare('SELECT count(*) n FROM families').get().n,0);
  assert.equal((await h.call('sync',b.profile,b.token)).bonds.length,0);
});
test('couples get reunions and anniversary stories based on real relationship dates',async t=>{
  const h=harness(t);const [a,b]=await closeFriends(h);
  await h.call('romance',{target:b.id,allow:true},a.token);await h.call('romance',{target:a.id,allow:true},b.token);
  const now=Math.floor(Date.now()/1000);
  h.DB.sqlite.exec(`UPDATE bonds SET together_at=${now-5*86400},last_at=${now-4*86400}; UPDATE pets SET last_visit=0`);
  let result=await h.call('visit',{target:b.id},a.token);
  assert.ok(result.visits.some(v=>v.activity.includes('reunited after days apart')));
  h.DB.sqlite.exec(`UPDATE bonds SET last_at=${now-86400}; UPDATE pets SET last_visit=0`);
  result=await h.call('visit',{target:b.id},a.token);
  assert.ok(result.visits.some(v=>v.activity.includes('celebrated another day together')));
});
test('hat stories do not skip a borrowing and a new couple has no premature anniversary',async()=>{
  const {story}=await import('../src/stories.mjs');
  const a={id:'a',seed:2},b={id:'b',seed:3};
  for(const n of [1,5,9]) {
    assert.match(story(a,b,{encounters:n-1},100).activity,/borrowed a hat/);
    assert.match(story(a,b,{encounters:n+2},100).activity,/returned the borrowed hat/);
  }
  const date=story(a,b,{encounters:6,together_at:100,last_at:99},200);
  assert.match(date.activity,/awkward date/);
});
test('a shared friend code makes two creatures friends at once and can be replaced',async t=>{
  const {join,call}=harness(t);const a=await join('Pixel'),b=await join('Bean'),c=await join('Mochi');
  const created=await call('invite-create',{},a.token);
  assert.match(created.invite.code,/^[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}$/);
  assert.ok(created.invite.expires>Math.floor(Date.now()/1000)+6*86400);
  // Only the owner's creation response carries the readable code.
  assert.equal((await call('sync',a.profile,a.token)).invite.code,undefined);
  assert.ok((await call('sync',a.profile,a.token)).invite.expires>0);
  await call('invite-accept',{code:created.invite.code},a.token,409);
  const met=await call('invite-accept',{code:created.invite.code.toLowerCase().replace('-',' ')},b.token);
  assert.match(met.message,/You and Pixel are friends/);
  assert.equal(met.friends[0].id,a.id);
  assert.equal((await call('sync',a.profile,a.token)).friends[0].id,b.id);
  // Both creatures were free, so they met at the gate and share a first story.
  assert.equal(met.visits.length,1);assert.equal(met.bonds[0].creature.id,a.id);
  // A new code replaces the old one immediately.
  const next=await call('invite-create',{},a.token);assert.notEqual(next.invite.code,created.invite.code);
  await call('invite-accept',{code:created.invite.code},c.token,404);
  await call('invite-accept',{code:next.invite.code},c.token);
  await call('invite-revoke',{},a.token);
  assert.equal((await call('sync',a.profile,a.token)).invite,null);
});
test('friend codes respect blocks, expiry, format and attempt limits',async t=>{
  const {join,call,DB}=harness(t);const a=await join('Pixel'),b=await join('Bean'),c=await join('Mochi');
  const code=(await call('invite-create',{},a.token)).invite.code;
  await call('block',{target:b.id},a.token);
  await call('invite-accept',{code},b.token,403);
  assert.deepEqual((await call('sync',b.profile,b.token)).friends,[]);
  await call('invite-accept',{code:'O0I1-L000'},c.token,400);
  DB.sqlite.exec('UPDATE invites SET expires=1');
  await call('invite-accept',{code},c.token,404);
  // Guessing is bounded per creature per day, hit or miss.
  for(let i=0;i<19;i++) await call('invite-accept',{code:'2222-2222'},c.token,404);
  await call('invite-accept',{code:'2222-2222'},c.token,429);
});
test('park presence counts other creatures this week and in the park now',async t=>{
  const {join,call,DB}=harness(t);const a=await join('Pixel'),b=await join('Bean');await join('Mochi',{discover:false});
  const now=Math.floor(Date.now()/1000);
  let park=(await call('sync',a.profile,a.token)).park;
  assert.deepEqual(park,{week:2,now:1});
  DB.sqlite.exec(`UPDATE pets SET seen=${now-8*86400} WHERE id='${b.id}'`);
  park=(await call('sync',a.profile,a.token)).park;
  assert.deepEqual(park,{week:1,now:0});
});
