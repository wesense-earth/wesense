import json, os

idx = json.load(open('data/archive-replicator/path_index.json'))
mapped = set()
for k, v in idx.items():
    if isinstance(v, dict) and 'hash' in v:
        mapped.add(v['hash'])

# Check unmapped files - size distribution and samples
sizes = []
samples = []
for f in os.scandir('data/archive-replicator/blobs/data'):
    if f.is_file():
        h = f.name.replace('.data', '')
        if h not in mapped:
            sz = f.stat().st_size
            sizes.append(sz)
            if len(samples) < 10:
                samples.append((sz, f.name))

sizes.sort(reverse=True)
print(f"Unmapped files: {len(sizes)}")
print(f"Total size: {sum(sizes)/1073741824:.2f} GB")
print(f"Largest: {sizes[0]/1048576:.1f} MB")
print(f"Smallest: {sizes[-1]/1024:.1f} KB")
print(f"Median: {sizes[len(sizes)//2]/1024:.1f} KB")
print()

# Size buckets
buckets = {'<1KB': 0, '1-10KB': 0, '10-100KB': 0,
           '100KB-1MB': 0, '1-5MB': 0, '5-12MB': 0, '>12MB': 0}
bsz = {'<1KB': 0, '1-10KB': 0, '10-100KB': 0,
        '100KB-1MB': 0, '1-5MB': 0, '5-12MB': 0, '>12MB': 0}
for s in sizes:
    if s < 1024: b = '<1KB'
    elif s < 10240: b = '1-10KB'
    elif s < 102400: b = '10-100KB'
    elif s < 1048576: b = '100KB-1MB'
    elif s < 5242880: b = '1-5MB'
    elif s < 12582912: b = '5-12MB'
    else: b = '>12MB'
    buckets[b] += 1
    bsz[b] += s

print(f"{'BUCKET':>12} {'COUNT':>7} {'SIZE':>10}")
for b in ['<1KB','1-10KB','10-100KB','100KB-1MB','1-5MB','5-12MB','>12MB']:
    if buckets[b] > 0:
        print(f"{b:>12} {buckets[b]:>7} {bsz[b]/1073741824:>8.2f} GB")
