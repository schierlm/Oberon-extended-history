MODULE M1;
  IMPORT M0;

  TYPE Ptr* = POINTER TO Rec;
    Rec* = RECORD (M0.Rec) END ;  (*extension of M0.Rec*)
    PtrArr* = M0.PtrArr;
    PtrArrProc* = M0.PtrArrProc;

  VAR gptr*: Ptr;
    gptrarr*: PtrArr;
    gproc*: M0.Proc;
    garrproc*: M0.PtrArrProc;

  PROCEDURE P*; BEGIN END P;

  PROCEDURE SetGlobalPtr*(q: M0.Ptr); BEGIN gptr := q(Ptr) END SetGlobalPtr;
  PROCEDURE SetDynamicPtr*(q: M0.Ptr); BEGIN gptr.ptr := q(Ptr) END SetDynamicPtr;

  PROCEDURE SetGlobalPtrArr*(q: M0.PtrArr); BEGIN gptrarr := q(PtrArr) END SetGlobalPtrArr;
  PROCEDURE SetDynamicPtrArr*(q: M0.PtrArr); BEGIN gptrarr[1].ptr := q(PtrArr) END SetDynamicPtrArr;

  PROCEDURE SetGlobalProc*(q: M0.Proc); BEGIN gproc := q END SetGlobalProc;
  PROCEDURE SetDynamicProc*(q: M0.Proc); BEGIN gptr.proc := q END SetDynamicProc;

  PROCEDURE SetDynamicArrRec*(q: M0.Proc); BEGIN gptrarr[2].x := 8; gptrarr[2].proc := q END SetDynamicArrRec;
  PROCEDURE SetDynamicArrProc*(q: M0.Proc); BEGIN garrproc[2] := q END SetDynamicArrProc;

  PROCEDURE Init*; BEGIN END Init;

BEGIN NEW(gptr); NEW (gptrarr, 10); NEW(garrproc, 150)
END M1.
