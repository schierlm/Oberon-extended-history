MODULE MenuViewers; (*JG 26.8.90 / 16.9.93 / NW 10.3.13 / AP 12.12.15*)
  IMPORT Input, Display, Cursors, Viewers;

  CONST ViewerColor = Display.white;

  TYPE Viewer* = POINTER TO ViewerDesc;
    ViewerDesc* = RECORD (Viewers.ViewerDesc)
      menuH*: INTEGER
    END;

  PROCEDURE Copy (V: Viewer; VAR V1: Viewer);
    VAR Menu, Main: Viewers.Viewer; M: Viewers.CopyMsg;
  BEGIN Menu := V.dsc; Main := V.dsc.next;
    NEW(V1); V1^ := V^; V1.state := 0;
    M.V := NIL; Menu.handle(Menu, M); V1.dsc := M.V;
    M.V := NIL; Main.handle(Main, M); V1.dsc.next := M.V;
    V1.dsc.next.next := NIL; V1.dsc.parent := V1; V1.dsc.next.parent := V1; V1.parent := NIL
  END Copy;

  PROCEDURE Draw (V: Viewers.Viewer);
  BEGIN
    Display.ReplConst(ViewerColor, V.X, V.Y, 1, V.H, Display.replace);
    Display.ReplConst(ViewerColor, V.X + V.W - 1, V.Y, 1, V.H, Display.replace);
    Display.ReplConst(ViewerColor, V.X + 1, V.Y, V.W - 2, 1, Display.replace);
    Display.ReplConst(ViewerColor, V.X + 1, V.Y + V.H - 1, V.W - 2, 1, Display.replace)
  END Draw;

  PROCEDURE Extend (V: Viewer; newY: INTEGER);
    VAR dH: INTEGER;
  BEGIN dH := V.Y - newY;
    IF dH > 0 THEN
      Display.ReplConst(Display.black, V.X + 1, newY + 1, V.W - 2, dH, Display.replace);
      Display.ReplConst(ViewerColor, V.X, newY, 1, dH, Display.replace);
      Display.ReplConst(ViewerColor, V.X + V.W - 1, newY, 1, dH, Display.replace);
      Display.ReplConst(ViewerColor, V.X + 1, newY, V.W - 2, 1, Display.replace)
    END
  END Extend;

  PROCEDURE Reduce (V: Viewer; newY: INTEGER);
  BEGIN Display.ReplConst(ViewerColor, V.X + 1, newY, V.W - 2, 1, Display.replace)
  END Reduce;

  PROCEDURE Grow (V: Viewer; oldH: INTEGER);
    VAR dH: INTEGER;
  BEGIN dH := V.H - oldH;
    IF dH > 0 THEN
      Display.ReplConst(ViewerColor, V.X, V.Y + oldH, 1, dH, Display.replace);
      Display.ReplConst(ViewerColor, V.X + V.W - 1, V.Y + oldH, 1, dH, Display.replace);
      Display.ReplConst(ViewerColor, V.X + 1, V.Y + V.H - 1, V.W - 2, 1, Display.replace)
    END
  END Grow;

  PROCEDURE Shrink (V: Viewer; newH: INTEGER);
  BEGIN Display.ReplConst(ViewerColor, V.X + 1, V.Y + newH - 1, V.W - 2, 1, Display.replace)
  END Shrink;

  PROCEDURE Adjust (F: Viewers.Viewer; id, dY, Y, H: INTEGER);
    VAR M: Viewers.ViewerMsg;
  BEGIN M.id := id; M.dY := dY; M.Y := Y; M.H := H; F.handle(F, M); F.Y := Y; F.H := H
  END Adjust;

  PROCEDURE Restore (V: Viewer);
    VAR Menu, Main: Viewers.Viewer;
  BEGIN Menu := V.dsc; Main := V.dsc.next;
    Cursors.RemoveMarks(V.X, V.Y, V.W, V.H);
    Draw(V);
    Menu.X := V.X + 1; Menu.Y := V.Y + V.H - 1; Menu.W := V.W - 2; Menu.H := 0;
    Main.X := V.X + 1; Main.Y := V.Y + V.H - V.menuH; Main.W := V.W - 2; Main.H := 0;
    IF V.H > V.menuH + 1 THEN
      Adjust(Menu, Viewers.extend, 0, V.Y + V.H - V.menuH, V.menuH - 1);
      Adjust(Main, Viewers.extend, 0, V.Y + 1, V.H - V.menuH - 1)
    ELSE Adjust(Menu, Viewers.extend, 0, V.Y + 1, V.H - 2)
    END
  END Restore;

  PROCEDURE Modify (V: Viewer; Y, H: INTEGER);
    VAR Menu, Main: Viewers.Viewer;
  BEGIN Menu := V.dsc; Main := V.dsc.next;
    IF Y < V.Y THEN (*extend*)
      Cursors.RemoveMarks(V.X, Y, V.W, V.Y - Y);
      Extend(V, Y);
      IF H > V.menuH + 1 THEN
        Adjust(Menu, Viewers.extend, 0, Y + H - V.menuH, V.menuH - 1);
        Adjust(Main, Viewers.extend, 0, Y + 1, H - V.menuH - 1)
      ELSE Adjust(Menu, Viewers.extend, 0, Y + 1, H - 2)
      END
    ELSIF Y > V.Y THEN (*reduce*)
      Cursors.RemoveMarks(V.X, V.Y, V.W, V.H);
      IF H > V.menuH + 1 THEN
        Adjust(Main, Viewers.reduce, 0, Y + 1, H - V.menuH - 1);
        Adjust(Menu, Viewers.reduce, 0, Y + H - V.menuH, V.menuH - 1)
      ELSE
        Adjust(Main, Viewers.reduce, 0, Y + H - V.menuH, 0);
        Adjust(Menu, Viewers.reduce, 0, Y + 1, H - 2)
      END;
      Reduce(V, Y)
    END
  END Modify;

  PROCEDURE Change (V: Viewer; X, Y: INTEGER; Keys: SET);
    VAR Menu, Main: Viewers.Viewer; D: Viewers.DisplayArea;
      V1: Viewers.Viewer;
      keysum: SET; Y0, dY, H: INTEGER; inverted: BOOLEAN;
  BEGIN (*Keys # {}*)
    Menu := V.dsc; Main := V.dsc.next;
    Cursors.DrawMouseArrow(X, Y);
    Display.ReplConst(Display.white, V.X + 1, V.Y + V.H - 1 - V.dsc.H, V.W - 2, V.dsc.H, Display.invert);
    keysum := Keys; Input.Mouse(Keys, X, Y); inverted := TRUE;
    WHILE Keys # {} DO Y0 := Y;
      keysum := keysum + Keys;
      Cursors.DrawMouseArrow(X, Y); Input.Mouse(Keys, X, Y);
      IF Keys = {2} THEN (*ML*)
        IF inverted & (Y # Y0) THEN inverted := FALSE;
          Display.ReplConst(Display.white, V.X + 1, V.Y + V.H - 1 - V.dsc.H, V.W - 2, V.dsc.H, Display.invert);
        END;
        IF Y > Y0 THEN (*extend*) dY := Y - Y0;
          V1 := Viewers.Next(V);
          IF V1.state > 1 THEN
            CASE V1 OF
            Viewer:
              IF V1.H < V1.menuH + 2 THEN dY := 0
              ELSIF V1.H < V1.menuH + 2 + dY THEN dY := V1.H - V1.menuH - 2
              END |
            Viewers.Viewer: IF V1.H < 1 + dY THEN dY := V1.H - 1 END
            END
          ELSIF V1.H < dY THEN dY := V1.H
          END;
          Viewers.Change(V, V.Y + V.H + dY);
          Cursors.RemoveMarks(V.X, V.Y, V.W, V.H);
          Grow(V, V.H - dY);
          IF V.H > V.menuH + 1 THEN
            Adjust(Menu, Viewers.extend, dY, V.Y + V.H - V.menuH, V.menuH - 1);
            Adjust(Main, Viewers.extend, dY, V.Y + 1, V.H - V.menuH - 1)
          ELSE (*V.H > 1*)
            Adjust(Menu, Viewers.extend, dY, V.Y + 1, V.H - 2);
            Adjust(Main, Viewers.extend, dY, V.Y + V.H - V.menuH, 0)
          END;
        ELSIF Y < Y0 THEN (*reduce*) dY := Y0 - Y;
          IF V.H >= V.menuH + 2 THEN
            IF V.H < V.menuH + 2 + dY THEN dY := V.H - V.menuH - 2 END;
            Cursors.RemoveMarks(V.X, V.Y, V.W, V.H);
            H := V.H - dY;
            Adjust(Main, Viewers.reduce, dY, V.Y + 1, H - V.menuH - 1);
            Adjust(Menu, Viewers.reduce, dY, V.Y + H - V.menuH, V.menuH - 1);
            Shrink(V, H); Viewers.Change(V, V.Y + H)
          END
        END
      END
    END;
    IF inverted THEN
      Display.ReplConst(Display.white, V.X + 1, V.Y + V.H - 1 - V.dsc.H, V.W - 2, V.dsc.H, Display.invert)
    END;
    IF ~(0 IN keysum) THEN (*~MR*)
      IF 1 IN keysum THEN (*MM*) D := Viewers.ThisDisplay(V); V1 := Viewers.This(D, X, Y);
        IF (V1 IS Viewer) & (Y > V1.Y + V1.H - V1(Viewer).menuH - 2) THEN Y := V1.Y + V1.H END;
        IF Y < V1.Y + V.menuH + 2 THEN Y := V1.Y + V.menuH + 2 END;
        Viewers.Close(V); Viewers.Open(D, V, X, Y); Restore(V)
      END
    END
  END Change;

  PROCEDURE Suspend (V: Viewer);
    VAR Menu, Main: Viewers.Viewer;
  BEGIN Menu := V.dsc; Main := V.dsc.next;
    Adjust(Main, Viewers.reduce, 0, V.Y + V.H - V.menuH, 0);
    Adjust(Menu, Viewers.reduce, 0, V.Y + V.H - 1, 0)
  END Suspend;

  PROCEDURE Handle* (V: Viewers.Viewer; VAR M: Viewers.Msg);
    VAR X, Y: INTEGER;
      Menu, Main: Viewers.Viewer; V1: Viewer;
  BEGIN Menu := V.dsc; Main := V.dsc.next;
      CASE M OF
      Viewers.InputMsg:
        IF M.id = Viewers.track THEN
          X := M.X; Y := M.Y;
          IF Y < V.Y + 1 THEN Cursors.DrawMouseArrow(X, Y)
          ELSIF Y < V.Y + V.H - V(Viewer).menuH THEN Main.handle(Main, M)
          ELSIF Y < V.Y + V.H - V(Viewer).menuH + 2 THEN Menu.handle(Menu, M)
          ELSIF Y < V.Y + V.H - 1 THEN
            IF 2 IN M.keys THEN Change(V(Viewer), X, Y, M.keys) ELSE Menu.handle(Menu, M) END
          ELSE Cursors.DrawMouseArrow(X, Y)
          END
        ELSE Menu.handle(Menu, M); Main.handle(Main, M)
        END |
      Viewers.ControlMsg:
        IF M.id = Viewers.mark THEN
          X := M.X; Y := M.Y; Cursors.DrawMouseArrow(X, Y); Cursors.DrawPointer(X, Y)
        ELSE Menu.handle(Menu, M); Main.handle(Main, M)
        END |
      Viewers.CopyMsg:
        Copy(V(Viewer), V1); M.V := V1 |
      Viewers.ViewerMsg:
        IF M.id = Viewers.restore THEN Restore(V(Viewer))
        ELSIF M.id = Viewers.modify THEN Modify(V(Viewer), M.Y, M.H)
        ELSIF M.id = Viewers.suspend THEN Suspend(V(Viewer))
        END |
      Viewers.Msg: Menu.handle(Menu, M); Main.handle(Main, M)
      END
  END Handle;

  PROCEDURE New* (Menu, Main: Viewers.Viewer; menuH, X, Y: INTEGER): Viewer; 
    VAR V: Viewer;
  BEGIN NEW(V);
    V.handle := Handle; V.dsc := Menu; V.dsc.next := Main; V.menuH := menuH;
    V.dsc.next.next := NIL; V.dsc.parent := V; V.dsc.next.parent := V; V.parent := NIL;
    Viewers.Open(Viewers.CurDisplay, V, X, Y); Restore(V); RETURN V
  END New;

END MenuViewers.
