unit Strshort;

{ PROBE: the same call as STRLIT.PAS, with the parameter declared as a SHORT
  string. One thing differs -- Sink takes a String[18] rather than a String --
  so whatever changes in the caller is attributable to that and nothing else.

  [re] TP6 REFUSES `S : String[18]` INLINE: `Error 89: ")" expected`. A short
  string parameter has to go through a named type, so if the original's display
  routines take one, its source declares a type for it. That is a constraint on
  the reconstruction's shape, not just on this probe.

  See STRLIT.PAS for why this is measured rather than argued. }

interface

type
  TLine = String[18];

procedure Sink(S : TLine);
procedure PassLiteral;

implementation

procedure Sink(S : TLine);
begin
end;

procedure PassLiteral;
begin
  Sink('     WELCOME      ');
end;

end.
