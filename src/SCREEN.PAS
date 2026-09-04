unit Screen;

{ Mode 13h and a 64000-byte virtual screen: allocate it, clear it, blit it,
  release it. This is the only unit of SOFTEL.EXE that is ours to rebuild.

  [re] It is segment 118a of the load image, 0x8b bytes of code and five
  bytes of zero padding to 0x90. The other four code segments belong to
  somebody else -- 11f5 is System, 1193 is Crt, 1160 is the stock GoldPlay
  unit, and 12eb is DGROUP -- so this file plus the program at 1000 is the
  whole reconstruction.

  [re] Every routine below is transcribed from a linear disassembly of that
  segment. The unit's own name and its identifiers are NOT recoverable from a
  load image: only the addresses, the shapes and the call targets are. So the
  names here are this reconstruction's choices and claim nothing about what
  Asphyxia called them. }

interface

var
  { [re] DS:$351e, four bytes -- the pointer GetMem returns is stored as
    offset at $351e and segment at $3520. }
  Virtual : Pointer;

  { [re] 1568 BYTES, AND THE SIZE IS MEASURED RATHER THAN GUESSED. dsmap.py
    pairs every absolute data reference in the original with ours and reports
    the shift: 88 sites from DS:$0003 up to and including Virtual at DS:$351e
    carry a shift of ZERO, and every one of the 47 sites at DS:$3b42 and above
    carried exactly -1568 until this was declared. The boundary is where the
    shift changes, and it falls between these two variables, so what is
    missing sits here and is 1568 bytes wide.

    WHAT IT IS remains unknown, and the name says so rather than implying a
    use. No instruction in this unit touches it and none in the program does
    either, so a load image cannot say what it held -- only where it was and
    how big. Do not give it a type or a name that claims more than that: the
    kit's own rule is that a name should be no stronger than the evidence, and
    the evidence here is an address and a length. }
  Unread3522 : array [1..1568] of Byte;

  { [re] DS:$3b42. Written once, immediately after the allocation, from the
    segment half of Virtual. }
  VirtualSeg : Word;

{ Copy one whole 320x200 screen. Src and Dst are SEGMENTS, not pointers. }
procedure Blit(Src, Dst : Word);

{ BIOS mode 13h: 320x200 in 256 colours. }
procedure SetGraphicsMode;

{ Allocate the virtual screen and clear it to colour 0. }
procedure OpenVirtual;

{ Release it. }
procedure CloseVirtual;

{ [re] THE GAP IS NOW MEASURED AND DECLARED, and the way it was settled is
  worth keeping because the earlier reading of it was wrong in an instructive
  way. This file used to say the distance was 1572 bytes and offered three
  candidate explanations, one of which was that VirtualSeg might belong to
  another unit entirely.

  It is 1568, it is this unit's, and dsmap.py said so in one run: the shift
  it reports is zero for all 88 sites up to Virtual and exactly -1568 for all
  47 at VirtualSeg and above. A boundary in that table is worth more than any
  amount of reading around the addresses -- which is what the instrument's own
  docstring says, and this target had been doing the reading instead.

  The four-byte discrepancy in the old note came from subtracting the two
  addresses and forgetting that Virtual is four bytes wide. }

implementation

