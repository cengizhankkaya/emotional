"""Checks database.rules.json against the Realtime Database emulator.

Run from the repository root:

    firebase emulators:exec --only database --project demo-test \
        "python3 tool/database_rules_test.py"

Each case writes or reads as a given user (auth_variable_override), the way
the app and older app versions still in the stores do.
"""
import json
import sys
import urllib.parse
import urllib.request

BASE="http://127.0.0.1:9123"; NS="demo-test-default-rtdb"
def req(method, path, uid, body=None):
    q={"ns":NS}
    if uid: q["auth_variable_override"]=json.dumps({"uid":uid})
    url=f"{BASE}/{path}.json?"+urllib.parse.urlencode(q)
    data=None if body is None else json.dumps(body).encode()
    r=urllib.request.Request(url,data=data,method=method,headers={"Authorization":"Bearer owner"})
    try:
        with urllib.request.urlopen(r) as resp: return resp.status
    except urllib.error.HTTPError as e: return e.code
fails=0
def expect(name, ok, status):
    global fails
    good=(status==200)==ok
    if not good: fails+=1
    print(("PASS" if good else "FAIL"), name, status)
room={"createdAt":1,"host":"alice","users":{"alice":"Alice"},"status":"waiting"}
expect("alice clears own signal before room exists", True, req("DELETE","rooms/111111/signal/alice","alice"))
expect("alice creates room", True, req("PUT","rooms/111111","alice",room))
expect("bob cannot overwrite existing room on create", False, req("PUT","rooms/111111","bob",{**room,"host":"bob","users":{"bob":"Bob"}}))
expect("bob reads host", True, req("GET","rooms/111111/host","bob"))
expect("bob joins (own user entry)", True, req("PUT","rooms/111111/users/bob","bob","Bob"))
expect("eve cannot hijack room by adding herself", False, req("PUT","rooms/111111","eve",{"host":"eve","users":{"eve":"Eve"}}))
expect("eve cannot write messages", False, req("PUT","rooms/111111/messages/m1","eve",{"senderId":"eve","text":"x"}))
expect("bob cannot impersonate alice", False, req("PUT","rooms/111111/messages/m2","bob",{"senderId":"alice","text":"x"}))
expect("bob sends own message", True, req("PUT","rooms/111111/messages/m3","bob",{"senderId":"bob","text":"hi"}))
expect("bob sends offer to alice", True, req("PUT","rooms/111111/signal/alice/offers/bob","bob",{"sdp":"x","type":"offer"}))
expect("eve cannot forge bob's offer", False, req("PUT","rooms/111111/signal/alice/offers/bob","eve",{"sdp":"x"}))
expect("alice clears bye from bob in own inbox", True, req("DELETE","rooms/111111/signal/alice/bye/bob","alice"))
expect("bob updates videoState", True, req("PATCH","rooms/111111/videoState","bob",{"isPlaying":True}))
expect("eve cannot update videoState", False, req("PATCH","rooms/111111/videoState","eve",{"isPlaying":False}))
expect("eve writes own usersState", True, req("PATCH","rooms/111111/usersState/eve","eve",{"video":True}))
expect("eve cannot create ghost room via users", False, req("PUT","rooms/999999/users/eve","eve","Eve"))
expect("name over 100 chars rejected", False, req("PUT","rooms/111111/users/carol","carol","x"*101))
expect("old-client join fallback (PATCH users)", True, req("PATCH","rooms/111111/users","carol",{"carol":"Carol"}))
expect("member reassigns host", True, req("PATCH","rooms/111111","bob",{"host":"bob"}))
expect("old-client leave transaction (member rewrites room)", True, req("PUT","rooms/111111","alice",{"createdAt":1,"host":"bob","users":{"bob":"Bob","carol":"Carol"},"messages":{"m3":{"senderId":"bob","text":"hi"}}}))
expect("alice (left) onDisconnect-style self remove", True, req("DELETE","rooms/111111/users/alice","alice"))
expect("report create", True, req("PUT","reports/r1","bob",{"reporterUserId":"bob"}))
expect("report overwrite denied", False, req("PUT","reports/r1","bob",{"reporterUserId":"bob","x":1}))
expect("last member deletes room", True, req("DELETE","rooms/111111","bob"))
sys.exit(1 if fails else 0)
