program Softel;

{ SOFTEL.EXE -- Asphyxia's second demo, 1993, for the Softel BBS in Durban. }

{$M 4000,0,200000}
{$S-}

uses Crt, Screen, GoldPlay;

type
  TRGB     = record
               R, G, B : Byte;
             end;
  TPalette = array [0..255] of TRGB;

  TStrip   = array [1..5508] of Byte;

  TSprite  = array [1..210] of Byte;

  TGlyph   = array [1..16, 1..16] of Byte;

  TFont    = array [32..90] of TGlyph;

  TObj     = record
               X, Y : Word;
             end;
  TFrame   = array [1..52] of TObj;
  TPath    = array [1..72] of TFrame;

var

  Font       : ^TFont;                 { 15104 bytes }
  Pal        : TPalette;

  I          : Word;

  DatFile    : File;                   { untyped, so 128 bytes,
                                         and $034c + 128 = $03cc exactly }
  SaveTop    : array [1..960] of Byte; { ScrollUp's wrap rows }
  Clean      : TStrip;                 { the pristine strip }
  Work       : TStrip;                 { the strip drawn into }
  Buf        : Pointer;                { 64000-byte work buffer }
  BufSeg     : Word;
  Path       : ^TPath;                 { 72 frames x 208 bytes }
  Blip       : TSprite;
  KeyHit     : Byte;                   { a key was pressed }
  Faded      : Byte;                   { the fade has finished }
  Frame      : Byte;                   { cycles 1..72 }

  Unread3373 : Byte;

  Music      : Char;

  Unread3375 : Byte;

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

function FadeStep : Boolean;
var
  Moved : Boolean;
  I     : Word;
begin
  Moved := False;
  for I := 1 to 255 do
    begin
      if Pal[I].R > 1 then begin Moved := True; Dec(Pal[I].R); end;
      if Pal[I].G > 1 then begin Moved := True; Dec(Pal[I].G); end;
      if Pal[I].B > 1 then begin Moved := True; Dec(Pal[I].B); end;
    end;
  FadeStep := Moved;
end;

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

procedure DrawFrame(N : Byte);
var
  I  : Byte;
  PX : Word;
  PY : Word;
begin
  for I := 1 to 51 do
    begin
      PX := Path^[N][I].X;
      PY := Path^[N][I].Y;
      PutSprite(PX, PY, Blip, BufSeg);
    end;
end;

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

procedure SetPalette(P : TPalette);
var
  I : Word;
begin
  for I := 0 to 255 do
    with P[I] do
      SetRGB(I, R, G, B);
end;

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
  if (P[1].R = 0) and (P[1].B = 0) and (P[1].G = 0) then Faded := 1;
  WaitRetrace;
  SetPalette(P);
end;

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

procedure ScrollUp;
begin
  Move(Mem[VirtualSeg : $0140], SaveTop, 960);
  MoveBlock(VirtualSeg, VirtualSeg, 31360, $0500, $0140);
  Move(SaveTop, Mem[VirtualSeg : $F500], 960);
end;

procedure PutGlyph(Ch : Byte; X : Word);
var
  I, J : Integer;
begin
  for I := 1 to 16 do
    for J := 1 to 16 do
      if Font^[Ch][J][I] <> 0 then
        Work[X + J + I * 306] := Font^[Ch][J][I];
end;

procedure ShowLine(S : String);
var
  I     : Byte;
  U0102 : Byte;
  N     : Byte;
  U0104 : Byte;
  U0105 : Byte;
  U0106 : Byte;
  X     : Integer;
  Line  : String;
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
    if I < Length(S) then Inc(X, 17);
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

procedure ShowLineReverse(S : String);
var
  I     : Integer;
  U0104 : Integer;
  N     : Integer;
  X     : Integer;
  Line  : String;
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
    if N > 1 then Dec(X, 17);
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

procedure FlyCredit(Y : Byte; S : String);
var
  Pos  : Integer;
  Row  : Integer;
  Left : Integer;
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
  until Music in ['N', 'Y'];
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

  asm
    mov ah, 1
    mov ch, 6
    mov cl, 7
    int 10h
  end;
end.
