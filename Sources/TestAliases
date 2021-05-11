--------------------------------------------------------------
TestAliases.Mod
--------------------------------------------------------------

--------------------------- Test suite #1 (no errors) --------------------------------------

ORP.Compile @/s ~

MODULE M;      (*no error message*)
  TYPE T0* = RECORD i: INTEGER END ;
END M.

MODULE M0;      (*no error message*)
  TYPE T0* = RECORD i: INTEGER END ;
END M0.

MODULE M1;      (*no error message*)
  IMPORT M0;
  TYPE T1* = RECORD (M0.T0) j: INTEGER END ;
  VAR a: M0.T0; b: T1;
BEGIN a := b
END M1.

MODULE M2;      (*no error message*)
  IMPORT M1;
  TYPE T2* = RECORD (M1.T1) k: INTEGER END ;  (*re-imports M0.T0*)
  VAR a: M1.T1; b: T2;
BEGIN a := b
END M2.

--------------------------- Test suite #2 (no errors) --------------------------------------

ORP.Compile @/s ~

MODULE M3;                     (*no error message*)
  IMPORT M := M0, M1;
  VAR a: M.T0; b: M1.T1;
BEGIN a := b
END M3.

MODULE M4;                     (*no error message*)
  IMPORT M := M0, M0 := M1;
  VAR a: M.T0;
    b: M0.T1;
BEGIN
  a := b
END M4.

MODULE M5;                     (*no error message*)
  IMPORT Y1 := M0, M1;
  VAR a: Y1.T0; b: M1.T1;
BEGIN a := b
END M5.

MODULE M6;                     (*no error message*)
  IMPORT D := Display, Oberon; (*Oberon re-imports module Display*)
  VAR m1: D.FrameMsg; m2: Oberon.InputMsg;
  PROCEDURE Handle(V: D.Frame; VAR M: D.FrameMsg);
  BEGIN
    CASE M OF
      Oberon.InputMsg: m2 := M |
      D.FrameMsg: m1 := M
    END
  END Handle;
END M6.

--------------------------- Test suite #3 (with errors) ------------------------------------

ORP.Compile @/s ~

MODULE M7;                      (*conflict with re-import*)
  IMPORT M1, M0 := M;           (*M0 is re-imported via M1 and then used as an alias name*)
  VAR a: M0.T0; b: M1.T1;
BEGIN a := b
END M7.

MODULE M8;                      (*conflict with alias*)
  IMPORT M0 := M, M1;           (*M0 is used as an alias and then re-imported via M1*)
  VAR a: M0.T0; b: M1.T1;
BEGIN a := b
END M8.

MODULE M9;                      (*mult def*)
  IMPORT M := M0, M0;           (*because a module M0 is imported under *two* different names M and M0*)
  VAR a: M.T0; b: M0.T0;
BEGIN a := b
END M9.

MODULE M10;                     (*mult def*)
  IMPORT M := M0, M2, M;        (*because the name M is used twice, once as an alias, once as a module name*)
  TYPE T3* = RECORD (M2.T2) k: INTEGER END ;
  VAR a: M2.T2; b: T3; c: M.T0;
BEGIN a := b; c := b
END M10.

MODULE M11;                     (*mult def*)
  IMPORT M := M0, M := M2;      (*because the name M is used twice as an alias*)
END M11.

MODULE M12;                     (*mult def*)
  IMPORT M, M := M0, M2;        (*because the name M is used twice, once as an alias, once as a module name*)
  TYPE T3* = RECORD (M2.T2) k: INTEGER END ;
  VAR a: M2.T2; b: T3; c: M.T0;
BEGIN a := b; c := b
END M12.

MODULE M13;                     (*invalid import order*)
  IMPORT M1, M0;                (*because M1.T1 re-imports M0.T0 *before* M0 is imported directly*)
  VAR a: M0.T0; b: M1.T1;
BEGIN a := b
END M13.

--------------------------- Test suite #4 (no errors) ------------------------------------

ORP.Compile @/s ~

MODULE B0; IMPORT M0, X := M1; END B0.  (*no error message*)
MODULE B1; IMPORT X := M, M := M0; END B1.  (*no error message*)
MODULE B2; IMPORT M := M0, M0 := M; END B2.  (*no error message*)
MODULE B3; IMPORT M0 := M, X := M0; END B3.  (*no error message*)

MODULE B4; IMPORT M0, M1; END B4.  (*no error message (M0 explicitly imported and re-imported)*)
MODULE B5; IMPORT M := M0, M1; END B5.  (*no error message (M0 explicitly imported and re-imported)*)

--------------------------- Test suite #5 (with errors) ------------------------------------

ORP.Compile @/s ~

MODULE C1; IMPORT M, M; END C1.  (*mult def*)
MODULE C2; IMPORT M, M := M0; END C2.  (*mult def*)
MODULE C3; IMPORT M := M0, M; END C3.  (*mult def*)
MODULE C4; IMPORT M := M0, M := M0; END C4.  (*mult def*)
MODULE C5; IMPORT X := M, X := M0; END C5.  (*mult def*)

MODULE C6; IMPORT M, X := M; END C6.  (*mult def*)
MODULE C7; IMPORT X := M, M; END C7.  (*mult def*)
MODULE C8; IMPORT M, X := M, Y := M; END C8.  (*mult def*)
MODULE C9; IMPORT X := M, Y := M; END C9.  (*mult def*)

MODULE C10; IMPORT M1, M0; END C10.  (*invalid import order*)

MODULE C11; IMPORT M1, M0 := M; END C11.  (*conflict with re-import*)
MODULE C12; IMPORT M0 := M, M1; END C12.  (*conflict with alias*)
