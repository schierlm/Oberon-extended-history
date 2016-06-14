MODULE Viewers; (*JG 14.9.90 / NW 15.9.13 / AP 13.6.16*)
  CONST restore* = 0; modify* = 1; suspend* = 2; consume* = 3; track* = 4; defocus* = 5; neutralize* = 6; mark* = 7;
    inf = 65535; DnLength* = 24;

  TYPE Msg* = RECORD END;
    Viewer* = POINTER TO ViewerDesc;
    Handler* = PROCEDURE (V: Viewer; VAR M: Msg);
    ViewerDesc* = RECORD
      prev, next*, dsc*, parent*: Viewer;    (*parent = NIL for top level viewers and display areas*)
      X*, Y*, W*, H*, minH*: INTEGER;
      handle*: Handler;
      state*: INTEGER                        (*>1: displayed; 1: filler; 0: closed; <0: suspended*)
    END;

    Display* = POINTER TO DisplayDesc;       (*logical display area*)
    DisplayDesc* = RECORD (ViewerDesc)
      curW*, id*: INTEGER;
      name*: ARRAY DnLength OF CHAR;
      focusViewer*, backup: Viewer
    END;

    ViewerMsg* = RECORD (Msg)
      id*: INTEGER;                          (*restore, modify, suspend*)
      X*, Y*, W*, H*: INTEGER;
      state*: INTEGER;
    END;

    InputMsg* = RECORD (Msg)
      id*, X*, Y*: INTEGER;                  (*consume, track*)
      keys*: SET;
      ch*: CHAR
    END;

    ControlMsg* = RECORD (Msg)
      id*, X*, Y*: INTEGER                   (*defocus, neutralize, mark*)
    END;

    CopyMsg* = RECORD (Msg)
      V*: Viewer
    END;

  VAR nextId: INTEGER;
    CurDisplay*, FillerDisplay: Display;

  PROCEDURE This* (D: Display; X, Y: INTEGER): Viewer;
    VAR T, V: Viewer;
  BEGIN
    IF (X < inf) & (Y < D.H) THEN
      T := D.dsc;
      REPEAT T := T.next UNTIL X < T.X + T.W;
      V := T.dsc;
      REPEAT V := V.next UNTIL Y < V.Y + V.H
    ELSE V := NIL
    END;
    RETURN V(Viewer)
  END This;

  PROCEDURE ThisViewer* (V: Viewer): Viewer;
  BEGIN WHILE V.parent # NIL DO V := V.parent END; RETURN V (*toplevel viewer*)
  END ThisViewer;

  PROCEDURE ThisDisplay* (V: Viewer): Display;
  BEGIN WHILE V.parent # NIL DO V := V.parent END;
    WHILE V.state # 1 DO V := V.next END; (*filler viewer*)
    RETURN V.parent.parent(Display) (*track, display*)
  END ThisDisplay;

  PROCEDURE SetFocusViewer* (V: Viewer); (*V in CurDisplay*)
  BEGIN CurDisplay.focusViewer := V
  END SetFocusViewer;

  PROCEDURE PassFocus* (V: Viewer); (*V in CurDisplay*)
    VAR M: ControlMsg;
  BEGIN M.id := defocus; CurDisplay.focusViewer.handle(CurDisplay.focusViewer, M); SetFocusViewer(V)
  END PassFocus;

  PROCEDURE Adjust* (V: Viewer; id, Y, H: INTEGER);
    VAR M: ViewerMsg;
  BEGIN M.id := id; M.Y := Y; M.H := H; V.handle(V, M); V.Y := Y; V.H := H
  END Adjust;

  PROCEDURE Open* (D: Display; V: Viewer; X, Y: INTEGER);
    VAR T, v: Viewer;
  BEGIN
    IF (V.state = 0) & (X < inf) THEN
      IF Y > D.H THEN Y := D.H END;
      T := D.dsc.next;
      WHILE X >= T.X + T.W DO T := T.next END;
      v := T.dsc.next;
      WHILE Y > v.Y + v.H DO v := v.next END;
      IF Y < v.Y + V.minH THEN Y := v.Y + V.minH END;
      V.X := T.X; V.W := T.W; V.Y := v.Y; V.H := Y - v.Y;
      Adjust(v, modify, Y, v.Y + v.H - Y);
      V.next := v; V.prev := v.prev; v.prev.next := V; v.prev := V;
      V.parent := NIL; V.state := 2
    END
  END Open;

  PROCEDURE Close* (V: Viewer);
    VAR D: Display; M: ViewerMsg;
  BEGIN
     IF V.state > 1 THEN D := ThisDisplay(V);
      M.id := suspend; M.state := 0; V.handle(V, M); V.state := 0; D.backup := V;
      Adjust(V.next, modify, V.Y, V.H + V.next.H);
      V.prev.next := V.next; V.next.prev := V.prev
    END
  END Close;

  PROCEDURE Recall* (D: Display; VAR V: Viewer);
  BEGIN V := D.backup (*last closed viewer*)
  END Recall;

  PROCEDURE Validate* (V: Viewer; VAR Y, H: INTEGER);
    VAR D: Display; v: Viewer; s: INTEGER;
  BEGIN
    IF V.state > 1 THEN D := ThisDisplay(V);
      IF H < V.minH THEN H := V.minH END;
      v := V.prev; s := 0;
      WHILE v.state > 1 DO s := s + v.minH; v := v.prev END;
      IF Y < s THEN Y := s END;
      v := V.next; s := 0;
      WHILE v.state > 1 DO s := s + v.minH; v := v.next END;
      IF Y > D.H - s - V.minH THEN Y := D.H - s - V.minH; H := V.minH
      ELSIF Y + H > D.H - s THEN H := D.H - s - Y
      END
    END
  END Validate;

  PROCEDURE Change* (V: Viewer; Y, H: INTEGER);
    CONST none = 0; self = 1; above = 2; below = 3;
    VAR u, v: Viewer; a, b: BOOLEAN; i, y, dY: INTEGER; m: ARRAY 3 OF INTEGER;
  BEGIN (*Y,H validated*)
    IF V.state > 1 THEN
      m[0] := none; m[1] := self; m[2] := none; a := Y + H > V.Y + V.H; b := Y + H < V.Y + V.H;
      IF Y < V.Y THEN m[0] := below;
        IF a THEN  m[1] := above; m[2] := self ELSIF b THEN m[2] := above END
      ELSIF Y > V.Y THEN m[2] := below;
        IF a THEN m[0] := above ELSIF b THEN m[0] := self; m[1] := above END
      ELSE
        IF a THEN m[0] := above ELSIF b THEN m[2] := above ELSE m[1] := none END
      END;
      FOR i := 0 TO 2 DO (*modify viewers in the right order*) v := V.next; u := V.prev;
        IF m[i] = self THEN Adjust(V, modify, Y, H)
        ELSIF m[i] = above THEN
          IF a THEN dY := Y + H - V.Y - V.H;
            WHILE (v.state > 1) & (dY > v.H - v.minH) DO dY := dY - v.H + v.minH; v := v.next END;
            y := v.Y;
            IF v.state > 1 THEN Adjust(v, modify, y + dY, v.H - dY); v := v.prev; y := y + dY - v.minH
            ELSE v.Y := v.Y + dY; v.H := v.H - dY; v := v.prev; y := y + dY - v.minH
            END;
            WHILE v # V DO Adjust(v, modify, y, v.minH); v := v.prev; y := y - v.minH END
          ELSE Adjust(v, modify, Y + H, v.Y + v.H - Y - H)
          END
        ELSIF (m[i] = below) & (u.state > 1) THEN
          IF Y > V.Y THEN Adjust(u, modify, u.Y, Y - u.Y)
          ELSE dY := V.Y - Y;
            WHILE (u.state > 1) & (dY > u.H - u.minH) DO dY := dY - u.H + u.minH; u := u.prev END;
            IF u.state > 1 THEN Adjust(u, modify, u.Y, u.H - dY); y := u.Y + u.H ELSE y := u.Y END;
            u := u.next;
            WHILE u # V DO Adjust(u, modify, y, u.minH); y := y + u.H; u := u.next END
          END
        END
      END
    END
  END Change;

  PROCEDURE Locate* (D: Display; X, H: INTEGER; VAR fil, bot, max: Viewer);
    VAR T, V: Viewer;
  BEGIN
    IF X < inf THEN T := D.dsc;
      REPEAT T := T.next UNTIL X < T.X + T.W;
      fil := T.dsc; bot := fil.next; max := fil; V := fil.next;
      WHILE V # fil DO
        IF V.H > max.H THEN max := V END;
        V := V.next
      END
    END
  END Locate;

  PROCEDURE BroadcastDisplay* (D: Display; VAR M: Msg); (*to specified display*)
    VAR T, V: Viewer;
  BEGIN T := D.dsc.next;
    WHILE T # D.dsc DO V := T.dsc; 
      REPEAT V := V.next; V.handle(V, M) UNTIL V = T.dsc;
      T := T.next
    END
  END BroadcastDisplay;

  PROCEDURE Broadcast* (VAR M: Msg); (*to current display*)
  BEGIN BroadcastDisplay(CurDisplay, M)
  END Broadcast;

  PROCEDURE BroadcastAll* (VAR M: Msg); (*to all displays*)
    VAR S: Viewer;
  BEGIN S := FillerDisplay.next;
    WHILE S # FillerDisplay DO BroadcastDisplay(S(Display), M); S := S.next END
  END BroadcastAll;

  PROCEDURE SetDisplay* (D: Display);
    VAR M: ViewerMsg;
  BEGIN
    IF CurDisplay # NIL THEN M.id := suspend; Broadcast(M); CurDisplay.state := -CurDisplay.state END;
    CurDisplay := D(Display); CurDisplay.state := -CurDisplay.state;
    M.id := restore; BroadcastDisplay(CurDisplay, M)
  END SetDisplay;

  PROCEDURE GetDisplay* (id: INTEGER): Display;
    VAR S: Viewer;
  BEGIN S := FillerDisplay;
    REPEAT S := S.next UNTIL (S = FillerDisplay) OR (S(Display).id = id);
    IF S = FillerDisplay THEN S := NIL END;
    RETURN S(Display)
  END GetDisplay;

  PROCEDURE CloseDisplay* (id: INTEGER); (*unless it is the current display*)
    VAR D: Display;
  BEGIN D := GetDisplay(id);
    IF (D # NIL) & (D.id # CurDisplay.id) THEN D.state := 0; D.prev.next := D.next; D.next.prev := D.prev END
  END CloseDisplay;

  PROCEDURE SetDisplayName* (D: Display; name: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < DnLength) & (name[i] > 0X) DO D.name[i] := name[i]; INC(i) END;
    IF i < DnLength THEN D.name[i] := 0X END
  END SetDisplayName;

  PROCEDURE InitFiller (X, Y, W, H, minH: INTEGER; Filler: Viewer);
  BEGIN Filler.X := X; Filler.Y := Y; Filler.W := W; Filler.H := H; Filler.minH := minH;
    Filler.state := 1; Filler.next := Filler; Filler.prev := Filler
  END InitFiller;

  PROCEDURE InitTrack* (D: Display; W, H: INTEGER; Filler: Viewer);
    VAR T, fillerTrack, fillerViewer: Viewer;
  BEGIN InitFiller(D.curW, 0, W, H, 0, Filler);
    NEW(T); Filler.parent := T; T.parent := D; T.dsc := Filler;
    T.X := D.curW; T.W := W; T.Y := 0; T.H := H; T.minH := 0;
    fillerTrack := D.dsc; fillerViewer := fillerTrack.dsc;
    fillerViewer.X := D.curW + W; fillerViewer.W := inf - fillerViewer.X;
    fillerTrack.X := fillerViewer.X; fillerTrack.W := fillerViewer.W;
    T.next := fillerTrack; T.prev := fillerTrack.prev; T.prev.next := T; fillerTrack.prev := T;
    D.curW := D.curW + W
  END InitTrack;

  PROCEDURE InitDisplay* (D: Display; W, H: INTEGER; name: ARRAY OF CHAR);
    VAR fillerTrack, fillerViewer: Viewer;
  BEGIN D.id := nextId; SetDisplayName(D, name);
    D.X := 0; D.W := W; D.Y := 0; D.H := H; D.state := 2; D.curW := 0; D.minH := 1;
    D.focusViewer := NIL; D.backup := NIL; D.parent := NIL;
    NEW(fillerTrack); InitFiller(0, 0, inf, H, 0, fillerTrack); D.dsc := fillerTrack;
    NEW(fillerViewer); InitFiller(0, 0, inf, H, 0, fillerViewer); fillerTrack.dsc := fillerViewer;
    fillerViewer.parent := fillerTrack; fillerTrack.parent := D;
    D.next := FillerDisplay; D.prev := FillerDisplay.prev; D.prev.next := D; FillerDisplay.prev := D;
    nextId := nextId + 1
  END InitDisplay;

BEGIN CurDisplay := NIL; nextId := 0;
  NEW(FillerDisplay); InitFiller(0, 0, inf, inf, 0, FillerDisplay); FillerDisplay.dsc := NIL;
  FillerDisplay.curW := 0; FillerDisplay.id := -1; FillerDisplay.name := "FillerDisplay";
  FillerDisplay.focusViewer := NIL; FillerDisplay.backup := NIL; FillerDisplay.parent := NIL
END Viewers.
