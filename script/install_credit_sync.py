#!/usr/bin/env python3
"""Install the opt-in, five-minute local reset-credit sync."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--sessions', type=Path, default=Path.home() / '.codex/sessions')
args = parser.parse_args()
if args.sessions.name != 'sessions' or not args.sessions.is_dir():
    raise SystemExit('Select an existing Codex sessions directory')
label = 'com.cherine.codex-reset.credit-sync'
support = Path.home() / 'Library/Application Support/CodexReset'
support.mkdir(parents=True, exist_ok=True)
worker = support / 'sync_reset_credits.py'
shutil.copyfile(Path(__file__).with_name('sync_reset_credits.py'), worker)
output = args.sessions.resolve() / 'codex-reset-credits.json'
plist = Path.home() / 'Library/LaunchAgents' / (label + '.plist')
plist.parent.mkdir(parents=True, exist_ok=True)
with plist.open('wb') as destination:
    plistlib.dump({'Label': label, 'ProgramArguments': [sys.executable, str(worker), '--output', str(output)],
                  'StartInterval': 300, 'RunAtLoad': True, 'ProcessType': 'Background'}, destination)
domain = 'gui/' + str(os.getuid())
subprocess.run(['launchctl', 'bootout', domain + '/' + label], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(['launchctl', 'bootstrap', domain, str(plist)], check=True)
print('Installed five-minute read-only reset-credit sync.')
