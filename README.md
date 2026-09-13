# Berzerk — Analogue Pocket

An Analogue Pocket port of **Berzerk** (Stern, 1980) and its sequel
**Frenzy** (Stern, 1982), built on the openFPGA framework.

## The Games

**Berzerk** drops you into an endless maze of electrified walls patrolled by
hostile robots and asks one thing: get out alive. Shoot, dodge, flee room to
room — but linger and **Evil Otto**, an indestructible bouncing smiley, comes
to hurry you along. Touch a wall, take a shot, or let Otto reach you, and
that's it.

It was one of the first games to talk. The robots taunt you out loud, and in
1980 that was startling enough to be the reason people queued up.

**Frenzy** is the 1982 sequel on the same board. The walls are destructible
now, your shots ricochet, and Otto has company.

## Hardware

Stern dedicated board:

| Part | Role |
|---|---|
| Zilog Z80 | CPU |
| S14001A | Speech synthesis |
| Custom audio | Sound effects (timer + noise) |
| Display | Horizontal CRT, RGB (1bpp + intensity), 256×224 |

There's no tile or sprite hardware. The picture is drawn into a 1-bit buffer
with a separate colour map, which is why the palette looks so bold and flat.

## The Port

Built on the MiSTer **Arcade-Berzerk** core. Dar's `berzerk.vhd` runs intact;
everything around it is the shell that adapts it to openFPGA / APF at the
game's native 15 kHz timing.

Frenzy is not in the MiSTer core — it's added here. It runs the same board, so
the only thing that needed changing was the CPU memory map: Frenzy's program
is a contiguous 16K with no RAM hole, it has an extra ROM at `c000`, and its
NVRAM sits at `f800` instead of `0800`. Video, colour RAM, speech, sound and
I/O are untouched, which matches how MAME treats the two.

The core works out which game it has from the size of the image you load, so
there's no variant byte to get wrong and nothing to set by hand.

## Controls

| Pocket | Action |
|---|---|
| **D-Pad** | Move (8-way) |
| **A / B / X / Y** | Fire |
| **Start** | 1P Start (2P Start on controller 2) |
| **Select** | Insert coin |

These are remappable from the Pocket's own Controls screen. One trade-off
comes with that: openFPGA won't accept named buttons and the analog-stick
mapping in the same file, so a docked controller's left stick no longer acts
as a d-pad. Its actual d-pad still works.

## Versions

Seven sets run off the one core, picked from the ROM slot:

| Set | |
|---|---|
| `berzerk` | Revision RC31A |
| `berzerka` | Revision RC31 |
| `berzerkb` | Revision RC28 |
| `berzerkf` | French speech |
| `berzerkg` | German speech |
| `berzerks` | Spanish speech |
| `frenzy` | Frenzy (RA1) |

The three language sets swap the voice ROMs as well as the program, so the
robots taunt you in French, German or Spanish.

## ROMs

ROMs are **not** included — nothing in this repo contains copyrighted data.
Supply your own MAME romsets and build the images into
`dist/Assets/berzerk/common/` either way:

- **`.mra` recipe** — one per set in that folder. Run it through the standard
  `mra` tool, e.g. `mra berzerkg.mra`.
- **`pack_rom.py`** — drop the romset zips beside the script and run
  `python pack_rom.py berzerkg`, one set per run.

Both match files by CRC32 and produce byte-identical images.

The five Berzerk variants are split clones, so keep the parent `berzerk.zip`
alongside the clone zip when building them. Frenzy is self-contained. Note the
parent set wants the **rc31a** revision of `rom5.5c` (CRC `e0fab8f5`).

Keep the `.rom` files in that folder and on your SD card — they land at
`Assets/berzerk/common/` on the card.

## Notes

On power-up the game runs the original hardware self-test, so the screen is
briefly blank before play starts. That's authentic and left as-is.

High scores don't survive a power cycle. The NVRAM is plain RAM here, on both
games.

## Credits

- **Original arcade games:** Stern Electronics (1980, 1982)
- **FPGA arcade core:** Dar — [darfpga](https://darfpga.blogspot.fr)
- **S14001A speech emulation:** Jonathan Gevaryahu, R. Belmont (via MAME),
  VHDL conversion by Dar
- **MiSTer integration:** the MiSTer-devel project
- **Analogue Pocket port:** [HarpMudd](https://github.com/harpmudd)
- **Z80 CPU core (T80):**
  - **[Daniel Wallner](https://opencores.org/projects/t80)** — original author (2001–2002, OpenCores)
  - **Mike Johnson / [MikeJ](https://www.fpgaarcade.com)** (FPGAArcade) — DJNZ M1_n fix, clock enable, IM 2 fix
    and interrupt-ack fix (v0232–0240); project tidy-up, March 2005 (Ver 300)
  - **[Sean Riddle](http://seanriddle.com)** — parity flag for 8080 vs Z80 (Ver 301)
  - **[TobiFlex](https://github.com/TobiFlex)** — undocumented DDCB / FDCB opcodes (Ver 303, 20 April 2010)
  - **Alexey Melnikov ([Sorgelig](https://github.com/Sorgelig))** — timing accuracy and ZEXDOC / ZEXALL /
    Z80Full / Z80memptr verification (Ver 350, 2018), and the `T80pa`
    pseudo-asynchronous top level
- **SDRAM controller, data loader, I2S audio, sync FIFO:** Adam Gastineau ([agg23](https://github.com/agg23))
- **openFPGA framework (APF), bridge command handler, reference `core_top`:** [Analogue](https://www.analogue.co)
- **PLL and other megafunctions:** Intel/Altera (Quartus-generated)

## About / Support

I'm into retro games and the Analogue Pocket, always cooking up something new.
I love being part of a community built on sharing and the love of games — so if
any of my projects bring you joy, chip in below; it fuels the next thing.

💛 **[Support this project via PayPal](https://www.paypal.com/donate/?hosted_button_id=S22WV924XU2ME)**
