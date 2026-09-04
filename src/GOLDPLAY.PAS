{$S-,B+,I+}
{ GoldPlay v1.00 -- the ProTracker player unit, by The CodeBlasters, 1992.
  NOT our code. It is reconstructed source for somebody else's unit, kept
  here because it is the one build input SOFTEL.EXE could not otherwise
  rebuild: goldplay/v1.00 ships GOLDPLAY.TPU and no goldplay.pas.

  Distributed as SMILEWARE, which asks that the package not be changed. The
  package is not changed: goldplay/ is untouched read-only reference, and
  bin/SOFTEL.OVL is still byte-identical to the shipped v1.00 overlay. This
  file only reproduces what the shipped TPU already contains.

  [re] The base is goldplay/v1.01/goldplay.pas, the nearest release that
  ships source. Compiled as-is it reproduces the first 128 bytes of v1.00's
  code block and then parts, 444 of 672 bytes differing. Three changes close
  it, and each was measured against the shipped TPU rather than chosen:

  [re] $B+ -- complete boolean evaluation. v1.00 materialises the guard in
  StartPlaying, StopPlaying and DeAlloc as a byte AND: `cmp word [Error],0;
  mov al,0; jne +1; inc ax; and al,[PlayerLoaded]; or al,al; je`. Under the
  default $B- the same expression short-circuits into two compares and two
  jumps, which is what v1.01 emits.

  [re] The guard's TERM ORDER is reversed. v1.01 reads
  `(PlayerLoaded) and (Error=0)`; the AND above takes PlayerLoaded as its
  memory operand, so it is the SECOND term, and Error the first. Under $B+
  the order is visible in the bytes.

  [re] $I+ at Reset. v1.00 carries a five-byte I/O result check after
  `Reset(F,1)` in LoadOVL -- a far call with nothing pushed -- and none
  after `Assign`, which cannot set IOResult. build.toml asserts /$I- for
  SOFTEL.PAS's sake, so this unit turns checking back on itself. The
  $I-/$I+ pair already in the body is v1.01's own and is left alone: it
  is what suppresses the checks on the eight BlockReads and restores the one
  on Close.

  [re] Everything else is v1.01's source verbatim, including its layout and
  its spelling. The result compiles to 672 bytes identical to
  goldplay/v1.00/GOLDPLAY.TPU's code block, and the demo still builds to
  R7 -- md5 7c4350cb3e664c942149feef990f3801 -- with the shipped TPU no
  longer staged. Checked by units.py as segment 1160.

  [re] What this does NOT establish is that v1.00's own source read this
  way. The interface is v1.01's, and the private identifiers below are
  v1.01's; only the code generated from them is measured. A different source
  emitting the same bytes would be equally consistent with the evidence. }
Unit GOLDPLAY;

INTERFACE
Procedure AskInit;
Procedure Initialize;
Procedure LoadModule(Mfile:String);
Procedure StartPlaying;
Procedure StopPlaying;
Procedure DeAlloc;
Procedure SetSys(SDEV,TSPEED,SBDMA,SBIRQ,SBPORT:WORD);
Procedure LoadOVL(FNamn:String);
Procedure RemoveOVL;
Procedure MasterVolume(MastVol:Word);
Function  BopBar(BarNo:Word):Word;

Var Error:Word;

IMPLEMENTATION

Var F:File;
    PlayPoint:Pointer;
    PlaySeg:Word;
    PlaySize:Word;

    SAskInit     :Procedure;
    SInitialize  :Procedure;
    SLoadModule  :Procedure;
    SStartPlaying:Procedure;
    SStopPlaying :Procedure;
    SDeAlloc     :Procedure;
    SDPoint	 :Pointer;

    Temp:Word;
    ModNamn:String;

Var SSDev,STSpeed,SSBDMA,SSBIRQ,SSBPort:Word;

Const PlayerLoaded:Boolean=False;

Procedure ASKINIT;
Begin;
If PlayerLoaded then SASKINIT;
End;

Procedure Initialize;
Begin;
If PlayerLoaded then SINITIALIZE;
End;

Procedure LoadModule(MFile:String);
Begin;
Error:=0;
If PlayerLoaded then
Begin;
ModNamn:=MFile+#0;

Asm;
Mov Dx,Offset [ModNamn+1]
Call SLoadModule
Jnc @NoError
Mov Error,Ax
@NoError:
End;
End;
End;

Procedure StartPlaying;
Begin;

If (Error=0) and (PlayerLoaded) then SStartPlaying;
End;

Procedure StopPlaying;
Begin;
If (Error=0) and (PlayerLoaded) then SStopPlaying;
End;

