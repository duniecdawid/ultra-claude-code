#!/usr/bin/env python3
"""Mock Anthropic API gateway — simulate a subscription usage-limit hit against a live
Claude Code session without burning real quota.

Point a disposable Claude Code session at this gateway via
    ANTHROPIC_BASE_URL=http://127.0.0.1:<port> claude
and flip the MODE file to control behavior (hot-swappable, checked per request):

    pass    -> everything proxies through to https://api.anthropic.com (streaming preserved)
    reject  -> POST /v1/messages* returns 429 with the unified rate-limit headers Claude Code
               recognizes as a subscription limit; everything else still proxies

The reject response reproduces the real limit UX exactly (verified 2026-07-23 against Claude
Code 2.1.218: banner "You've hit your session limit · resets <time>", the /rate-limit-options
menu, and a StopFailure hook firing with error:"rate_limit").

State files (created on demand, all in --state-dir, default: alongside this script):
    MODE         current mode word ("pass" or "reject"); missing file = pass
    RESET_EPOCH  epoch seconds advertised as the limit reset; missing = now + 300

Requests are logged one line each to access.log in the state dir.

See README.md for the full end-to-end drill this rig supports.
"""
import argparse
import http.server
import json
import os
import socketserver
import time

import requests

UPSTREAM = "https://api.anthropic.com"

HOP = {"host", "connection", "keep-alive", "transfer-encoding", "content-length",
       "te", "trailer", "upgrade", "proxy-authorization", "proxy-authenticate",
       # requests transparently decompresses upstream bodies: ask for identity
       # encoding and never relay stale encoding headers with plain bytes
       # (relaying content-encoding: gzip for decompressed bytes makes the
       # Claude Code client fail with ZlibError — found the hard way).
       "accept-encoding", "content-encoding"}

STATE_DIR = os.path.dirname(os.path.abspath(__file__))


def state_path(name):
    return os.path.join(STATE_DIR, name)


def mode():
    try:
        return open(state_path("MODE")).read().strip()
    except OSError:
        return "pass"


def reset_epoch():
    try:
        return int(open(state_path("RESET_EPOCH")).read().strip())
    except (OSError, ValueError):
        return int(time.time()) + 300


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    log_file = None

    def log_message(self, fmt, *args):  # quiet stderr; we log ourselves
        pass

    def _log(self, note):
        self.log_file.write(f"{time.strftime('%H:%M:%S')} {self.command} {self.path} -> {note}\n")

    def _reject_limit(self):
        epoch = reset_epoch()
        body = json.dumps({
            "type": "error",
            "error": {
                "type": "rate_limit_error",
                "message": f"Claude AI usage limit reached|{epoch}",
            },
        }).encode()
        self.send_response(429)
        self.send_header("content-type", "application/json")
        self.send_header("anthropic-ratelimit-unified-status", "rejected")
        self.send_header("anthropic-ratelimit-unified-reset", str(epoch))
        self.send_header("anthropic-ratelimit-unified-representative-claim", "five_hour")
        self.send_header("anthropic-ratelimit-unified-fallback", "unavailable")
        self.send_header("retry-after", str(max(1, epoch - int(time.time()))))
        self.send_header("request-id", "req_mock_limit_000000000001")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        self._log(f"429 LIMIT (reset={epoch})")

    def _forward(self):
        length = int(self.headers.get("content-length") or 0)
        req_body = self.rfile.read(length) if length else None
        headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP}
        try:
            up = requests.request(self.command, UPSTREAM + self.path,
                                  headers=headers, data=req_body,
                                  stream=True, timeout=600)
        except Exception as e:  # noqa: BLE001
            self.send_response(502)
            self.send_header("content-length", "0")
            self.end_headers()
            self._log(f"502 upstream error: {e}")
            return
        self.send_response(up.status_code)
        is_stream = "text/event-stream" in (up.headers.get("content-type") or "")
        for k, v in up.headers.items():
            if k.lower() in HOP:
                continue
            self.send_header(k, v)
        if is_stream:
            # close-delimited stream: relay chunks as they arrive
            self.send_header("connection", "close")
            self.end_headers()
            try:
                for chunk in up.iter_content(chunk_size=None):
                    if chunk:
                        self.wfile.write(chunk)
                        self.wfile.flush()
            except Exception as e:  # noqa: BLE001
                self._log(f"stream relay aborted: {e}")
            self._log(f"{up.status_code} streamed")
            self.close_connection = True
        else:
            data = up.content
            self.send_header("content-length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            self._log(f"{up.status_code} {len(data)}B")

    def _route(self):
        if (mode() == "reject" and self.command == "POST"
                and self.path.startswith("/v1/messages")
                and "count_tokens" not in self.path):
            self._reject_limit()
        else:
            self._forward()

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = _route


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True


def main():
    global STATE_DIR
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("port", nargs="?", type=int, default=8399)
    ap.add_argument("--state-dir", default=STATE_DIR,
                    help="directory for MODE / RESET_EPOCH / access.log (default: script dir)")
    args = ap.parse_args()
    STATE_DIR = args.state_dir
    os.makedirs(STATE_DIR, exist_ok=True)
    Handler.log_file = open(state_path("access.log"), "a", buffering=1)
    print(f"mock-limit-rig gateway on 127.0.0.1:{args.port}, mode={mode()}, "
          f"state={STATE_DIR}", flush=True)
    Server(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
