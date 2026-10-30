#!/usr/bin/env python3
import sys, json, hashlib
from cryptography.hazmat.primitives.serialization import load_pem_private_key
priv=load_pem_private_key(open(sys.argv[1],'rb').read(),password=None)   # TEST AA key
content=sys.argv[2]; out=sys.argv[3]
h='sha256:'+hashlib.sha256(open(content,'rb').read().replace(b'\r\n',b'\n')).hexdigest()
stmt={"schema":"blogpub/approval/v1","slug":sys.argv[4],"id":sys.argv[5],
 "contentHash":h,"author":"Ryan Phelan","publish_time":sys.argv[6],
 "approved_at":sys.argv[7],"nonce":sys.argv[8]}
msg=json.dumps(stmt,sort_keys=True,separators=(',',':')).encode()
stmt["sig"]=priv.sign(msg).hex()
open(out,'w').write(json.dumps(stmt,indent=2))
print("wrote",out)
