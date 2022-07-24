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

MODULE B1;
  IMPORT M1;
  TYPE T2* = RECORD (M1.T1) ch: CHAR END ;  (*re-imports the type M0.T0, but module M0 remains invisible*)
  VAR a: M1.T1; b: T2;
    M0: INTEGER;                            (*no error message*)
BEGIN a := b
END B1.

MODULE B2;
  IMPORT M1;
  TYPE T2* = RECORD (M1.T1) ch: CHAR END ;  (*re-imports the type M0.T0, but module M0 remains invisible*)
    M0 = RECORD x: INTEGER END ;            (*no error message*)
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

MODULE C1; IMPORT M, M; END C1.              (*mult def*)
MODULE C2; IMPORT M, M := M0; END C2.        (*mult def*)
MODULE C3; IMPORT M := M0, M; END C3.        (*mult def*)
MODULE C4; IMPORT M := M0, M := M0; END C4.  (*mult def*)
MODULE C5; IMPORT X := M, X := M0; END C5.   (*mult def*)

MODULE C6; IMPORT M, X := M; END C6.         (*mult def*)
MODULE C7; IMPORT X := M, M; END C7.         (*mult def*)
MODULE C8; IMPORT X := M, Y := M; END C8.    (*mult def*)
MODULE C9; IMPORT M, X := M, Y := M; END C9. (*mult def 2x*)

MODULE C10; IMPORT M1, M0; END C10.          (*invalid import order in Variant 1, no error message in Variant 2*)

--------------------------- Test suite D ------------------------------------

ORP.Compile @/s ~

MODULE D1;                                  (*mult def*)
  IMPORT M := M0, M0;                       (*because a module M0 is imported under *two* different names M and M0*)
  VAR a: M.T0; b: M0.T0;
BEGIN a := b
END D1.

MODULE D2;                                  (*mult def*)
  IMPORT M := M0, M2, M;                    (*because the name M is used twice, once as an alias, once as a module name*)
  TYPE T3* = RECORD (M2.T2) ch: CHAR END ;
  VAR a: M2.T2; b: T3; c: M.T0;
BEGIN a := b; c := b
END D2.

MODULE D3;                                  (*mult def*)
  IMPORT M := M0, M := M2;                  (*because the name M is used twice as an alias*)
END D3.

MODULE D4;                                  (*mult def*)
  IMPORT M, M := M0, M2;                    (*because the name M is used twice, once as an alias, once as a module name*)
  TYPE T3* = RECORD (M2.T2) ch: CHAR END ;
  VAR a: M2.T2; b: T3; c: M.T0;
BEGIN a := b; c := b
END D4.

MODULE D5;                                  (*no error message*)
  IMPORT M0, M1;
  VAR a: M0.T0; b: M1.T1;
BEGIN a := b
END D5.

MODULE D6;                                  (*invalid import order in Variant 1, no error message in Variant 2*)
  IMPORT M1, M0;
  VAR a: M0.T0; b: M1.T1;
BEGIN a := b
END D6.

MODULE D7;                                  (*no error message*)
  IMPORT M3, M4;
  VAR a: M3.T3; b: M4.T4;
BEGIN a := b
END D7.

MODULE D8;                                  (*invalid import order in Variant 1, no error message in Variant 2*)
  IMPORT M4, M3;
  VAR a: M3.T3; b: M4.T4;
BEGIN a := b
END D8.


--------------------------- Test suite E ------------------------------------

ORP.Compile @/s ~

MODULE E0;
 TYPE A* = RECORD i: INTEGER END ;
   B* = A;
END E0.

MODULE E1;
  IMPORT E0;
  VAR a*: E0.A;  (*re-exports E0.A, but not E0.B*)
END E1.

MODULE E2;
  IMPORT E1, E0;  (*E1 re-imports E0.A*)
  VAR a*: E0.A; b*: E0.B;
BEGIN a := b
END E2.
