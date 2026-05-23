#!/usr/bin/env python3
"""
Range-request対応HTTPサーバ
IGV.jsでBAM/FASTAを正しく配信するために必要
"""
import os, sys, mimetypes, urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8765
ROOT = os.path.dirname(os.path.abspath(__file__))
# scripts/ の一つ上がデータルート
ROOT = os.path.dirname(ROOT)

class RangeHandler(BaseHTTPRequestHandler):

    def do_OPTIONS(self):
        self.send_response(200)
        self._headers()
        self.end_headers()

    def do_HEAD(self):
        self._serve(send_body=False)

    def do_GET(self):
        self._serve(send_body=True)

    def _headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', 'Range')
        self.send_header('Access-Control-Expose-Headers',
                         'Content-Range, Content-Length, Accept-Ranges')

    def _serve(self, send_body=True):
        # URLデコード・クエリ除去
        path = urllib.parse.unquote(self.path.split('?')[0])
        filepath = os.path.normpath(os.path.join(ROOT, path.lstrip('/')))

        # ディレクトリトラバーサル防止
        if not filepath.startswith(ROOT):
            self.send_error(403); return

        if not os.path.isfile(filepath):
            self.send_error(404); return

        file_size = os.path.getsize(filepath)
        ctype = mimetypes.guess_type(filepath)[0] or 'application/octet-stream'

        range_header = self.headers.get('Range', '')
        if range_header.startswith('bytes='):
            # Range request → 206 Partial Content
            try:
                spec = range_header[6:].split(',')[0].strip()
                s, e = spec.split('-')
                start = int(s) if s else max(0, file_size - int(e))
                end   = int(e) if e else file_size - 1
                end   = min(end, file_size - 1)
                length = end - start + 1

                self.send_response(206)
                self._headers()
                self.send_header('Content-Type', ctype)
                self.send_header('Content-Length', str(length))
                self.send_header('Content-Range',
                                 f'bytes {start}-{end}/{file_size}')
                self.send_header('Accept-Ranges', 'bytes')
                self.end_headers()

                if send_body:
                    self._send_file(filepath, start, length)
            except Exception as ex:
                self.send_error(416, str(ex))
        else:
            # 通常リクエスト → 200
            self.send_response(200)
            self._headers()
            self.send_header('Content-Type', ctype)
            self.send_header('Content-Length', str(file_size))
            self.send_header('Accept-Ranges', 'bytes')
            self.end_headers()

            if send_body:
                self._send_file(filepath, 0, file_size)

    def _send_file(self, path, offset, length):
        with open(path, 'rb') as f:
            f.seek(offset)
            remaining = length
            while remaining > 0:
                chunk = f.read(min(65536, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    def log_message(self, fmt, *args):
        print(f'  {fmt % args}')


if __name__ == '__main__':
    # ポートが使用中なら終了して再起動
    import socket
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        if s.connect_ex(('127.0.0.1', PORT)) == 0:
            print(f'⚠ ポート {PORT} が使用中です。既存プロセスを停止してから再実行してください。')
            sys.exit(1)

    print(f'======================================')
    print(f'  Alignment Viewer (Range-capable)')
    print(f'  http://localhost:{PORT}/igv.html')
    print(f'  Ctrl+C で終了')
    print(f'======================================')
    HTTPServer(('127.0.0.1', PORT), RangeHandler).serve_forever()
