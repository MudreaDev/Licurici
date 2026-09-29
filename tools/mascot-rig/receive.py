"""Server local minimal: primește imagini prin POST /<nume> și le salvează în assets-src/licurici/.

Folosit ca să preiau imaginile din Gemini (browser) fără descărcări manuale.
Rulare: python tools/mascot-rig/receive.py   (portul 8765, doar localhost)
"""

import base64
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets-src", "licurici")


class H(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Private-Network", "true")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self):
        name = re.sub(r"[^a-zA-Z0-9_.-]", "", self.path.strip("/")) or "img.jpg"
        data = self.rfile.read(int(self.headers["Content-Length"]))
        if data[:5] != b"\xff\xd8\xff\xe0\x00" and data[:4] != b"\x89PNG":
            data = base64.b64decode(data)
        with open(os.path.join(OUT, name), "wb") as f:
            f.write(data)
        self.send_response(200)
        self._cors()
        self.end_headers()
        self.wfile.write(str(len(data)).encode())


HTTPServer(("127.0.0.1", 8765), H).serve_forever()
