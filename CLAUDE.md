# Softel

A reconstruction of **SOFTEL.EXE**, the second demo by Asphyxia (Denthor / EzE / LiveWire), released 1993 for the Softel BBS, Durban. The goal is Pascal sources that rebuild the shipped binary byte for byte.

## The method is in the kit

`kit/` is a submodule and is the portable half of this effort. **Read [`kit/WORKING.md`](kit/WORKING.md) at the start of every session** — sections 1, 2, 2a and 4 are about a page. Nothing about this target belongs in `kit/`; if a file under `kit/` names `SOFTEL`, a segment address or a machine path, it is in the wrong place.

`kit.toml` at this root answers where things are. Every instrument prints the answer it used and where it came from.

## What this target is

| | |
|---|---|
| the original | `ref/softel.bin` — a copy of `bin/SOFTEL.EXE`, part `000`, the only image |
| the distribution | `bin/` — exactly as it shipped, and not load-bearing for any check |
| our sources | `src/` |
| compiler | Borland / Turbo Pascal 6 (`Portions Copyright (c) 1983,90 Borland` at file offset `0x2489`) |
| disassembly | `ghidra/` — **untracked**, and recreatable; see below |

**`bin/SOFTEL.OVL` is not ours.** It is byte-identical to `goldplay/v1.00/GOLDPLAY.OVL` — the stock GoldPlay v1.00 overlay by The CodeBlasters, unmodified. It is a build **input**, never a reconstruction target, and `goldplay/` as a whole is read-only reference (both `v1.00` and `v1.01`; the demo shipped v1.00). Do not point `layout.src` at it — the wizard proposes it on `shape only` evidence and is wrong.

`bin/SOFTEL.DAT` is data loaded at runtime (`softel.dat`), `bin/PATEGA.MOD` the ProTracker module GoldPlay plays.

## Open at the top of the record

`plan.py --report` is the authority. The one thing blocking everything else:

- **no build toolchain** — no Turbo Pascal 6, no `build/`, no build config, so `layout.build` and `layout.built` are unanswered and SETUP.md's steps 3–5 (layout, units, blocks configs) are all blocked behind a linker map that does not exist yet.

## The Ghidra project is not in the repository

`ghidra/` is gitignored. It is an instrument's working state, not the record: when it was tracked it held **0 functions and 1 symbol**, so all 1.75M was derived from `bin/SOFTEL.EXE` plus the loader's defaults, and it is locked and mutating whenever Ghidra is open. Everything read out of it lives here as text — the memory map in `link.toml`, `first_para` in `kit.toml`, the segment identifications in `status.toml`, the instruction readings in `src/SCREEN.PAS`.

To recreate it: import `bin/SOFTEL.EXE` as `x86:LE:16:Real Mode` and accept the MZ loader's defaults, which put the load image at `1000:0000` — that is where `target.first_para = 0x1000` comes from. Auto-analysis has never been run. **Ghidra's block boundaries are 16 bytes out** — see the segmentation table below — so do not take them as measurements.

If real annotation ever accumulates there, prefer moving it into the sources as `@asm` markers and `[re]` prose over tracking the database: a marker is read by `markers.py` and locked by the ratchet, and a `.gbf` is read by nothing.

## The segmentation

Measured, and it does NOT match Ghidra's block boundaries — see below.

| segment | extent | what it is |
|---|---|---|
| `1000` | `0x1600` | the PROGRAM. No far return, which is correct: a program body ends in the runtime's halt |
| `1160` | `0x2a0` | **GOLDPLAY** — 671 bytes of code, 1 byte of linker padding |
| `118a` | `0x90` | **OURS** — `src/SCREEN.PAS`, and its code is the original's bytes. 5 routines, `0x8b` + 5 pad |
| `1193` | `0x620` | the RTL's **Crt** unit — not ours to transcribe |
| `11f5` | `0xf60` | the Turbo Pascal runtime |
| `12eb` | `0x50` | **DGROUP's initialised head** — 79 zero bytes and one `02`, and the last thing in the file |
| BSS | from `12eb:0050` | not in the file at all. `0x4d00` = 19712 bytes, EXACTLY the MZ `minalloc` |

