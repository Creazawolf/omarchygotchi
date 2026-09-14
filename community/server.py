#!/usr/bin/env python3
"""Small self-hosted creature community. Put behind HTTPS for remote use."""
import argparse
import hashlib
import json
import secrets
import sqlite3
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

SCHEMA = '''
CREATE TABLE IF NOT EXISTS pets(id TEXT PRIMARY KEY, token TEXT UNIQUE, profile TEXT, seen REAL, discover INTEGER, last_visit REAL DEFAULT 0);
CREATE TABLE IF NOT EXISTS links(src TEXT, dst TEXT, status TEXT, PRIMARY KEY(src,dst));
CREATE TABLE IF NOT EXISTS visits(id TEXT PRIMARY KEY, a TEXT, b TEXT, activity TEXT, at REAL);
CREATE TABLE IF NOT EXISTS limits(key TEXT PRIMARY KEY, start REAL, count INTEGER);
'''
ACTIVITIES = ['chased fireflies', 'built a pillow fort', 'shared a picnic', 'explored the moon garden', 'played hide-and-seek', 'watched the stars']

class Problem(Exception):
    def __init__(self, message, status=400):
        self.message, self.status = message, status

class Community:
    def __init__(self, database):
        self.db = sqlite3.connect(database)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(SCHEMA)

    def limit(self, key, maximum, seconds=3600):
        now = time.time()
        row = self.db.execute('SELECT * FROM limits WHERE key=?', (key,)).fetchone()
        if row and now-row['start'] < seconds and row['count'] >= maximum:
            raise Problem('Please wait before trying again.', 429)
        if not row or now-row['start'] >= seconds:
            self.db.execute('INSERT OR REPLACE INTO limits VALUES(?,?,1)', (key, now))
        else:
            self.db.execute('UPDATE limits SET count=count+1 WHERE key=?', (key,))
        self.db.execute('DELETE FROM limits WHERE start<?', (now-86400,))
        self.db.commit()

    def profile(self, data):
        name = data.get('name', '')
        if not isinstance(name, str) or not name.strip() or len(name) > 20 or any(ord(c)<32 for c in name):
            raise Problem('Choose a creature name of 1–20 characters.')
        stage = data.get('stage', 'egg')
        if stage not in ['egg','baby','kid','teen','adult','elder','ghost']:
            raise Problem('Invalid creature stage.')
        seed = data.get('seed', 1)
        if type(seed) is not int or not 0 <= seed <= 4294967295:
            raise Problem('Invalid creature appearance.')
        return json.dumps(dict(name=name.strip(), stage=stage, seed=seed))

    def public(self, row):
        return dict(json.loads(row['profile']), id=row['id'], online=time.time()-row['seen']<120)

    def blocked(self, a, b):
        return self.db.execute("SELECT 1 FROM links WHERE status='blocked' AND ((src=? AND dst=?) OR (src=? AND dst=?))", (a,b,b,a)).fetchone() is not None

    def call(self, action, data, token='', ip='local'):
        now = time.time()
        if action == 'register':
            profile = self.profile(data)
            self.limit('register:'+ip, 10)
            token, pid = secrets.token_urlsafe(32), secrets.token_hex(8)
            self.db.execute('INSERT INTO pets(id,token,profile,seen,discover) VALUES(?,?,?,?,0)', (pid,hashlib.sha256(token.encode()).hexdigest(),profile,now))
            self.db.commit()
            return dict(id=pid, token=token)
        me = self.db.execute('SELECT * FROM pets WHERE token=?', (hashlib.sha256(token.encode()).hexdigest(),)).fetchone()
        if not token or not me:
            raise Problem('Community identity is invalid.', 401)
        pid = me['id']
        self.limit('user:'+pid, 180, 60)
        message = ''
        if action == 'sync':
            self.db.execute('UPDATE pets SET profile=?,seen=?,discover=? WHERE id=?', (self.profile(data),now,int(data.get('discover') is True),pid))
        elif action == 'offline':
            self.db.execute('UPDATE pets SET discover=0,seen=0 WHERE id=?', (pid,))
        elif action == 'delete':
            self.db.execute('DELETE FROM links WHERE src=? OR dst=?', (pid,pid))
            self.db.execute('DELETE FROM visits WHERE a=? OR b=?', (pid,pid))
            self.db.execute('DELETE FROM pets WHERE id=?', (pid,))
            self.db.commit()
            return dict(message='Community profile deleted.')
        elif action in ['request','accept','decline','remove','block','unblock','visit']:
            target = data.get('target', '')
            if action == 'visit' and not target:
                candidates = self.db.execute("SELECT * FROM pets WHERE id!=? AND discover=1 AND seen>?", (pid,now-120)).fetchall()
                candidates = [p for p in candidates if not self.blocked(pid,p['id']) and json.loads(p['profile'])['stage'] not in ['egg','ghost'] and now-p['last_visit']>=300]
                if not candidates:
                    raise Problem('The park is quiet. Try again when another creature is online.', 409)
                target = secrets.choice(candidates)['id']
            other = self.db.execute('SELECT * FROM pets WHERE id=?', (target,)).fetchone()
            if not other or target == pid:
                raise Problem('Creature not found.', 404)
            if action not in ['block','unblock'] and self.blocked(pid,target):
                raise Problem('This connection is unavailable.', 403)
            if action == 'request':
                self.limit('requests:'+pid, 20)
                met = self.db.execute('SELECT 1 FROM visits WHERE (a=? AND b=?) OR (a=? AND b=?)', (pid,target,target,pid)).fetchone()
                if not met:
                    raise Problem('Meet this creature in the park first.')
                existing = self.db.execute('SELECT 1 FROM links WHERE (src=? AND dst=?) OR (src=? AND dst=?)', (pid,target,target,pid)).fetchone()
                if existing:
                    raise Problem('A request or friendship already exists.')
                self.db.execute("INSERT INTO links VALUES(?,?,'pending')", (pid,target))
                message = 'Friend request sent.'
            elif action == 'accept':
                changed = self.db.execute("UPDATE links SET status='friends' WHERE src=? AND dst=? AND status='pending'", (target,pid)).rowcount
                if not changed:
                    raise Problem('This request is no longer pending.')
                message = 'You are now friends!'
            elif action == 'decline':
                self.db.execute("DELETE FROM links WHERE src=? AND dst=? AND status='pending'", (target,pid))
            elif action == 'remove':
                self.db.execute("DELETE FROM links WHERE ((src=? AND dst=?) OR (src=? AND dst=?)) AND status!='blocked'", (pid,target,target,pid))
            elif action == 'block':
                self.db.execute("DELETE FROM links WHERE ((src=? AND dst=?) OR (src=? AND dst=?)) AND status!='blocked'", (pid,target,target,pid))
                self.db.execute("INSERT OR REPLACE INTO links VALUES(?,?,'blocked')", (pid,target))
            elif action == 'unblock':
                self.db.execute("DELETE FROM links WHERE src=? AND dst=? AND status='blocked'", (pid,target))
            elif action == 'visit':
                if not me['discover'] or now-me['seen']>120 or json.loads(me['profile'])['stage'] in ['egg','ghost']:
                    raise Problem('Your creature must be awake and available in the park.', 409)
                if not other['discover'] or now-other['seen']>120:
                    raise Problem('This creature is away. Try later.', 409)
                if now-me['last_visit']<300 or now-other['last_visit']<300:
                    raise Problem('Creatures need five minutes between playdates.', 429)
                activity = secrets.choice(ACTIVITIES)
                self.db.execute('INSERT INTO visits VALUES(?,?,?,?,?)', (secrets.token_hex(12),pid,target,activity,now))
                self.db.execute('UPDATE pets SET last_visit=? WHERE id IN (?,?)', (now,pid,target))
                message = 'Your creatures '+activity+'!'
        else:
            raise Problem('Unknown community action.', 404)
        self.db.execute('DELETE FROM visits WHERE at<?', (now-30*86400,))
        self.db.commit()
        result = self.snapshot(pid)
        result['message'] = message
        return result

    def snapshot(self, pid):
        friends, incoming, outgoing, blocked = [], [], [], []
        for row in self.db.execute('SELECT * FROM links WHERE src=? OR dst=?', (pid,pid)):
            otherid = row['dst'] if row['src']==pid else row['src']
            other = self.db.execute('SELECT * FROM pets WHERE id=?', (otherid,)).fetchone()
            if not other: continue
            p = self.public(other)
            if row['status']=='blocked':
                if row['src']==pid: blocked.append(p)
            elif self.blocked(pid,otherid): continue
            elif row['status']=='friends': friends.append(p)
            elif row['dst']==pid: incoming.append(p)
            else: outgoing.append(p)
        visits = []
        for v in self.db.execute('SELECT * FROM visits WHERE a=? OR b=? ORDER BY at DESC LIMIT 30', (pid,pid)):
            oid = v['b'] if v['a']==pid else v['a']
            if self.blocked(pid,oid): continue
            other = self.db.execute('SELECT * FROM pets WHERE id=?', (oid,)).fetchone()
            if other: visits.append(dict(id=v['id'], creature=self.public(other), activity=v['activity'], at=v['at']))
        return dict(id=pid, friends=friends, incoming=incoming, outgoing=outgoing, blocked=blocked, visits=visits)

class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(10)
    def log_message(self, *args): pass  # Never log credentials or profile payloads.
    def do_POST(self):
        try:
            length = int(self.headers.get('Content-Length','0'))
            if not 0 < length <= 4096: raise Problem('Invalid request size.', 413)
            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict): raise Problem('Expected an object.')
            with self.server.community.db:
                result = self.server.community.call(self.path.removeprefix('/v1/'), data, self.headers.get('Authorization','').removeprefix('Bearer '), self.client_address[0])
            self.reply(200,result)
        except Problem as e: self.reply(e.status,dict(error=e.message))
        except (ValueError, TypeError): self.reply(400,dict(error='Invalid request.'))
        except Exception: self.reply(500,dict(error='Community server error.'))
    def reply(self,status,data):
        payload = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--host',default='127.0.0.1')
    parser.add_argument('--port',type=int,default=8765)
    parser.add_argument('--database',default='community.sqlite3')
    args = parser.parse_args()
    server = HTTPServer((args.host,args.port),Handler)
    server.timeout = 10
    server.community = Community(args.database)
    print(f'Creature community listening on {args.host}:{args.port}',flush=True)
    server.serve_forever()
