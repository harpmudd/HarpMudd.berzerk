# Berzerk (Stern, 1980) — Analogue Pocket

An Analogue Pocket port of **Berzerk** (Stern, 1980) by **HarpMudd**, built on
the openFPGA framework.

## The Game

Berzerk drops you into an endless maze of electrified walls patrolled by
hostile robots, and asks one thing: get out alive. You shoot, you dodge, you
flee room to room — but linger too long and **Evil Otto**, an indestructible
bouncing smiley, comes to hurry you along. Touch a wall, get shot, or let
Otto reach you and it's over.

It's a landmark for two reasons. It was one of the first games to use
**speech synthesis** — the robots taunt you out loud ("Intruder alert!",
"The humanoid must not escape!", "Chicken! Fight like a robot!") — and one of
the first with persistent score bookkeeping. Pure, tense, score-chasing
survival.

## Hardware

Stern dedicated board:

| Part | Role |
|---|---|
| Zilog Z80 | CPU |
| S14001A | Speech synthesis |
| Custom audio | Sound effects (timer + noise) |
| Display | Horizontal CRT, RGB (1bpp + intensity), 256×224 |

Berzerk has no tile or sprite hardware — the picture is drawn into a 1-bit
video buffer with a separate color map, which is why the palette is bold and
flat.

## The Port

Built on the MiSTer **Arcade-Berzerk** core:

- **FPGA arcade hardware implementation:** Dar (darfpga) — including the
  S14001A speech (MAME emulation by Jonathan Gevaryahu "Lord Nightmare" /
  R. Belmont, VHDL conversion by Dar) and the T80 Z80 core by Daniel Wallner
- **MiSTer integration:** the MiSTer-devel project

This Analogue Pocket build adapts that RTL to the openFPGA / APF framework at
the game's native 15 kHz timing (256×224). Many thanks to the authors above.

## Controls

| Pocket | Action |
|---|---|
| **D-Pad** | Move (8-way) |
| **Any face button** | Fire |
| **Start** | 1P Start (2P Start on controller 2) |
| **Select** | Insert coin |

## Notes & Caveats

On power-up the game runs its original hardware self-test (a brief blank
screen) before play begins — this is authentic Berzerk behavior, preserved
as-is.

## ROMs

ROMs are **not** included. Build your own from the bundled `.mra` recipe in
`Assets/berzerk/common/` — it lists the required MAME romset files by name
and CRC32, with no copyrighted data. Run it through the `mra` tool to produce
`berzerk.rom`, then keep that `.rom` in the same folder (and on your Pocket
SD card). Note the parent set needs the **rc31a** revision of `rom5.5c`
(CRC `e0fab8f5`).

## Credits

- **Original arcade game:** Stern Electronics (1980)
- **FPGA arcade core:** Dar (darfpga)
- **S14001A speech emulation:** Jonathan Gevaryahu, R. Belmont (via MAME)
- **MiSTer integration:** MiSTer-devel project
- **Analogue Pocket port:** HarpMudd
- **Z80 CPU core (T80):**
  - **Daniel Wallner** — original author (2001–2002, OpenCores)
  - **Mike Johnson / MikeJ** (FPGAArcade) — DJNZ M1_n fix, clock enable, IM 2 fix
    and interrupt-ack fix (v0232–0240); project tidy-up, March 2005 (Ver 300)
  - **Sean Riddle** — parity flag for 8080 vs Z80 (Ver 301)
  - **TobiFlex** — undocumented DDCB / FDCB opcodes (Ver 303, 20 April 2010)
  - **Alexey Melnikov (Sorgelig)** — timing accuracy and ZEXDOC / ZEXALL /
    Z80Full / Z80memptr verification (Ver 350, 2018), and the `T80pa`
    pseudo-asynchronous top level
- **SDRAM controller, data loader, I2S audio, sync FIFO:** Adam Gastineau (agg23)
- **openFPGA framework (APF), bridge command handler, reference `core_top`:** Analogue
- **PLL and other megafunctions:** Intel/Altera (Quartus-generated)

## About / Support

I'm into retro games and the Analogue Pocket, always cooking up something new.
I love being part of a community built on sharing and the love of games — so if
any of my projects bring you joy, grab me a coffee; it fuels the next thing.

☕ **[buymeacoffee.com/harpmudd](https://buymeacoffee.com/harpmudd)**
