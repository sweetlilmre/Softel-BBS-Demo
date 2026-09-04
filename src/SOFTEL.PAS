program Softel;

{ SOFTEL.EXE -- Asphyxia's second demo, 1993, for the Softel BBS in Durban.

  [re] This is segment 1000 of the load image: 0x1600 bytes, entry at 0f94.
  Together with SCREEN.PAS it is the whole reconstruction -- 11f5 is System,
  1193 is Crt, 1160 is the stock GoldPlay unit and 12eb is DGROUP, and none
  of those is ours to write.

  [re] The opening is TESTPLAY.PAS, GoldPlay's own example, which the
  distribution ships beside the library: the same LoadOvl / AskInit /
  Initialize / LoadModule sequence in the same order, and the same
  'Module Not Found' message. That is what identified GoldPlay's five entry
  points by order as well as by arity.

  [re] Read with Ghidra's decompiler over segment 1000's fifteen near-call
  targets. Every name below is this reconstruction's: a load image carries
  addresses and shapes, never identifiers.

  [re] STATE OF THIS FILE: the structure and the two long call sequences are
  transcribed and the shapes are read, but four routines are declared with
  routine bodies written. Nothing here is yet claimed to MATCH -- the plan's
  rows carry that, and they are all still at R0. Their addresses are on the plan as
  rows at R0. Nothing here should be read as a claim that the bytes match. }

