unit Strlit;

{ PROBE: what does a call site emit when a string LITERAL is passed to a
  String value parameter?

  WHY IT EXISTS. Segment 1000's 61 display calls each spend eighteen bytes
  where this reconstruction spends eight -- the original routes the constant
  through 01f5:096d into a small stack local and leaves four bytes behind as
  the callee's argument, while ours pushes CS:offset straight. That ten bytes
  times 61 sites is most of SOFTEL's remaining gap, and it is ONE cause, so a
  wrong guess moves every site the wrong way at once.

  Two things are ruled out already and neither needs probing again: the
  parameter type is not it, because GoldPlay's own v1.01 source declares
  LoadOVL(FNamn:String) exactly as ours resolves; and it is not a copy of the
  string, because the destination local is at most eight bytes wide while the
  advert lines are eighteen characters.

  Sink is empty on purpose. What is measured is the CALLER. }

interface

procedure Sink(S : String);
procedure PassLiteral;
procedure PassVariable;

implementation

var
  Global : String;

procedure Sink(S : String);
begin
end;

procedure PassLiteral;
begin
  Sink('     WELCOME      ');
end;

procedure PassVariable;
begin
  Sink(Global);
end;

end.
