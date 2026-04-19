import json, os

idx = json.load(open('data/archive-replicator/path_index.json'))
mapped = set()
for k, v in idx.items():
    if isinstance(v, dict) and 'hash' in v:
        mapped.add(v['hash'])

# Look at the large unmapped files (5MB+)
large = []
for f in os.scandir('data/archive-replicator/blobs/data'):
    if f.is_file():
        h = f.name.replace('.data', '')
        if h not in mapped:
            sz = f.stat().st_size
            if sz >= 5242880:
                large.append((sz, f.path, h))

large.sort(reverse=True)
print(f"Large unmapped files (>5MB): {len(large)}")
print()

# Read first 256 bytes of top 5 to identify content
for sz, path, h in large[:5]:
    with open(path, 'rb') as fh:
        header = fh.read(256)
    # Check for known file signatures
    sig = ''
    if header[:4] == b'PAR1':
        sig = 'PARQUET'
    elif header[:1] == b'{':
        sig = 'JSON'
    elif header[:4] == b'\x89PNG':
        sig = 'PNG'
    elif header[:3] == b'PK\x03':
        sig = 'ZIP'
    elif header[:8] == b'\x00\x00\x00\x00\x00\x00\x00\x00':
        sig = 'ZEROS/EMPTY'
    else:
        sig = f'UNKNOWN (first 16 bytes: {header[:16].hex()})'
    print(f"{sz/1048576:8.1f} MB  {h[:20]}...  {sig}")
    print(f"           Header: {header[:64].hex()}")
    print()

# Also check the tiny files (<1KB)
print("--- Sample tiny files (<1KB) ---")
tiny_count = 0
for f in os.scandir('data/archive-replicator/blobs/data'):
    if f.is_file() and f.stat().st_size < 1024:
        h = f.name.replace('.data', '')
        if h not in mapped:
            with open(f.path, 'rb') as fh:
                content = fh.read()
            if tiny_count < 5:
                try:
                    text = content.decode('utf-8', errors='replace')
                    print(f"  {len(content):>5} bytes  {h[:20]}...  {text[:100]}")
                except:
                    print(f"  {len(content):>5} bytes  {h[:20]}...  (binary: {content[:32].hex()})")
            tiny_count += 1

print(f"\nTotal tiny unmapped files: {tiny_count}")
