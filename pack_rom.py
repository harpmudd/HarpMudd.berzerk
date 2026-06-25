"""
pack_rom.py — Build a flat ROM image for the HarpMudd Berzerk Pocket core.

Berzerk (Stern, 1980). Single game, dedicated entity (Dar/darfpga core via
MiSTer Arcade-Berzerk). Single Z80; Votrax SC-01 speech is in berzerk_speech.

Usage:
  python pack_rom.py [berzerk]

ROM image layout (0x6000 bytes, byte offset = dn_addr in FPGA). The berzerk
entity demuxes dn_addr internally; the byte image must match the .mra exactly,
including the load-bearing repeats (the entity's partial address decode reads
the repeated copies — same idea as bombjack's doubled 4K pages):
  0x0000  rom1.1d   2K  program
  0x0800  rom2.3d   2K  program
  0x1000  rom3.5d   2K  program
  0x1800  rom4.6d   2K  program
  0x2000  rom5.5c   2K  program  (repeated x4 -> 0x2000/2800/3000/3800)
  0x4000  rom0.1c   2K  program  (repeated x2 -> 0x4000/4800)
  0x5000  r_vo_1c   2K  speech voice data
  0x5800  r_vo_2c   2K  speech voice data
Image ends at 0x6000 exactly — no padding.
"""

import sys
import zipfile
import zlib
import os

DEFAULT_ZIP_DIR = r"C:\Projects\Downloaded_Artifacts"
ASSETS_DIR      = r"C:\Projects\HarpMudd.berzerk\dist\Assets\berzerk\common"

ROM_IMAGE_SIZE = 0x6000

# (CRC32, expected_size, description, rom_image_offset, mirror_offset_or_None)
BERZERK_ROM_DEFS = [
    (0x7ba69fde, 0x800, "rom1.1d  (program)",        0x0000, None),
    (0xa1d5248b, 0x800, "rom2.3d  (program)",        0x0800, None),
    (0xfcaefa95, 0x800, "rom3.5d  (program)",        0x1000, None),
    (0x1e35b9a0, 0x800, "rom4.6d  (program)",        0x1800, None),
    (0xe0fab8f5, 0x800, "rom5.5c  (program, copy 1)",0x2000, None),
    (0xe0fab8f5, 0x800, "rom5.5c  (program, copy 2)",0x2800, None),
    (0xe0fab8f5, 0x800, "rom5.5c  (program, copy 3)",0x3000, None),
    (0xe0fab8f5, 0x800, "rom5.5c  (program, copy 4)",0x3800, None),
    (0xca566dbc, 0x800, "rom0.1c  (program, copy 1)",0x4000, None),
    (0xca566dbc, 0x800, "rom0.1c  (program, copy 2)",0x4800, None),
    (0x2cfe825d, 0x800, "r_vo_1c  (speech voice)",   0x5000, None),
    (0xd2b6324e, 0x800, "r_vo_2c  (speech voice)",   0x5800, None),
]

#          rom_defs           out_name       description
GAMES = {
    "berzerk": (BERZERK_ROM_DEFS, "berzerk.rom", "Berzerk (Stern, 1980)"),
}


def crc32_of(data):
    return zlib.crc32(data) & 0xFFFFFFFF


def load_zip_by_crc(zip_path):
    found = {}
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            data = zf.read(info.filename)
            found[crc32_of(data)] = data
    return found


def load_dir_by_crc(zip_dir):
    found = {}
    zips = sorted(f for f in os.listdir(zip_dir) if f.lower().endswith('.zip'))
    if not zips:
        print(f"  (no zip files found in {zip_dir})")
        return found
    for zname in zips:
        print(f"  scanning {zname}")
        try:
            found.update(load_zip_by_crc(os.path.join(zip_dir, zname)))
        except Exception as e:
            print(f"  WARNING: could not read {zname}: {e}")
    return found


def main():
    game = sys.argv[1].lower() if len(sys.argv) > 1 else "berzerk"
    if game not in GAMES:
        print(f"ERROR: unknown game '{game}'. Choose: {', '.join(GAMES)}")
        sys.exit(1)

    rom_defs, out_name, desc = GAMES[game]
    out_path = os.path.join(ASSETS_DIR, out_name)

    print(f"ROM packer — {desc}")
    print(f"Output: {out_path}\n")
    print(f"Scanning all zips in: {DEFAULT_ZIP_DIR}")
    found = load_dir_by_crc(DEFAULT_ZIP_DIR)
    print()

    image = bytearray(ROM_IMAGE_SIZE)
    errors = []

    for (crc, size, d, offset, mirror) in rom_defs:
        if crc in found:
            data = found[crc]
            if len(data) != size:
                errors.append(f"  WRONG SIZE  {d}: expected {size}, got {len(data)}")
                continue
            image[offset:offset + size] = data
            if mirror is not None:
                image[mirror:mirror + size] = data
            print(f"  OK          {d}  @ 0x{offset:05X}")
        else:
            errors.append(f"  MISSING     {d}  (CRC {crc:08x})")

    print()
    if errors:
        print("MISSING OR INVALID ROMs:")
        for e in errors:
            print(e)
        sys.exit(1)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(image)

    print(f"\nSUCCESS: wrote {len(image)} bytes -> {out_path}")


if __name__ == "__main__":
    main()
