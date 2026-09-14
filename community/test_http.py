import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
from http.server import HTTPServer
from server import Handler, Community
from client import run

class HttpTests(unittest.TestCase):
    def test_two_clients_and_private_persistent_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            server = HTTPServer(('127.0.0.1',0),Handler)
            ready = threading.Event()
            def serve():
                server.community = Community(directory+'/db.sqlite3')
                ready.set()
                server.serve_forever(poll_interval=0.05)
                server.community.db.close()
            thread = threading.Thread(target=serve,daemon=True); thread.start(); ready.wait(3)
            url = 'http://127.0.0.1:'+str(server.server_port)
            def client(home,action,data):
                with patch.object(Path,'home',return_value=Path(directory)/home):
                    return run(url,action,data)
            a=dict(name='Pixel',seed=1,stage='adult',discover=True)
            b=dict(name='Bean',seed=2,stage='adult',discover=True)
            try:
                alice=client('a','sync',a); bob=client('b','sync',b)
                visit=client('a','visit',{})
                self.assertEqual(visit['visits'][0]['creature']['id'],bob['id'])
                client('a','request',dict(target=bob['id']))
                incoming=client('b','sync',b)
                self.assertEqual(incoming['incoming'][0]['id'],alice['id'])
                client('b','accept',dict(target=alice['id']))
                self.assertEqual(len(client('a','sync',a)['friends']),1)
                files=list((Path(directory)/'a/.local/state/omarchy/tamagotchi-community').glob('*.json'))
                self.assertEqual(len(files),1)
                self.assertEqual(files[0].stat().st_mode & 0o777,0o600)
                client('a','delete',{})
                self.assertFalse(files[0].exists())
                with self.assertRaises(ValueError): run('http://example.com','sync',a)
            finally:
                server.shutdown(); thread.join(3); server.server_close()
if __name__=='__main__': unittest.main()
