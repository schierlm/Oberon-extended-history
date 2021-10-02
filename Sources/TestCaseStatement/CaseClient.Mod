MODULE CaseClient;

IMPORT CaseBase, Out;

PROCEDURE Test;
VAR
  x: INTEGER;
BEGIN
  CASE CaseBase.p OF
    CaseBase.P1:
      CaseBase.ModifyGlobal; (*this sets the dynamic type CaseBase.p to CaseBase.P2 => loophole?*)
      x := CaseBase.p.i1
    | CaseBase.P:  x := CaseBase.p.i
  END;
  Out.Int(x, 0);
  Out.Ln
END Test;

PROCEDURE Run*;
BEGIN
  CaseBase.First();
  Test();
  CaseBase.Second();
  Test()
END Run;

END CaseClient.
