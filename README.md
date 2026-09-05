# SOFTEL

Pascal sources that rebuild **SOFTEL.EXE** — the second demo by **Asphyxia** (Denthor, EzE, LiveWire), released in 1993 for the Softel BBS in Durban, South Africa — byte for byte.

```
md5 7c4350cb3e664c942149feef990f3801   bin/SOFTEL.EXE     the 1993 binary
md5 7c4350cb3e664c942149feef990f3801   build/SOFTEL.EXE   built from src/
```

12,832 bytes, and not one of them differs. `kit/tools/pascal/artefact.py status.toml --check` reports **R7** — the top of the kit's fidelity ladder, recomputed on every run rather than read back from a file.

The demo's own `README.1ST` is in [`bin/`](bin/), in the author's words:

> Here it is, the second demo coded by Asphyxia. This was coded just a few weeks after we formed the group, and we were quite proud of it.

## What is verified, and how

Every figure below is produced by a tool, and each one recomputes it:

| check | tool | result |
|---|---|---|
| the whole image | `artefact.py --check` | **R7 holds** against `ref/softel.bin` |
| segment alignment | `spans.py link.toml 000` | 11,952 of 11,952 bytes, **100.0%** |
| per-unit code blocks | `mapcmp.py link.toml` | **5 units exact**, 0 bytes in any live gap |
| our units against the original image | `units.py units.toml` | `GOLDPLAY` 671 and `SCREEN` 139 bytes, identical but for link-time fixups |
| a watched run | `observe.py` | **R3** on 4 Sep 2026 — a viewer sees no difference |

R3 came first and by a person: no instrument can say whether a demo *looks* right, so somebody ran both binaries side by side and said so. Byte-identity came afterwards.

## The scope: three segments are ours

The image holds six. Only three are built here, and one of those is somebody else's code that we nonetheless rebuild from source:

| segment | size | what it is |
|---|---|---|
| `1000` | `0x1600` | **the program** — `src/SOFTEL.PAS` |
| `118a` | `0x8b` | **the virtual-screen unit** — `src/SCREEN.PAS` |
| `1160` | `0x29f` | **GoldPlay**, by The CodeBlasters — not ours, rebuilt by `src/GOLDPLAY.PAS` |
| `1193` | `0x620` | Turbo Pascal's `Crt` — the RTL, out of scope |
| `11f5` | `0xf60` | the Turbo Pascal runtime — out of scope |
| `12eb` | `0x50` | DGROUP's initialised head, 79 zeros and one `02` |

Neither GoldPlay release ships source for its engine, so `src/GOLDPLAY.PAS` is a reconstruction of the unit from v1.01's Pascal, measured against v1.00's compiled `.TPU`. Three source-level facts close the gap and each was read off the bytes: `{$B+}`, `{$I+}` at one `Reset`, and the term order of a single guard. **The build therefore has no unbuildable input** — a fresh checkout compiles.

`bin/SOFTEL.OVL` is *not* a target. It is byte-identical to the stock GoldPlay v1.00 overlay, unmodified: runtime data the player loads from disk. `bin/SOFTEL.DAT` and `bin/PATEGA.MOD` are likewise data — the second a 1990 ProTracker module.

## Layout

| | |
|---|---|
| [`src/`](src/) | the reconstruction of record — the sources, with the evidence for every byte |
| [`clean-src/`](clean-src/) | the same program with the apparatus stripped out, **generated** from `src/` |
| [`bin/`](bin/) | the distribution, exactly as it shipped in 1993 |
| [`ref/`](ref/) | `softel.bin`, the measurement copy — what everything is compared against |
| [`probes/`](probes/) | one-construct programs, each compiled to settle one compiler question |
| [`kit/`](kit/) | the method, as a submodule — portable, and holds no fact about this target |
| `*.toml` | the answers: where things are, how it is built, what is claimed |

`CLAUDE.md` is the working notes: the segmentation as measured, the traps in reading this image, and the things that were not guessable. Read it before changing a source file.

## Building it

You need DOSBox-X and a Turbo Pascal 6 installation. Their locations go in `kit.local.toml`, which is never committed — copy nothing else; no tracked file in this repository names a path on anybody's machine.

```
.venv/Scripts/python.exe kit/tools/pascal/build.py build.toml
.venv/Scripts/python.exe kit/tools/pascal/artefact.py status.toml --check
```

**The compiler is Turbo Pascal 6.0, not 6.01** — `TURBO.TPL` carries `Portions Copyright (c) 1983,90 Borland`, byte for byte what the image holds at offset `0x2489`.

**And the switch line is load-bearing: `/$G+ /$X+ /$O+ /$I- /GD /Q`, plus `{$S-}` and `{$M 4000,0,200000}` in the source.** Every switch on it was measured against the image rather than chosen, and changing any one stops the build matching. The demo shipped no `TPC.CFG`, so there was nothing to read them off; `build.toml` records what each was measured against. A wrong switch does not fail the build — it produces a build that measures wrong.

## Running it

```
python runtest.py
```

Stages both executables and the three data files they read onto `R:` under DOSBox-X and leaves you at a prompt. Type `ORIG` or `OURS`. A stale rebuild is refused rather than staged, because watching a build older than its sources is the one mistake you cannot take back — once you have seen it, you believe it.

## The stripped copy

`src/` answers *how do we know this byte is right*: addresses, operand deltas, notes on which instrument caught what. None of that is what a reader who came to understand the **demo** is looking for, and no single copy serves both readers. So `clean-src/` is made mechanically, and regenerated whenever `src/` moves:

```
.venv/Scripts/python.exe kit/tools/pascal/clean.py src clean-src --exclude asm/shared-exempt.txt --report
```

117 tagged paragraphs, 4 address-only comments and 10 address prefixes come out, over three files.

**And that copy is compiled, which is not decoration.** The stripper checks itself by blanking every `{ ... }` in both copies and comparing the code — immune to wording, and therefore also immune to a `{$I-}`, because a compiler directive *is* a comment to that check. Damage to a directive is the single edit the stripper can make that it will never report, and the switch line above is exactly what such an edit would break. So `build.clean.toml` is generated from `build.toml` by `cleanconf.py`, the copy is built, and the linked images are compared — `cmp build/SOFTEL.EXE build-clean/SOFTEL.EXE`, identical.

## Credits, and what is not ours

The demo is **Asphyxia's**: Denthor (code), EzE, LiveWire. **GoldPlay** is by *Sourcer* and *Robban* of **The CodeBlasters**, and is SMILEWARE — share it, credit the authors, send them a postcard. `PATEGA.MOD` is by an author the demo's own README could not name. This repository is a reconstruction of their work and claims nothing about it; the sources here are a transcription, and where a name in them reads like a fact it is cited.
