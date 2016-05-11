MODULE Tasks; (*AP 7.5.16*)
  IMPORT SYSTEM, Kernel, Files, Modules, Input, Display, Cursors, Viewers;

  (*Oberon's tasking system schedules interactive tasks and background tasks.
    Interactive tasks are represented by a viewer and are initiated by the user.
    Background tasks are scheduled with low priority when interactions are absent.*)

  CONST off = 0; idle = 1; active = 2;   (*task states*)
    BasicCycle = 20; ESC = 1BX; SETSTAR = 1AX;

  TYPE Task* = POINTER TO TaskDesc;
    Handler* = PROCEDURE;
    TaskDesc* = RECORD
      state, nextTime, period*: INTEGER;
      next: Task;
      handle: Handler
    END;

  VAR NofTasks*, DH: INTEGER;
    CurTask: Task;
    ActCnt: INTEGER;  (*action count for GC*)

  PROCEDURE GC;
    VAR mod: Modules.Module;
  BEGIN
    IF (ActCnt <= 0) OR (Kernel.allocated >= Kernel.heapLim - Kernel.heapOrg - 10000H) THEN
      mod := Modules.root; LED(21H);
      WHILE mod # NIL DO
        IF mod.name[0] # 0X THEN Kernel.Mark(mod.ptr) END ;
        mod := mod.next
      END ;
      LED(23H);
      Files.RestoreList; LED(27H);
      Kernel.Scan; LED(20H);
      ActCnt := BasicCycle
    END
  END GC;

  PROCEDURE NewTask*(h: Handler; period: INTEGER): Task;
    VAR t: Task;
  BEGIN NEW(t); t.state := off; t.next := t; t.handle := h; t.period := period; RETURN t
  END NewTask;
  
  PROCEDURE Install* (T: Task);
  BEGIN
    IF T.state = off THEN
      T.next := CurTask.next; CurTask.next := T; T.state := idle; T.nextTime := 0; INC(NofTasks)
    END
  END Install;

  PROCEDURE Remove* (T: Task);
    VAR t: Task;
  BEGIN
    IF T.state # off THEN t := T;
      WHILE t.next # T DO t := t.next END ;
      t.next := T.next; T.state := off; T.next := NIL; CurTask := t; DEC(NofTasks)
    END
  END Remove;

  PROCEDURE Collect* (count: INTEGER);
  BEGIN ActCnt := count
  END Collect;

  PROCEDURE Loop*;
    VAR V: Viewers.Viewer; M: Viewers.InputMsg; N: Viewers.ControlMsg;
       prevX, prevY, X, Y, t: INTEGER; keys: SET; ch: CHAR;
  BEGIN
    REPEAT
      Input.Mouse(keys, X, Y);
      IF Input.Available() > 0 THEN Input.Read(ch);
        IF ch = ESC THEN
          N.id := Viewers.neutralize; Viewers.Broadcast(N); Cursors.FadePointer; LED(0)
        ELSIF ch = SETSTAR THEN
          N.id := Viewers.mark; N.X := X; N.Y := Y; V := Viewers.This(Viewers.CurDisplay, X, Y); V.handle(V, N)
        ELSE M.id := Viewers.consume; M.ch := ch;
          Viewers.FocusViewer.handle(Viewers.FocusViewer, M); DEC(ActCnt)
        END
      ELSIF keys # {} THEN
        M.id := Viewers.track; M.X := X; M.Y := Y; M.keys := keys;
        REPEAT V := Viewers.This(Viewers.CurDisplay, M.X, M.Y); V.handle(V, M); Input.Mouse(M.keys, M.X, M.Y)
        UNTIL M.keys = {};
        DEC(ActCnt)
      ELSE
        IF (X # prevX) OR (Y # prevY) OR ~Cursors.MouseOn() THEN
          M.id := Viewers.track; M.X := X;
          IF Y >= DH THEN Y := DH END ;
          M.Y := Y; M.keys := keys; V := Viewers.This(Viewers.CurDisplay, X, Y); V.handle(V, M); prevX := X; prevY := Y
        END;
        CurTask := CurTask.next; t := Kernel.Time();
        IF t >= CurTask.nextTime THEN
          CurTask.nextTime := t + CurTask.period; CurTask.state := active; CurTask.handle; CurTask.state := idle
        END
      END
    UNTIL FALSE
  END Loop;

  PROCEDURE Reset*;
  BEGIN
    IF CurTask.state = active THEN Remove(CurTask) END ;
    SYSTEM.LDREG(14, Kernel.stackOrg); (*reset stack pointer*) Loop
  END Reset;

BEGIN DH := Display.Height;
  ActCnt := 0; CurTask := NewTask(GC, 1000); Install(CurTask)
END Tasks.
