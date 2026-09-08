#!/usr/bin/env python3
"""Read reset-credit metadata through Codex; never consume a credit."""
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import tempfile
import time


def find_codex():
    candidates = [Path('/Applications/ChatGPT.app/Contents/Resources/codex'),
                  Path('/Applications/Codex.app/Contents/Resources/codex'),
                  Path.home() / '.local/bin/codex']
    located = shutil.which('codex')
    if located:
        candidates.append(Path(located))
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    raise RuntimeError('Codex CLI unavailable')


def read_account(binary):
    process = subprocess.Popen([binary, 'app-server', '--stdio'], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    pending = bytearray()

    def send(value):
        process.stdin.write((json.dumps(value) + '\n').encode())
        process.stdin.flush()

    def response(request_id):
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            while b'\n' in pending:
                raw, _, rest = pending.partition(b'\n')
                pending[:] = rest
                message = json.loads(raw)
                if message.get('id') == request_id:
                    if 'error' in message:
                        raise RuntimeError('Codex request failed')
                    return message['result']
            if selector.select(timeout=min(1, max(0, deadline - time.monotonic()))):
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError('Codex exited')
                pending.extend(chunk)
                if len(pending) > 4 * 1024 * 1024:
                    raise RuntimeError('Response too large')
        raise TimeoutError('Codex response timed out')

    try:
        send({'id': 1, 'method': 'initialize', 'params': {
            'clientInfo': {'name': 'codex_reset_widget', 'version': '1.0'},
            'capabilities': {'experimentalApi': True}}})
        response(1)
        send({'method': 'initialized'})
        send({'id': 2, 'method': 'account/rateLimits/read', 'params': None})
        return response(2)
    finally:
        selector.close()
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        process.stdin.close()
        process.stdout.close()


def iso(epoch):
    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).isoformat().replace('+00:00', 'Z')


def credit_snapshot(account):
    credits = account.get('rateLimitResetCredits')
    if not isinstance(credits, dict):
        raise ValueError('Credit metadata unavailable')
    count = credits.get('availableCount')
    if type(count) is not int or count < 0:
        raise ValueError('Invalid credit count')
    expirations = []
    for credit in credits.get('credits', []):
        if credit.get('status') == 'available' and isinstance(credit.get('expiresAt'), (int, float)):
            expirations.append(iso(credit['expiresAt']))
    # Persist only display fields: no account ID, credit ID, tokens or conversation data.
    return {'availableCount': count, 'expirations': sorted(expirations),
            'fetchedAt': iso(time.time()), 'error': None}


def account_snapshot(account):
    snapshot = credit_snapshot(account)
    limits_by_id = account.get('rateLimitsByLimitId')
    limits = limits_by_id.get('codex') if isinstance(limits_by_id, dict) else None
    if limits is None:
        legacy = account.get('rateLimits')
        if isinstance(legacy, dict) and legacy.get('limitId') in (None, 'codex'):
            limits = legacy
    snapshot['usage'] = None
    if isinstance(limits, dict):
        for slot in ['primary', 'secondary']:
            window = limits.get(slot)
            if not isinstance(window, dict) or window.get('windowDurationMins') != 10080:
                continue
            used, reset = window.get('usedPercent'), window.get('resetsAt')
            if type(used) in (int, float) and 0 <= used <= 100 and type(reset) in (int, float) and reset > 0:
                snapshot['usage'] = {'usedPercent': used, 'resetAt': iso(reset),
                                     'recordedAt': snapshot['fetchedAt'], 'source': 'codexAccount'}
                break
    snapshot['attemptedAt'] = snapshot['fetchedAt']
    return snapshot


def write_atomic(path, value):
    descriptor, temporary = tempfile.mkstemp(prefix='.reset-credits-', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w') as output:
            json.dump(value, output, ensure_ascii=False)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--codex')
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.with_suffix('.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        try:
            snapshot = account_snapshot(read_account(args.codex or find_codex()))
        except Exception:
            try:
                snapshot = json.loads(args.output.read_text())
            except (OSError, ValueError):
                snapshot = {'availableCount': None, 'expirations': [], 'fetchedAt': None}
            snapshot['error'] = 'Codex 账号同步失败'
            snapshot['attemptedAt'] = iso(time.time())
        write_atomic(args.output, snapshot)


if __name__ == '__main__':
    main()
