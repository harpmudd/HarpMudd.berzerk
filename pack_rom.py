"""
pack_rom.py — Build a flat ROM image for the HarpMudd Berzerk Pocket core.

Berzerk (Stern, 1980). Single game, dedicated entity (Dar/darfpga core via
MiSTer Arcade-Berzerk). Single Z80; Votrax SC-01 speech is in berzerk_speech.

Usage:
  python pack_rom.py [berzerk]

ROM image layout (0x6000 bytes, byte offset = dn_addr in FPGA). The berzerk
entity demuxes dn_addr internally; the byte image must match the .mra exactly,
including the repeated copies — the entity decodes only part of the address,
so it genuinely reads them:
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

HERE = os.path.dirname(os.path.abspath(__file__))
# MAME romset .zip files. No machine-specific path is committed: set the
# HARPMUDD_ROMS env var, drop the .zip files next to this script, or keep a
# "Downloaded_Artifacts" folder beside the repo (dev convention).
DEFAULT_ZIP_DIR = next(
    (d for d in (os.environ.get("HARPMUDD_ROMS"),
                 os.path.join(os.path.dirname(HERE), "Downloaded_Artifacts"))
     if d and os.path.isdir(d)),
    HERE)
ASSETS_DIR      = os.path.join(HERE, "dist", "Assets", "berzerk", "common")

ROM_IMAGE_SIZE    = 0x6000       # Berzerk and its variants
FRENZY_IMAGE_SIZE = 0x9000       # 16K program + c000 ROM (x4) + 4K speech

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

BERZERKA_ROM_DEFS = [
    (0x7ba69fde, 0x800, "berzerk_rc31_1d.rom1.1d", 0x0000, None),
    (0xa1d5248b, 0x800, "berzerk_rc31_3d.rom2.3d", 0x0800, None),
    (0xfcaefa95, 0x800, "berzerk_rc31_5d.rom3.5d", 0x1000, None),
    (0x1e35b9a0, 0x800, "berzerk_rc31_6d.rom4.6d", 0x1800, None),
    (0xc8c665e5, 0x800, "berzerk_rc31_5c.rom5.5c  (copy 1)", 0x2000, None),
    (0xc8c665e5, 0x800, "berzerk_rc31_5c.rom5.5c  (copy 2)", 0x2800, None),
    (0xc8c665e5, 0x800, "berzerk_rc31_5c.rom5.5c  (copy 3)", 0x3000, None),
    (0xc8c665e5, 0x800, "berzerk_rc31_5c.rom5.5c  (copy 4)", 0x3800, None),
    (0xca566dbc, 0x800, "berzerk_rc31_1c.rom0.1c  (copy 1)", 0x4000, None),
    (0xca566dbc, 0x800, "berzerk_rc31_1c.rom0.1c  (copy 2)", 0x4800, None),
    (0x2cfe825d, 0x800, "berzerk_r_vo_1c.1c", 0x5000, None),
    (0xd2b6324e, 0x800, "berzerk_r_vo_2c.2c", 0x5800, None),
]

BERZERKB_ROM_DEFS = [
    (0xe58c8678, 0x800, "berzerk_rc28_1d.rom1.1d", 0x0000, None),
    (0x705bb339, 0x800, "berzerk_rc28_3d.rom2.3d", 0x0800, None),
    (0x6a1936b4, 0x800, "berzerk_rc28_5d.rom3.5d", 0x1000, None),
    (0xfa5dce40, 0x800, "berzerk_rc28_6d.rom4.6d", 0x1800, None),
    (0x2579b9f4, 0x800, "berzerk_rc28_5c.rom5.5c  (copy 1)", 0x2000, None),
    (0x2579b9f4, 0x800, "berzerk_rc28_5c.rom5.5c  (copy 2)", 0x2800, None),
    (0x2579b9f4, 0x800, "berzerk_rc28_5c.rom5.5c  (copy 3)", 0x3000, None),
    (0x2579b9f4, 0x800, "berzerk_rc28_5c.rom5.5c  (copy 4)", 0x3800, None),
    (0x5b7eb77d, 0x800, "berzerk_rc28_1c.rom0.1c  (copy 1)", 0x4000, None),
    (0x5b7eb77d, 0x800, "berzerk_rc28_1c.rom0.1c  (copy 2)", 0x4800, None),
    (0x2cfe825d, 0x800, "berzerk_r_vo_1c.1c", 0x5000, None),
    (0xd2b6324e, 0x800, "berzerk_r_vo_2c.2c", 0x5800, None),
]

BERZERKF_ROM_DEFS = [
    (0xa1de2a3e, 0x800, "berzerk_rc31f_1d.rom1.1d", 0x0000, None),
    (0xbc31c478, 0x800, "berzerk_rc31f_3d.rom2.3d", 0x0800, None),
    (0x316192b5, 0x800, "berzerk_rc31f_5d.rom3.5d", 0x1000, None),
    (0xcd51238c, 0x800, "berzerk_rc31f_6d.rom4.6d", 0x1800, None),
    (0x563b13b6, 0x800, "berzerk_rc31f_5c.rom5.5c  (copy 1)", 0x2000, None),
    (0x563b13b6, 0x800, "berzerk_rc31f_5c.rom5.5c  (copy 2)", 0x2800, None),
    (0x563b13b6, 0x800, "berzerk_rc31f_5c.rom5.5c  (copy 3)", 0x3000, None),
    (0x563b13b6, 0x800, "berzerk_rc31f_5c.rom5.5c  (copy 4)", 0x3800, None),
    (0x3ba6e56e, 0x800, "berzerk_rc31f_1c.rom0.1c  (copy 1)", 0x4000, None),
    (0x3ba6e56e, 0x800, "berzerk_rc31f_1c.rom0.1c  (copy 2)", 0x4800, None),
    (0xd7bfaca2, 0x800, "berzerk_rvof_1c.1c", 0x5000, None),
    (0x7bdc3573, 0x800, "berzerk_rvof_2c.2c", 0x5800, None),
]

BERZERKG_ROM_DEFS = [
    (0x19bb3aac, 0x800, "berzerk_rc32_1d.rom1.1d", 0x0000, None),
    (0xb0888ff7, 0x800, "berzerk_rc32g_3d.rom2.3d", 0x0800, None),
    (0xe23239a9, 0x800, "berzerk_rc32_5d.rom3.5d", 0x1000, None),
    (0x651b31b7, 0x800, "berzerk_rc32g_6d.rom4.6d", 0x1800, None),
    (0x8a403bba, 0x800, "berzerk_rc32g_5c.rom5.5c  (copy 1)", 0x2000, None),
    (0x8a403bba, 0x800, "berzerk_rc32g_5c.rom5.5c  (copy 2)", 0x2800, None),
    (0x8a403bba, 0x800, "berzerk_rc32g_5c.rom5.5c  (copy 3)", 0x3000, None),
    (0x8a403bba, 0x800, "berzerk_rc32g_5c.rom5.5c  (copy 4)", 0x3800, None),
    (0x77923a9e, 0x800, "berzerk_rc32_1c.rom0.1c  (copy 1)", 0x4000, None),
    (0x77923a9e, 0x800, "berzerk_rc32_1c.rom0.1c  (copy 2)", 0x4800, None),
    (0xfc1da15f, 0x800, "berzerk_rvog_1c.1c", 0x5000, None),
    (0x7f6808fb, 0x800, "berzerk_rvog_2c.2c", 0x5800, None),
]

BERZERKS_ROM_DEFS = [
    (0x19bb3aac, 0x800, "berzerk_rc32_1d.rom1.1d", 0x0000, None),
    (0x5423ea87, 0x800, "berzerk_rc32_3d.rom2.3d", 0x0800, None),
    (0xe23239a9, 0x800, "berzerk_rc32_5d.rom3.5d", 0x1000, None),
    (0x959efd86, 0x800, "berzerk_rc32_6d.rom4.6d", 0x1800, None),
    (0x9ad80e4e, 0x800, "berzerk_rc32s_5c.rom5.5c  (copy 1)", 0x2000, None),
    (0x9ad80e4e, 0x800, "berzerk_rc32s_5c.rom5.5c  (copy 2)", 0x2800, None),
    (0x9ad80e4e, 0x800, "berzerk_rc32s_5c.rom5.5c  (copy 3)", 0x3000, None),
    (0x9ad80e4e, 0x800, "berzerk_rc32s_5c.rom5.5c  (copy 4)", 0x3800, None),
    (0x77923a9e, 0x800, "berzerk_rc32_1c.rom0.1c  (copy 1)", 0x4000, None),
    (0x77923a9e, 0x800, "berzerk_rc32_1c.rom0.1c  (copy 2)", 0x4800, None),
    (0x0b51409c, 0x800, "berzerk_rvos_1c.1c", 0x5000, None),
    (0x0b51409c, 0x800, "berzerk_rvos_1c.1c", 0x5800, None),
]

FRENZY_ROM_DEFS = [
    (0xabdd25b8, 0x1000, "frenzy_ra1_rom1.1d", 0x0000, None),
    (0x536e4ae8, 0x1000, "frenzy_ra1_rom2.3d", 0x1000, None),
    (0x3eb9bc9b, 0x1000, "frenzy_ra1_rom3.5d", 0x2000, None),
    (0xe1d3133c, 0x1000, "frenzy_ra1_rom4.6d", 0x3000, None),
    (0x5581a7b1, 0x1000, "frenzy_ra1_rom5.5c  (copy 1)", 0x4000, None),
    (0x5581a7b1, 0x1000, "frenzy_ra1_rom5.5c  (copy 2)", 0x5000, None),
    (0x5581a7b1, 0x1000, "frenzy_ra1_rom5.5c  (copy 3)", 0x6000, None),
    (0x5581a7b1, 0x1000, "frenzy_ra1_rom5.5c  (copy 4)", 0x7000, None),
    (0x2cfe825d, 0x800, "e169-1cvo.1c", 0x8000, None),
    (0xd2b6324e, 0x800, "e169-2cvo.2c", 0x8800, None),
]

# Frenzy is the SAME BOARD with a different memory map -- MAME's frenzy() is
# berzerk() with frenzy_map swapped in and nothing else changed. Its image is
# 0x9000: a contiguous 16K program, the c000-cfff ROM repeated x4 (the entity
# reads the repeats, same idea as berzerk's rom5), then the SAME two voice ROMs
# berzerk uses -- MAME loads them as e169-1cvo/2cvo with identical CRCs.

#          rom_defs           out_name       description                 image size
GAMES = {
    "berzerk":  (BERZERK_ROM_DEFS,  "berzerk.rom",  "Berzerk (revision RC31A)",       ROM_IMAGE_SIZE),
    "berzerka": (BERZERKA_ROM_DEFS, "berzerka.rom", "Berzerk (revision RC31)",        ROM_IMAGE_SIZE),
    "berzerkb": (BERZERKB_ROM_DEFS, "berzerkb.rom", "Berzerk (revision RC28)",        ROM_IMAGE_SIZE),
    "berzerkf": (BERZERKF_ROM_DEFS, "berzerkf.rom", "Berzerk (French Speech, revision RC31)",  ROM_IMAGE_SIZE),
    "berzerkg": (BERZERKG_ROM_DEFS, "berzerkg.rom", "Berzerk (German Speech, revision RC32)",  ROM_IMAGE_SIZE),
    "berzerks": (BERZERKS_ROM_DEFS, "berzerks.rom", "Berzerk (Spanish Speech, revision RC32)", ROM_IMAGE_SIZE),
    "frenzy":   (FRENZY_ROM_DEFS,   "frenzy.rom",   "Frenzy (revision RA1)",          FRENZY_IMAGE_SIZE),
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

    rom_defs, out_name, desc, image_size = GAMES[game]
    out_path = os.path.join(ASSETS_DIR, out_name)

    print(f"ROM packer — {desc}")
    print(f"Output: {out_path}\n")
    print(f"Scanning all zips in: {DEFAULT_ZIP_DIR}")
    found = load_dir_by_crc(DEFAULT_ZIP_DIR)
    print()

    image = bytearray(image_size)
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
