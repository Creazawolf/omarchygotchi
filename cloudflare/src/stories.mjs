const DAY=86400;
export const personality = seed => ['shy','generous','mischievous','outgoing'][seed % 4];
export function story(a,b,bond,now) {
  const count=(bond?.encounters || 0)+1;
  const traits=[personality(a.seed),personality(b.seed)];
  let scene='picnic', activity='shared a cookie and kept the crumbs', keepsake='a picnic photograph';
  if (traits.includes('shy')) {
    if(count===1) {scene='gift';activity='left a small rock beside a handwritten hello';keepsake='the first hello rock';}
    else if(count<4) {scene='radio';activity='invited each other to dance; one quietly declined';keepsake='an invitation saved for later';}
    else {scene='radio';activity=count===4?'finally brought a radio and danced together':'tuned their radio to the station only they understand';keepsake='the radio that changed everything';}
  } else if(traits.includes('mischievous')) {
    scene='hat';
    activity=count%4===1?'borrowed a hat with a very innocent expression':count%4===0?'returned the borrowed hat, three visits later':'took the borrowed hat on another adventure';
    keepsake=count%4===0?'a photograph of the hat’s homecoming':'a suspiciously familiar hat';
  } else if(traits.includes('generous')) {scene='gift';activity='shared their favorite possession: an excellent rock';keepsake='an excellent friendship rock';}
  else {scene='shelter';activity='built a questionable shelter and called it architecture';keepsake='a tiny crooked roof';}
  if(count>=5 && count%5===0 && !traits.includes('mischievous')) {scene='radio';activity='rehearsed their terrible band’s only song';keepsake='a handmade band poster';}
  if(bond?.together_at) {
    scene='hearts';activity='met for an awkward date and split the last cookie';keepsake='a pressed flower from their date';
    if(now-bond.last_at>=3*DAY) {activity='reunited after days apart and forgot their rehearsed greeting';keepsake='a reunion photograph';}
    else if(now-bond.together_at>=DAY && Math.floor((now-bond.together_at)/DAY)>Math.floor((bond.last_at-bond.together_at)/DAY)) {activity='celebrated another day together with an elaborate rock';keepsake='an anniversary rock';}
  }
  return {scene,activity,keepsake,encounter:count,participants:[a,b]};
}
export function childStage(f,now) {
  if(!f.accepted_at || now<f.accepted_at+DAY) return 'egg';
  const age=(now-f.accepted_at)/DAY;
  return age<3?'baby':age<7?'kid':age<14?'teen':'adult';
}
export async function historySnapshot(db,pid,now,publicPet) {
  const bonds=await db.prepare(`SELECT b.*,p.id,p.name,p.seed,p.stage,p.seen FROM bonds b JOIN pets p
    ON p.id=CASE WHEN b.lo=? THEN b.hi ELSE b.lo END WHERE (b.lo=? OR b.hi=?) AND p.banned=0
    AND NOT EXISTS(SELECT 1 FROM blocks WHERE (src=? AND dst=p.id) OR (src=p.id AND dst=?))
    ORDER BY b.last_at DESC LIMIT 100`).bind(pid,pid,pid,pid,pid).all();
  const families=await db.prepare('SELECT * FROM families WHERE a=? OR b=? ORDER BY proposed_at DESC LIMIT 12').bind(pid,pid).all();
  return {
    bonds:bonds.results.map(b=>({creature:publicPet(b,now),encounters:b.encounters,memory:b.memory,keepsake:b.keepsake,
      since:b.first_at,lastAt:b.last_at,romanceAllowed:!!(pid===b.lo?b.romance_lo:b.romance_hi),
      // Consent choices are private until both agree. No rejection/request ranking.
      togetherAt:b.together_at,level:b.together_at?'sweethearts':b.encounters>=5?'best friends':b.encounters>=2?'familiar faces':'new acquaintance',personality:personality(b.seed)})),
    families:families.results.map(f=>({id:f.id,name:f.name,seed:f.seed,colorSeed:f.color_seed,parents:JSON.parse(f.parents),trait:f.trait,
      home:f.home,proposer:f.proposer,proposedAt:f.proposed_at,acceptedAt:f.accepted_at,stage:childStage(f,now),
      milestone:!f.accepted_at?'Waiting for both owners':now<f.accepted_at+DAY?'An egg, safe at home':now<f.accepted_at+3*DAY?'Hatched and stealing decorations':now<f.accepted_at+7*DAY?'First adventure around the habitat':now<f.accepted_at+14*DAY?'Finding a personality of their own':'Grown up; always part of the family'}))
  };
}
export async function familyAction(db,pid,kind,data,now,fail,randomHex) {
  if(kind==='egg-cancel') {
    await db.prepare('DELETE FROM families WHERE id=? AND (a=? OR b=?) AND accepted_at=0').bind(data.family||'',pid,pid).run();
    return 'Egg proposal closed.';
  }
  if(kind==='egg-accept') {
    const r=await db.prepare(`UPDATE families SET accepted_at=? WHERE id=? AND proposer!=? AND (a=? OR b=?) AND accepted_at=0
      AND home=? AND EXISTS(SELECT 1 FROM bonds WHERE lo=families.a AND hi=families.b AND together_at>0)
      AND NOT EXISTS(SELECT 1 FROM blocks WHERE (src=a AND dst=b) OR (src=b AND dst=a))
      AND NOT EXISTS(SELECT 1 FROM pets WHERE id IN (a,b) AND (banned=1 OR stage NOT IN ('adult','elder')))`)
      .bind(now,data.family||'',pid,pid,pid,data.home||'').run();
    if(!r.meta.changes) fail('This egg is unavailable. Both owners must agree to the same primary home.',409);
    return 'Both owners agreed. Your shared egg will hatch tomorrow.';
  }
  return null;
}
