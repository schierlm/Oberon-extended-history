MODULE TestTypeCase;  (*test type case statements / AP 1.10.21*)

  TYPE P0 = POINTER TO R0;
    P1 = POINTER TO R1;
    P2 = POINTER TO R2;

    R0 = RECORD fld0: INTEGER; ptr0: P0 END ;
    R1 = RECORD (R0) fld1: INTEGER; ptr1: P1 END ;
    R2 = RECORD (R0) fld2: INTEGER; ptr2: P2 END ;


  VAR p0: P0; p1: P1; p2: P2;
    r0: R0; r1: R1; r2: R2;

  PROCEDURE AssignGlobal();
  BEGIN p0 := p2
  END AssignGlobal;

  PROCEDURE Proc1(p0: P0); BEGIN END Proc1;
  PROCEDURE Proc2(VAR p1: P1); BEGIN END Proc2;
  PROCEDURE Proc3(VAR r0: R0); BEGIN r0 := r2 (*projection*) END Proc3;
  PROCEDURE Proc4(r0: R0); BEGIN END Proc4;
  PROCEDURE Proc5(VAR i: INTEGER); BEGIN END Proc5;
  PROCEDURE Proc6(b: BOOLEAN); BEGIN END Proc6;

  PROCEDURE check0();
  BEGIN p0 := p1;
    CASE p0 OF
      P1:
        AssignGlobal();    (*this sets the dynamic type of p0 to P2 - this is explicitly allowed*)
        p0.fld1 := 123     (*but there is a type violation here at runtime, as p0 is considered of type P1*)
    END
  END check0;

  PROCEDURE check1();
    VAR p, pa: P0;
  BEGIN p := p1;
    CASE p OF
      P1:
        pa := p;
        Proc1(p);
        Proc2(p);
        Proc5(p.fld1);
        (*p := p2;*)       (*this be an illegal assignment, as the dynamic type of p is P1 here*)
        p.fld1 := 123;
        CASE p OF
          P1:
            p := p1;
            Proc1(p);
            Proc2(p)
        END ;
        p := p1
    END
  END check1;

  PROCEDURE check2();
  BEGIN p0 := p1;
    IF p0 IS P1 THEN
      AssignGlobal();      (*after this statement, the runtime type of p0 is not P1 anymore, but P2*)
      (*p0(P1).fld1 := 123;*)  (*thereore, there (correctly) would be a TRAP 2 type guard failure at runtime here*)
    END
  END check2;

  PROCEDURE check3(VAR r: R0);
    VAR rr: R1;
  BEGIN r := r1;           (*projection of the fields of r1 onto the fiels of r0*)
    CASE r OF
      R1:
        rr := r;
        r := r1;           (*projection of the fields of r1 onto the fiels of r0*)
        Proc3(r);
        Proc4(r);
        r.fld1 := 234
    END
  END check3;

  PROCEDURE check4();
    VAR r: R1;
  BEGIN r := r1;
    (*
    CASE r OF             (*would be an invalid case expression, as a record must be a variable parameter*)
      R1: r.fld1 := 345
    END
    *)
  END check4;

  PROCEDURE check5(p: P0);
  BEGIN
    CASE p OF
      P1: Proc6(p IS P1)
    END
  END check5;

  PROCEDURE check6(VAR p: P0);
  BEGIN
    CASE p OF P1:
      p0 := p2;
      p.fld1 := 1
    END
  END check6;

  PROCEDURE check7();
    VAR p: P0;
  BEGIN p := p1; p.fld0 := 33;
    CASE p.fld0 OF         (*selecting a field is allowed for the numeric case statement*)
      33..44: INC(p.fld0)
    END
  END check7;

  PROCEDURE check8();
    VAR p: P0;
  BEGIN p := p1; p.ptr0 := p1;
    (*
    CASE p.ptr0 OF         (*would be an invalid case expression, as selecting a field is NOT allowed for the type case statement*)
      P1: p.fld0 := 35
    END
    *)
  END check8;

  PROCEDURE Go0*;
  BEGIN check0()
  END Go0;

  PROCEDURE Go1*;
  BEGIN check1()
  END Go1;

  PROCEDURE Go2*;
  BEGIN check2()
  END Go2;

  PROCEDURE Go3*;
  BEGIN check3(r0)
  END Go3;

  PROCEDURE Go4*;
  BEGIN check4()
  END Go4;

  PROCEDURE Go5*;
  BEGIN check5(p0)
  END Go5;

  PROCEDURE Go6*;
  BEGIN p0 := p1; check6(p0)
  END Go6;

  PROCEDURE Go7*;
  BEGIN check7()
  END Go7;

  PROCEDURE Go8*;
  BEGIN check8()
  END Go8;

BEGIN NEW(p0); NEW(p1); NEW(p2)
END TestTypeCase.

ORP.Compile TestTypeCase.Mod/s ~
System.Free TestTypeCase ~

ORTool.DecObj TestNumericCase.rsc ~

TestTypeCase.Go0
TestTypeCase.Go1
TestTypeCase.Go2
TestTypeCase.Go3
TestTypeCase.Go4
TestTypeCase.Go5
TestTypeCase.Go6
TestTypeCase.Go7
TestTypeCase.Go8
