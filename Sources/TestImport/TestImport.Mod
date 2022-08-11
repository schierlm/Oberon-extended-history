--------------------------- Preparation for subsequent test suites ----------

ORP.Compile @/s ~

MODULE M;                                   (*no error message*)
  TYPE T0* = RECORD i: INTEGER END ;
END M.

MODULE M0;                                  (*no error message*)
  TYPE T0* = RECORD i: INTEGER END ;
END M0.

MODULE M1;                                  (*no error message*)
  IMPORT M0;
  TYPE T1* = RECORD (M0.T0) j: INTEGER END ;
  VAR a: M0.T0; b: T1;
BEGIN a := b
END M1.

MODULE M2;                                  (*no error message*)
  IMPORT M0, M1;
END M2.

MODULE M3;                                  (*no error message*)
  TYPE T3* = POINTER TO R3;
    R3* = RECORD i: INTEGER END ;
END M3.

MODULE M4;                                  (*no error message*)
  IMPORT M3;
  TYPE T4* = POINTER TO R4;
    R4* = RECORD (M3.R3) j: INTEGER END ;
  VAR a: M3.T3; b: T4;
BEGIN a := b
END M4.

--------------------------- Test suite A ------------------------------------

ORP.Compile @/s ~

MODULE A0; IMPORT M0, X := M1; END A0.      (*no error message*)
MODULE A1; IMPORT M1 := M, M := M0; END A1. (*no error message (M imported under alias M1, M then reused as alias for M0)*)
MODULE A2; IMPORT M0 := M, M := M0; END A2. (*no error message (M imported under alias M0, M then reused as alias for M0)*)
MODULE A3; IMPORT M0 := M, X := M0; END A3. (*no error message (M imported under alias M0, M0 then imported under alias X)*)

MODULE A4; IMPORT M0, M1; END A4.           (*no error message (M0 first explicitly imported, then (only) re-imported) by M1*)
MODULE A5; IMPORT M := M0, M1; END A5.      (*no error message (M0 first explicitly imported, then (only) re-imported) by M1*)

MODULE A6; IMPORT M1, M0 := M; END A6.      (*no error message*)
MODULE A7; IMPORT M0 := M, M1; END A7.      (*no error message*)

--------------------------- Test suite B --------------------------------------

ORP.Compile @/s ~

MODULE B1;                                  (*no error message*)
  IMPORT M1;
  TYPE T2* = RECORD (M1.T1) ch: CHAR END ;  (*re-imports the type M0.T0, but module M0 remains invisible*)
  VAR a: M1.T1; b: T2;
    M0: INTEGER;
BEGIN a := b
END B1.

MODULE B2;                                  (*no error message*)
  IMPORT M1;
  TYPE T2* = RECORD (M1.T1) ch: CHAR END ;  (*re-imports the type M0.T0, but module M0 remains invisible*)
    M0 = RECORD x: INTEGER END ;
    T3 = POINTER TO M0;
  VAR a: M1.T1; b: T2;
BEGIN a := b
END B2.

MODULE B3;                                  (*no error message*)
  IMPORT M := M0, M1;
  VAR a: M.T0; b: M1.T1;
BEGIN a := b
END B3.

MODULE B4;                                  (*no error message*)
  IMPORT M := M0, M0 := M1;
  VAR a: M.T0; b: M0.T1;
BEGIN a := b
END B4.

MODULE B5;                                  (*no error message*)
  IMPORT Y1 := M0, M1;
  VAR a: Y1.T0; b: M1.T1;
BEGIN a := b
END B5.

MODULE B6;                                  (*no error message*)
  IMPORT D := Display, Oberon;              (*module Display is explicitly imported before it is re-imported by module Oberon*)
  VAR m1: D.FrameMsg; m2: Oberon.InputMsg;
  PROCEDURE Handle(V: D.Frame; VAR M: D.FrameMsg);
  BEGIN
    CASE M OF
      Oberon.InputMsg: m2 := M |
      D.FrameMsg: m1 := M
    END
  END Handle;
END B6.

MODULE B7;                                  (*no error message*)
  IMPORT M1, M0 := M;                       (*M1 re-imports M0, but there is no conflict with the alias name M0*)
  VAR a: M0.T0; b: M1.T1;