{ [re] 118a:0000..0021. Frame plus stack check, then eleven bytes of
  assembler, then LEAVE and RETF 4.

  The parameters are segments rather than pointers, which the disassembly
  states rather than implies: [bp+8] goes into DS and [bp+6] into ES, and
  nothing dereferences either. With a far call and BP pushed, [bp+8] is the
  first parameter and [bp+6] the second, so the source order is (Src, Dst).

  [re] cx is 0x7d00 = 32000 words = 64000 bytes, which is one 320x200 mode
  13h screen exactly. `rep movsw` and not `rep movsb`.

  [reading] The `cld` is in the original and is kept. It is not redundant to
  the compiler -- nothing in a Pascal prologue clears the direction flag -- so
  the author put it there, and dropping it would change the bytes.

  [re] The `xor si,si` and `xor di,di` are 31 f6 and 31 ff in the original.
  Both mnemonics have two encodings and the assembler picks one; if these come
  out as 33 f6 and 33 ff, that is the first thing to look at rather than
  evidence of a wrong transcription. }
{ [re] @asm 000 118a:0000 }
procedure Blit(Src, Dst : Word);
begin
  asm
    push ds
    cld
    mov ax, Dst
    mov es, ax
    mov ax, Src
    mov ds, ax
    xor si, si
    xor di, di
    mov cx, 32000
    rep movsw
    pop ds
  end;
end;

{ [re] 118a:0024..0029, and it is FIVE BYTES with no frame and no stack check:
  b8 13 00 / cd 10 / cb. That is why it is declared `assembler` -- a plain
  `begin asm ... end; end` would open with the same push bp / mov bp,sp /
  xor ax,ax / lcall that every other routine here does, and this routine has
  none of it.

  [re] The far RETF is the compiler's, not ours: an interface routine of a
  unit is far in Turbo Pascal 6 without any $F+ being written. }
{ [re] @asm 000 118a:0024 }
procedure SetGraphicsMode; assembler;
asm
  mov ax, $13
  int $10
end;

{ [re] 118a:002a..005d. Three statements, and each one is legible in the
  calls it makes:

    push $fa00; lcall 01f5:023f; store DX:AX at $351e/$3520
        -- 64000 in, a pointer back, kept in Virtual. GetMem, whose size
        argument the compiler passes and whose result it assigns.
    les di,[$351e]; mov ax,es; mov [$3b42],ax
        -- the segment half of Virtual, stored. Seg(Virtual^) compiles to
        exactly this: load the far pointer, then read ES.
    les di,[$351e]; push es; push di; push $fa00; push 0; lcall 01f5:0f36
        -- an address, a count and a value. FillChar.

  [reading] 01f5:023f and 01f5:0f36 are read as GetMem and FillChar from the
  shape of their arguments, not from their bodies. rtl.py find is what
  confirms a runtime routine, by taking its body from a reference and
  refusing any pattern that matches more than once, and this target has no
  RTL.toml yet. The transcription does not depend on the names being right --
  it depends on the argument shapes, which are measured.

  [re] The second `les di,[$351e]` is a reload, not a redundancy: it is what
  two separate statements produce, and writing this as one statement would
  emit one load. }
{ [re] @asm 000 118a:002a }
procedure OpenVirtual;
begin
  GetMem(Virtual, 64000);
  VirtualSeg := Seg(Virtual^);
  FillChar(Virtual^, 64000, 0);
end;

{ [re] 118a:005e..0079. push [$3520]; push [$351e]; push $fa00;
  lcall 01f5:0254 -- the pointer pushed segment-first then offset, which is
  how a far pointer is passed, followed by the size. FreeMem.

  [reading] The size is passed as a literal 64000 rather than read from a
  variable, so the original repeats the constant here as it does in
  OpenVirtual. }
{ [re] @asm 000 118a:005e }
procedure CloseVirtual;
begin
  FreeMem(Virtual, 64000);
end;

{ [re] 118a:007a..008a, reached from the program's startup at 1000:0f9e,
  which is where Turbo Pascal calls each unit's initialisation in link order.
  The whole body is one far call to 01f5:0d55 and nothing else -- frame,
  stack check, the call, LEAVE, RETF.

  [reading] A System routine taking no arguments and called once from a
  unit's initialisation reads as Randomize. That is an inference from arity
  and position, and it is the weakest claim in this file: any argumentless
  System procedure would compile to the same three instructions. If the byte
  comparison lands and this call's target does not, the name is what is
  wrong, not the shape. }
{ [re] @asm 000 118a:007a ScreenInit }
begin
  Randomize;
end.
