unit Stackchk;

{ PROBE: does a framed procedure open with a per-routine runtime call, and is
  that what $S+ emits?

  WHY IT EXISTS. Segment 118a's four framed routines each open with
  `push bp / mov bp,sp / xor ax,ax / lcall 01f5:04df`, and GoldPlay's unit at
  1160 -- compiled by somebody else, with their own switches -- has a frame but
  no such call. That is the shape of a stack check, and it would mean SOFTEL
  was compiled $S+. build.toml asserts no code-generation switch, so if the
  original is $S+ then TPC's own default already agrees and nothing needs
  saying; if it is not, the switch line is wrong and every routine we
  transcribe would differ in its opening bytes.

  Reasoning about it is what this replaces. Compile with /$S+ and with /$S-
  and read the two prologues.

  NoLocals matches 118a's routines, which take parameters and declare nothing.
  WithLocals is here because a stack check's operand is the frame size, so a
  routine with locals should show a non-zero AX where NoLocals shows zero --
  which distinguishes a stack check from a fixed prologue call. }

interface

procedure NoLocals(A, B : Word);
procedure WithLocals(A : Word);

implementation

procedure NoLocals(A, B : Word);
begin
  Mem[$B800:0] := A + B;
end;

procedure WithLocals(A : Word);
var
  Buf : array [0..199] of Word;
  I   : Word;
begin
  for I := 0 to 199 do Buf[I] := A;
  Mem[$B800:0] := Buf[0];
end;

end.
