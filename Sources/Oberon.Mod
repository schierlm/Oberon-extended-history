MODULE Oberon; (*JG 6.9.90 / 23.9.93 / 13.8.94 / 14.4.13 / NW 22.12.15 / AP 7.5.16*)
  IMPORT Kernel, Modules, Input, Display, Cursors, Viewers, Fonts, Texts, Tasks;

  TYPE DisplayArea* = POINTER TO DisplayDesc;
    DisplayDesc* = RECORD (Viewers.DisplayDesc)
      log*: Texts.Text;
      defaultFnt*: Fonts.Font;
      defaultCol*, defaultOff*: INTEGER
    END;

    SelectionMsg* = RECORD (Viewers.Msg)
      time*: LONGINT;
      text*: Texts.Text;
      beg*, end*: LONGINT
    END;

  VAR User*: ARRAY 8 OF CHAR; Password*: LONGINT;
    Log*: Texts.Text;

    Par*: RECORD
      vwr*: Viewers.Viewer;
      frame*: Viewers.Viewer;
      text*: Texts.Text;
      pos*: LONGINT
    END;

    CurFnt*: Fonts.Font;
    CurCol*, CurOff*: INTEGER;

    DefaultFnt*: Fonts.Font;
    DefaultCol*, DefaultOff*: INTEGER;

    DW, DH: INTEGER;

    display*: DisplayArea;

  (*user identification*)

  PROCEDURE Code(VAR s: ARRAY OF CHAR): LONGINT;
    VAR i: INTEGER; a, b, c: LONGINT;
  BEGIN
    a := 0; b := 0; i := 0;
    WHILE s[i] # 0X DO
      c := b; b := a; a := (c MOD 509 + 1) * 127 + ORD(s[i]);
      INC(i)
    END;
    IF b >= 32768 THEN b := b - 65536 END;
    RETURN b * 65536 + a
  END Code;

  PROCEDURE SetUser* (VAR user, password: ARRAY OF CHAR);
  BEGIN User := user; Password := Code(password)
  END SetUser;

  PROCEDURE Clock*(): LONGINT;
  BEGIN RETURN Kernel.Clock()
  END Clock;

  PROCEDURE SetClock* (d: LONGINT);
  BEGIN Kernel.SetClock(d)
  END SetClock;

  PROCEDURE Time*(): LONGINT;
  BEGIN RETURN Kernel.Time()
  END Time;

  (*global default and current looks*)

  PROCEDURE SetDefaultFont* (fnt: Fonts.Font);
  BEGIN DefaultFnt := fnt
  END SetDefaultFont;

  PROCEDURE SetDefaultColor* (col: INTEGER);
  BEGIN DefaultCol := col
  END SetDefaultColor;

  PROCEDURE SetDefaultOffset* (voff: INTEGER);
  BEGIN DefaultOff := voff
  END SetDefaultOffset;

  PROCEDURE ResetDefaultLooks*;
  BEGIN DefaultFnt := Fonts.Default; DefaultCol := Display.white; DefaultOff := 0
  END ResetDefaultLooks;

  PROCEDURE SetFont* (fnt: Fonts.Font);
  BEGIN CurFnt := fnt
  END SetFont;

  PROCEDURE SetColor* (col: INTEGER);
  BEGIN CurCol := col
  END SetColor;

  PROCEDURE SetOffset* (voff: INTEGER);
  BEGIN CurOff := voff
  END SetOffset;

  (*per-display default looks*)

  PROCEDURE SetDisplayFont* (D: DisplayArea; fnt: Fonts.Font);
  BEGIN D.defaultFnt := fnt
  END SetDisplayFont;

  PROCEDURE SetDisplayColor* (D: DisplayArea; col: INTEGER);
  BEGIN D.defaultCol := col
  END SetDisplayColor;

  PROCEDURE SetDisplayOffset* (D: DisplayArea; voff: INTEGER);
  BEGIN D.defaultOff := voff
  END SetDisplayOffset;

  PROCEDURE ResetDisplayLooks* (D: DisplayArea);   (*to the global default looks*)
  BEGIN D.defaultFnt := DefaultFnt; D.defaultCol := DefaultCol; D.defaultOff := DefaultOff
  END ResetDisplayLooks;

  (*logs and text selections*)

  PROCEDURE OpenLog* (T: Texts.Text);
  BEGIN Log := T
  END OpenLog;

  PROCEDURE SetDisplayLog* (D: DisplayArea; T: Texts.Text);
  BEGIN D.log := T
  END SetDisplayLog;

  PROCEDURE WrDisplayLog* (D: DisplayArea; W: Texts.Writer);
  BEGIN Texts.Append(D.log, W.buf)
  END WrDisplayLog;

  PROCEDURE WrLog* (W: Texts.Writer);
  BEGIN WrDisplayLog(Viewers.CurDisplay(DisplayArea), W)
  END WrLog;

  PROCEDURE GetSelection* (VAR text: Texts.Text; VAR beg, end, time: LONGINT); (*from all displays*)
    VAR M: SelectionMsg;
  BEGIN
    M.time := -1; Viewers.BroadcastAll(M); time := M.time;
    IF time >= 0 THEN text := M.text; beg := M.beg; end := M.end END
  END GetSelection;

  PROCEDURE GetDisplaySelection* (D: DisplayArea; VAR text: Texts.Text; VAR beg, end, time: LONGINT); (*from specified display*)
    VAR M: SelectionMsg;
  BEGIN
    M.time := -1; Viewers.BroadcastDisplay(D, M); time := M.time;
    IF time >= 0 THEN text := M.text; beg := M.beg; end := M.end END
  END GetDisplaySelection;

  PROCEDURE GetCurSelection* (VAR text: Texts.Text; VAR beg, end, time: LONGINT); (*from current display*)
    VAR M: SelectionMsg;
  BEGIN
    M.time := -1; Viewers.Broadcast(M); time := M.time;
    IF time >= 0 THEN text := M.text; beg := M.beg; end := M.end END
  END GetCurSelection;

  (*display management*)

  PROCEDURE HandleFiller (V: Viewers.Viewer; VAR M: Viewers.Msg);
  BEGIN
    CASE M OF
    Viewers.InputMsg: IF M.id = Viewers.track THEN Cursors.DrawMouseArrow(M.X, M.Y) END |
    Viewers.ControlMsg: IF M.id = Viewers.mark THEN Cursors.DrawPointer(M.X, M.Y) END |
    Viewers.ViewerMsg:
      IF (M.id = Viewers.restore) & (V.W > 0) & (V.H > 0) THEN
        Cursors.RemoveMarks(V.X, V.Y, V.W, V.H);
        Display.ReplConst(Display.black, V.X, V.Y, V.W, V.H, Display.replace)
      ELSIF (M.id = Viewers.modify) & (M.Y < V.Y) THEN
        Cursors.RemoveMarks(V.X, M.Y, V.W, V.Y - M.Y);
        Display.ReplConst(Display.black, V.X, M.Y, V.W, V.Y - M.Y, Display.replace)
      END
    END
  END HandleFiller;

  PROCEDURE OpenDisplay* (VAR D: DisplayArea; W, H: INTEGER; name: ARRAY OF CHAR);
  BEGIN NEW(D); Viewers.OpenDisplay(D, W, H, name); ResetDisplayLooks(D)
  END OpenDisplay;

  PROCEDURE DisplayWidth* (X: INTEGER): INTEGER;
  BEGIN RETURN DW
  END DisplayWidth;

  PROCEDURE DisplayHeight* (X: INTEGER): INTEGER;
  BEGIN RETURN DH
  END DisplayHeight;

  PROCEDURE OpenTrack* (X, W: INTEGER);
    VAR Filler: Viewers.Viewer;
  BEGIN
    NEW(Filler); Filler.handle := HandleFiller;
    Viewers.OpenTrack(Viewers.CurDisplay, X, W, Filler)
  END OpenTrack;

  PROCEDURE InitTrack* (D: Viewers.DisplayArea; W, H: INTEGER);
    VAR Filler: Viewers.Viewer;
  BEGIN
    Input.SetMouseLimits(D.curW + W, H);
    Display.ReplConst(Display.black, D.curW, 0, W, H, Display.replace);
    NEW(Filler); Filler.handle := HandleFiller;
    Viewers.InitTrack(D, W, H, Filler)
  END InitTrack;

  (*standard Oberon display with user track and system track*)

  PROCEDURE UserTrack* (X: INTEGER): INTEGER;
  BEGIN RETURN X DIV DW * DW
  END UserTrack;

  PROCEDURE SystemTrack* (X: INTEGER): INTEGER;
  BEGIN RETURN X DIV DW * DW + DW DIV 8 * 5
  END SystemTrack;

  PROCEDURE UY (X: INTEGER): INTEGER;
    VAR h: INTEGER;
      fil, bot, alt, max: Viewers.Viewer;
  BEGIN
    Viewers.Locate(Viewers.CurDisplay, X, 0, fil, bot, alt, max);
    IF fil.H >= DH DIV 8 THEN h := DH ELSE h := max.Y + max.H DIV 2 END ;
    RETURN h
  END UY;

  PROCEDURE AllocateUserViewer* (DX: INTEGER; VAR X, Y: INTEGER);
  BEGIN
    IF Cursors.PointerOn() THEN X := Cursors.Pointer.X; Y := Cursors.Pointer.Y
    ELSE X := DX DIV DW * DW; Y := UY(X)
    END
  END AllocateUserViewer;

  PROCEDURE SY (X: INTEGER): INTEGER;
    VAR H0, H1, H2, H3, y: INTEGER;
      fil, bot, alt, max: Viewers.Viewer;
  BEGIN H3 := DH - DH DIV 3;
    H2 := H3 - H3 DIV 2; H1 := DH DIV 5; H0 := DH DIV 10;
    Viewers.Locate(Viewers.CurDisplay, X, DH, fil, bot, alt, max);
    IF fil.H >= DH DIV 8 THEN y := DH
    ELSIF max.H >= DH - H0 THEN y := max.Y + H3
    ELSIF max.H >= H3 - H0 THEN y := max.Y + H2
    ELSIF max.H >= H2 - H0 THEN y := max.Y + H1
    ELSIF max # bot THEN y := max.Y + max.H DIV 2
    ELSIF bot.H >= H1 THEN y := bot.H DIV 2
    ELSE y := alt.Y + alt.H DIV 2
    END ;
    RETURN y
  END SY;

  PROCEDURE AllocateSystemViewer* (DX: INTEGER; VAR X, Y: INTEGER);
  BEGIN
    IF Cursors.PointerOn() THEN X := Cursors.Pointer.X; Y := Cursors.Pointer.Y
    ELSE X := DX DIV DW * DW + DW DIV 8 * 5; Y := SY(X)
    END
  END AllocateSystemViewer;

  PROCEDURE MarkedViewer* (): Viewers.Viewer;
  BEGIN RETURN Viewers.This(Viewers.CurDisplay, Cursors.Pointer.X, Cursors.Pointer.Y)
  END MarkedViewer;

  (*command interpretation*)

  PROCEDURE SetPar*(V: Viewers.Viewer; T: Texts.Text; pos: LONGINT);
  BEGIN Par.vwr := Viewers.ThisViewer(V); Par.frame := V; Par.text := T; Par.pos := pos
  END SetPar;

  PROCEDURE Call* (name: ARRAY OF CHAR; VAR res: INTEGER);
    VAR mod: Modules.Module; P: Modules.Command;
      i, j: INTEGER; ch: CHAR;
      Mname, Cname: ARRAY 32 OF CHAR;
  BEGIN i := 0; ch := name[0];
    WHILE (ch # ".") & (ch # 0X) DO Mname[i] := ch; INC(i); ch := name[i] END ;
    IF ch = "." THEN
      Mname[i] := 0X; INC(i);
      Modules.Load(Mname, mod); res := Modules.res;
      IF Modules.res = 0 THEN
        j := 0; ch := name[i]; INC(i);
        WHILE ch # 0X DO Cname[j] := ch; INC(j); ch := name[i]; INC(i) END ;
        Cname[j] := 0X;
        P := Modules.ThisCommand(mod, Cname); res := res;
        IF Modules.res = 0 THEN P END
      END
    ELSE res := 5
    END
  END Call;

  PROCEDURE Collect* (count: INTEGER);
  BEGIN Tasks.Collect(count)
  END Collect;

BEGIN User[0] := 0X;
  DW := Display.Width; DH := Display.Height; ResetDefaultLooks;
  CurFnt := Fonts.Default; CurCol := Display.white; CurOff := 0;
  OpenDisplay(display, DW, DH, "Oberon");
  Viewers.SetCurDisplay(display);
  InitTrack(display, DW DIV 8 * 5, DH);  (*init user track*)
  InitTrack(display, DW DIV 8 * 3, DH);  (*init system track*)
  Viewers.SetFocusViewer(Viewers.This(display, 0,0));
END Oberon.
