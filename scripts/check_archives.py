import json, os, collections

idx = json.load(open('data/archive-replicator/path_index.json'))

# Check the format of the first entry
first_key = next(iter(idx))
first_val = idx[first_key]
print(f"Sample entry: {first_key} -> {first_val}")
print(f"Value type: {type(first_val)}")
print()

# Build reverse map based on actual format
rev = {}
for k, v in idx.items():
    if isinstance(v, str):
        rev[v] = k
    elif isinstance(v, dict) and 'hash' in v:
        rev[v['hash']] = k
    elif isinstance(v, dict):
        # Try first string value
        for val in v.values():
            if isinstance(val, str):
                rev[val] = k
                break

cs = collections.Counter()
cc = collections.Counter()
unmapped = 0
for f in os.scandir('data/archive-replicator/blobs/data'):
    if f.is_file():
        h = f.name.replace('.data', '')
        p = rev.get(h, None)
        if p is None:
            unmapped += 1
            c = '_unmapped'
        else:
            c = p.split('/')[0]
        cs[c] += f.stat().st_size
        cc[c] += 1

print(f"{'COUNTRY':>10} {'FILES':>7} {'SIZE':>10}")
for c, sz in cs.most_common(25):
    print(f"{c.upper():>10} {cc[c]:>7} {sz/1073741824:>8.2f} GB")

t = sum(cs.values())
r = len(cs) - 25
print(f"{'TOTAL':>10} {sum(cc.values()):>7} {t/1073741824:>8.2f} GB")
if r > 0:
    x = t - sum(s for _, s in cs.most_common(25))
    print(f"  + {r} more countries: {x/1073741824:.2f} GB")
if unmapped > 0:
    print(f"\n{unmapped} files not in path index (iroh internal or orphaned)")
