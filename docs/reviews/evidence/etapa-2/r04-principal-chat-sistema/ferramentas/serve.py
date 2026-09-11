# Servidor estatico com fallback de rota para o build web (SPA) na rota real.
import http.server, os, sys, functools
root = sys.argv[1]; port = int(sys.argv[2]); host = sys.argv[3] if len(sys.argv) > 3 else '127.0.0.1'
class H(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        p = super().translate_path(path)
        if not os.path.exists(p) and '.' not in os.path.basename(path.split('?')[0]):
            return os.path.join(root, 'index.html')
        return p
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store'); super().end_headers()
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer((host, port), functools.partial(H, directory=root)).serve_forever()
