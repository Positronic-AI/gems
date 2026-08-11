#!/usr/bin/env python3
"""Publish the release AAB to Google Play production.

Usage: python3 scripts/publish-play.py "<release notes, <=500 chars>"

Needs ~/.config/lit-play/play-publisher.json (service account) and a built
build/app/outputs/bundle/release/app-release.aab. Notes hard-cap at 500
chars — the API 403s above that (learned on 1.3.0).
"""
import json, os, sys, subprocess

PACKAGE = "ai.positronic.gem_game"
KEY = os.path.expanduser("~/.config/lit-play/play-publisher.json")
AAB = "build/app/outputs/bundle/release/app-release.aab"

notes = sys.argv[1] if len(sys.argv) > 1 else ""
if len(notes) > 500:
    sys.exit(f"Release notes are {len(notes)} chars — Play caps at 500.")

from google.oauth2 import service_account
from google.auth.transport.requests import Request as GRequest
import urllib.request

creds = service_account.Credentials.from_service_account_file(
    KEY, scopes=["https://www.googleapis.com/auth/androidpublisher"])
creds.refresh(GRequest())
tok = creds.token
base = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"

def call(method, url, data=None, ctype="application/json"):
    req = urllib.request.Request(url, method=method,
        headers={"Authorization": f"Bearer {tok}", "Content-Type": ctype},
        data=data)
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.loads(r.read() or b"{}")

edit = call("POST", f"{base}/edits")["id"]
print("edit:", edit)

with open(AAB, "rb") as f:
    up = call("POST",
        f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}/edits/{edit}/bundles",
        data=f.read(), ctype="application/octet-stream")
ver = up["versionCode"]
print("uploaded versionCode:", ver)

call("PUT", f"{base}/edits/{edit}/tracks/production", data=json.dumps({
    "track": "production",
    "releases": [{
        "versionCodes": [str(ver)],
        "status": "completed",
        "releaseNotes": [{"language": "en-US", "text": notes}] if notes else [],
    }],
}).encode())
print("production track set")

done = call("POST", f"{base}/edits/{edit}:commit")
print("COMMITTED:", done.get("id"))
