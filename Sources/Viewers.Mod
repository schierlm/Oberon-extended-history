MODULE Viewers; (*JG 14.9.90 / NW 15.9.13 / AP 9.5.16*)
  IMPORT Display;

  CONST restore* = 0; modify* = 1; suspend* = 2; extend* = 3; reduce* = 4; (*viewer message ids*)
    consume* = 5; track* = 6; (*input message ids*)
    defocus* = 7; neutralize* = 8; mark* = 9; (*control message ids*)
    inf = 65535; DnLength* = 24;

  TYPE Msg* = RECORD END ;
    Viewer* = POINTER TO ViewerDesc;
    Handler* = PROCEDURE (V: Viewer; VAR M: Msg);
    ViewerDesc* = RECORD
      next*, dsc*: Viewer;
      X*, Y*, W*, H*: INTEGER;
      handle*: Handler;
      state*: INTEGER;
      parent*: Viewer  (*subviewer: parent viewer; toplevel viewer: NIL; filler viewer: track; track: display*)
    END;

    Track = POINTER TO TrackDesc;
    TrackDesc = RECORD (ViewerDesc) under: Viewer END;

    DisplayArea* = POINTER TO DisplayDesc;
    DisplayDesc* = RECORD (ViewerDesc)
      curW*, minH*, id*: INTEGER;
      name*: ARRAY DnLength OF CHAR;
      focusViewer*, backup: Viewer           (*backup = last closed viewer*)
    END;

    ViewerMsg* = RECORD (Msg)
      id*: INTEGER;                          (*restore, modify, suspend, extend, reduce*)
      X*, Y*, W*, H*, dY*: INTEGER;
      state*: INTEGER                        (*>1: displayed; 1: filler; 0: closed; <0: suspended*)
    END;

    InputMsg* = RECORD (Msg)
      id*: INTEGER;                          (*consume, track*)
      keys*: SET;
      X*, Y*: INTEGER;
      ch*: CHAR
    END;

    ControlMsg* = RECORD (Msg)
      id*, X*, Y*: INTEGER                   (*defocus, neutralize, mark*)
    END;

    CopyMsg* = RECORD (Msg)
      V*: Viewer
    END;

  VAR nextId, DH: INTEGER;
    FocusViewer*: Viewer;
    CurDisplay*, FillerDisplay: DisplayArea;

  PROCEDURE Handle*(V: Viewer; VAR M: Msg);
  BEGIN IF (V # NIL) & (V.handle # NIL) THEN V.handle(V, M) END
  END Handle;

  PROCEDURE ThisParent* (V: Viewer): Viewer; (*immediate parent*)
  BEGIN RETURN V.parent
  END ThisParent;

  PROCEDURE ThisViewer* (V: Viewer): Viewer; (*toplevel parent viewer*)
  BEGIN WHILE V.parent # NIL DO V := V.parent END ; RETURN V
  END ThisViewer;

  PROCEDURE ThisTrack* (V: Viewer): Track;
  BEGIN V := ThisViewer(V); V := V.next;
    WHILE V.state # 1 DO V := V.next END; (*filler viewer*)
    RETURN V.parent(Track) (*track*)
  END ThisTrack;

  PROCEDURE ThisDisplay* (V: Viewer): DisplayArea;
  BEGIN V := ThisTrack(V);
    RETURN V.parent(DisplayArea) (*display*)
  END ThisDisplay;

  PROCEDURE Open* (D: DisplayArea; V: Viewer; X, Y: INTEGER);
    VAR T, u, v: Viewer; M: ViewerMsg;
  BEGIN
    IF (V.state = 0) & (X < inf) THEN
      IF Y > DH THEN Y := DH END;
      T := D.dsc.next; (*first track*)
      WHILE X >= T.X + T.W DO T := T.next END;
      u := T.dsc; v := u.next;
      WHILE Y > v.Y + v.H DO u := v; v := u.next END;
      IF Y < v.Y + D.minH THEN Y := v.Y + D.minH END;
      IF (v.next.Y # 0) & (Y > v.Y + v.H - D.minH) THEN
        V.X := T.X; V.W := T.W; V.Y := v.Y; V.H := v.H;
        M.id := suspend; M.state := 0;
        v.handle(v, M); v(Viewer).state := 0;
        V.next := v.next; u.next := V; V.state := 2
      ELSE V.X := T.X; V.W := T.W; V.Y := v.Y; V.H := Y - v.Y;
        M.id := modify; M.Y := Y; M.H := v.Y + v.H - Y;
        v.handle(v, M); v.Y := M.Y; v.H := M.H;
        V.next := v; u.next := V; V.state := 2
      END
    END
  END Open;

  PROCEDURE Change* (V: Viewer; Y: INTEGER);
    VAR D: DisplayArea; v: Viewer; M: ViewerMsg;
  BEGIN
    IF V.state > 1 THEN D := ThisDisplay(V);
      IF Y > DH THEN Y := DH END;
      v := V.next;
      IF (v.next.Y # 0) & (Y > v.Y + v.H - D.minH) THEN Y := v.Y + v.H - D.minH END;
      IF Y >= V.Y + D.minH THEN
        M.id := modify; M.Y := Y; M.H := v.Y + v.H - Y;
        v.handle(v, M); v.Y := M.Y; v.H := M.H; V.H := Y - V.Y
      END
    END
  END Change;

  PROCEDURE RestoreTrack (S: Viewer);
    VAR T, t, v: Viewer; M: ViewerMsg;
  BEGIN t := S.next;
    WHILE t.next # S DO t := t.next END;
    T := S(Track).under;
    WHILE T.next # NIL DO T := T.next END;
    t.next := S(Track).under; T.next := S.next; M.id := restore;
    REPEAT t := t.next; v := t.dsc;
      REPEAT v := v.next; v.handle(v, M); v(Viewer).state := - v(Viewer).state
      UNTIL v = t.dsc
    UNTIL t = T
  END RestoreTrack;

  PROCEDURE Close* (V: Viewer);
    VAR D: DisplayArea; T, U: Viewer; M: ViewerMsg;
  BEGIN
    IF V.state > 1 THEN D := ThisDisplay(V);
      U := V.next; T := D.dsc;
      REPEAT T := T.next UNTIL V.X < T.X + T.W;
      IF (T(Track).under = NIL) OR (U.next # V) THEN
        M.id := suspend; M.state := 0;
        V.handle(V, M); V.state := 0; D.backup := V;
        M.id := modify; M.Y := V.Y; M.H := V.H + U.H;
        U.handle(U, M); U.Y := M.Y; U.H := M.H;
        WHILE U.next # V DO U := U.next END;
        U.next := V.next
      ELSE (*close track*)
        M.id := suspend; M.state := 0;
        V.handle(V, M); V.state := 0; D.backup := V;
        U.handle(U, M); U(Viewer).state := 0;
        RestoreTrack(T)
      END
    END
  END Close;

  PROCEDURE Recall* (D: DisplayArea; VAR V: Viewer);
  BEGIN V := D.backup
  END Recall;

  PROCEDURE This* (D: DisplayArea; X, Y: INTEGER): Viewer;
    VAR T, V: Viewer;
  BEGIN
    IF (X < inf) & (Y < DH) THEN
      T := D.dsc;
      REPEAT T := T.next UNTIL X < T.X + T.W;
      V := T.dsc;
      REPEAT V := V.next UNTIL Y < V.Y + V.H
    ELSE V := NIL
    END ;
    RETURN V(Viewer)
  END This;

  PROCEDURE Next* (V: Viewer): Viewer;
  BEGIN RETURN V.next(Viewer)
  END Next;

  PROCEDURE Locate* (D: DisplayArea; X, H: INTEGER; VAR fil, bot, alt, max: Viewer);
    VAR T, V: Viewer;
  BEGIN
    IF X < inf THEN
      T := D.dsc;
      REPEAT T := T.next UNTIL X < T.X + T.W;
      fil := T.dsc; bot := fil.next;
      IF bot.next # fil THEN
        alt := bot.next; V := alt.next;
        WHILE (V # fil) & (alt.H < H) DO
          IF V.H > alt.H THEN alt := V END;
          V := V.next
        END
      ELSE alt := bot
      END;
      max := T.dsc; V := max.next;
      WHILE V # fil DO
        IF V.H > max.H THEN max := V END;
        V := V.next
      END
    END
  END Locate;

  PROCEDURE InitTrack* (D: DisplayArea; W, H: INTEGER; Filler: Viewer);
    VAR S: Viewer; T: Track; fillerTrack: Track; fillerViewer: Viewer;
  BEGIN
    IF Filler.state = 0 THEN
      Filler.X := D.curW; Filler.W := W; Filler.Y := 0; Filler.H := H;
      Filler.state := 1; Filler.next := Filler;
      NEW(T); Filler.parent := T; T.parent := D;
      T.X := D.curW; T.W := W; T.Y := 0; T.H := H; T.dsc := Filler; T.under := NIL;
      fillerTrack := D.dsc(Track); fillerViewer := fillerTrack.dsc;
      fillerViewer.X := D.curW + W; fillerViewer.W := inf - fillerViewer.X;
      fillerTrack.X := fillerViewer.X; fillerTrack.W := fillerViewer.W;
      S := fillerTrack;
      WHILE S.next # fillerTrack DO S := S.next END;
      S.next := T; T.next := fillerTrack; D.curW := D.curW + W;
    END
  END InitTrack;

  PROCEDURE OpenTrack* (D: DisplayArea; X, W: INTEGER; Filler: Viewer);
    VAR newT: Track; S, T, t, v: Viewer; M: ViewerMsg; v0: Viewer;
  BEGIN
    IF (X < inf) & (Filler.state = 0) THEN
      S := D.dsc; T := S.next;
      WHILE X >= T.X + T.W DO S := T; T := S.next END;
      WHILE X + W > T.X + T.W DO T := T.next END;
      M.id := suspend; t := S;
      REPEAT t := t.next; v := t.dsc;
        REPEAT v := v.next; M.state := -v(Viewer).state; v.handle(v, M); v(Viewer).state := M.state
        UNTIL v = t.dsc
      UNTIL t = T;
      Filler.X := S.next.X; Filler.W := T.X + T.W - S.next.X; Filler.Y := 0; Filler.H := DH;
      Filler.state := 1; Filler.next := Filler;
      NEW(newT); Filler.parent := newT; newT.parent := D;
      newT.X := Filler.X; newT.W := Filler.W; newT.Y := 0; newT.H := DH;
      newT.dsc := Filler; newT.under := S.next; S.next := newT;
      newT.next := T.next; T.next := NIL;
    END
  END OpenTrack;

  PROCEDURE CloseTrack* (D: DisplayArea; X: INTEGER);
    VAR T, V: Viewer; M: ViewerMsg;
  BEGIN
    IF X < inf THEN
      T := D.dsc;
      REPEAT T := T.next UNTIL X < T.X + T.W;
      IF T(Track).under # NIL THEN
        M.id := suspend; M.state := 0; V := T.dsc;
        REPEAT V := V.next; V.handle(V, M); V(Viewer).state := 0 UNTIL V = T.dsc;
        RestoreTrack(T)
      END
    END
  END CloseTrack;

  PROCEDURE BroadcastDisplay* (D: DisplayArea; VAR M: Msg); (*to specified display*)
    VAR T, V: Viewer;
  BEGIN T := D.dsc.next;
    WHILE T # D.dsc DO
      V := T.dsc; 
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
     WHILE S # FillerDisplay DO BroadcastDisplay(S(DisplayArea), M); S := S.next END
  END BroadcastAll;

  PROCEDURE PassFocus* (V: Viewer);
    VAR M: ControlMsg;
  BEGIN M.id := defocus; FocusViewer.handle(FocusViewer, M); FocusViewer := V;
  END PassFocus;

  PROCEDURE SetFocusViewer* (V: Viewer);
  BEGIN FocusViewer := V; CurDisplay.focusViewer := V
  END SetFocusViewer;

  (*--------------------------- logical display areas ----------------------------*)

  PROCEDURE SetDisplayName* (D: DisplayArea; name: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < DnLength) & (name[i] > 0X) DO D.name[i] := name[i]; INC(i) END;
    IF i < DnLength THEN D.name[i] := 0X END
  END SetDisplayName;

  PROCEDURE OpenDisplay* (D: DisplayArea; W, H: INTEGER; name: ARRAY OF CHAR);
    VAR S: Viewer; fillerTrack: Track; fillerViewer: Viewer;
  BEGIN D.id := nextId; SetDisplayName(D, name);
    D.X := 0; D.Y := 0; D.W := W; D.H := H; D.state := 2; D.curW := 0; D.minH := 1;
    D.focusViewer := NIL; D.backup := NIL; D.parent := NIL;
    NEW(fillerViewer);
    fillerViewer.X := 0; fillerViewer.W := inf; fillerViewer.Y := 0; fillerViewer.H := H;
    fillerViewer.state := 1; fillerViewer.next := fillerViewer;
    NEW(fillerTrack);
    fillerViewer.parent := fillerTrack; fillerTrack.parent := D;
    fillerTrack.X := 0; fillerTrack.W := inf; fillerTrack.Y := 0; fillerTrack.H := H;
    fillerTrack.state := 1; fillerTrack.dsc := fillerViewer; fillerTrack.next := fillerTrack;
    D.dsc := fillerTrack;
    S := FillerDisplay;
    WHILE S.next # FillerDisplay DO S := S.next END;
    S.next := D; D.next := FillerDisplay; nextId := nextId + 1
  END OpenDisplay;

  PROCEDURE CloseDisplay* (D: DisplayArea); (*close display unless it is the current display*)
    VAR S, T: Viewer;
  BEGIN
    IF (D # NIL) & (D # CurDisplay) THEN S := FillerDisplay; T := S.next;
      WHILE (T # FillerDisplay) & (T # D) DO S := T; T := S.next END;
      IF T # FillerDisplay THEN S.next := T.next END
    END
  END CloseDisplay;

  PROCEDURE SetCurDisplay* (D: DisplayArea);
    VAR S: Viewer; M: ViewerMsg;
  BEGIN
    IF D # CurDisplay THEN S := FillerDisplay;
      REPEAT S := S.next UNTIL (S = D) OR (S = FillerDisplay);
      IF S # FillerDisplay THEN
        IF CurDisplay # NIL THEN CurDisplay.state := -CurDisplay.state END;
        CurDisplay := S(DisplayArea); S.state := -S.state; FocusViewer := CurDisplay.focusViewer;
        M.id := restore; BroadcastDisplay(CurDisplay, M)
      END
    END
  END SetCurDisplay;

  PROCEDURE GetDisplay* (id: INTEGER): DisplayArea;
    VAR S: Viewer;
  BEGIN S := FillerDisplay;
    REPEAT S := S.next UNTIL (S(DisplayArea).id = id) OR (S = FillerDisplay);
    IF S = FillerDisplay THEN S := NIL END;
    RETURN S(DisplayArea)
  END GetDisplay;

  PROCEDURE FirstDisplay* (): DisplayArea;
    VAR S: Viewer;
  BEGIN IF FillerDisplay = FillerDisplay.next THEN S := NIL ELSE S := FillerDisplay.next END ;
    RETURN S(DisplayArea)
  END FirstDisplay;

  PROCEDURE NextDisplay* (D: DisplayArea): DisplayArea;
  BEGIN RETURN D.next(DisplayArea)
  END NextDisplay;

  PROCEDURE EndDisplay* (D: DisplayArea): BOOLEAN;
  BEGIN RETURN D = FillerDisplay
  END EndDisplay;

BEGIN DH := Display.Height; CurDisplay := NIL; FocusViewer := NIL; nextId := 0;
  NEW(FillerDisplay);
  FillerDisplay.next := FillerDisplay; FillerDisplay.dsc := NIL;
  FillerDisplay.X := 0; FillerDisplay.Y := 0; FillerDisplay.W := inf; FillerDisplay.H := DH; FillerDisplay.state := 1;
  FillerDisplay.curW := 0; FillerDisplay.minH := 1; FillerDisplay.id := -1; FillerDisplay.name := "FillerDisplay";
  FillerDisplay.focusViewer := NIL; FillerDisplay.backup := NIL; FillerDisplay.parent := NIL
END Viewers.
