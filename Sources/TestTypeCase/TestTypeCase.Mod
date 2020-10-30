MODULE TestTypeCase;
  (*
   * The type case statement CASE p OF T1... | T2... END in Extended Oberon..
   *
   * Disallows...
   *
   *   1. Global case variables p in a case statement CASE p OF T1... | T2... END
   *   2. Assignments *to* case variables p *within* the scope of a CASE statement
   *   3. Passing a case variable p of type POINTER as a VAR parameter to a procedure P(p)
   *
   * Allows...
   *
   *   1. Local variables or (value or VAR) parameters as case variables
   *   2. Assignments to *fields* p.f of a case variable p (either a pointer or record)
   *   3. Passing a case variable p as a *value* parameter to a procedure P(p)
   *   4. Passing a case variable r of type RECORD as a VAR parameter to a procedure P(r),
   *      where the record r must itself be a VAR parameter in this case
   *)

  TYPE R0 = RECORD fld0: INTEGER END; 
    R1 = RECORD (R0) fld1: INTEGER END ;
    R2 = RECORD (R0) fld2: INTEGER END ;  (*same field offset as R1.fld1!*)

    P0 = POINTER TO R0;
    P1 = POINTER TO R1;
    P2 = POINTER TO R2;

  VAR p0: P0; p1: P1; p2: P2; r0: R0; r1: R1; r2: R2;

  PROCEDURE AssignGlobal();
  BEGIN p0 := p2
  END AssignGlobal;

  PROCEDURE Proc1(p0: P0); BEGIN END Proc1;
  PROCEDURE Proc2(VAR p1: P1); BEGIN END Proc2;
  PROCEDURE Proc3(VAR r0: R0); BEGIN r0 := r2 END Proc3; (*projection*)
  PROCEDURE Proc4(VAR i: INTEGER); BEGIN END Proc4;
  PROCEDURE Proc5(b: BOOLEAN); BEGIN END Proc5;

  PROCEDURE check0();
  BEGIN p0 := p1;  (*sets the dynamic type of the global variable p0 to P1*)
    CASE p0 OF (*ERROR "global case variable not allowed"*)
      P1:
        AssignGlobal(); (*if p were allowed to be global, the dynamic type of p0 would be set to P2 here*)
        p0.fld1 := 123 (*and therefore, there would be a type violation here, as the CASE stmt thinks p0 is still of type P1*)
    END ;
  END check0;

  PROCEDURE check1();
    VAR p, pa: P0;
  BEGIN p := p1;  (*sets the dynamic type of the local variable p to P1*)
    CASE p OF
    P1:
      pa := p;  (*allowed, since p is not modified*)
      Proc1(p);  (*allowed, since p is passed as a value parameter*)
      Proc2(p);  (*ERROR "not allowed" -> not allowed, since p is passed as a VAR parameter*)
      Proc4(p.fld1);  (*allowed, since a field of p, but not p itself is passed*)
      p := p2;  (*ERROR "assignment not allowed"  -> not allowed, since p is modified through an assignment*)
      p.fld1 := 123;  (*guaranteed to be correct, since the runtime type of p cannot change inside CASE*)
      CASE pa OF  (*nested case statement*)
        P1:
          Proc1(p);  (*allowed, since p is passed as a value parameter*)
          Proc2(p)   (*ERROR "not allowed" -> not allowed, since p is passed as a VAR parameter*)
      END ;
      p := p1  (*ERROR "assignment not allowed" -> not allowed, since p is modified through an assignment*)
    END
  END check1;

  PROCEDURE check2();
  BEGIN p0 := p1;  (*sets the dynamic type of the global variable p0 to P1*)
    IF p0 IS P1 THEN
      AssignGlobal(); (*the runtime type of p0 is not P1 anymore, but P2*)
      p0(P1).fld1 := 123; (*thereore, there (correctly) is a type guard failure (TRAP 2) at runtime*)
    END
  END check2;

  PROCEDURE check3(VAR r: R0);
    VAR rr: R1;
  BEGIN r := r1; (*allowed since pr is a VAR parameter (projection to fields of base type)*)
    CASE r OF
      R1:
        rr := r;  (*allowed, since r itself is not modified*)
        r := r1;  (*ERROR "assignment not allowed" -> not allowed, since r is modified through an assignment*)
        Proc3(r);  (*allowed since r is a record passed as a VAR parameter*)
        r.fld1 := 234
    END
  END check3;

  PROCEDURE check4();
    VAR r: R1;
  BEGIN r := r1;
    CASE r OF  (*ERROR "invalid type" -> not allowed since r is neither a pointer nor a VAR parameter*)
      R1: r.fld1 := 345
    END ;
  END check4;

  PROCEDURE check5(p: P0);
  BEGIN
    CASE p OF
      P1: Proc5(p IS P1)
    END
  END check5;

  PROCEDURE Go*;
  BEGIN
    check0();
    check1();
    check2();
    check3(r0);
    check4();
    check5(p0)
  END Go;

BEGIN NEW(p0); NEW(p1); NEW(p2)
END TestTypeCase.

ORP.Compile TestTypeCase.Mod/s ~
System.Free TestTypeCase ~
TestTypeCase.Go
