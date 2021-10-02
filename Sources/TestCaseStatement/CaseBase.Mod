MODULE CaseBase;
TYPE
  P* = POINTER TO PDesc;
  PDesc* = RECORD
    i*: INTEGER;
  END;

  P1* = POINTER TO P1Desc;
  P1Desc* = RECORD (PDesc)
    i1*: INTEGER;
  END;

VAR
  p*: P;
  p1: P1;

PROCEDURE First*;
BEGIN
  NEW(p);
  p.i := 1
END First;

PROCEDURE Second*;
BEGIN
  NEW(p1);
  p := p1;
  p(P1).i1 := 2
END Second;

PROCEDURE ModifyGlobal*;
BEGIN p := p1
END ModifyGlobal;

END CaseBase.


