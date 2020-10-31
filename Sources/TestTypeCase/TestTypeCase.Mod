MODULE TestTypeCase;
  (*
   * Test of a type case statement
   *
   *    CASE x OF
   *       T1: S1
   *     | T2: S2
   *    ELSE S3
   *    END
   *
   * which implements the following rules and restrictions:
   *
   * - Case variables must be simple identifiers that cannot be followed by selectors, i.e. they
   *   cannot be elements of a structure (such as array elements or record fields).
   * - The case variable cannot be a global variable, but must be either a local variable of pointer
   *   type, a value parameter of pointer type or a variable parameter of record type.
   * - A case variable of pointer type cannot be passed as a variable parameter to a procedure.
   * - Case variables cannot be assigned to a different value by the statements Si of a type case
   *   statement. However, individual elements (fields) of case variables may be modified.
   * - If the value of the case expression does not correspond to any case label in the source text,
   *   the statement sequence following the symbol ELSE is selected, if there is one, otherwise no
   *   action is taken.
   *)

  TYPE R0 = RECORD fld0: INTEGER END; 
    R1 = RECORD (R0) fld1: INTEGER END ;
    R2 = RECORD (R0) fld2: INTEGER END ;

    P0 = POINTER TO R0;
    P1 = POINTER TO R1;
    P2 = POINTER TO R2;

    A = ARRAY OF INTEGER;  (*open array*)
    P = POINTER TO A;

  VAR p: P; p0: P0; p1: P1; p2: P2;
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
    CASE p0 OF  (*ERROR "invalid case variable" - global case variables are not allowed*)
      P1:
        AssignGlobal();  (*if p were allowed to be global, the dynamic type of p0 would be set to P2 here*)
        p0.fld1 := 123  (*and there would be a type violation here, as p0 is considered of type P1*)
    END
  END check0;

  PROCEDURE check1();
    VAR p, pa: P0;
  BEGIN p := p1;
    CASE p OF
      P1:
        pa := p;
        Proc1(p);
        Proc2(p);  (*ERROR "invalid parameter" - cannot pass a case variable of a pointer type as a VAR parameter*)
        Proc5(p.fld1);
        p := p2;  (*ERROR "invalid assignment"  - cannot modify a case variable through an assignment*)
        p.fld1 := 123;
        CASE pa OF
          P1:
            Proc1(p);
            Proc2(p)   (*ERROR "invalid parameter" - cannot pass a case variable of a pointer type as a VAR parameter*)
        END ;
        p := p1  (*ERROR "invalid assignment" - cannot modify a case variable through an assignment*)
    END
  END check1;

  PROCEDURE check2();
  BEGIN p0 := p1;
    IF p0 IS P1 THEN
      AssignGlobal();  (*the runtime type of p0 is not P1 anymore, but P2, after this statement*)
      p0(P1).fld1 := 123;  (*thereore, there (correctly) will be a type guard failure at runtime here*)
    END
  END check2;

  PROCEDURE check3(VAR r: R0);
    VAR rr: R1;
  BEGIN r := r1; (*projection of the fields of R1 onto the fiels of R0*)
    CASE r OF
      R1:
        rr := r;
        r := r1;  (*ERROR "invalid assignment" - cannot modify a case variable through an assignment*)
        Proc3(r);
        Proc4(r);
        r.fld1 := 234
    END
  END check3;

  PROCEDURE check4();
    VAR r: R1;
  BEGIN r := r1;
    CASE r OF  (*ERROR "invalid case variable" - a record must be a variable parameter*)
      R1: r.fld1 := 345
    END ;
  END check4;

  PROCEDURE check5(p: P0);
  BEGIN
    CASE p OF
      P1: Proc6(p IS P1)
    END
  END check5;

  PROCEDURE check6(VAR p: P0);
  BEGIN
    CASE p OF P1:  (*ERROR "invalid case variable" - a pointer must be either a local variable or a value parameter*)
      p0 := p2;
      p.fld1 := {4,1}
    END;
  END check6;

  PROCEDURE check7();
    VAR q: P;
  BEGIN q := p;
    CASE q OF  (*ERROR "invalid case variable" - a pointer must be a pointer to record*)
      P: q[3] := 3
    END
  END check7;

  PROCEDURE Go*;
  BEGIN
    check0();
    check1();
    check2();
    check3(r0);
    check4();
    check5(p0);
    p0 := p1; check6(p0);
    check7()
  END Go;

BEGIN NEW(p, 100); NEW(p0); NEW(p1); NEW(p2)
END TestTypeCase.

ORP.Compile TestTypeCase.Mod/s ~
System.Free TestTypeCase ~
TestTypeCase.Go
