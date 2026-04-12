import json, os, collections

idx = json.load(open('data/archive-replicator/path_index.json'))
rev = {v: k for k, v in idx.items()}
cs = collections.Counter()
cc = collections.Counter()
for f in os.scandir('data/archive-replicator/blobs/data'):
    if f.is_file():
        h = f.name.replace('.data', '')
        p = rev.get(h, 'unknown/unknown')
        c = p.split('/')[0]
        cs[c] += f.stat().st_size
        cc[c] += 1

print(f"{'COUNTRY':>10} {'FILES':>7} {'SIZE':>10}")
for c, sz in cs.most_common(20):
    print(f"{c.upper():>10} {cc[c]:>7} {sz/1073741824:>8.2f} GB")

t = sum(cs.values())
r = len(cs) - 20
print(f"{'TOTAL':>10} {sum(cc.values()):>7} {t/1073741824:>8.2f} GB")
if r > 0:
    x = t - sum(s for _, s in cs.most_common(20))
    print(f"  + {r} more countries: {x/1073741824:.2f} GB")
