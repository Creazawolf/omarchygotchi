import copy
import unittest
from client import validate_snapshot

class ValidationTests(unittest.TestCase):
    def test_allowlisted_profile_and_capabilities(self):
        p=dict(id='a'*32,name='Pixel',seed=1,stage='adult',online=True,secret='omit')
        data=dict(id='b'*32,friends=[p],incoming=[],outgoing=[],blocked=[],visits=[],capabilities=dict(serverRoaming=True,offlineVisits=True))
        clean=validate_snapshot(data,'sync')
        self.assertNotIn('secret',clean['friends'][0])
        self.assertTrue(clean['capabilities']['offlineVisits'])
        for mutation in [dict(friends=[p]*201),dict(visits=[{}]),dict(friends=[dict(p,seed=-1)]),dict(friends='bad')]:
            broken=copy.deepcopy(data);broken.update(mutation)
            with self.assertRaises(ValueError): validate_snapshot(broken,'sync')
    def test_friend_codes_and_presence(self):
        base=dict(id='b'*32,friends=[],incoming=[],outgoing=[],blocked=[],visits=[],capabilities=dict(friendCodes=True,presence=True))
        clean=validate_snapshot(base|dict(park=dict(week=3,now=1),invite=dict(code='K7QF-M2XD',expires=1790000000)),'invite-create')
        self.assertEqual(clean['park'],{'week':3,'now':1})
        self.assertEqual(clean['invite']['code'],'K7QF-M2XD')
        self.assertTrue(clean['capabilities']['friendCodes'])
        self.assertIsNone(validate_snapshot(base,'sync')['invite'])
        for broken in [dict(invite=dict(code='k7qf-m2xd',expires=1)),dict(invite=dict(code='K7QF-M2X0',expires=1)),dict(invite=dict(expires=-1)),dict(park=dict(week='3',now=1)),dict(park=[])]:
            with self.assertRaises(ValueError): validate_snapshot(base|broken,'sync')
    def test_legacy_server_has_no_cloud_capabilities(self):
        data=dict(id='a'*16,friends=[],incoming=[],outgoing=[],blocked=[],visits=[])
        self.assertFalse(validate_snapshot(data,'sync')['capabilities']['serverRoaming'])
if __name__=='__main__': unittest.main()

class HistoryValidationTests(unittest.TestCase):
    def fixture(self):
        a=dict(id='a'*32,name='Pixel',seed=4,stage='adult')
        b=dict(id='b'*32,name='Bean',seed=2,stage='adult')
        scene=dict(scene='radio',activity='shared a radio',keepsake='a radio',encounter=4,participants=[a,b])
        return dict(id=a['id'],friends=[b],incoming=[],outgoing=[],blocked=[],visits=[dict(id='c'*32,creature=b,activity=scene['activity'],at=100,until=1000,scene=scene)],bonds=[dict(creature=b,encounters=4,memory='shared a radio',keepsake='a radio',since=1,lastAt=100,romanceAllowed=False,togetherAt=0,level='familiar faces',personality='mischievous')],families=[dict(id='d'*32,name='Pip',seed=4,colorSeed=2,stage='egg',parents=[a,b],trait='shy',home=a['id'],proposer=a['id'],proposedAt=100,acceptedAt=0,milestone='Waiting for both owners')])
    def test_shared_scene_and_family_allowlist(self):
        data=self.fixture();data['families'][0]['private']='omit'
        clean=validate_snapshot(data,'sync')
        self.assertEqual(clean['visits'][0]['scene']['participants'][0]['name'],'Pixel')
        self.assertNotIn('private',clean['families'][0])
    def test_rejects_forged_participants_home_dates_markup_controls_and_large_albums(self):
        for mutate in [
            lambda d: d['visits'][0]['scene']['participants'][0].update(id='e'*32),
            lambda d: d['visits'][0]['scene'].update(scene='run-command'),
            lambda d: d['families'][0].update(home='e'*32),
            lambda d: d['families'][0].update(colorSeed=-1),
            lambda d: d['families'][0].update(acceptedAt=float('nan')),
            lambda d: d['bonds'][0].update(encounters=True),
            lambda d: d['bonds'][0].update(memory='bad\u202ename'),
            lambda d: d.update(families=d['families']*13),
        ]:
            data=self.fixture();mutate(data)
            with self.assertRaises(ValueError): validate_snapshot(data,'sync')
