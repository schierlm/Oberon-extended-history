MODULE System; (*JG 3.10.90 / NW 12.10.93 / NW 28.11.15 / AP 12.12.90 / 12.12.16*)
  IMPORT SYSTEM, Kernel, FileDir, Files, Modules, Input, Fonts, Texts,
    Viewers, Oberon, MenuViewers, TextFrames;

  CONST StandardMenu = "System.Close System.Copy System.Grow Edit.Search Edit.Store | System.Expand System.Clone";
    LogMenu = "Edit.Locate Edit.Search System.Copy System.Grow System.Clear | System.Expand System.Clone";

  VAR W: Texts.Writer;
    pat: ARRAY 32 OF CHAR;

  PROCEDURE GetArg(VAR S: Texts.Scanner);
    VAR T: Texts.Text; beg, end, time: LONGINT;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF (S.class = Texts.Char) & (S.c = "^") THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
    END
  END GetArg;

  PROCEDURE EndLine;
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END EndLine;

  (* ------------- Toolbox for system control ---------------*)

  PROCEDURE SetUser*;
    VAR i: INTEGER; ch: CHAR;
      user: ARRAY 8 OF CHAR;
      password: ARRAY 16 OF CHAR;
  BEGIN i := 0; Input.Read(ch);
    WHILE (ch # "/") & (i < 7) DO user[i] := ch; INC(i); Input.Read(ch) END;
    user[i] := 0X; i := 0; Input.Read(ch);
    WHILE (ch > " ") & (i < 15) DO password[i] := ch; INC(i); Input.Read(ch) END;
    password[i] := 0X; Oberon.SetUser(user, password)
  END SetUser;

  PROCEDURE SetFont*;
    VAR S: Texts.Scanner;
  BEGIN GetArg(S);
    IF S.class = Texts.Name THEN Oberon.SetFont(Fonts.This(S.s)) END
  END SetFont;

  PROCEDURE SetColor*;
    VAR S: Texts.Scanner;
  BEGIN GetArg(S);
    IF S.class = Texts.Int THEN Oberon.SetColor(S.i) END
  END SetColor;

  PROCEDURE SetOffset*;
    VAR S: Texts.Scanner;
  BEGIN GetArg(S);
    IF S.class = Texts.Int THEN Oberon.SetOffset(S.i) END
  END SetOffset;
  
  PROCEDURE Date*;
    VAR S: Texts.Scanner;
      dt, hr, min, sec, yr, mo, day: LONGINT;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN (*set clock*)
      day := S.i; Texts.Scan(S); mo := S.i; Texts.Scan(S); yr := S.i; Texts.Scan(S);
      hr := S.i; Texts.Scan(S); min := S.i; Texts.Scan(S); sec := S.i;
      dt := ((((yr*16 + mo)*32 + day)*32 + hr)*64 + min)*64 + sec;
      Kernel.SetClock(dt)
    ELSE (*read clock*) Texts.WriteString(W, "System.Clock");
      dt := Oberon.Clock(); Texts.WriteClock(W, dt); EndLine
    END
  END Date;

  PROCEDURE Collect*;
  BEGIN Oberon.Collect(0)
  END Collect;

  (* ------------- Toolbox for logical display areas ---------------*)

  PROCEDURE MakeDisplayName(x: INTEGER; prefix: ARRAY OF CHAR; VAR name: ARRAY OF CHAR); (*0 <= x < 10^5*)
    VAR i, j: INTEGER; buf: ARRAY 5 OF INTEGER;
  BEGIN i := 0; j := 0;
    WHILE prefix[j] > 0X DO name[j] := prefix[j]; INC(j) END;
    REPEAT buf[i] := x MOD 10; x := x DIV 10; INC(i) UNTIL x = 0;
    REPEAT DEC(i); name[j] := CHR(buf[i] + ORD("0")); INC(j) UNTIL (i = 0) OR (j = Viewers.DnLength);
    IF j < Viewers.DnLength THEN name[j] := 0X END
  END MakeDisplayName;

  PROCEDURE OpenViewers; (*open log and system tool viewer in system track of current display*)
    VAR logV, toolV, menu, main: Viewers.Viewer; curDisplay: Oberon.Display;
      X, Y: INTEGER;
  BEGIN curDisplay := Viewers.CurDisplay(Oberon.Display);
    IF curDisplay # NIL THEN
      Texts.WriteString(W, "Oberon V6  NW 14.4.13 / AP 1.11.16  Display ");
      Texts.WriteInt(W, curDisplay.id, 2); Texts.Write(W, " "); Texts.WriteString(W, curDisplay.name);
      Texts.WriteLn(W); Texts.Append(curDisplay.log, W.buf);
      Oberon.AllocateSystemViewer(0, X, Y);
      menu := TextFrames.NewMenu("System.Log", LogMenu);
      main := TextFrames.NewText(curDisplay.log, 0);
      logV := MenuViewers.New(menu, main, TextFrames.menuH, X, Y);
      Oberon.AllocateSystemViewer(0, X, Y);
      menu := TextFrames.NewMenu("System.Tool", StandardMenu);
      main := TextFrames.NewText(TextFrames.Text("System.Tool"), 0);
      toolV := MenuViewers.New(menu, main, TextFrames.menuH, X, Y)
    END
  END OpenViewers;

  PROCEDURE OpenDisplay0(name: ARRAY OF CHAR); (*if name is empty, a default name is created*)
    VAR D: Oberon.Display; DW, DH: INTEGER;
  BEGIN DW := Oberon.DisplayWidth(0); DH := Oberon.DisplayHeight(0);
    NEW(D); Viewers.InitDisplay(D, DW, DH, name);
    IF D.name = "" THEN MakeDisplayName(D.id, "Display ", D.name) END;
    Oberon.OpenDisplayLog(D, TextFrames.Text(""));
    Oberon.OpenLog(D.log);
    Oberon.NewTrack(D, DW DIV 8 * 5, DH);
    Oberon.NewTrack(D, DW DIV 8 * 3, DH);
    Viewers.SetDisplay(D);
    Viewers.SetFocusViewer(D, Viewers.This(D, 0, 0));
    Input.SetMouseLimits(D.curW, D.H);
    OpenViewers
  END OpenDisplay0;

  PROCEDURE OpenDisplay*; (*display name is provided as parameter*)
    VAR S: Texts.Scanner; old: INTEGER;
  BEGIN old := Viewers.CurDisplay.id;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN OpenDisplay0(S.s) ELSE OpenDisplay0("") END;
    Texts.WriteString(W, "Now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 2);
    Texts.WriteString(W,". To return to previous display:  System.SetDisplay ");
    Texts.WriteInt(W, old, 2); EndLine
  END OpenDisplay;

  PROCEDURE CloseDisplay*; (*display id is provided as parameter*)
    VAR D: Viewers.Display; S: Texts.Scanner; old, id, hint: INTEGER;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN id := S.i; D := Viewers.GetDisplay(id);
      IF D = NIL THEN Texts.WriteString(W, " no such display ")
      ELSE old := Viewers.CurDisplay.id;
        IF D.id = old THEN Texts.Scan(S);
          IF S.class = Texts.Int THEN hint := S.i ELSE hint := 0 END;
          Viewers.CloseDisplay(D.id, hint);
          IF Viewers.CurDisplay.id = old THEN Texts.WriteString(W, " can't close last display")
          ELSE Oberon.OpenLog(Viewers.CurDisplay(Oberon.Display).log);
            Texts.WriteString(W, " Display "); Texts.WriteInt(W, id, 2); Texts.WriteString(W, " was closed.")
          END
        ELSE Viewers.CloseDisplay(id, old);
          Texts.WriteString(W, " Display "); Texts.WriteInt(W, id, 2); Texts.WriteString(W, " was closed.")
        END
      END
    ELSE Texts.WriteString(W, " must provide a valid display number")
    END;
    EndLine
  END CloseDisplay;

  PROCEDURE SetDisplay*; (*display id is provided as parameter*)
    VAR D: Viewers.Display; V: Viewers.Viewer; S: Texts.Scanner; old: INTEGER;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN D := Viewers.GetDisplay(S.i);
      IF D = NIL THEN Texts.WriteString(W, " no such display ")
      ELSE old := Viewers.CurDisplay.id;
        IF D.id = old THEN Texts.WriteString(W, " already the current display ")
        ELSE Viewers.SetDisplay(D);
          Input.SetMouseLimits(D.curW, D.H);
          Oberon.OpenLog(D(Oberon.Display).log);
          Texts.WriteString(W, "Now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 2);
          Texts.WriteString(W,". To return to previous display:  System.SetDisplay ");
          Texts.WriteInt(W, old, 2)
        END
      END
    ELSE Texts.WriteString(W, " must provide a valid display number")
    END;
    EndLine
  END SetDisplay;

  PROCEDURE SetDisplayName*; (*display id and name are provided as parameters*)
    VAR D: Viewers.Display; S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN  Texts.Scan(S);
      IF S.class = Texts.Name THEN D := Viewers.GetDisplay(S.i);
        IF D = NIL THEN Texts.WriteString(W, " no such display ")
        ELSE Viewers.SetDisplayName(D, S.s);
          Texts.WriteString(W, " name of display "); Texts.WriteInt(W, D.id, 2);
          Texts.Write(W, " "); Texts.WriteString(W, " set to "); Texts.WriteString(W, D.name)
        END
      ELSE Texts.WriteString(W, " no display name provided (SetDisplayName id name)")
      END
    ELSE Texts.WriteString(W, " no display id provided (SetDisplayName id name)")
    END;
    EndLine
  END SetDisplayName;

  PROCEDURE ShowDisplays*;
    VAR D: Viewers.Viewer;
  BEGIN D := Viewers.root; Texts.WriteString(W, "System.ShowDisplays"); EndLine;
    WHILE D # NIL DO Texts.WriteString(W, " ");
      Texts.WriteString(W, " display "); Texts.WriteInt(W, D(Viewers.Display).id, 2);
      Texts.WriteString(W, " "); Texts.WriteString(W, D(Viewers.Display).name);
      IF D = Viewers.CurDisplay THEN Texts.WriteString(W, "      (current display)") END;
      EndLine;
      D := D.next
    END
  END ShowDisplays;

  PROCEDURE ThisDisplay*;
    VAR V: Viewers.Viewer; D: Viewers.Display;
  BEGIN V := Oberon.Par.vwr; D := Viewers.ThisDisplay(V);
    Texts.WriteString(W, " current display "); Texts.WriteInt(W, D.id, 2); Texts.Write(W, " ");
    Texts.WriteString(W, D.name); EndLine
  END ThisDisplay;

  (* ------------- Toolbox for standard display ---------------*)

  PROCEDURE Open*; (*open viewer in system track*)
    VAR X, Y: INTEGER;
      V: Viewers.Viewer;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    IF S.class = Texts.Name THEN
      Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, X, Y);
      V := MenuViewers.New(
        TextFrames.NewMenu(S.s, StandardMenu),
        TextFrames.NewText(TextFrames.Text(S.s), 0), TextFrames.menuH, X, Y)
    END
  END Open;

  PROCEDURE Clear*; (*used to clear Log*)
    VAR T: Texts.Text; F: Viewers.Viewer; buf: Texts.Buffer;
  BEGIN F := Oberon.Par.frame;
    IF (F # NIL) & (F.next IS TextFrames.Frame) & (F = Oberon.Par.vwr.dsc) THEN      
      NEW(buf); Texts.OpenBuf(buf); T := F.next(TextFrames.Frame).text; Texts.Delete(T, 0, T.len, buf)
    END
  END Clear;

  PROCEDURE Close*;
    VAR V: Viewers.Viewer;
  BEGIN
    IF Oberon.Par.frame = Oberon.Par.vwr.dsc THEN V := Oberon.Par.vwr ELSE V := Oberon.MarkedViewer() END;
    Viewers.Close(V)
  END Close;

  PROCEDURE CloseTrack*;
    VAR D: Viewers.Display; V: Viewers.Viewer;
  BEGIN V := Oberon.MarkedViewer(); D := Viewers.ThisDisplay(V); Viewers.CloseTrack(D, V.X)
  END CloseTrack;

  PROCEDURE Recall*; (*recover the last closed viewer of the current display*)
    VAR V: Viewers.Viewer; curDisplay: Viewers.Display; M: Viewers.ViewerMsg;
  BEGIN curDisplay := Viewers.CurDisplay; Viewers.Recall(curDisplay, V);
    IF (V # NIL) & (V.state = 0) THEN
      Viewers.Open(curDisplay, V, V.X, V.Y + V.H); M.id := Viewers.restore; V.handle(V, M)
    END
  END Recall;

  PROCEDURE Flush*; (*clear the last closed viewer of the current display*)
  BEGIN Viewers.Flush(Viewers.CurDisplay)
  END Flush;

  PROCEDURE RecallFocus*; (*recover the focus viewer of the current display*)
    VAR V: Viewers.Viewer; curDisplay: Viewers.Display; M: Viewers.ViewerMsg;
  BEGIN curDisplay := Viewers.CurDisplay; V := Viewers.CurDisplay.focusViewer;
    IF (V # NIL) & (V.state = 0) THEN
      Viewers.Open(curDisplay, V, V.X, V.Y + V.H); M.id := Viewers.restore; V.handle(V, M)
    END
  END RecallFocus;

  PROCEDURE OpenLog*; (*open a(nother) log viewer of the current display*)
    VAR V, curDisplay: Viewers.Viewer; X, Y: INTEGER;
  BEGIN curDisplay := Viewers.CurDisplay;
    IF curDisplay IS Oberon.Display THEN Oberon.AllocateSystemViewer(0, X, Y);
      V := MenuViewers.New(
        TextFrames.NewMenu("System.Log", LogMenu),
        TextFrames.NewText(curDisplay(Oberon.Display).log, 0), TextFrames.menuH, X, Y)
    END
  END OpenLog;

  PROCEDURE Copy*; (*create a copy of the viewer in the current display*)
    VAR V, V1: Viewers.Viewer; M: Viewers.CopyMsg; N: Viewers.ViewerMsg;
  BEGIN V := Oberon.Par.vwr; V.handle(V, M); V1 := M.V(Viewers.Viewer);
    Viewers.Open(Viewers.CurDisplay, V1, V.X, V.Y + V.H DIV 2);
    N.id := Viewers.restore; V1.handle(V1, N)
  END Copy;

  PROCEDURE Grow*; (*create a copy of the viewer in a newly created overlaying track*)
    VAR D: Viewers.Display; V, V1: Viewers.Viewer; M: Viewers.CopyMsg; N: Viewers.ViewerMsg;
  BEGIN V := Oberon.Par.vwr; D := Viewers.ThisDisplay(V);
    IF V.H < D.H - D.minH THEN Oberon.OpenTrack(D, V.X, V.W)
    ELSIF V.W < D.W THEN Oberon.OpenTrack(D, Oberon.UserTrack(V.X), D.W)
    END;
    IF (V.H < D.H - D.minH) OR (V.W < D.W) THEN
      V.handle(V, M); V1 := M.V(Viewers.Viewer);
      Viewers.Open(D, V1, V.X, D.H);
      N.id := Viewers.restore; V1.handle(V1, N)
    END
  END Grow;

  PROCEDURE Clone*; (*create a copy of the viewer in a newly created display*)
    VAR V, V1: Viewers.Viewer; M: Viewers.CopyMsg; N: Viewers.ViewerMsg; old: INTEGER;
      name: ARRAY Viewers.DnLength OF CHAR;
  BEGIN V := Oberon.Par.vwr; V.handle(V, M); V1 := M.V(Viewers.Viewer);
    old := Viewers.CurDisplay.id; MakeDisplayName(old, "cloned from display ", name);
    OpenDisplay0(name);
    Viewers.Open(Viewers.CurDisplay, V1, 0, Oberon.DisplayHeight(0));
    N.id := Viewers.restore; V1.handle(V1, N);
    Texts.WriteString(W, "Now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 2);
    Texts.WriteString(W,". To return to previous display:  System.SetDisplay ");
    Texts.WriteInt(W, old, 2); Texts.WriteLn(W);
    Texts.WriteString(W,"To close this (cloned) display and then return:     System.CloseDisplay ");
    Texts.WriteInt(W, Viewers.CurDisplay.id, 2); Texts.WriteInt(W, old, 2);
    EndLine
  END Clone;

  PROCEDURE Expand*; (*expand the viewer in the current display as much as possible*)
    VAR V: Viewers.Viewer; y, h: INTEGER;
  BEGIN V := Oberon.Par.vwr; y := 0; h := Oberon.DisplayHeight(0);
    Viewers.Validate(V, y, h); Viewers.Change(V, y, h)
  END Expand;

  PROCEDURE ExtendDisplay*; (*extend the current display to the right*)
    VAR V: Viewers.Viewer; curDisplay: Viewers.Display;
      X, Y, DX, DW, DH: INTEGER;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    IF S.class = Texts.Name THEN curDisplay := Viewers.CurDisplay; DX := curDisplay.curW;
      DW := Oberon.DisplayWidth(DX); DH := Oberon.DisplayHeight(DX);
      Oberon.NewTrack(curDisplay, DW DIV 8 * 5, DH);
      Oberon.NewTrack(curDisplay, DW DIV 8 * 3, DH);
      Input.SetMouseLimits(curDisplay.curW, curDisplay.H);
      Oberon.AllocateSystemViewer(DX, X, Y);
      V := MenuViewers.New(
        TextFrames.NewMenu(S.s, StandardMenu),
        TextFrames.NewText(TextFrames.Text(S.s), 0),
        TextFrames.menuH, X, Y)
    END
  END ExtendDisplay;

  (* ------------- Toolbox for module management ---------------*)

  PROCEDURE Free1 (VAR S: Texts.Scanner);
  BEGIN Texts.WriteString(W, S.s); Modules.Free(S.s);
    IF Modules.res = 0 THEN Texts.WriteString(W, " unloading")
    ELSIF Modules.res = 1 THEN Texts.WriteString(W, " removing (types in use in dynamic objects)")
    ELSIF Modules.res = 2 THEN Texts.WriteString(W, " removing (procedures in use in dynamic objects)")
    ELSIF Modules.res = 3 THEN Texts.WriteString(W, " removing (procedures in use in static objects)")
    ELSIF Modules.res = 4 THEN Texts.WriteString(W, " unloading failed (clients exist)")
    END ;
    EndLine
  END Free1;

  PROCEDURE Free*;
    VAR T: Texts.Text;
      beg, end, time: LONGINT;
      S: Texts.Scanner;
  BEGIN Texts.WriteString(W, "System.Free"); EndLine;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF (S.class = Texts.Char) & (S.c = "^") THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S);
        IF S.class = Texts.Name THEN Free1(S) END
      END
    ELSE
      WHILE S.class = Texts.Name DO Free1(S); Texts.Scan(S) END
    END ;
    Oberon.Collect(0)
  END Free;

  PROCEDURE FreeFonts*;
  BEGIN Texts.WriteString(W, "System.FreeFonts"); Fonts.Free; EndLine
  END FreeFonts;

  (* ------------- Toolbox of file system ---------------*)

  PROCEDURE List(name: FileDir.FileName; adr: LONGINT; VAR cont: BOOLEAN);
    VAR i0, i, j0, j: INTEGER; hp: FileDir.FileHeader;
  BEGIN
    i := 0;
    WHILE (pat[i] > "*") & (pat[i] = name[i]) DO INC(i) END ;
    IF (pat[i] = 0X) & (name[i] = 0X) THEN i0 := i; j0 := i
    ELSIF pat[i] = "*" THEN
      i0 := i; j0 := i+1;
      WHILE name[i0] # 0X DO
        i := i0; j := j0;
        WHILE (name[i] # 0X) & (name[i] = pat[j]) DO INC(i); INC(j) END ;
        IF pat[j] = 0X THEN
          IF name[i] = 0X THEN (*match*) j0 := j ELSE INC(i0) END
        ELSIF pat[j] = "*" THEN i0 := i; j0 := j+1
        ELSE INC(i0)
        END
      END
    END ;
    IF (name[i0] = 0X) & (pat[j0] = 0X) THEN (*found*)
      Texts.WriteString(W, name);
      IF pat[j0+1] = "!" THEN (*option*)
        Kernel.GetSector(adr, hp);
        Texts.Write(W, 9X); Texts.WriteClock(W, hp.date);
        Texts.WriteInt(W, hp.aleng*FileDir.SectorSize + hp.bleng - FileDir.HeaderSize, 8) (*length*)
        (*Texts.WriteHex(W, adr)*)
      END ;
      Texts.WriteLn(W)
    END
  END List;

  PROCEDURE Directory*;
    VAR X, Y, i: INTEGER; ch: CHAR;
      R: Texts.Reader;
      T, t: Texts.Text;
      V: Viewers.Viewer;
      beg, end, time: LONGINT;
      pre: ARRAY 32 OF CHAR;
  BEGIN Texts.OpenReader(R, Oberon.Par.text, Oberon.Par.pos); Texts.Read(R, ch);
    WHILE ch = " " DO Texts.Read(R, ch) END;
    IF (ch = "^") OR (ch = 0DX) THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN
        Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
        WHILE ch <= " " DO Texts.Read(R, ch) END
      END
    END ;
    i := 0;
    WHILE ch > "!" DO pat[i] := ch; INC(i); Texts.Read(R, ch) END;
    pat[i] := 0X;
    IF ch = "!" THEN pat[i+1] := "!" END ; (*directory option*)
    i := 0;
    WHILE pat[i] > "*" DO pre[i] := pat[i]; INC(i) END;
    pre[i] := 0X;
    Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, X, Y); t := TextFrames.Text("");
    V := MenuViewers.New(
      TextFrames.NewMenu("System.Directory", StandardMenu),
      TextFrames.NewText(t, 0), TextFrames.menuH, X, Y);
    FileDir.Enumerate(pre, List); Texts.Append(t, W.buf)
  END Directory;

  PROCEDURE CopyFiles*;
    VAR f, g: Files.File; Rf, Rg: Files.Rider; ch: CHAR;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.CopyFiles"); EndLine;
    WHILE S.class = Texts.Name DO
      name := S.s; Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
            Texts.WriteString(W, " copying"); Texts.Append(Oberon.Log, W.buf);
            f := Files.Old(name);
            IF f # NIL THEN g := Files.New(S.s);
              Files.Set(Rf, f, 0); Files.Set(Rg, g, 0); Files.Read(Rf, ch);
              WHILE ~Rf.eof DO Files.Write(Rg, ch); Files.Read(Rf, ch) END;
              Files.Register(g)
            ELSE Texts.WriteString(W, " failed")
            END ;
            EndLine
          END
        END
      END ;
      Texts.Scan(S)
    END
  END CopyFiles;

  PROCEDURE RenameFiles*;
    VAR res: INTEGER;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.RenameFiles"); EndLine;
    WHILE S.class = Texts.Name DO
      name := S.s; Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
            Texts.WriteString(W, " renaming"); Files.Rename(name, S.s, res);
            IF res > 1 THEN Texts.WriteString(W, " failed") END;
            EndLine
          END
        END
      END ;
      Texts.Scan(S)
    END
  END RenameFiles;

  PROCEDURE DeleteFiles*;
    VAR res: INTEGER; S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.DeleteFiles"); EndLine;
    WHILE S.class = Texts.Name DO
      Texts.WriteString(W, S.s); Texts.WriteString(W, " deleting");
      Files.Delete(S.s, res);
      IF res # 0 THEN Texts.WriteString(W, " failed") END;
      EndLine; Texts.Scan(S)
    END
  END DeleteFiles;

  (* ------------- Toolbox for system inspection ---------------*)

  PROCEDURE Watch*;
  BEGIN Texts.WriteString(W, "System.Watch"); Texts.WriteLn(W);
    Texts.WriteString(W, "  Modules space (bytes)"); Texts.WriteInt(W, Modules.AllocPtr, 8);
    Texts.WriteInt(W, Modules.AllocPtr * 100 DIV Kernel.heapOrg, 4); Texts.Write(W, "%"); EndLine;
    Texts.WriteString(W, "  Heap speace"); Texts.WriteInt(W, Kernel.allocated, 8);
    Texts.WriteInt(W, Kernel.allocated * 100 DIV (Kernel.heapLim - Kernel.heapOrg), 4); Texts.Write(W, "%"); EndLine;
    Texts.WriteString(W, "  Disk sectors "); Texts.WriteInt(W, Kernel.NofSectors, 4);
    Texts.WriteInt(W, Kernel.NofSectors * 100 DIV 10000H, 4); Texts.Write(W, "%"); EndLine;
    Texts.WriteString(W, "  Tasks"); Texts.WriteInt(W, Oberon.NofTasks, 4); EndLine
  END Watch;

  PROCEDURE ShowModules*;
    VAR T: Texts.Text;
      V: Viewers.Viewer;
      M: Modules.Module;
      X, Y: INTEGER;
      name: Modules.ModuleName;
  BEGIN T := TextFrames.Text("");
    Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, X, Y);
    V := MenuViewers.New(TextFrames.NewMenu("System.ShowModules", StandardMenu),
        TextFrames.NewText(T, 0), TextFrames.menuH, X, Y);
    M := Modules.root;
    WHILE M # NIL DO
      IF M.name[0] = 0X THEN Texts.WriteString(W, "---")
      ELSIF M.name[0] < 80X THEN Texts.WriteString(W, M.name); Texts.Write(W, 9X); Texts.WriteHex(W, ORD(M));
        Texts.WriteHex(W, M.code); Texts.WriteInt(W, M.refcnt, 4);
      ELSE (*hidden module*) name := M.name; name[0] := CHR(ORD(name[0]) - 128);
        Texts.WriteString(W, "*"); Texts.WriteString(W, name); Texts.Write(W, 9X); Texts.WriteHex(W, ORD(M));
        Texts.WriteHex(W, M.code); Texts.WriteInt(W, M.refcnt, 4);
        Texts.WriteString(W, " (removed from module list)")
      END ;
      Texts.WriteLn(W); M := M.next
    END;
    Texts.Append(T, W.buf)
  END ShowModules;

  PROCEDURE ShowCommands*;
    VAR M: Modules.Module;
      comadr: LONGINT; ch: CHAR;
      T: Texts.Text;
      S: Texts.Scanner;
      V: Viewers.Viewer;
      X, Y: INTEGER;
  BEGIN GetArg(S);
    IF S.class = Texts.Name THEN
      Modules.Load(S.s, M);
      IF M # NIL THEN
        Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, X, Y); T := TextFrames.Text("");
        V := MenuViewers.New(TextFrames.NewMenu("System.Commands", StandardMenu),
            TextFrames.NewText(T, 0), TextFrames.menuH, X, Y);
        comadr := M.cmd; SYSTEM.GET(comadr, ch); INC(comadr);
        WHILE ch # 0X DO
          Texts.WriteString(W, S.s); Texts.Write(W, ".");
          REPEAT Texts.Write(W, ch); SYSTEM.GET(comadr, ch); INC(comadr)
          UNTIL ch = 0X;
          WHILE comadr MOD 4 # 0 DO INC(comadr) END ;
          Texts.WriteLn(W); INC(comadr, 4); SYSTEM.GET(comadr, ch); INC(comadr)
        END ;
        Texts.Append(T, W.buf)
      END
    END
  END ShowCommands;

  PROCEDURE InitMod(name: ARRAY OF CHAR);
    VAR mod: Modules.Module; P: Modules.Command; w: INTEGER;
  BEGIN mod := Modules.root;
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END ;
    IF mod # NIL THEN SYSTEM.GET(mod.ent, w);
      P := SYSTEM.VAL(Modules.Command, mod.code + w); P
    END
  END InitMod;

  PROCEDURE RunInit*; (*call module initialization body*)
    VAR S: Texts.Scanner;
  BEGIN GetArg(S);
    IF S.class = Texts.Name THEN InitMod(S.s) END
  END RunInit;

  PROCEDURE ShowFonts*;
    VAR fnt: Fonts.Font;
  BEGIN Texts.WriteString(W, "System.ShowFonts"); Texts.WriteLn(W); fnt := Fonts.root;
    WHILE fnt # NIL DO
      Texts.Write(W, 9X); Texts.WriteString(W, fnt.name); Texts.WriteLn(W); fnt := fnt.next
    END ;
    Texts.Append(Oberon.Log, W.buf)
  END ShowFonts;

  PROCEDURE Trap(VAR a: INTEGER; b: INTEGER);
    VAR u, v, w: INTEGER; mod: Modules.Module;
  BEGIN u := SYSTEM.REG(15); SYSTEM.GET(u - 4, v); w := v DIV 10H MOD 10H; (*trap number*)
    IF w = 0 THEN Kernel.New(a, b)
    ELSE (*trap*) Texts.WriteLn(W); Texts.WriteString(W, "  pos "); Texts.WriteInt(W, v DIV 100H MOD 10000H, 4);
      Texts.WriteString(W, "  TRAP"); Texts.WriteInt(W, w, 4); mod := Modules.root;
      WHILE (mod # NIL) & ((u < mod.code) OR (u >= mod.imp)) DO mod := mod.next END ;
      IF mod # NIL THEN Texts.WriteString(W, " in "); Texts.WriteString(W, mod.name) END ;
      Texts.WriteString(W, " at"); Texts.WriteHex(W, u);
      Texts.WriteString(W, "   pos "); Texts.WriteInt(W, (u - mod.code) DIV 4, 4); Texts.WriteString(W, " in DecObj");
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); Oberon.Reset
    END
  END Trap;

  PROCEDURE Abort;
    VAR n: INTEGER; mod: Modules.Module;
  BEGIN n := SYSTEM.REG(15); Texts.WriteString(W, "  ABORT"); mod := Modules.root;
    WHILE (mod # NIL) & ((n < mod.code) OR (n >= mod.imp)) DO mod := mod.next END ;
    IF mod # NIL THEN Texts.WriteString(W, " in "); Texts.WriteString(W, mod.name) END ;
    Texts.WriteString(W, " at"); Texts.WriteHex(W, n);
    Texts.WriteString(W, "   pos "); Texts.WriteInt(W, (n - mod.code - 4) DIV 4, 4); Texts.WriteString(W, " in DecObj");
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); Oberon.Reset
  END Abort;

BEGIN Texts.OpenWriter(W); OpenDisplay0("Oberon");  
  Kernel.Install(SYSTEM.ADR(Trap), 20H); Kernel.Install(SYSTEM.ADR(Abort), 0)
END System.
