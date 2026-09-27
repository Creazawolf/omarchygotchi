#!/usr/bin/env python3
"""One bounded request; identity stays in a private, server-specific local file."""
import hashlib
import json
import os
import re
import unicodedata
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise ValueError('Server redirects are not supported. Use its final HTTPS address.')

def validate_snapshot(result, action):
    if not isinstance(result, dict):
        raise ValueError('Invalid community response.')
    if action == 'delete':
        return {'message': 'Community profile deleted.'}
    def creature(p):
        if not isinstance(p, dict) or not re.fullmatch(r'[a-f0-9]{16,64}', str(p.get('id', ''))):
            raise ValueError('Invalid creature profile.')
        if not isinstance(p.get('name'), str) or not 1 <= len(p['name']) <= 20 or any(unicodedata.category(c) in ['Cc','Cf'] for c in p['name']):
            raise ValueError('Invalid creature name.')
        if type(p.get('seed')) is not int or not 0 <= p['seed'] <= 4294967295:
            raise ValueError('Invalid creature appearance.')
        if p.get('stage') not in ['egg','baby','kid','teen','adult','elder','ghost']:
            raise ValueError('Invalid creature stage.')
        return {k: p[k] for k in ['id','name','seed','stage']} | {'online': p.get('online') is True}
    def number(value, maximum=32503680000):
        if type(value) is not int or not 0 <= value <= maximum:
            raise ValueError('Invalid shared history number.')
        return value
    def words(value, maximum=240):
        if not isinstance(value, str) or len(value)>maximum or any(unicodedata.category(c) in ['Cc','Cf'] for c in value):
            raise ValueError('Invalid shared history text.')
        return value
    def identity(value):
        if not isinstance(value,str) or not re.fullmatch(r'[a-f0-9]{16,64}',value):
            raise ValueError('Invalid history identity.')
        return value
    def listing(key, maximum):
        values=result.get(key,[])
        if not isinstance(values,list) or len(values)>maximum or any(not isinstance(v,dict) for v in values):
            raise ValueError('Invalid shared history list.')
        return values
    clean = {'id': str(result.get('id', ''))[:64], 'message': str(result.get('message', ''))[:240]}
    for key in ['friends','incoming','outgoing','blocked']:
        values = result.get(key)
        if not isinstance(values, list) or len(values) > 200:
            raise ValueError('Community list is invalid or too large.')
        clean[key] = [creature(p) for p in values]
    values = result.get('visits')
    if not isinstance(values, list) or len(values) > 30:
        raise ValueError('Community journal is invalid or too large.')
    clean['visits'] = []
    for visit in values:
        if not isinstance(visit, dict) or not re.fullmatch(r'[a-f0-9]{16,64}', str(visit.get('id', ''))):
            raise ValueError('Invalid journal entry.')
        if not isinstance(visit.get('activity'), str) or len(visit['activity']) > 100:
            raise ValueError('Invalid journal activity.')
        at = visit.get('at')
        if type(at) not in [int, float] or not 0 <= at <= 32503680000:
            raise ValueError('Invalid journal date.')
        entry={'id': visit['id'], 'creature': creature(visit.get('creature')), 'activity': words(visit['activity'],100), 'at': at, 'until':number(visit.get('until',0))}
        scene=visit.get('scene')
        if scene is not None:
            if not isinstance(scene,dict) or scene.get('scene') not in ['picnic','gift','radio','hat','shelter','hearts']:
                raise ValueError('Invalid shared scene.')
            people=scene.get('participants')
            if not isinstance(people,list) or len(people)!=2:
                raise ValueError('Invalid scene participants.')
            people=[creature(p) for p in people]
            if set(p['id'] for p in people)!={clean['id'],entry['creature']['id']}:
                raise ValueError('Scene participants do not match this visit.')
            entry['scene']={'scene':scene['scene'],'activity':words(scene.get('activity'),100),'keepsake':words(scene.get('keepsake'),100),'encounter':number(scene.get('encounter'),1000000),'participants':people}
        clean['visits'].append(entry)
    caps = result.get('capabilities', {})
    clean['capabilities'] = {k: isinstance(caps, dict) and caps.get(k) is True for k in ['offlineVisits','serverRoaming','sharedHistory','families','friendCodes','presence']}
    park = result.get('park')
    if park is not None:
        if not isinstance(park, dict):
            raise ValueError('Invalid park presence.')
        clean['park'] = {'week': number(park.get('week'), 100000), 'now': number(park.get('now'), 100000)}
    invite = result.get('invite')
    if invite is not None:
        if not isinstance(invite, dict):
            raise ValueError('Invalid friend code.')
        entry = {'expires': number(invite.get('expires'))}
        # The readable code only ever arrives in its owner's creation response.
        if 'code' in invite:
            if not isinstance(invite['code'], str) or not re.fullmatch(r'[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}', invite['code']):
                raise ValueError('Invalid friend code.')
            entry['code'] = invite['code']
        clean['invite'] = entry
    else:
        clean['invite'] = None
    clean['bonds']=[]
    for b in listing('bonds',100):
        if b.get('level') not in ['sweethearts','best friends','familiar faces','new acquaintance'] or b.get('personality') not in ['shy','generous','mischievous','outgoing'] or type(b.get('romanceAllowed')) is not bool:
            raise ValueError('Invalid relationship.')
        clean['bonds'].append({'creature':creature(b.get('creature')),'encounters':number(b.get('encounters'),1000000),'memory':words(b.get('memory')),'keepsake':words(b.get('keepsake',''),100),'since':number(b.get('since')),'lastAt':number(b.get('lastAt')),'romanceAllowed':b['romanceAllowed'],'togetherAt':number(b.get('togetherAt')),'level':b['level'],'personality':b['personality']})
    clean['families']=[]
    for f in listing('families',12):
        child=creature(dict(f,online=False))
        parents=f.get('parents')
        if not isinstance(parents,list) or len(parents)!=2:
            raise ValueError('Invalid family parents.')
        parents=[creature(p) for p in parents]
        ids=[p['id'] for p in parents]
        if clean['id'] not in ids or len(set(ids))!=2 or f.get('home') not in ids or f.get('proposer') not in ids:
            raise ValueError('Invalid family home or consent.')
        clean['families'].append(child | {'colorSeed':number(f.get('colorSeed'),4294967295),'parents':parents,'trait':words(f.get('trait'),40),'home':identity(f.get('home')),'proposer':identity(f.get('proposer')),'proposedAt':number(f.get('proposedAt')),'acceptedAt':number(f.get('acceptedAt')),'milestone':words(f.get('milestone'))})
    return clean