{ [re] THE ORDER OF THIS CLAUSE IS MEASURED, not stylistic. Turbo Pascal 6
  emits unit code segments in the REVERSE of the uses clause: written as
  `Crt, GoldPlay, Screen` the map came out SCREEN, GOLDPLAY, CRT, and the
  original is GOLDPLAY, SCREEN, CRT. Reversing to `Crt, Screen, GoldPlay`
  is what puts them in the original's order, and it independently predicts
  the startup's init calls -- the image calls Crt's init then Screen's,
  which is this clause's own order, and GoldPlay has no init at all. }
{ [re] THE PROGRAM IS $S- AND THE UNIT IS NOT, which is a source directive
  rather than a command-line switch -- SCREEN.PAS matched at 144 of 144 bytes
  with stack checking left at TPC's default, and its routines DO open with the
  seven-byte `xor ax,ax / lcall` check.

  Segment 1000's do not. 0231 is `enter 0300h,0` straight into its body, 013e
  is `enter 6,0`, and 03ae is a bare `push bp / mov bp,sp` -- no check on any
  of them. That seven bytes per framed routine was the uniform +7 this
  reconstruction carried on every routine measured against the original. }
{$S-}

uses Crt, Screen, GoldPlay;

type
  { [re] 768 bytes at DS:$004a, walked 0..255 by SetPalette. }
  TRGB     = array [0..2] of Byte;
  TPalette = array [0..255] of TRGB;

  { [re] 5508 bytes. PutGlyph writes it with a stride of 306, and
    306 * 18 = 5508, so it is 306 wide by 18 high. }
  TStrip   = array [1..5508] of Byte;

  { [re] 210 bytes. PutSprite draws exactly 15 columns by 14 rows from it,
    and 15 * 14 = 210. }
  TSprite  = array [1..210] of Byte;

  { [re] The font: 15104 bytes, 59 glyphs of 256. PutGlyph indexes it as
    Ch * 0x100 + J * 0x10 + I, so a glyph is 16 by 16 and is stored with J
    as the outer subscript -- transposed against the screen, where J is the
    COLUMN and I the row. }
  TGlyph   = array [1..16, 1..16] of Byte;
  TFont    = array [0..58] of TGlyph;

  { [re] The animation path: 14976 bytes as 72 frames of 208, and 72 * 208 is
    14976 exactly. DrawFrame reads a word pair at N * 208 + I * 4 - 212, and
    with both subscripts based at one that is precisely (N-1)*208 + (I-1)*4 --
    which is what fixes the frame at 208 bytes rather than the 204 that 51
    objects need, and fixes Y as the FIRST word of the pair. }
  TObj     = record
               Y, X : Word;
             end;
  TFrame   = array [1..52] of TObj;
  TPath    = array [1..72] of TFrame;

var
  { [re] DGROUP IN ADDRESS ORDER, because Turbo Pascal allocates a unit's
    variables in DECLARATION order -- so this list IS the layout, and a
    missing declaration shifts every address below it. dsgaps.py prices these
    against the original with no build at all; dsmap.py checks them once
    there is a linked image. }

  Font       : ^TFont;                 { DS:$0046 -- 15104 bytes }
  Pal        : TPalette;               { DS:$004a }

  { [re] DS:$034a, and it is TESTPLAY.PAS's own `Var I:Word` kept in place --
    the ending below fades the music with `for I := 64 downto 0`, exactly as
    that example does, and this is the counter it walks. Its position here,
    between the palette and the file variable, is where TestPlay declares
    it. }
  I          : Word;

  DatFile    : File;                   { DS:$034c -- untyped, so 128 bytes,
                                         and $034c + 128 = $03cc exactly }
  SaveTop    : array [1..960] of Byte; { DS:$03cc -- ScrollUp's wrap rows }
  Clean      : TStrip;                 { DS:$078c -- the pristine strip }
  Work       : TStrip;                 { DS:$1d10 -- the strip drawn into }
  Buf        : Pointer;                { DS:$3294 -- 64000-byte work buffer }
  BufSeg     : Word;                   { DS:$3298 }
  Path       : ^TPath;                 { DS:$329a -- 72 frames x 208 bytes }
  Blip       : TSprite;                { DS:$329e }
  KeyHit     : Byte;                   { DS:$3370 -- a key was pressed }
  Faded      : Byte;                   { DS:$3371 -- the fade has finished }
  Frame      : Byte;                   { DS:$3372 -- cycles 1..72 }

  { [re] DS:$3373, and DS:$3375 below. One byte each, between variables that
    ARE reached, and nothing observed touches either. Same reasoning as
    Unread034A. }
  Unread3373 : Byte;

  Music      : Char;                   { DS:$3374 }

  { [re] GoldPlay's Error is at DS:$3376, so this program's own variables end
    here. }
  Unread3375 : Byte;

{ [re] 1000:0000, and it is FOURTEEN BYTES with NO FRAME:
  mov dx,3dah / in al,dx / and al,8 / jne / in al,dx / and al,8 / je / ret.
  DX is loaded ONCE and both loops reuse it, which is what makes it fourteen;
  the Pascal spelling with Port[$3DA] reloads DX each time and came to
  thirty-two with a frame. So it is assembler, and the port address is hoisted
  deliberately rather than by accident. }
procedure WaitRetrace; assembler;
asm
  mov dx, 03dah
@@low:
  in al, dx
  and al, 8
  jne @@low
@@high:
  in al, dx
  and al, 8
  je @@high
end;

{ [re] 1000:000e. One step of a fade to black -- every colour from 1 up has
  each component decremented while it is above 1, and the result says whether
  anything moved, so the caller can loop until it stops. }
function FadeStep : Boolean;
var
  I     : Word;
  Moved : Boolean;
begin
  Moved := False;
  for I := 1 to 255 do
    begin
      if Pal[I][0] > 1 then begin Moved := True; Dec(Pal[I][0]); end;
      if Pal[I][1] > 1 then begin Moved := True; Dec(Pal[I][1]); end;
      if Pal[I][2] > 1 then begin Moved := True; Dec(Pal[I][2]); end;
    end;
  FadeStep := Moved;
end;

{ [re] PARAMETER ORDER FOR THIS ROUTINE AND THE NEXT TWO CAME FROM THE RAW
  PUSH ORDER, not from a decompiler. Ghidra numbers parameters by stack
  offset, so its param_1 is the LAST pushed -- the reverse of the declaration
  order -- and reading its signature straight off gets them backwards. At
  1000:053d the pushes are 7, 0x14, DS:$1d10, then the buffer segment, which
  is PutStrip(X, Y, Strip, Dest). At 1000:0551 the CHARACTER is pushed first
  and the x position second, so it is PutGlyph(Ch, X) and not the other way
  about -- which is how this file had it until the bytes were read.

  [re] 1000:0095, and 1000:00f0 below is the same routine with a different
  inner loop. The frame layout confirms the signature: `ret 0Ah` is five
  words, the destination offset is computed as X + Y*320 -- as Y*256 plus
  Y*64, which is the `mov bh,bl / xor bl,bl` and the six `shl ax,1` -- and
  the destination SEGMENT is the last parameter. A `var` parameter is the far
  pointer at [bp+6].

  [re] Both are NEAR: `ret` and not `retf`, because a routine declared in the
  program rather than in a unit interface is near by default. And neither
  opens with a stack check, even though the program is $S+ -- an `assembler`
  procedure does not get one, which 118a:0024 shows too.

  [re] The odd `push ax / mov ax,cx` before the row loop and `mov cx,ax`
  inside it is the original's way of keeping the column count across rows.
  Kept as written: a cleaner spelling would emit different bytes. }
procedure PutSprite(X, Y : Word; var S : TSprite; Dest : Word); assembler;
asm
  push ds
  push es
  lds si, S
  mov ax, X
  mov bx, Y
  push ax
  mov ax, Dest
  mov es, ax
  mov ax, bx
  mov bh, bl
  xor bl, bl
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  add bx, ax
  pop ax
  add ax, bx
  mov di, ax
  mov dl, 0eh
  xor ch, ch
  mov cl, 0fh
  cld
  push ax
  mov ax, cx
@@row:
  push di
  mov cx, ax
@@pixel:
  mov bl, [si]
  or bl, bl
  jne @@opaque
  inc si
  inc di
  loop @@pixel
  jmp @@endrow
@@opaque:
  movsb
  loop @@pixel
@@endrow:
  pop di
  dec dl
  je @@done
  add di, 0140h
  jmp @@row
@@done:
  pop ax
  pop es
  pop ds
end;

{ [re] 1000:00f0. The strip blitted whole -- 0x99 words by 0x12 rows,
  destination stride 0x140. The body calls it with X=7 and Y=20, so the
  306-wide strip lands at column 7 of a 320-wide buffer -- and 0x99 words is
  306 bytes exactly. }
procedure PutStrip(X, Y : Word; var S : TStrip; Dest : Word); assembler;
asm
  push ds
  push es
  lds si, S
  mov ax, X
  mov bx, Y
  push ax
  mov ax, Dest
  mov es, ax
  mov ax, bx
  mov bh, bl
  xor bl, bl
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  shl ax, 1
  add bx, ax
  pop ax
  add ax, bx
  mov di, ax
  mov dl, 012h
  xor ch, ch
  mov cl, 099h
  cld
  push ax
  mov ax, cx
@@row:
  push di
  mov cx, ax
  rep movsw
  pop di
  dec dl
  je @@done
  add di, 0140h
  jmp @@row
@@done:
  pop ax
  pop es
  pop ds
end;

{ [re] DECLARATION ORDER IS THE ORIGINAL'S: DrawFrame at 013e comes BEFORE
  SetRGB at 01ad, and this file had them the other way round. Order is not
  cosmetic -- every near call's displacement depends on it.

  [re] 1000:013e. One animation frame: 51 objects, each a word pair taken
  from the path table at Frame * 208 + I * 4. }
procedure DrawFrame(N : Byte);
var
  I : Byte;
begin
  for I := 1 to 51 do
    PutSprite(Path^[N][I].X, Path^[N][I].Y, Blip, BufSeg);
end;

{ [re] 1000:01ad. One palette entry: the colour index to the DAC write port
  at $3C8, then the three components to $3C9. Interrupts are masked across
  the four OUTs. Byte parameters each take a word on the stack, so Col is at
  [bp+0Ah] and B at [bp+4], which is the order below. }
procedure SetRGB(Col, R, G, B : Byte); assembler;
asm
  cli
  mov dx, 03c8h
  mov al, Col
  out dx, al
  inc dx
  mov al, R
  out dx, al
  mov al, G
  out dx, al
  mov al, B
  out dx, al
  sti
end;

{ [re] 1000:01ca. All 256 entries. The parameter is BY VALUE -- the routine
  copies 768 bytes into a local before reading it, which is what a value
  parameter of array type does. }
procedure SetPalette(P : TPalette);
var
  I : Word;
begin
  for I := 0 to 255 do
    SetRGB(I, P[I][0], P[I][1], P[I][2]);
end;

{ [re] 1000:0231 IS THE DEMO'S CLOCK, and its parameter is VAR -- it writes
  through the caller's array, which a value parameter could not do.

  IT CYCLES ENTRIES 1..192, and the indices are read off the offsets rather
  than guessed. The Move is (P+0x15 -> P+3, 0x240) and every one of those is
  divisible by three: 0x15 is entry 7, 3 is entry 1, and 0x240 is 192
  entries. The six writes that follow are to P+0x231 through P+0x240, which
  is entries 187 to 192 -- the tail of the range that was just shifted down,
  so the six that fell off the front wrap round to the end.

  [re] A PREVIOUS READING HAD THESE AS 119..124 and it was simply wrong: 561
  divided by three is 187, not 119. Nothing measured caught it, because a
  wrong palette index is still a valid palette index -- it would have cycled
  the wrong six colours and looked plausible on screen. Per-routine SIZE is
  what led here, not correctness.

  [re] The six are copied STRAIGHT from the saved copy to the palette, one
  three-byte record each. An earlier version went through six TRGB temporaries
  and cost 114 bytes over the original for exactly that.

  [re] When KeyHit is set it writes zeros to those same six instead, so the
  cycling colours drain to black; when the first reaches black it sets Faded,
  and Faded is what every display loop tests to exit. The three components are
  tested in the order [0], [2], [1], which is the original's order and not a
  tidy one. Then a retrace wait, and out. }
procedure CyclePalette(var P : TPalette);
var
  Save : TPalette;
begin
  Save := P;
  Move(P[7], P[1], 576);
  P[187] := Save[1];
  P[188] := Save[2];
  P[189] := Save[3];
  P[190] := Save[4];
  P[191] := Save[5];
  P[192] := Save[6];
  if KeyHit <> 0 then
    begin
      FillChar(P[187], 3, 0);
      FillChar(P[188], 3, 0);
      FillChar(P[189], 3, 0);
      FillChar(P[190], 3, 0);
      FillChar(P[191], 3, 0);
      FillChar(P[192], 3, 0);
    end;
  if (P[1][0] = 0) and (P[1][2] = 0) and (P[1][1] = 0) then Faded := 1;
  WaitRetrace;
  SetPalette(P);
end;

{ [re] 1000:038b. The five-argument block move ScrollUp uses, and the push
  order confirms this declaration: [bp+0Ch] goes to DS as the source segment
  and [bp+4] is added to DI as the destination offset.

  [re] `xor si,si` followed by `add si,SrcOfs` rather than a plain `mov` is
  the original's spelling and is kept -- the shorter form is different bytes. }
procedure MoveBlock(SrcSeg, DstSeg, Count, SrcOfs, DstOfs : Word); assembler;
asm
  push ds
  cld
  mov ax, DstSeg
  mov es, ax
  mov ax, SrcSeg
  mov ds, ax
  xor si, si
  xor di, di
  add si, SrcOfs
  add di, DstOfs
  mov cx, Count
  rep movsw
  pop ds
end;

{ [re] 1000:03ae. The background wrap-scrolls up three scanlines: 960 bytes
  saved off the top, 31360 moved down over them, and the saved rows written
  back at the bottom. }
procedure ScrollUp;
begin
  Move(Mem[VirtualSeg : $0140], SaveTop, 960);
  MoveBlock(VirtualSeg, VirtualSeg, 31360, $0500, $0140);
  Move(SaveTop, Mem[VirtualSeg : $F500], 960);
end;

{ [re] 1000:03f5. One 16x16 glyph into the strip, skipping zero pixels so a
  glyph is transparent over what is already there.

  [re] Through the TYPED pointer, not Mem[Seg():Ofs()]. The original reads the
  font off a pointer with folded array arithmetic; spelling it with Mem[] and
  an explicit segment reloads ES on every one of the 256 accesses and cost 44
  bytes over the original.

  [re] The subscript order is the original's and it is not the obvious one: J
  is the glyph's outer subscript and the strip's column, I is the glyph's inner
  and the strip's row. The source expression is read twice, once in the test
  and once in the assignment, which is what the original does too. }
procedure PutGlyph(Ch : Byte; X : Word);
var
  I, J : Byte;
begin
  for I := 1 to 16 do
    for J := 1 to 16 do
      if Font^[Ch][J][I] <> 0 then
        Work[X + I * 306 + J] := Font^[Ch][J][I];
end;

{ [re] 1000:04a1 and 1000:05e0 ARE MIRROR IMAGES and the difference is two
  numbers. Both exit at once if a key is down or the fade has finished, both
  reset the strip from Clean, and both loop: scroll, cycle, blit the strip,
  draw a glyph, advance the frame, blit to $A000. ShowLine walks X from 0
  upward by 17 with its character index rising from 1, so the line builds
  from the left; ShowLineReverse starts X at 289 and walks DOWN by 17 with
  the index falling from Length, so it builds from the right. That is why the
  body alternates them.

  [reading] The two 18-blank constants at 048e and 05cd are one per routine.
  A shared constant would have been emitted once, so the source has the
  literal written out twice rather than a named constant used twice.

  [re] The guard is one short-circuit test and an Exit rather than a positive
  if-block: 04b8 calls KeyPressed and jumps to the tail when it is true, then
  tests Faded and jumps to the BODY when that is zero, falling through to the
  tail otherwise. That is `if KeyPressed or (Faded <> 0) then Exit`.

  [re] The strip is reset with an explicit Move and not an array assignment:
  the original calls the runtime with (Clean, Work, 5508). }
procedure ShowLine(S : String);
var
  Line : String;
  X    : Integer;
  N    : Byte;
  I    : Byte;
begin
  if KeyPressed or (Faded <> 0) then Exit;
  I := 1;
  N := 1;
  Line := '                  ';
  Move(Clean, Work, 5508);
  X := 0;
  repeat
    Line[I] := S[I];
    ScrollUp;
    CyclePalette(Pal);
    Blit(VirtualSeg, BufSeg);
    PutStrip(7, 20, Work, BufSeg);
    PutGlyph(Ord(Line[I]), X);
    if I < Length(S) then X := X + 17;
    DrawFrame(Frame);
    Inc(Frame);
    if Frame > 72 then Frame := 1;
    Blit(BufSeg, $A000);
    Inc(N);
    if N <= Length(S) then I := N;
    if KeyPressed then
      begin
        KeyHit := 1;
        ReadKey;
      end;
  until (N = 50) or KeyPressed or (Faded <> 0);
end;

{ [re] The mirror, and three numbers are the whole difference: the blank
  constant is the one at 05cd rather than 048e, X starts at 289 and walks
  DOWN by 17, and the counter starts at Length and runs to -20 -- 0xffec as a
  word, which is what says it is signed rather than a Byte. }
procedure ShowLineReverse(S : String);
var
  Line : String;
  X    : Integer;
  N    : Integer;
  I    : Byte;
begin
  if KeyPressed or (Faded <> 0) then Exit;
  I := Length(S);
  N := Length(S);
  Line := '                  ';
  Move(Clean, Work, 5508);
  X := 289;
  repeat
    Line[I] := S[I];
    ScrollUp;
    CyclePalette(Pal);
    Blit(VirtualSeg, BufSeg);
    PutStrip(7, 20, Work, BufSeg);
    PutGlyph(Ord(Line[I]), X);
    if N > 1 then X := X - 17;
    DrawFrame(Frame);
    Inc(Frame);
    if Frame > 72 then Frame := 1;
    Blit(BufSeg, $A000);
    Dec(N);
    if N > 0 then I := N;
    if KeyPressed then
      begin
        KeyHit := 1;
        ReadKey;
      end;
  until (N = -20) or KeyPressed or (Faded <> 0);
end;

{ [re] 1000:070f. softel.dat, six BlockReads that sum to 100566 -- the file's
  exact size, which is the check on every size here: a wrong one would have
  to be paid for by another wrong one. }
procedure LoadData;
begin
  Assign(DatFile, 'softel.dat');
  Reset(DatFile, 1);
  BlockRead(DatFile, Blip, 210);
  BlockRead(DatFile, Clean, 5508);
  BlockRead(DatFile, Path^, 14976);
  BlockRead(DatFile, Virtual^, 64000);
  BlockRead(DatFile, Pal, 768);
  BlockRead(DatFile, Font^, 15104);
  Close(DatFile);
end;

{ [re] 1000:07c0 is the finale and it is TEXT MODE rather than the virtual
  screen, which is the only reason Crt is linked at all. It counts the
  non-space characters, then repeatedly picks a random position in the line
  and walks that character up from row 24 to row Y with GotoXY and a Delay
  per step, blanking the cell it came from, until every one is placed.

  [re] The row comes FIRST: the body pushes it before the string.

  [re] Both `if` guards in the decompilation are a for-loop's own entry test
  rather than statements of their own. `if Length(S) <> 0` in front of the
  counting pass is what `for Pos := 1 to Length(S)` emits, and
  `if Y < 25` in front of the walk is what `for Row := 24 downto Y` emits --
  24 >= Y being the condition to enter at all. Writing either as a real `if`
  would emit the test twice.

  [re] Crt.GotoXY takes (X, Y) here: at the call the position is pushed before
  the row, which is the same push-order reading that corrected PutGlyph.

  [re] Random(Length(S)) returns 0..Length-1 and the original adds one, so the
  index is 1..Length. S is a value parameter and IS modified -- a placed
  character is blanked in the local copy so it is not chosen twice, which is
  what makes the outer loop terminate. }
procedure FlyCredit(Y : Byte; S : String);
var
  Left : Integer;
  Row  : Word;
  Pos  : Byte;
begin
  Left := 0;
  for Pos := 1 to Length(S) do
    if S[Pos] <> ' ' then Inc(Left);
  repeat
    Pos := Random(Length(S)) + 1;
    if S[Pos] <> ' ' then
      begin
        Dec(Left);
        for Row := 24 downto Y do
          begin
            GotoXY(Pos, Row);
            Write(S[Pos]);
            if Row < 24 then
              begin
                GotoXY(Pos, Row + 1);
                Write(' ');
              end;
            Delay(5);
          end;
        S[Pos] := ' ';
      end;
  until Left = 0;
end;

begin
  ClrScr;
  Write('Do you want music? (y/n) : ');
  repeat
    Music := UpCase(ReadKey);
  until Pos(Music, 'YN') <> 0;
  Write(Music);
  WriteLn;
  if Music = 'Y' then
    begin
      LoadOvl('softel.ovl');
      AskInit;
      Initialize;
      LoadModule('patega.mod');
      if Error <> 0 then
        begin
          WriteLn('Module Not Found');
          Halt;
        end;
      ClrScr;
    end;
  Frame := 1;
  Faded := 0;
  KeyHit := 0;
  OpenVirtual;
  GetMem(Path, 14976);
  GetMem(Buf, 64000);
  GetMem(Font, 15104);
  BufSeg := Seg(Buf^);
  SetGraphicsMode;
  LoadData;
  if Music = 'Y' then StartPlaying;
  SetPalette(Pal);
  Blit(VirtualSeg, $A000);

  { [re] The whole advert is one repeat loop -- 13e9 jumps back to 10d3,
    which is the FIRST of these calls. That is why the 44 calls are unrolled
    in the image: they are statements, not a loop over a table. }
  repeat
    ShowLine('     WELCOME      ');
    ShowLineReverse('     TO THE       ');
    ShowLine('SOFTEL MONSTER BBS');
    ShowLineReverse('   THE LARGEST    ');
    ShowLine('  BBS IN AFRICA   ');
    ShowLineReverse('  WITH ACCESS TO  ');
    ShowLine('INTERNATIONAL MAIL');
    ShowLineReverse('(FIDO,USENET,ETC.)');
    ShowLine('  WITH 100''S OF   ');
    ShowLineReverse('   CONFERENCES    ');
    ShowLine('AND GAZIILLIONS OF');
    ShowLineReverse('REALLY GREAT FILES');
    ShowLine('       ####       ');
    ShowLineReverse('  A NEW MEGATAPE  ');
    ShowLine(' EVERY WEEK FROM  ');
    ShowLineReverse('THE UK, BRINGS THE');
    ShowLine('LATEST FILES RIGHT');
    ShowLineReverse('TO YOUR DOORSTEP. ');
    ShowLine('       ####       ');
    ShowLineReverse('AND NOW WITH EVEN ');
    ShowLine(' BETTER WITH THE  ');
    ShowLineReverse('LATEST VERSION OF ');
    ShowLine('PC-BOARD (V 15.0) ');
    ShowLineReverse('       ####       ');
    ShowLineReverse('   YOU HAVE NOT   ');
    ShowLine('EXPERIENCED BBS''N ');
    ShowLineReverse('  UNTIL YOU HAVE  ');
    ShowLine('EXPERIENCED SOFTEL');
    ShowLineReverse('!THE MONSTER BBS! ');
    ShowLine('                  ');
    ShowLineReverse('                  ');
    ShowLine('PHONE THE ASPHYXIA');
    ShowLineReverse('BBS (031) 765-5312');
    ShowLine('HST DS 16.8, FOR ');
    ShowLineReverse('OUR LATEST DEMOS!!');
    ShowLine('                  ');
    ShowLineReverse('                  ');
    ShowLine(' A S P H Y X I A  ');
    ShowLineReverse('   R U L E S !    ');
    ShowLine('                  ');
    ShowLineReverse('                  ');
    ShowLine('                  ');
    ShowLineReverse('                  ');
  until KeyPressed or (Faded <> 0);

  repeat
    SetPalette(Pal);
    ShowLine(' ');
  until not FadeStep;

  FreeMem(Buf, 64000);
  FreeMem(Font, 15104);
  CloseVirtual;
  TextMode(3);

  { [re] INT 10h with AH=1 and CH=$FF hides the cursor. Assembler because the
    original is -- Crt has no way to say it. }
  asm
    mov ah, 1
    mov ch, 0ffh
    mov cl, 9
    int 10h
  end;

  FlyCredit(3, '                              -=[ ASPHYXIA ]=-');
  FlyCredit(5, '                    Asphyxia was proud to present to you');
  FlyCredit(6, '                              the SOFTEL DEMO');
  FlyCredit(8, '           Softel Is the largest BBS in Africa, and the Asphyxia');
  FlyCredit(9, '                team may be reached there under the names');
  FlyCredit(10, '               Grant Smith, Peter Edwards or Brian Bailey');
  FlyCredit(11, '                       (Denthor, EzE and LiveWire)');
  FlyCredit(13, '               Or reach us at the following EMAIL Adresses :');
  FlyCredit(14, '                                     Grant.Smith@catpe.alt.za');
  FlyCredit(15, '                                     Brian.Bailey@catpe.alt.za');
  FlyCredit(16, '                                  or Peter.Edwards@catpe.alt.za');
  FlyCredit(18, '                              or   Edwards@Beastie.cs.und.ac.za');
  FlyCredit(19, '                                   Bailey@Beastie.cs.und.ac.za');
  FlyCredit(20, '               Or leave mail to ''Asphyxia'' at the ASPHYXIA BBS');
  FlyCredit(21, '                                Tel : (031) 765-5312');
  FlyCredit(23, '                      This is the second Demo written by');
  FlyCredit(24, '                      -=[       A S P H Y X I A      ]=-');

  { [re] 1000:159a onward. WriteLn, then the keyboard is drained -- while a
    key is waiting, read and discard it -- so the fade below is not skipped
    by whatever keystroke ended the advert.

    [re] Then TESTPLAY.PAS's ending, kept almost word for word: the volume
    walked down 64 to 0 with a Delay(50) each step, then StopPlaying, DeAlloc
    and RemoveOvl. Those four calls are what account for GoldPlay's segment
    being 0x2a0 in the original against 0x228 when they were missing here --
    smart linking keeps only what is reached, so an absent call shows up as a
    short segment rather than as an error. }
  WriteLn;
  while KeyPressed do ReadKey;
  if Music = 'Y' then
    begin
      for I := 64 downto 0 do
        begin
          MasterVolume(I);
          Delay(50);
        end;
      StopPlaying;
      DeAlloc;
      RemoveOvl;
    end;

  { [re] CH=6, CL=7 restores the ordinary cursor the block above hid. }
  asm
    mov ah, 1
    mov ch, 6
    mov cl, 7
    int 10h
  end;
end.
