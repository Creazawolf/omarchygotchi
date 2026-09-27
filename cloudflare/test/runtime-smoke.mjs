import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
const base=process.argv[2] || 'http://127.0.0.1:8787';
if (new URL(base).hostname!=='127.0.0.1') throw new Error('This test only runs against the disposable localhost database.');
const users=[];
function sql(command) {
 const args=['d1','execute','omarchy-creature-community','--local','--command',command];
 if(process.env.TAMA_D1_STATE) args.push('--persist-to',process.env.TAMA_D1_STATE);
 execFileSync('./node_modules/.bin/wrangler',args,{stdio:'pipe'});
}
async function call(action,payload={},token='') {
 const response=await fetch(base+'/v1/'+action,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},body:JSON.stringify(payload)});
 const body=await response.json();assert.equal(response.status,200,JSON.stringify(body));return body;
}
try {
 for(const name of ['TestPixel','TestBean']) {
  const profile={name,seed:123,stage:'adult',discover:true,offlineVisits:true,autoRoam:true};
  const user=await call('register',profile);users.push({...user,profile});await call('sync',profile,user.token);
 }
 const [a,b]=users;
 await call('visit',{},a.token);
 await call('request',{target:b.id},a.token);
 await call('accept',{target:a.id},b.token);
 assert.equal((await call('sync',a.profile,a.token)).friends[0].id,b.id);
 for(const u of users) assert.match(u.id,/^[a-f0-9]{32}$/);
 const now=Math.floor(Date.now()/1000);
 sql(`UPDATE pets SET seen=${now-3600},last_visit=0 WHERE id IN ('${a.id}','${b.id}')`);
 const scheduled=await fetch(base+'/__scheduled?cron=*/15+*+*+*+*');assert.equal(scheduled.status,200,await scheduled.text());
 const journal=await call('sync',a.profile,a.token);
 assert.equal(journal.visits.length,2,'Cron should record a second adventure while both profiles were offline.');
 for(let i=0;i<4;i++) {
  sql(`UPDATE pets SET last_visit=0 WHERE id IN ('${a.id}','${b.id}')`);
  await call('visit',{target:b.id},a.token);
 }
 await call('romance',{target:b.id,allow:true},a.token);
 await call('romance',{target:a.id,allow:true},b.token);
 const proposal=await call('egg-propose',{target:b.id,home:a.id,name:'TestPip'},a.token);
 const child=proposal.families[0];
 assert.equal(child.acceptedAt,0);
 const family=await call('egg-accept',{family:child.id,home:a.id},b.token);
 assert.ok(family.families[0].acceptedAt>0);
 const other=await call('sync',a.profile,a.token);
 assert.deepEqual(other.families,family.families);
 assert.equal(other.bonds[0].encounters,6);
 execFileSync('python3',['-c',"import sys,json; sys.path.insert(0,'../community'); from client import validate_snapshot; validate_snapshot(json.load(sys.stdin),'sync')"],{input:JSON.stringify(other)});
 // A friend code redeemed by a third creature: friends at once, counted in the park.
 const profile={name:'TestMochi',seed:456,stage:'adult',discover:true};
 const c=await call('register',profile);users.push({...c,profile});await call('sync',profile,c.token);
 const code=(await call('invite-create',{},a.token)).invite.code;
 const redeemed=await call('invite-accept',{code},c.token);
 assert.equal(redeemed.friends[0].id,a.id);
 assert.ok(redeemed.park.week>=2);
 execFileSync('python3',['-c',"import sys,json; sys.path.insert(0,'../community'); from client import validate_snapshot; validate_snapshot(json.load(sys.stdin),'invite-accept')"],{input:JSON.stringify(redeemed)});
 await call('block',{target:b.id},a.token);
 assert.equal((await call('sync',b.profile,b.token)).friends.length,0);
 console.log('Real Cloudflare runtime: registration, visible visits, friendship, offline cron, mutual romance, shared egg consent, friend codes, park presence, Python validation, blocking, and deletion passed.');
} finally {
 for(const u of users) await call('delete',{},u.token);
}
