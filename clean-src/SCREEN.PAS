unit Screen;

{ Mode 13h and a 64000-byte virtual screen: allocate it, clear it, blit it,
  release it. This is the only unit of SOFTEL.EXE that is ours to rebuild. }

interface

var
  Virtual : Pointer;

  Unread3522 : array [1..1568] of Byte;

  VirtualSeg : Word;

{ Copy one whole 320x200 screen. Src and Dst are SEGMENTS, not pointers. }
procedure Blit(Src, Dst : Word);

{ BIOS mode 13h: 320x200 in 256 colours. }
procedure SetGraphicsMode;

{ Allocate the virtual screen and clear it to colour 0. }
procedure OpenVirtual;

{ Release it. }
procedure CloseVirtual;


implementation

{  [reading] The `cld` is in the original and is kept. It is not redundant to
  the compiler -- nothing in a Pascal prologue clears the direction flag -- so
  the author put it there, and dropping it would change the bytes. }
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

procedure SetGraphicsMode; assembler;
asm
  mov ax, $13
  int $10
end;

procedure OpenVirtual;
begin
  GetMem(Virtual, 64000);
  VirtualSeg := Seg(Virtual^);
  FillChar(Virtual^, 64000, 0);
end;

procedure CloseVirtual;
begin
  FreeMem(Virtual, 64000);
end;

begin
  Randomize;
end.
