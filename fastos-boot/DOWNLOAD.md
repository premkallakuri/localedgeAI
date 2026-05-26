# DGX SPARK FASTOS — large image download

The split OS image exceeds GitHub's file-size limits. **`fastos.partaa` (3.8 GB) is not stored in this repository.**

## Image parts

| File | Size | In repo | SHA-256 |
|------|------|---------|---------|
| `fastos.partaa` | 3.8 GB | **No — host separately** | `b158e2a9ce7842a942eb39d5a25de924dc63423c7175f2dad1b898e39f244ad9` |
| `fastos.partab` | 1.6 GB | Yes (Git LFS) | `b7f4f40a8c1d4d0fba1d1570ebf67b9e5b608f1b6886bbc3ab4d220bdfce478b` |

## Reassemble

Place both parts in the same directory, then:

```bash
cat fastos.partaa fastos.partab > fastos.img.xz
xz -d fastos.img.xz   # if compressed as xz stream
```

Release metadata: see `fastos-release.txt` (DGX SPARK FASTOS 1.120.36).

## Boot layout

Disk partitioning example: `sgdisk.txt.example`

Boot artifacts in this folder: `boot/`, `efi/`, `fw/`, `vmlinuz`, `initrd`, `efi.tar.xz`.
