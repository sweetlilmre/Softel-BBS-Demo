unit Strvia;

{ PROBE: does assigning a literal to a LOCAL and passing that local produce
  the original's eighteen-byte call site?

  WHY THIS SHAPE. The original does, in order: lea di,[bp-0x14] / push ss /
  push di / mov di,CONST / push cs / push di / lcall 01f5:096d / call. Eight
  bytes go on the stack and only four are consumed, so the helper takes the
  constant and leaves the local's address behind as the callee's argument.
  That is what an assignment from a string constant into a local followed by
  a call passing that local would look like if the compiler pushes the local's
  address once and reuses it.

  Measured already and NOT the cause: a plain String parameter with a literal
  argument (STRLIT.PAS PassLiteral) and with a variable argument
  (PassVariable) both push the address directly in eight bytes; a short
  String[18] parameter (STRSHORT.PAS) moves the copy into the CALLEE and
  leaves the caller direct.

  The local is 20 bytes for an 18-character string -- TP6 rounds the 19 up --
  which matches the original's [bp-0x14] once the filename temp at [bp-0xc] is
  understood as sharing the same reused stack region. }

interface

type
  TLine = String[18];

procedure Sink(S : String);
procedure ViaLocalShort;
procedure ViaLocalLong;

implementation

procedure Sink(S : String);
begin
end;

procedure ViaLocalShort;
var
  Line : TLine;
begin
  Line := '     WELCOME      ';
  Sink(Line);
end;

procedure ViaLocalLong;
var
  Line : String;
begin
  Line := '     WELCOME      ';
  Sink(Line);
end;

end.
