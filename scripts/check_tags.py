"""Check which blobs are tagged vs untagged in the iroh blob store.
Tagged blobs are protected from GC. Untagged blobs will be cleaned up.

Run from the wesense directory:
    python3 scripts/check_tags.py
"""
import json
import os

# Load path index to know which hashes are our archives
idx = json.load(open('data/archive-replicator/path_index.json'))
archive_hashes = set()
for k, v in idx.items():
    if isinstance(v, dict) and 'hash' in v:
        archive_hashes.add(v['hash'])

print(f"Path index entries: {len(idx)}")
print(f"Unique archive hashes: {len(archive_hashes)}")
print()

# Count blobs that are in the path index vs not
mapped_size = 0
mapped_count = 0
unmapped_size = 0
unmapped_count = 0

for f in os.scandir('data/archive-replicator/blobs/data'):
    if f.is_file():
        h = f.name.replace('.data', '')
        sz = f.stat().st_size
        if h in archive_hashes:
            mapped_count += 1
            mapped_size += sz
        else:
            unmapped_count += 1
            unmapped_size += sz

print(f"Mapped (in path index - your archive data):")
print(f"  {mapped_count} files, {mapped_size/1073741824:.2f} GB")
print()
print(f"Unmapped (NOT in path index - should be cleaned by GC):")
print(f"  {unmapped_count} files, {unmapped_size/1073741824:.2f} GB")
print()
print(f"If GC works correctly, you should reclaim ~{unmapped_size/1073741824:.1f} GB")
