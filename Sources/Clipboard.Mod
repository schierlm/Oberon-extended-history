MODULE Clipboard; (*AP 7.5.16*)
  IMPORT SYSTEM, Texts, Viewers, Oberon, TextViewers;

  CONST control = -24; data = -20;

  PROCEDURE Copy(T: Texts.Text; beg, end: INTEGER);
    VAR R: Texts.Reader;
      ch: CHAR;
  BEGIN
    Texts.OpenReader(R, T, beg);
    SYSTEM.PUT(control, end - beg);
    WHILE beg < end DO
      Texts.Read(R, ch);
      SYSTEM.PUT(data, ch);
      beg := beg + 1
    END
  END Copy;

  PROCEDURE CopySelection*;
    VAR T: Texts.Text;
      beg, end, time: INTEGER;
  BEGIN
    Oberon.GetSelection(T, beg, end, time);
    IF time >= 0 THEN Copy(T, beg, end) END
  END CopySelection;

  PROCEDURE CopyViewer*;
    VAR V: Viewers.Viewer;
      F: TextViewers.Viewer;
  BEGIN
    V := Oberon.MarkedViewer();
    IF (V # NIL) & (V.dsc # NIL) & (V.dsc.next IS TextViewers.Viewer) THEN
      F := V.dsc.next(TextViewers.Viewer);
      Copy(F.text, 0, F.text.len)
    END
  END CopyViewer;

  PROCEDURE Paste*;
    VAR W: Texts.Writer;
      V: Viewers.Viewer;
      F: TextViewers.Viewer;
      len, i: INTEGER;
      ch: CHAR;
  BEGIN
    V := Viewers.FocusViewer;
    IF (V # NIL) & (V.dsc # NIL) & (V.dsc.next IS TextViewers.Viewer) THEN
      SYSTEM.GET(control, len);
      IF len > 0 THEN
        Texts.OpenWriter(W);
        FOR i := 1 TO len DO
          SYSTEM.GET(data, ch);
          Texts.Write(W, ch)
        END;
        F := V.dsc.next(TextViewers.Viewer);
        Texts.Insert(F.text, F.carloc.pos, W.buf);
        TextViewers.SetCaret(F, F.carloc.pos + len)
      END
    END
  END Paste;

END Clipboard.