**Ghidra's blocks are 16 bytes out, and it misleads twice.** Its `CODE_0` runs to `1000:160f` and its `CODE_1` starts at `1160:0010`. Both are wrong: the program ends at `1000:15ff`, and the GoldPlay unit begins at `1160:0000`. Taking Ghidra's boundaries hides GoldPlay's whole first routine — which the program calls — and lends the program a far return that is really that routine's `RETF`.

**`1160` is GoldPlay by measurement, not inference.** `align.locate` puts the segment at offset 960 of `goldplay/v1.00/GOLDPLAY.TPU`, where that TPU's symbol names stop and its code starts. Across 672 bytes the two differ in 105 runs and no run exceeds 4 bytes — 20 of width 4, 71 of width 2, 14 of width 1 — and 104 of the 105 are zero in the TPU, the addend left for whoever resolves the reference. The EXE's relocation table holds exactly 20 entries in this segment, one per 4-byte far pointer; the 2-byte runs are DGROUP offsets and the 1-byte runs near displacements, both resolved at link time and so absent from a load-time table.

**Two traps in reading this image.**

*`survey.py`'s framed return count is not a census, and since kit `fee3f0b` it says so.* Its anchored scan cannot see a frameless routine — one reading parameters off `ss:[bx+n]` — so it prints a separate **upper bound** beside the certain count. Read the bound as direction and magnitude: `1193` is 2 framed against 11+14 candidates and holds roughly thirty assembler routines, while `1160` is 9 and 0 and really does hold nine.

*Do not infer code-versus-data from relocation counts.* `11f5` is the target of 149 of the 191 fixups, which reads like a data group being addressed and is in fact a runtime being called — a fixup naming a far `CALL` target is indistinguishable from one naming a data word. That reading was made and withdrawn; `plan.py --report` carries it under `segment-inventory`.

*A near-zero region matches any other near-zero region.* `12eb` scores 100% against `GOLDPLAY.TPU`. It is 79 zeros and one `02`.

**The load image ends exactly at `12eb:0050`.** 12032 image bytes, and `12eb:0050` in image coordinates is `0x2f00` = 12032. So `12eb` is DGROUP: 80 bytes of initialised data in the file, then BSS. Ghidra calls those 80 bytes `CODE_5` because four fixups name paragraph `02eb` — but those are references *to* the data group (a `MOV AX,DGROUP` loading DS), not code inside it. Twice now on this target, reading a segment's role off relocation data has been wrong.

## What is actually ours to write

Two segments, and no more:

| | |
|---|---|
| `1000` | the program, `0x1600` bytes |
| `118a` | one unit, `0x8b` bytes of code |

Everything else in the image belongs to somebody else — `11f5` is `System`, `1193` is `Crt`, `1160` is stock GoldPlay, `12eb` is DGROUP. That is the whole scope of the reconstruction.

`118a`'s five routines, read off the disassembly:

| offset | what it does |
|---|---|
| `0000` | `procedure(destSeg, srcSeg)` — `rep movsw`, `cx=0x7d00` = 64000 bytes = one 320×200 screen. A flip or copy. `retf 4` |
| `0024` | `mov ax,0x13; int 0x10; retf` — set mode 13h. **Frameless**, 5 bytes |
| `002a` | `GetMem(64000)` into the pointer at `[0x351e]`, then `FillChar(p,64000,0)` — allocate and clear the virtual screen |
| `005e` | `FreeMem(p, 64000)` |
| `007a` | the unit's init, reached from the startup at `0f9e` |

## The original was compiled `$S+`, and that is measured