BEGIN (*a := b*)                            (*this, however, WOULD be an illegal assignment, because M0.T0 is in fact M.T0*)
END B7.

MODULE B8;                                  (*no error mesage*)
  IMPORT M0 := M, M1;                       (*M1 re-imports M0, but there is no conflict with the alias name M0*)
  VAR a: M0.T0; b: M1.T1;
BEGIN (*a := b*)                            (*this, however, WOULD be an illegal assignment, because M0.T0 is in fact M.T0*)
END B8.


--------------------------- Test suite C ------------------------------------

ORP.Compile @/s ~

MODULE C1;                                  (*no error message*)
  IMPORT M0, M1;
  VAR a: M0.T0; b: M1.T1;
BEGIN a := b
END C1.

MODULE C2;                                  (*no error message*)
  IMPORT M1, M0;                            (*M0 is first-reimported by M1, then M0 is xexplicitly imported*)
  VAR a: M0.T0; b: M1.T1;
BEGIN a := b
END C2.

MODULE C3;                                  (*no error message*)
  IMPORT M3, M4;
  VAR a: M3.T3; b: M4.T4;
BEGIN a := b
END C3.

MODULE C4;                                  (*no error message*)
  IMPORT M4, M3;                            (*M4 is first-reimported by M4, then M3 is xexplicitly imported*)
  VAR a: M3.T3; b: M4.T4;
BEGIN a := b
END C4.

--------------------------- Test suite D ------------------------------------

ORP.Compile @/s ~

MODULE D0;                                  (*no error message*)
 TYPE A* = RECORD i: INTEGER END ;
   B* = A;
END D0.

MODULE D1;                                  (*no error message*)
  IMPORT D0;
  VAR a*: D0.A;                             (*re-exports E0.A, but not E0.B*)
END D1.

MODULE D2;                                  (*no error message*)
  IMPORT D1, D0;                            (*E1 re-imports E0.A*)
  VAR a*: D0.A; b*: D0.B;
BEGIN a := b
END D2.

--------------------------- Test suite E (should produce error messages) ------------------------------------

ORP.Compile @/s ~

MODULE E1; IMPORT M, M; END E1.              (*mult def*)
MODULE E2; IMPORT M, M := M0; END E2.        (*mult def*)
MODULE E3; IMPORT M := M0, M; END E3.        (*mult def*)
MODULE E4; IMPORT M := M0, M := M0; END E4.  (*mult def*)
MODULE E5; IMPORT X := M, X := M0; END E5.   (*mult def*)

MODULE E6; IMPORT M, X := M; END E6.         (*mult def*)
MODULE E7; IMPORT X := M, M; END E7.         (*mult def*)
MODULE E8; IMPORT X := M, Y := M; END E8.    (*mult def*)
MODULE E9; IMPORT M, X := M, Y := M; END E9. (*mult def 2x*)

MODULE E10;                                 (*mult def*)
  IMPORT M1, M0 := M, M0;                   (*M1 re-imports M0, initially no conflict with the alias name M0, but then conflict*)
  VAR a: M0.T0; b: M1.T1;                   (*the direct import of M0 turns a previous re-import of M0 into an explicit one*)
END E10.                                    (*this too must be detected*)

--------------------------- Test suite F (should produce error messages) ------------------------------------

ORP.Compile @/s ~

MODULE F1;                                  (*mult def*)
  IMPORT M := M0, M0;                       (*because a module M0 is imported under *two* different names M and M0*)
  VAR a: M.T0; b: M0.T0;
BEGIN a := b
END F1.

MODULE F2;                                  (*mult def*)
  IMPORT M := M0, M2, M;                    (*because the name M is used twice, once as an alias, once as a module name*)
  TYPE T3* = RECORD (M2.T2) ch: CHAR END ;
  VAR a: M2.T2; b: T3; c: M.T0;
BEGIN a := b; c := b
END F2.

MODULE F3;                                  (*mult def*)
  IMPORT M := M0, M := M2;                  (*because the name M is used twice as an alias*)
END F3.

MODULE F4;                                  (*mult def*)
  IMPORT M, M := M0, M2;                    (*because the name M is used twice, once as an alias, once as a module name*)
  TYPE T3* = RECORD (M2.T2) ch: CHAR END ;
  VAR a: M2.T2; b: T3; c: M.T0;
BEGIN a := b; c := b
END F4.
