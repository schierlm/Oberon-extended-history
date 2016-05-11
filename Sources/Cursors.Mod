MODULE Cursors;  (*AP 12.12.15*)
  IMPORT Display;

  (*A cursor consists of a path X,Y into the display area representing its current position and a state of visibility.
    A marker is an abstract data type consisting of two operations Fade and Draw. It is used to actually draw or fade
    a cursor at its current position, thereby making it visible or invisible. To every cursor belongs a marker.*)

  TYPE Painter* = PROCEDURE (x, y: INTEGER);
    Marker* = RECORD Fade*, Draw*: Painter END;

    Cursor* = RECORD
       marker*: Marker; on*: BOOLEAN; X*, Y*: INTEGER
    END;

  VAR Mouse*, Pointer*: Cursor;  (*predefined cursors representing a mouse and a global system pointer*)
    Arrow*, Star*: Marker;  (*predefined markers representing an arrow pointing to the NW and a star symbol*)
    DW, DH, CL: INTEGER;

  PROCEDURE FlipArrow (X, Y: INTEGER);
  BEGIN
    IF X < CL THEN
      IF X > DW - 15 THEN X := DW - 15 END
    ELSE
      IF X > CL + DW - 15 THEN X := CL + DW - 15 END
    END;
    IF Y < 14 THEN Y := 14 ELSIF Y > DH THEN Y := DH END;
    Display.CopyPattern(Display.white, Display.arrow, X, Y - 14, Display.invert)
  END FlipArrow;
     
  PROCEDURE FlipStar (X, Y: INTEGER);
  BEGIN
    IF X < CL THEN
      IF X < 7 THEN X := 7 ELSIF X > DW - 8 THEN X := DW - 8 END
    ELSE
      IF X < CL + 7 THEN X := CL + 7 ELSIF X > CL + DW - 8 THEN X := CL + DW - 8 END
    END ;
    IF Y < 7 THEN Y := 7 ELSIF Y > DH - 8 THEN Y := DH - 8 END;
    Display.CopyPattern(Display.white, Display.star, X - 7, Y - 7, Display.invert)
  END FlipStar;

  PROCEDURE OpenCursor(VAR c: Cursor);
  BEGIN c.on := FALSE; c.X := 0; c.Y := 0
  END OpenCursor;
 
  PROCEDURE FadeCursor(VAR c: Cursor);
  BEGIN IF c.on THEN c.marker.Fade(c.X, c.Y); c.on := FALSE END
  END FadeCursor;

  PROCEDURE DrawCursor(VAR c: Cursor; m: Marker; x, y: INTEGER);
  BEGIN
    IF c.on & ((x # c.X) OR (y # c.Y) OR (m.Draw # c.marker.Draw)) THEN
      c.marker.Fade(c.X, c.Y); c.on := FALSE
    END;
    IF ~c.on THEN
      m.Draw(x, y); c.marker := m; c.X := x; c.Y := y; c.on := TRUE
    END
  END DrawCursor;

  PROCEDURE DrawMouse*(m: Marker; x, y: INTEGER);
  BEGIN DrawCursor(Mouse, m, x, y)
  END DrawMouse;

  PROCEDURE DrawMouseArrow*(x, y: INTEGER);
  BEGIN DrawCursor(Mouse, Arrow, x, y)
  END DrawMouseArrow;

  PROCEDURE FadeMouse*;
  BEGIN FadeCursor(Mouse)
  END FadeMouse;

  PROCEDURE MouseOn*(): BOOLEAN;
  BEGIN RETURN Mouse.on
  END MouseOn;

  PROCEDURE DrawPointer*(x, y: INTEGER);
  BEGIN DrawCursor(Pointer, Star, x, y)
  END DrawPointer;

  PROCEDURE FadePointer*;
  BEGIN FadeCursor(Pointer)
  END FadePointer;

  PROCEDURE PointerOn*(): BOOLEAN;
  BEGIN RETURN Pointer.on
  END PointerOn;

  PROCEDURE RemoveMarks* (X, Y, W, H: INTEGER);
  BEGIN
    IF (Mouse.X > X - 16) & (Mouse.X < X + W + 16) & (Mouse.Y > Y - 16) & (Mouse.Y < Y + H + 16) THEN
      FadeCursor(Mouse)
    END;
    IF (Pointer.X > X - 8) & (Pointer.X < X + W + 8) & (Pointer.Y > Y - 8) & (Pointer.Y < Y + H + 8) THEN
      FadeCursor(Pointer)
    END
  END RemoveMarks;

BEGIN DW := Display.Width; DH := Display.Height; CL := DW;
  Arrow.Fade := FlipArrow; Arrow.Draw := FlipArrow;
  Star.Fade := FlipStar; Star.Draw := FlipStar;
  OpenCursor(Mouse); OpenCursor(Pointer)
END Cursors.
