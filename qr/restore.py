#!/usr/bin/env python3
# Dung lai file tu cac note QR da dan. Chay trong thu muc chua *.txt:
#   python3 restore.py
# Tu sort chunk, bo trung, phat hien thieu, verify sha256. Thu tu dan khong quan trong.
import base64, bz2, hashlib, io, re, sys, tarfile
from pathlib import Path

H = re.compile(r"RD(32|64)\|([^|]+)\|(\d+)\|(\d+)\|([0-9a-f]{8})\|(\d+)\|")
g = {}
for f in sorted(Path(".").glob("*.txt")):
    t = re.sub(r"\s", "", f.read_text(errors="replace"))
    ms = list(H.finditer(t))
    if not ms:
        print(f"{f}: khong co header RD - bo qua")
    for m in ms:
        # Lay DUNG so ky tu header khai bao. App quet QR hay chen thu nhu
        # "Scanned QR code" quanh payload; cat theo do dai thi rac roi ra ngoai.
        enc, name, i, n, sha, ln = (m.group(1), m.group(2), int(m.group(3)),
                                    int(m.group(4)), m.group(5), int(m.group(6)))
        body = t[m.end():m.end() + ln]
        if len(body) != ln:
            print(f"{name} ma {i}: bi cat ngan, co {len(body)}/{ln} ky tu")
            continue
        g.setdefault((name, n, sha, enc), {})[i] = body

if not g:
    sys.exit("khong tim thay chunk nao trong *.txt")

bad = 0
for (name, n, sha, enc), parts in sorted(g.items()):
    if len(parts) != n:
        miss = sorted(set(range(1, n + 1)) - set(parts))
        print(f"{name}: co {len(parts)}/{n} ma, THIEU {miss}")
        bad = 1
        continue
    s = "".join(parts[i] for i in range(1, n + 1))
    try:
        if enc == "32":
            s = s.upper()
            d = base64.b32decode(s + "=" * (-len(s) % 8))
        else:
            d = base64.b64decode(s)
        raw = bz2.decompress(d)
    except Exception as e:
        print(f"{name}: DECODE LOI - {e}")
        bad = 1
        continue
    got = hashlib.sha256(raw).hexdigest()[:8]
    if got != sha:
        print(f"{name}: SHA LECH - {got} khac {sha}")
        bad = 1
        continue
    if ".tar" in name:
        with tarfile.open(fileobj=io.BytesIO(raw)) as tf:
            out = tf.getnames()
            try:
                tf.extractall(".", filter="data")
            except TypeError:
                tf.extractall(".")
        print(f"{name} OK ({len(raw)} byte) - giai ra {len(out)} file:")
        for x in out:
            print("   ", x)
    else:
        p = Path(name)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(raw)
        print(f"{name} OK ({len(raw)} byte)")
sys.exit(bad)