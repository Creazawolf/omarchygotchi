import tempfile
import unittest
from server import Community, Problem

class CommunityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.c = Community(self.tmp.name+'/test.sqlite3')
        self.a = self.c.call('register',self.profile('Pixel'))
        self.b = self.c.call('register',self.profile('Bean'))
        self.sync(self.a,'Pixel'); self.sync(self.b,'Bean')
    def tearDown(self):
        self.c.db.close(); self.tmp.cleanup()
    def profile(self,name): return dict(name=name,seed=123,stage='adult',discover=True)
    def sync(self,who,name): return self.c.call('sync',self.profile(name),who['token'])
    def call(self,action,who,target=''): return self.c.call(action,dict(target=target),who['token'])
    def test_encounter_and_mutual_friendship(self):
        visit = self.call('visit',self.a)['visits'][0]
        self.assertEqual(visit['creature']['id'],self.b['id'])
        self.assertEqual(self.sync(self.b,'Bean')['visits'][0]['id'],visit['id'])
        self.call('request',self.a,self.b['id'])
        with self.assertRaises(Problem): self.call('accept',self.a,self.b['id'])
        self.assertEqual(len(self.sync(self.b,'Bean')['incoming']),1)
        self.call('accept',self.b,self.a['id'])
        self.assertEqual(len(self.sync(self.a,'Pixel')['friends']),1)
        self.assertEqual(len(self.sync(self.b,'Bean')['friends']),1)
        self.call('remove',self.a,self.b['id'])
        self.assertEqual(self.sync(self.b,'Bean')['friends'],[])
    def test_blocking_both_directions_and_unblock(self):
        self.call('visit',self.a)
        self.call('block',self.b,self.a['id'])
        with self.assertRaises(Problem): self.call('request',self.a,self.b['id'])
        self.assertEqual(self.sync(self.a,'Pixel')['visits'],[])
        self.call('block',self.a,self.b['id'])
        self.call('unblock',self.a,self.b['id'])
        self.assertTrue(self.c.blocked(self.a['id'],self.b['id']))
    def test_no_self_matching_offline_and_cooldown(self):
        self.call('offline',self.b)
        with self.assertRaises(Problem): self.call('visit',self.a)
        self.sync(self.b,'Bean')
        self.call('visit',self.a)
        with self.assertRaises(Problem): self.call('visit',self.b)
    def test_auth_validation_and_no_request_spam(self):
        with self.assertRaises(Problem): self.c.call('sync',{},'bad-token')
        with self.assertRaises(Problem): self.c.call('register',self.profile('x'*21))
        with self.assertRaises(Problem): self.call('request',self.a,self.b['id'])
        self.call('visit',self.a)
        self.call('request',self.a,self.b['id'])
        with self.assertRaises(Problem): self.call('request',self.a,self.b['id'])
        self.call('decline',self.b,self.a['id'])
        self.assertEqual(self.sync(self.a,'Pixel')['outgoing'],[])
    def test_deletion_and_persistence(self):
        self.call('visit',self.a)
        dbpath = self.tmp.name+'/test.sqlite3'
        self.c.db.close(); self.c = Community(dbpath)
        self.assertEqual(len(self.sync(self.b,'Bean')['visits']),1)
        self.call('delete',self.a)
        self.assertEqual(self.sync(self.b,'Bean')['visits'],[])
        with self.assertRaises(Problem): self.sync(self.a,'Pixel')
    def test_profile_allowlist(self):
        p = self.profile('Pixel'); p['windowTitle']='private'; p['token']='private'
        self.c.call('sync',p,self.a['token'])
        result = self.call('visit',self.b)
        self.assertEqual(set(result['visits'][0]['creature']),{'id','name','seed','stage','online'})

if __name__=='__main__': unittest.main()