`118a`'s framed routines open `55 89 e5 31 c0 9a df 04 f5 01` — `push bp; mov bp,sp; xor ax,ax; lcall 01f5:04df`. `probes/STACKCHK.PAS` through `codegen.py` shows `/$S+` emitting exactly that sequence with the far pointer unresolved, and `/$S-` emitting no call at all. The probe's second routine pins it further: with 402 bytes of locals, `$S+` gives `mov ax,0x192; lcall; sub sp,0x192`, so the operand is the frame size and `xor ax,ax` means a frame of zero — correct for a routine with parameters and no locals. **`01f5:04df` is the RTL stack check.**

`$S+` is TPC's own default — `probecheck` gives 128 bytes for `tp6` on defaults and for `/$S+`, against 96 for `/$S-` — so `build.toml`'s assert-nothing switch line already emits this. `$G` and `$N` remain unmeasured.

GoldPlay was compiled `$S-`: no `04df` call anywhere in segment `1160`. It is linked as a prebuilt `.TPU`, so its switches are not ours to match — but that contrast is what made the prologue worth probing.

## The main program came from GoldPlay's example

`bin/SOFTEL.EXE` holds `Module Not Found` at `1000:0920`, verbatim from `goldplay/v1.00/TESTPLAY.PAS`. Read that file before reading the program's startup: it is the shape the demo was written from. Note that `LoadOvl` there is a **GoldPlay procedure**, not Turbo Pascal's overlay manager — `SOFTEL.OVL` is GoldPlay's own player core, loaded by its own code at runtime, and the unit is linked into the EXE like any other.

