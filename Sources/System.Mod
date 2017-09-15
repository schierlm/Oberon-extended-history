MODULE System; (*JG 3.10.90 / NW 12.10.93 / NW 28.11.15 / AP 1.9.17*)
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
    VAR logV, toolV, menu, main: Viewers.Frame; X, Y: INTEGER;
  BEGIN
    IF Viewers.CurDisplay # NIL THEN
      Texts.WriteString(W, "Oberon V6  NW 14.4.13 / AP 1.9.17  Display ");
      Texts.WriteInt(W, Viewers.CurDisplay.id, 2); Texts.Write(W, " ");
      Texts.WriteString(W, Viewers.CurDisplay.name); EndLine;
      Oberon.AllocateSystemViewer(0, X, Y);
      menu := TextFrames.NewMenu("System.Log", LogMenu);
      main := TextFrames.NewText(Oberon.Log, 0);
      logV := MenuViewers.New(menu, main, TextFrames.menuH, X, Y);
      Oberon.AllocateSystemViewer(0, X, Y);
      menu := TextFrames.NewMenu("System.Tool", StandardMenu);
      main := TextFrames.NewText(TextFrames.Text("System.Tool"), 0);
      toolV := MenuViewers.New(menu, main, TextFrames.menuH, X, Y)
    END
  END OpenViewers;

  PROCEDURE CreateDisplay(name: ARRAY OF CHAR);
    VAR D: Viewers.Display;
  BEGIN NEW(D); Oberon.InitDisplay(D, name); (*create and initialize a new display*)
    Oberon.SetDisplay(D); (*make it the current display*)
    OpenViewers (*open log and system tool viewer*)
  END CreateDisplay;

  PROCEDURE OpenDisplay*; (*display name is provided as parameter*)
    VAR S: Texts.Scanner; prev: INTEGER;
      name: ARRAY Viewers.DnLength OF CHAR;
  BEGIN prev := Viewers.CurDisplay.id;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN CreateDisplay(S.s)
    ELSE MakeDisplayName(prev, "opened from display ", name); CreateDisplay(name)
    END ;
    Texts.WriteString(W, " now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 2);
    Texts.WriteString(W,". to return to previous display:  System.SetDisplay "); Texts.WriteInt(W, prev, 2);
    EndLine
  END OpenDisplay;

  PROCEDURE CloseDisplay*; (*display id and (optionally) a hint are provided as parameters*)
    VAR D: Viewers.Display; S: Texts.Scanner; prev, id, hint: INTEGER;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN id := S.i; D := Viewers.GetDisplay(S.i);
      IF D = NIL THEN Texts.WriteString(W, " no such display ")
      ELSE prev := Viewers.CurDisplay.id;
        IF D.id = prev THEN Texts.Scan(S);
          IF S.class = Texts.Int THEN hint := S.i ELSE hint := 0 END
        ELSE hint := prev
        END ;
        Oberon.CloseDisplay(D, hint);
        IF (id = prev) & (Viewers.CurDisplay.id = prev) THEN Texts.WriteString(W, " can't close last display")
        ELSE Texts.WriteString(W, " display "); Texts.WriteInt(W, id, 2); Texts.WriteString(W, " closed");
          IF id = prev THEN Texts.WriteString(W, ". now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 2) END
        END
      END
    ELSE Texts.WriteString(W, " must provide a valid display number")
    END ;
    EndLine
  END CloseDisplay;

  PROCEDURE SetDisplay*; (*display id is provided as parameter*)
    VAR D: Viewers.Display; S: Texts.Scanner; prev: INTEGER;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN D := Viewers.GetDisplay(S.i);
      IF D = NIL THEN Texts.WriteString(W, " no such display ")
      ELSE prev := Viewers.CurDisplay.id;
        IF D.id = prev THEN Texts.WriteString(W, " already the current display ")
        ELSE Oberon.SetDisplay(D);
          Texts.WriteString(W, " now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 2);
          Texts.WriteString(W,". to return to previous display:  System.SetDisplay "); Texts.WriteInt(W, prev, 2)
        END
      END
    ELSE Texts.WriteString(W, " must provide a valid display number")
    END ;
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
    END ;
    EndLine
  END SetDisplayName;

  PROCEDURE ShowDisplays*;
    VAR D: Viewers.Frame;
  BEGIN D := Viewers.root; Texts.WriteString(W, "System.ShowDisplays"); EndLine;
    WHILE D # NIL DO
      Texts.WriteString(W, " display "); Texts.WriteInt(W, D(Viewers.Display).id, 2);
      Texts.WriteString(W, " "); Texts.WriteString(W, D(Viewers.Display).name);
      IF D = Viewers.CurDisplay THEN Texts.WriteString(W, "      (current display)") END ;
      EndLine;
      D := D.next
    END
  END ShowDisplays;

  PROCEDURE ThisDisplay*;
    VAR D: Viewers.Display;
  BEGIN D := Viewers.ThisDisplay(Oberon.Par.vwr);
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
    VAR T: Texts.Text; F: Viewers.Frame; buf: Texts.Buffer;
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
    VAR V: Viewers.Viewer; M: Viewers.ViewerMsg;
  BEGIN V := Viewers.FocusViewer;
    IF (V # NIL) & (V.state = 0) THEN
      Viewers.Open(Viewers.CurDisplay, V, V.X, V.Y + V.H); M.id := Viewers.restore; V.handle(V, M)
    END
  END RecallFocus;

  PROCEDURE OpenLog*; (*open a(nother) log viewer for the system-wide central log*)
    VAR V: Viewers.Viewer; X, Y: INTEGER;
  BEGIN Oberon.AllocateSystemViewer(0, X, Y);
    IF Oberon.Log = NIL THEN Oberon.OpenLog(TextFrames.Text("")) END ;
    V := MenuViewers.New(
      TextFrames.NewMenu("System.Log", LogMenu),
      TextFrames.NewText(Oberon.Log, 0), TextFrames.menuH, X, Y)
  END OpenLog;

  PROCEDURE Copy*; (*create a copy of the viewer in the current display*)
    VAR V, V1: Viewers.Viewer; M: Viewers.CopyMsg; N: Viewers.ViewerMsg;
  BEGIN V := Oberon.Par.vwr; V.handle(V, M); V1 := M.F(Viewers.Viewer);
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
      V.handle(V, M); V1 := M.F(Viewers.Viewer);
      Viewers.Open(D, V1, V.X, D.H);
      N.id := Viewers.restore; V1.handle(V1, N)
    END
  END Grow;

  PROCEDURE Clone*; (*create a copy of the viewer in a newly created display*)
    VAR D: Viewers.Display; V, V1: Viewers.Viewer;
      M: Viewers.CopyMsg; N: Viewers.ViewerMsg; prev: INTEGER;
      name: ARRAY Viewers.DnLength OF CHAR;
  BEGIN V := Oberon.Par.vwr; V.handle(V, M); V1 := M.F(Viewers.Viewer); prev := Viewers.CurDisplay.id;
    MakeDisplayName(prev, "cloned from display ", name); CreateDisplay(name);
    Viewers.Open(Viewers.CurDisplay, V1, 0, Oberon.DisplayHeight(0));
    N.id := Viewers.restore; V1.handle(V1, N);
    Texts.WriteString(W, " now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 2);
    Texts.WriteString(W,". to return to previous display:  System.SetDisplay ");
    Texts.WriteInt(W, prev, 2); Texts.WriteLn(W);
    Texts.WriteString(W," to close this (cloned) display and then return:  System.CloseDisplay ");
    Texts.WriteInt(W, Viewers.CurDisplay.id, 2); Texts.WriteInt(W, prev, 2);
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
      Oberon.InitTrack(curDisplay, DW DIV 8 * 5, DH);
      Oberon.InitTrack(curDisplay, DW DIV 8 * 3, DH);
      Input.SetMouseLimits(curDisplay.curW, curDisplay.H);
      Oberon.AllocateSystemViewer(DX, X, Y);
      V := MenuViewers.New(
        TextFrames.NewMenu(S.s, StandardMenu),
        TextFrames.NewText(TextFrames.Text(S.s), 0),
        TextFrames.menuH, X, Y)
    END
  END ExtendDisplay;

  (* ------------- Toolbox for module management ---------------*)

  PROCEDURE Select1(on, this, clients, imports: BOOLEAN); (*modules, clients, imports*)
    VAR T: Texts.Text;
      beg, end, time: LONGINT;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF (S.class = Texts.Char) & (S.c = "^") THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN
        Texts.OpenScanner(S, T, beg); Texts.Scan(S);
        IF (S.class = Texts.Name) OR (S.class = Texts.String) THEN
          Texts.Write(W, " "); Texts.WriteString(W, S.s);
          Modules.Select(S.s, on, this, clients, imports); Texts.Scan(S)
        END
      END
    ELSE
      WHILE (S.class = Texts.Name) OR (S.class = Texts.String) DO
	Texts.Write(W, " "); Texts.WriteString(W, S.s);
        Modules.Select(S.s, on, this, clients, imports); Texts.Scan(S)
      END
    END
  END Select1;

  PROCEDURE Select*; (*module names are provided as parameters*)
  BEGIN Texts.WriteString(W, "System.Select"); Select1(TRUE, TRUE, FALSE, FALSE); EndLine
  END Select;

  PROCEDURE SelectAll*;
  BEGIN Modules.SelectAll(TRUE)
  END SelectAll;

  PROCEDURE DeselectAll*;
  BEGIN Modules.SelectAll(FALSE)
  END DeselectAll;

  PROCEDURE WriteSelection(): BOOLEAN; (*in log viewer*)
    VAR mod: Modules.Module; hasSel: BOOLEAN;
  BEGIN mod := Modules.root; hasSel := FALSE;
    WHILE mod # NIL DO
      IF (mod.name[0] # 0X) & Modules.Selected(mod) THEN
        IF ~hasSel THEN Texts.Write(W, " "); hasSel := TRUE END ;
        Texts.Write(W, " "); Texts.WriteString(W, mod.name)
      END ;
      mod := mod.next
    END ;
    IF hasSel THEN Texts.Append(Oberon.Log, W.buf) END
    RETURN hasSel
  END WriteSelection;

  PROCEDURE WriteFreeMsg(allowhiding: BOOLEAN);
  BEGIN
    IF Modules.res = 0 THEN Texts.WriteString(W, " unloading")
    ELSIF Modules.res = 1 THEN Texts.WriteString(W, " unloading failed (clients exist)")
    ELSIF Modules.res < 5 THEN
      IF allowhiding THEN Texts.WriteString(W, " removing") ELSE Texts.WriteString(W, " unloading failed") END ;
      IF Modules.res = 2 THEN Texts.WriteString(W, " (types in use in dynamic objects)")
      ELSIF Modules.res = 3 THEN Texts.WriteString(W, " (procedures in use in dynamic objects)")
      ELSIF Modules.res = 4 THEN Texts.WriteString(W, " (procedures in use in static objects)")
      END
    END ;
    EndLine
  END WriteFreeMsg;

  PROCEDURE Free1(this, clients, imports, shrink, allowhiding: BOOLEAN; exclude: ARRAY OF CHAR);
  BEGIN Modules.SelectAll(FALSE); Select1(TRUE, this, clients, imports);
    IF exclude[0] # 0X THEN Modules.Select(exclude, FALSE, TRUE, FALSE, TRUE);
      Texts.WriteString(W, " ("); Texts.WriteString(W, exclude); Texts.WriteString(W, " and its clients excluded)")
    END ;
    EndLine;
    IF shrink THEN Modules.ShrinkSelection END ;
    IF WriteSelection() THEN Modules.FreeSelection(allowhiding); WriteFreeMsg(allowhiding); Oberon.Collect(0) END
  END Free1;

  (*Unload various subsets of modules from memory or hide them from module list*)

  PROCEDURE Free*; (*free modules as a group; module names are provided as parameters*)
  BEGIN Texts.WriteString(W, "System.Free"); Free1(TRUE, FALSE, FALSE, FALSE, TRUE, "")
  END Free;

  PROCEDURE FreeSelection*; (*free selected modules as a group*)
  BEGIN Texts.WriteString(W, "System.FreeSelection"); EndLine;
    IF WriteSelection() THEN Modules.FreeSelection(TRUE); WriteFreeMsg(TRUE); Oberon.Collect(0) END
  END FreeSelection;

  PROCEDURE FreeImports*; (*free modules and their imports; module names are provided as parameters*)
  BEGIN Texts.WriteString(W, "System.FreeImports"); Free1(TRUE, FALSE, TRUE, FALSE, TRUE, "System")
  END FreeImports;

  PROCEDURE FreeClients*; (*free modules and their clients; module names are provided as parameters*)
  BEGIN Texts.WriteString(W, "System.FreeClients"); Free1(TRUE, TRUE, FALSE, FALSE, TRUE, "System")
  END FreeClients;

  PROCEDURE FreeRemovableImports*; (*free the removable subset of the specifed modules and their imports*)
  BEGIN Texts.WriteString(W, "System.FreeRemovableImports"); Free1(TRUE, FALSE, TRUE, TRUE, TRUE, "System")
  END FreeRemovableImports;

  PROCEDURE FreeRemovableClients*; (*free the removable subset of the specifed modules and their clients*)
  BEGIN Texts.WriteString(W, "System.FreeRemovableClients"); Free1(TRUE, TRUE, FALSE, TRUE, TRUE, "System")
  END FreeRemovableClients;

  (*Unload various subsets of modules from memory, but don't hide them from module list if refs exist*)

  PROCEDURE Unload*; (*unload modules as a group; module names are provided as parameters*)
  BEGIN Texts.WriteString(W, "System.Unload"); Free1(TRUE, FALSE, FALSE, FALSE, FALSE, "System")
  END Unload;

  PROCEDURE UnloadSelection*; (*unload selected modules as a group*)
  BEGIN Texts.WriteString(W, "System.UnloadSelection"); EndLine;
    IF WriteSelection() THEN Modules.FreeSelection(FALSE); WriteFreeMsg(FALSE); Oberon.Collect(0) END
  END UnloadSelection;

  PROCEDURE UnloadImports*; (*unload modules and their imports; module names are provided as parameters*)
  BEGIN Texts.WriteString(W, "System.UnloadImports"); Free1(TRUE, FALSE, TRUE, FALSE, FALSE, "System")
  END UnloadImports;

  PROCEDURE UnloadClients*; (*unload modules and their clients; module names are provided as parameters*)
  BEGIN Texts.WriteString(W, "System.UnloadClients"); Free1(TRUE, TRUE, FALSE, FALSE, FALSE, "System")
  END UnloadClients;

  PROCEDURE UnloadRemovableImports*; (*unload the removable subset of the specifed modules and their imports*)
  BEGIN Texts.WriteString(W, "System.UnloadRemovableImports"); Free1(TRUE, FALSE, TRUE, TRUE, FALSE, "System")
  END UnloadRemovableImports;

  PROCEDURE UnloadRemovableClients*; (*unload the removable subset of the specifed modules and their clients*)
  BEGIN Texts.WriteString(W, "System.FreeRemovableClients"); Free1(TRUE, TRUE, FALSE, TRUE, FALSE, "System")
  END UnloadRemovableClients;

  (*Show various subsets of modules*)

  PROCEDURE Show1(this, clients, imports, shrink: BOOLEAN; exclude: ARRAY OF CHAR);
  BEGIN Modules.SelectAll(FALSE); Select1(TRUE, this, clients, imports);
    IF exclude[0] # 0X THEN Modules.Select(exclude, FALSE, TRUE, FALSE, TRUE);
      Texts.WriteString(W, " ("); Texts.WriteString(W, exclude); Texts.WriteString(W, " and its clients excluded)")
    END ;
    EndLine;
    IF shrink THEN Modules.ShrinkSelection END ;
    IF WriteSelection() THEN EndLine; Modules.SelectAll(FALSE) END
  END Show1;

  PROCEDURE ShowSelection*; (*show selected modules*)
  BEGIN Texts.WriteString(W, "System.ShowSelection"); EndLine;
    IF WriteSelection() THEN Texts.WriteString(W, " selected"); EndLine END
  END ShowSelection;

  PROCEDURE ShowImports*; (*show modules and their imports; module names are provided as parameters*)
  BEGIN Texts.WriteString(W, "System.ShowImports"); Show1(TRUE, FALSE, TRUE, FALSE, "")
  END ShowImports;

  PROCEDURE ShowClients*; (*show modules and their clients; module names are provided as parameters*)
  BEGIN Texts.WriteString(W, "System.ShowClients"); Show1(TRUE, TRUE, FALSE, FALSE, "")
  END ShowClients;

  PROCEDURE ShowRemovableImports*; (*show the removable subset of the specifed modules and their imports*)
  BEGIN Texts.WriteString(W, "System.ShowRemovableImports"); Show1(TRUE, FALSE, TRUE, TRUE, "System")
  END ShowRemovableImports;

  PROCEDURE ShowRemovableClients*; (*show the removable subset of the specifed modules and their clients*)
  BEGIN Texts.WriteString(W, "System.ShowRemovableClients"); Show1(TRUE, TRUE, FALSE, TRUE, "System")
  END ShowRemovableClients;

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
  BEGIN T := TextFrames.Text("");
    Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, X, Y);
    V := MenuViewers.New(TextFrames.NewMenu("System.ShowModules", StandardMenu),
        TextFrames.NewText(T, 0), TextFrames.menuH, X, Y);
    Modules.Collect;
    M := Modules.root;
    WHILE M # NIL DO
      IF M.name[0] # 0X THEN
        Texts.WriteString(W, M.name); Texts.WriteInt(W, M.num, 4); Texts.Write(W, 9X);
        Texts.WriteHex(W, ORD(M)); Texts.WriteHex(W, M.code); Texts.WriteInt(W, M.refcnt, 4)
      ELSE Texts.WriteString(W, "---")
      END ;
      IF Modules.Selected(M) THEN Texts.WriteString(W, " *") END ;
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

  PROCEDURE ShowFonts*;
    VAR fnt: Fonts.Font;
  BEGIN Texts.WriteString(W, "System.ShowFonts"); Texts.WriteLn(W); fnt := Fonts.root;
    WHILE fnt # NIL DO
      Texts.Write(W, 9X); Texts.WriteString(W, fnt.name); Texts.WriteLn(W); fnt := fnt.next
    END ;
    Texts.Append(Oberon.Log, W.buf)
  END ShowFonts;

  PROCEDURE Unmark*; (*heap*)
    VAR resType, resProc: INTEGER;
  BEGIN Kernel.Scan(NIL, NIL, resType, resProc)
  END Unmark;

  PROCEDURE InitMod(name: ARRAY OF CHAR);
    VAR mod: Modules.Module; body: Modules.Command; w: INTEGER;
  BEGIN mod := Modules.root;
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END ;
    IF mod # NIL THEN SYSTEM.GET(mod.ent, w);
      body := SYSTEM.VAL(Modules.Command, mod.code + w); body
    END
  END InitMod;

  PROCEDURE RunInit*; (*call module initialization body*)
    VAR S: Texts.Scanner;
  BEGIN GetArg(S);
    IF S.class = Texts.Name THEN InitMod(S.s) END
  END RunInit;

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

BEGIN Texts.OpenWriter(W);
  Oberon.OpenLog(TextFrames.Text("")); CreateDisplay("Oberon");
  Kernel.Install(SYSTEM.ADR(Trap), 20H); Kernel.Install(SYSTEM.ADR(Abort), 0)
END System.