def run(url, action, data):
    parsed = urllib.parse.urlsplit(url)
    if parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in ['', '/']:
        raise ValueError('Use a server origin, such as https://pets.example.org.')
    if parsed.scheme != 'https' and not (parsed.scheme=='http' and parsed.hostname in ['127.0.0.1','localhost','::1']):
        raise ValueError('Remote community servers require HTTPS.')
    if not parsed.hostname: raise ValueError('Enter a community server address.')
    url = url.rstrip('/')
    folder = Path.home()/'.local/state/omarchy/tamagotchi-community'
    folder.mkdir(parents=True,exist_ok=True,mode=0o700)
    os.chmod(folder,0o700)
    identity_path = folder/(hashlib.sha256(url.encode()).hexdigest()+'.json')
    identity = json.loads(identity_path.read_text()) if identity_path.exists() else None
    opener = urllib.request.build_opener(NoRedirect)
    def post(action, payload, token=''):
        req = urllib.request.Request(url+'/v1/'+action, data=json.dumps(payload).encode(), headers={'Content-Type':'application/json','Accept':'application/json','User-Agent':'Omarchygotchi/3.1','Authorization':'Bearer '+token},method='POST')
        try:
            with opener.open(req,timeout=8) as response:
                raw = response.read(262145)
                if len(raw)>262144: raise ValueError('Server response is too large.')
                return json.loads(raw)
        except urllib.error.HTTPError as e:
            try: message = json.loads(e.read(4096)).get('error') or ('Community request rejected (HTTP '+str(e.code)+').')
            except (ValueError,AttributeError): message = 'Community request failed.'
            raise ValueError(message) from None
    if identity is None:
        if action != 'sync': raise ValueError('Connect to the community first.')
        identity = post('register',data)
        if not isinstance(identity, dict) or not isinstance(identity.get('token'),str) or not re.fullmatch(r'[A-Za-z0-9_-]{32,128}', identity['token']): raise ValueError('Invalid server identity.')
        temporary = identity_path.with_suffix('.tmp')
        fd = os.open(temporary,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
        os.fchmod(fd, 0o600)
        with os.fdopen(fd,'w') as f: json.dump(identity,f)
        os.replace(temporary,identity_path)
    result = validate_snapshot(post(action,data,identity['token']), action)
    if action=='delete': identity_path.unlink(missing_ok=True)
    return result

if __name__=='__main__':
    try:
        print(json.dumps(run(sys.argv[1],sys.argv[2],json.loads(sys.argv[3]))))
    except Exception as e:
        # Avoid emitting exception URLs, headers or filesystem details.
        message = str(e) if isinstance(e,ValueError) else 'Cannot reach the community. Check the server address and your connection.'
        print(json.dumps(dict(error=message[:240])))