Procedure DeAlloc;
Begin;
If (Error=0) and (PlayerLoaded) then SDeAlloc;
End;

Procedure LoadOVL(FNamn:String);
Begin;
If PlayerLoaded=True then exit;
GetMem(PlayPoint,40000);
Asm
Mov  Ax,Word Ptr PlayPoint+2
Mov  PlaySeg,Ax
End;
Assign(F,FNamn);
Reset(F,1);
{$I-}
BlockRead(F,Temp,2);
Asm;
Mov Ax,Temp
Mov Word Ptr sAskInit,Ax
Mov Ax,PlaySeg
Mov Word Ptr sAskInit+2,Ax
End;
BlockRead(F,Temp,2);
Asm;
Mov Ax,Temp
Mov Word Ptr SInitialize,Ax
Mov Ax,PlaySeg
Mov Word Ptr SInitialize+2,Ax
End;
BlockRead(F,Temp,2);
Asm;
Mov Ax,Temp
Mov Word Ptr SLoadModule,Ax
Mov Ax,PlaySeg
Mov Word Ptr SLoadModule+2,Ax
End;
BlockRead(F,Temp,2);
Asm;
Mov Ax,Temp
Mov Word Ptr SStartplaying,Ax
Mov Ax,PlaySeg
Mov Word Ptr SStartplaying+2,Ax
End;
BlockRead(F,Temp,2);
Asm;
Mov Ax,Temp
Mov Word Ptr SStopPlaying,Ax
Mov Ax,PlaySeg
Mov Word Ptr SStopPlaying+2,Ax
End;
BlockRead(F,Temp,2);
Asm;
Mov Ax,Temp
Mov Word Ptr SDeAlloc,Ax
Mov Ax,PlaySeg
Mov Word Ptr SDeAlloc+2,Ax
End;
BlockRead(F,Temp,2);
Asm;
Mov Ax,Temp
Mov Word Ptr SDPoint,Ax
Mov Ax,PlaySeg
Mov Word Ptr SDPoint+2,Ax
End;
BlockRead(F,PlayPoint^,40000,PlaySize);
Asm;
Push Es
Mov  Es,PlaySeg
Mov  Cx,PlaySize
Shr  Cx,1
Mov  Bx,0

@UnCode:
Mov  Ax,Es:[Bx]
Ror  Ax,7
Xor  Ax,Cx
Xor  Ax,0B32Ah
Mov  Es:[Bx],Ax
Add  Bx,2
Loop @UnCode
Pop  Es
End;


{$I+}
Close(F);
PlayerLoaded:=True;
End;

Procedure RemoveOvl;
Begin;
FreeMem(PlayPoint,40000);
PlayerLoaded:=False;
End;

Procedure MasterVolume(MastVol:Word);
Begin;
If PlayerLoaded=False then Exit;
temp:=MastVol;
Asm;
Push Es
Mov  Bx,word ptr [SDPoint]
Mov  Es,word ptr [SDPoint+2]
Mov  Ax,Temp
Mov  Es:[Bx+10],Ax
Pop Es
End;
End;

Function BopBar(BarNo:Word):Word;
Begin;
If PlayerLoaded=False then Exit;
If (BarNo=0) or (Barno>4) then begin;BopBar:=0;Exit;End;
temp:=BarNo;
Asm;
Push Es
Mov  Bx,word ptr [SDPoint]
Mov  Es,word ptr [SDPoint+2]
Mov  Ax,Temp
Shl  Ax,1
Add  Bx,Ax
Mov  Ax,Es:[Bx+10]
Mov  Temp,Ax
Pop Es
End;
BopBar:=Temp;
End;

Procedure SetSys(SDEV,TSPEED,SBDMA,SBIRQ,SBPORT:WORD);
Begin;
If PlayerLoaded=False then Exit;
SSDEV:=SDEV; STSPEED:=TSPEED; SSBDMA:=SBDMA; SSBIRQ:=SBIRQ; SSBPORT:=SBPORT;
Asm;
Push Es
Mov  Bx,word ptr [SDPoint]
Mov  Es,word ptr [SDPoint+2]
Mov  Ax,SSDev
Mov  word ptr Es:[BX],Ax
Mov  Ax,StSpeed
Mov  word ptr Es:[BX+2],Ax
Mov  Ax,SSBDMA
Mov  word ptr Es:[BX+4],Ax
Mov  Ax,SSBIRQ
Mov  word ptr Es:[BX+6],Ax
Mov  Ax,SSBPORT
Mov  word ptr Es:[BX+8],Ax
Pop  Es
End;
End;

End.