The startup at `1000:0f94` calls `01f5:0000` (the runtime's init), then `0193:0000` and `018a:007a` — the unit inits, in link order.

## Building it

    .venv/Scripts/python.exe kit/tools/pascal/build.py build.toml --selftest

Proven working under both `tp6` and `tp61`. DOSBox-X and four Turbo Pascal trees (`TP600`, `TP601`, `TP700`, `TP701`) plus `TASM` are already installed on this machine; `kit.local.toml` names them and is **never committed**. `build.toml` is committed and holds no machine path.

**The switch line is `/$G+ /GD /Q`.** `$G+` is asserted on evidence — the original tears frames down with `c9` (`LEAVE`, an 80186/286 instruction) and the probe shows `/$S+` alone emitting `5d` (`POP BP`), with `/$G+` changing exactly one byte in 128. `$S` is deliberately *not* asserted, which is the opposite case: `$S+` is TPC's default **and** what the original shows, so naming it would add a switch that changes nothing. `$N` is the one code-generation switch still unmeasured. `/GD` gets the detailed `.MAP` that `link.toml` needs. `build.py` warns that a wrong switch line does not fail — it produces a build that *measures* wrong — and SOFTEL's distribution carries no `TPC.CFG`, so every switch has to be measured rather than read.

**Order matters: build, then `markers.py --emit`, then `ratchet.py --measured`.** `build.py` wipes the staging directory, so a `measured.toml` emitted before a build is deleted by it. `ratchet` refuses a missing file rather than reading it as empty, which is how this gets caught.

**No `binpath` in `build.toml`.** The kit derives the DOS bin directory from `toolchain.<compiler>` in `kit.local.toml` — the answer that invokes the compiler — so there is no typed copy to go stale. Do not add one back: the kit's observation `typed-copy-of-a-derived-path` measured 15 stale entries across five configs in the sibling consumer, wrong for as long as a rename was old, while every check passed. A path used only to decorate an environment fails at a moment nobody is watching.

**One trap, and it is the harness rather than the shell.** Every `\\` pair in a Bash tool command collapses to one `\` before bash sees it — measured: `\`→`\`, `\\`→`\`, `\\\`→`\\`, `\\\\`→`\\`, while `\t` and `\'` pass through untouched. Quoting the heredoc delimiter does not prevent it. So **do not double a backslash**: a lone `\` arrives intact, and writing `'C:\\TP600'` — correct POSIX practice — is exactly what silently halved these paths into invalid TOML. Both config files now use TOML literal strings with single separators (`'C:\TP600'`). If a consumer itself wants `\\` (a Python literal, an awk or sed regex) send four.

**And commands truncate above ~8KB**, which surfaces as `unexpected EOF while looking for matching '` — an error naming quoting rather than size. Write file content with the Write tool and run it; keep heredocs to a few short lines.

`link.toml` holds the layout, every address in it measured. Its `map` key names `build/SOFTEL.MAP`, which does not exist yet — there is no `SOFTEL.PAS` to compile. That is a to-do, not a silence.

## Where the reconstruction stands

Both sources are written. `python runtest.py` stages a watched run with the
shipped binary and ours side by side on R:.

| | |
|---|---|
| `SCREEN.PAS` | `units.py`: identical but for 46 link-time fixups |
| `SOFTEL.PAS` | `mapcmp`: 5072 of 5632 padded |
| DGROUP | `dsmap`: **163 references at shift zero**, `$0003..$3DA4` |
| GOLDPLAY / SCREEN / Crt | exact in `mapcmp` |

**Six routines are byte-identical** — `WaitRetrace`, `FadeStep`, `PutSprite`,
`PutStrip`, `SetRGB`, `MoveBlock`. `CyclePalette` and `ScrollUp` are size-exact
and differ only at far-call fixups.

## The one open question is the COMPILER, not the source

Every remaining byte has one explanation: **the original's compiler spills
intermediates to stack temporaries where ours computes them in registers.**
Three independent constructs show it, and a source difference can produce none
of them:

- **String constants passed by value.** The original copies each into a temp
  *sized to that constant* and passes the temp — 18 bytes per call site against
  our 8. The temp sizes match all seventeen credit-line lengths exactly, so the
  code generator is choosing them. 61 call sites × 10 bytes is the body's whole
  −600.
- **`SetPalette`.** `enter 6` against our `enter 2`; the four extra bytes hold a
  pointer, through which the original fetches `P[I][0]` while `[1]` and `[2]`
  come from direct indexing.
- **`DrawFrame`.** Same shape — `enter 6` against `enter 2`, loading an address
  through the local where ours pushes the computed value.

**All four installed compilers are eliminated**, and by a whole-program build
rather than a probe: building all of `SOFTEL.PAS` with `tp61` instead of `tp6`
gives an identical result, to the byte. TP7 *inlines* the very helper the
original calls out to. So the question is narrow — which TP6 build spills these?
Another 6.x patch level, a localised release, or BP7 in TP6 mode would settle it
in one build.

**Do not rewrite the Pascal to chase these bytes.** Imitating a temp this
compiler will not emit would make the source wrong in order to make the bytes
right.

## Two rules worth keeping about locals

**Declaration ORDER is the frame layout.** Turbo Pascal allocates locals
downward in declaration order, so the order of a `var` block is testable
against the original's `[bp-n]` displacements. `FadeStep` became byte-identical
purely by declaring `Moved` before `I` — the original writes its flag at
`[bp-2]` and this file had it at `[bp-5]`. The other obvious spelling, letting
the function result carry the flag, made it *worse* (129 against 135), which is
what proved the local was real.

**Each `enter` operand is a budget.** It gives the original's exact local byte
count, so a routine whose frame is short is missing a declaration and one whose
frame is long has an extra. `PutGlyph`'s original reserves 4 where `Byte`
counters give 2, so its `I` and `J` are `Word`s.

## Reading the instruments here

`routines.py` reports a matched *prefix* under its own stop rule, so "78 of 91"
is not necessarily a divergence — `PutSprite` is in fact identical over all 91.
Diff a routine directly before believing a partial figure.

`dsmap`'s residue of 7 sites at `$F50F` is not a defect: that is
`Mem[VirtualSeg:$F500]` in `ScrollUp`, a segment-override reference, which it
pairs as though it were DS-relative.
