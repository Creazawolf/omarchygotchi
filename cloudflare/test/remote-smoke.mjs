import assert from 'node:assert/strict';
const base=process.argv[2];
if(!base || new URL(base).protocol!=='https:' || !new URL(base).hostname.endsWith('.workers.dev')) throw new Error('Provide the deployed HTTPS workers.dev origin.');
const users=[];
async function call(action,body={},token='') {
 const r=await fetch(base+'/v1/'+action,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},body:JSON.stringify(body)});
 const data=await r.json();assert.equal(r.status,200,JSON.stringify(data));return data;
}
try {
 const health=await fetch(base+'/health');assert.equal(health.status,200);assert.equal((await health.json()).version,'3.1.0');
 assert.equal((await fetch(base+'/__scheduled')).status,405,'Internal schedule trigger must not be publicly callable.');
 for(const name of ['Setup test Pixel','Setup test Bean']) {
  const profile={name,seed:987654,stage:'adult',discover:true,offlineVisits:false,autoRoam:false};
  const identity=await call('register',profile);users.push({...identity,profile});await call('sync',profile,identity.token);
 }
 const [a,b]=users;
 const visit=await call('visit',{target:b.id},a.token);assert.equal(visit.visits[0].creature.id,b.id);
 assert.equal(visit.capabilities.sharedHistory,true);
 assert.equal(visit.capabilities.families,true);
 assert.deepEqual(visit.visits[0].scene.participants.map(p=>p.id).sort(),[a.id,b.id].sort());
 assert.equal(visit.bonds[0].encounters,1);
 assert.deepEqual(visit.families,[]);
 await call('request',{target:b.id},a.token);await call('accept',{target:a.id},b.token);
 assert.equal((await call('sync',a.profile,a.token)).friends[0].id,b.id);
 await call('block',{target:b.id},a.token);assert.equal((await call('sync',b.profile,b.token)).friends.length,0);
 console.log('Hosted 3.0 HTTPS service passed: health, capabilities, real shared scene, persistent bond, friend request/acceptance, blocking and private schedule endpoint.');
} finally {
 for(const user of users) await call('delete',{},user.token);
 if(users.length) console.log(users.length+' temporary test profiles removed.');
}
