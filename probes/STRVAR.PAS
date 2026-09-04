unit Strvar;

{ PROBE: assign a literal to an exactly-sized local, then pass it to a VAR
  parameter. The last untested combination.

  WHY THIS SHAPE AND NOT ANOTHER. The original's call site is
  lea di,[bp-n] / push ss / push di / mov di,CONST / push cs / push di /
  lcall 01f5:096d / call -- eight bytes pushed, four popped, the destination
  left behind as the callee's argument. 096d copies the source's length byte
  and that many bytes with NO bound, which is only safe when the destination
  is known to be big enough. An exactly-sized local is such a destination, and
  a var parameter is the only thing that needs a constant turned into a
  variable at all.

  [re] ELIMINATED ALREADY, so nobody repeats them: a String value parameter
  with a literal argument and with a variable argument (STRLIT.PAS); a short
  String[18] value parameter, where the copy moves into the CALLEE
  (STRSHORT.PAS); assign-to-local-then-pass for a VALUE parameter, which emits
  a BOUNDED copy in the opposite argument order and pushes the destination
  twice (STRVIA.PAS); passing a literal straight to a var parameter, which TP6
  refuses outright with Error 20, Variable identifier expected. Every compiler
  switch is eliminated too, and so is every installed compiler except TP 6.0.

  [re] THE COMPILER IS TP 6.0, NOT 6.01, and the runtime copyright string says
  so: TP600's TURBO.TPL carries `Portions Copyright (c) 1983,90 Borland`, which
  is byte for byte what the image holds at file offset 0x2489. TP601 says
  1983,91 and both 7.x say 1983,92; TP500 and TP550 carry no such string. This
  project had earlier tried to separate 6.0 from 6.01 by comparing runtime byte
  agreement -- 25.9% against 26.0%, a dead heat -- while the answer sat in
  plain ASCII inside the library.

  [re] 096d IS LINKED INTO THIS RECONSTRUCTION ALREADY, at the same SYSTEM
  offset the original calls, and nothing we write calls it. So the construct is
  one this source does not contain rather than one the compiler cannot emit. }

interface

type
  TLine = String[18];

procedure SinkVar(var S : String);

procedure ViaExactLocal;

implementation

procedure SinkVar(var S : String);
begin
end;

procedure ViaExactLocal;
var
  Line : TLine;
begin
  Line := '     WELCOME      ';
  SinkVar(Line);
end;

end.
