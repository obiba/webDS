"""Dev-only proxy that makes an Opal callable by webDS's fetch transport (issue #2).

Stands in for the Opal changes the transport needs (opal branch feat/session-header):
CORS for the page origin, session id in the X-Opal-Session header instead of the
opalsid cookie, no XSRF check for those requests (the proxy adds the token itself).

    python3 dev/opal-cors-proxy.py [https://opal-demo.obiba.org] [8099]

then in webDS: options(webds.fetch = "localhost") and url = "http://localhost:8099".
"""
import http.client
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

UPSTREAM = urlsplit(sys.argv[1] if len(sys.argv) > 1 else 'https://opal-demo.obiba.org')
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8099
EXPOSE = 'X-Opal-Version, Location, Content-Disposition, WWW-Authenticate, X-Opal-Session'
DROP_REQUEST = {'host', 'origin', 'referer', 'user-agent', 'connection', 'cookie', 'x-opal-session'}
DROP_RESPONSE = {'transfer-encoding', 'connection', 'content-length', 'strict-transport-security'}
local = threading.local()  # one keep-alive upstream connection per thread
xsrf = {}  # session id -> XSRF token


class Proxy(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def cors(self):
        self.send_header('Access-Control-Allow-Origin', self.headers.get('Origin', '*'))
        self.send_header('Access-Control-Allow-Credentials', 'true')
        self.send_header('Vary', 'Origin')

    def do_OPTIONS(self):
        self.send_response(204)
        self.cors()
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', self.headers.get('Access-Control-Request-Headers', ''))
        self.send_header('Access-Control-Max-Age', '600')
        self.send_header('Content-Length', '0')
        self.end_headers()

    def upstream(self, body, headers):
        for retry in (True, False):
            if not hasattr(local, 'conn'):
                local.conn = http.client.HTTPSConnection(UPSTREAM.netloc, timeout=300)
            try:
                local.conn.request(self.command, self.path, body, headers)
                return local.conn.getresponse()
            except (http.client.HTTPException, OSError):
                local.conn.close()
                del local.conn
                if not retry:
                    raise

    def forward(self):
        body = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        headers = {k: v for k, v in self.headers.items() if k.lower() not in DROP_REQUEST}
        # Opal's CSRF check: no Referer from another host, user agent in csrf.allowed-agents
        headers['User-Agent'] = 'python webds-proxy'
        sid = self.headers.get('X-Opal-Session')
        if sid:
            headers['Cookie'] = f'opalsid={sid}'
            if sid in xsrf:
                headers['X-XSRF-TOKEN'] = xsrf[sid]
        r = self.upstream(body, headers)
        data = r.read()
        self.send_response(r.status)
        self.cors()
        self.send_header('Access-Control-Expose-Headers', EXPOSE)
        cookies = {}
        for k, v in r.getheaders():
            if k.lower() == 'set-cookie':
                name, _, rest = v.partition('=')
                cookies[name] = rest.split(';', 1)[0]
            elif k.lower() not in DROP_RESPONSE:
                self.send_header(k, v)
        if 'opalsid' in cookies:
            self.send_header('X-Opal-Session', cookies['opalsid'])
            if cookies.get('XSRF-TOKEN'):
                xsrf[cookies['opalsid']] = cookies['XSRF-TOKEN']
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = do_PUT = do_DELETE = forward


if __name__ == '__main__':
    print(f'proxy http://localhost:{PORT} -> {UPSTREAM.geturl()}')
    ThreadingHTTPServer(('localhost', PORT), Proxy).serve_forever()
