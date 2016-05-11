MODULE System; (*JG 3.10.90 / NW 12.10.93 / NW 28.11.15 / AP 9.5.16*)
  IMPORT SYSTEM, Kernel, FileDir, Files, Modules, Input, Fonts, Texts,
    Viewers, Oberon, Tasks, MenuViewers, TextViewers;

  CONST
    StandardMenu = "System.Close System.Copy System.Grow Edit.Search Edit.Store";
    LogMenu = "Edit.Locate Edit.Search System.Copy System.Grow System.Clear";

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
  BEGIN Tasks.Collect(0)
  END Collect;

  (* ------------- Toolbox for logical display area management ---------------*)

  PROCEDURE OpenViewers;
    VAR logV, toolV: Viewers.Viewer;
      menu, main: Viewers.Viewer;
      d: LONGINT; X, Y: INTEGER;
  BEGIN d := Kernel.Clock(); Texts.WriteString(W, "Oberon V6  NW 14.4.13 / AP 24.4.16  Display ");
    Texts.WriteInt(W, Viewers.CurDisplay.id, 2); Texts.Write(W, " ");
    Texts.WriteString(W, Viewers.CurDisplay.name); EndLine;
    Oberon.AllocateSystemViewer(0, X, Y);
    menu := TextViewers.NewMenu("System.Log", LogMenu);
    main := TextViewers.NewText(Viewers.CurDisplay(Oberon.DisplayArea).log, 0);   (*!*)
    logV := MenuViewers.New(menu, main, TextViewers.menuH, X, Y);
    Oberon.AllocateSystemViewer(0, X, Y);
    menu := TextViewers.NewMenu("System.Tool", StandardMenu);
    main := TextViewers.NewText(TextViewers.Text("System.Tool"), 0);
    toolV := MenuViewers.New(menu, main, TextViewers.menuH, X, Y)
  END OpenViewers;

  PROCEDURE MakeDisplayName (x: INTEGER; VAR name: ARRAY OF CHAR); (*0 <= x < 10^5*)
    VAR i, j: INTEGER; buf: ARRAY 5 OF INTEGER;
  BEGIN name := "Display "; i := 0; j := 8;
    REPEAT buf[i] := x MOD 10; x := x DIV 10; INC(i) UNTIL x = 0;
    REPEAT DEC(i); name[j] := CHR(buf[i] + ORD("0")); INC(j) UNTIL (i = 0) OR (j = Viewers.DnLength);
    IF j < Viewers.DnLength THEN name[j] := 0X END
  END MakeDisplayName;

  PROCEDURE OpenDisplay (name: ARRAY OF CHAR); (*if name is empty, a default name will be created*)
    VAR D: Oberon.DisplayArea; DW, DH: INTEGER;
  BEGIN DW := Oberon.DisplayWidth(0); DH := Oberon.DisplayHeight(0);
    Oberon.OpenDisplay(D, DW, DH, name);
    IF D.name = "" THEN MakeDisplayName(D.id, D.name) END;
    Viewers.SetCurDisplay(D);                        (*required for InitTrack*)
    Oberon.InitTrack(D, DW DIV 8 * 5, DH);           (*add and init user track*)
    Oberon.InitTrack(D, DW DIV 8 * 3, DH);           (*add and init system track*)
    Viewers.SetFocusViewer(Viewers.This(D, 0, 0));
    Oberon.SetDisplayLog(D, TextViewers.Text(""));   (*create a new log for the new display*)
    Oberon.OpenLog(D.log);                           (*make Oberon.Log point to it*)
    OpenViewers;
  END OpenDisplay;

  PROCEDURE NewDisplay*; (*create new display with standard Oberon tracks and viewers*)
    VAR S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN OpenDisplay(S.s) ELSE OpenDisplay("") END
  END NewDisplay;

  PROCEDURE CloseDisplay*; (*display id is provided as parameter*)
    VAR D: Viewers.DisplayArea; S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN D := Viewers.GetDisplay(S.i);
      IF D = NIL THEN Texts.WriteString(W, " no such display ")
      ELSIF D = Viewers.CurDisplay THEN Texts.WriteString(W, " cannot close current display ")
      ELSE Texts.WriteString(W, " closing display "); Texts.WriteInt(W, D.id, 2);
        Texts.Write(W, " "); Texts.WriteString(W, D.name);
        Viewers.CloseDisplay(D)
      END;
      Texts.WriteLn(W); Oberon.WrLog(W);
    END
  END CloseDisplay;

  PROCEDURE ThisDisplay*;
    VAR V: Viewers.Viewer; D: Viewers.DisplayArea;
  BEGIN V := Oberon.Par.vwr; D := Viewers.ThisDisplay(V);
    Texts.WriteString(W, " current display "); Texts.WriteInt(W, D.id, 2); Texts.Write(W, " ");
    Texts.WriteString(W, D.name); Texts.WriteLn(W); Oberon.WrLog(W);
  END ThisDisplay;

  PROCEDURE SetDisplay*; (*set the current display, display id is provided as parameter*)
    VAR D: Viewers.DisplayArea; S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN D := Viewers.GetDisplay(S.i);
      IF D = NIL THEN Texts.WriteString(W, " no such display ")
      ELSIF D = Viewers.CurDisplay THEN Texts.WriteString(W, " already the current display ")
      ELSE
        Oberon.OpenLog(D(Oberon.DisplayArea).log); (*make Oberon.Log point to log of new current display*)
        Viewers.SetCurDisplay(D);
        Input.SetMouseLimits(D.curW, D.H);
        Viewers.SetFocusViewer(Viewers.This(D, 0, 0));
        Texts.WriteString(W, " Welcome back to display "); Texts.WriteInt(W, D.id, 2);
        Texts.Write(W, " "); Texts.WriteString(W, D.name);
      END;
      Texts.WriteLn(W); Oberon.WrLog(W)
    END
  END SetDisplay;

  PROCEDURE SetDisplayName*; (*display id and new name are provided as parameters*)
    VAR D: Viewers.DisplayArea; S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN  Texts.Scan(S);
      IF S.class = Texts.Name THEN D := Viewers.GetDisplay(S.i);
        IF D = NIL THEN Texts.WriteString(W, " no such display ")
        ELSE Viewers.SetDisplayName(D, S.s);
          Texts.WriteString(W, " name of display "); Texts.WriteInt(W, D.id, 2);
          Texts.Write(W, " "); Texts.WriteString(W, " set to "); Texts.WriteString(W, D.name)
        END
      ELSE Texts.WriteString(W, " no display name provided (SetDisplayName id name)");
      END
    ELSE Texts.WriteString(W, " no display id provided (SetDisplayName id name)");
    END;
    Texts.WriteLn(W); Oberon.WrLog(W)
  END SetDisplayName;
  
  PROCEDURE ShowDisplays*;
     VAR D: Viewers.DisplayArea;
  BEGIN Texts.WriteString(W, "System.ShowDisplays"); EndLine;
     D := Viewers.FirstDisplay();
     WHILE ~Viewers.EndDisplay(D) DO Texts.WriteString(W, " ");
       Texts.WriteString(W, " display "); Texts.WriteInt(W, D.id, 2);
       Texts.Write(W, " "); Texts.WriteString(W, D.name);
       IF D = Viewers.CurDisplay THEN Texts.WriteString(W, "      (current display)") END;
       Texts.WriteLn(W); Oberon.WrLog(W);
       D := Viewers.NextDisplay(D);
     END
  END ShowDisplays;

  (* ------------- Toolbox for standard display ---------------*)

  PROCEDURE Open*;  (*open viewer in system track*)
    VAR X, Y: INTEGER;
      V: Viewers.Viewer;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    IF S.class = Texts.Name THEN
      Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, X, Y);
      V := MenuViewers.New(
        TextViewers.NewMenu(S.s, StandardMenu),
        TextViewers.NewText(TextViewers.Text(S.s), 0), TextViewers.menuH, X, Y)
    END
  END Open;

  PROCEDURE Clear*;  (*used to clear Log*)
    VAR T: Texts.Text; V: Viewers.Viewer; buf: Texts.Buffer;
  BEGIN V := Oberon.Par.frame;
    IF (V # NIL) & (V.next IS TextViewers.Viewer) & (V = Oberon.Par.vwr.dsc) THEN
      T := V.next(TextViewers.Viewer).text; Texts.Delete(T, 0, T.len, buf)
    END
  END Clear;

  PROCEDURE Close*;
    VAR V: Viewers.Viewer;
  BEGIN
    IF Oberon.Par.frame = Oberon.Par.vwr.dsc THEN V := Oberon.Par.vwr
    ELSE V := Oberon.MarkedViewer()
    END;
    Viewers.Close(V)
  END Close;

  PROCEDURE CloseTrack*;
    VAR V: Viewers.Viewer;
  BEGIN V := Oberon.MarkedViewer(); Viewers.CloseTrack(Viewers.CurDisplay, V.X)
  END CloseTrack;

  PROCEDURE Recall*;
    VAR V: Viewers.Viewer; M: Viewers.ViewerMsg;
  BEGIN Viewers.Recall(Viewers.CurDisplay, V);
    IF (V # NIL) & (V.state = 0) THEN
      Viewers.Open(Viewers.CurDisplay, V, V.X, V.Y + V.H); M.id := Viewers.restore; V.handle(V, M)
    END
  END Recall;

  PROCEDURE Copy*;  (*if "n" is pressed, the copied viewer is opened in user track of a new display*)
    VAR V, V1: Viewers.Viewer; M: Viewers.CopyMsg; N: Viewers.ViewerMsg;
      X, Y: INTEGER; ch: CHAR;
  BEGIN V := Oberon.Par.vwr; X := V.X; Y := V.Y + V.H DIV 2;
    IF Input.Available() > 0 THEN Input.Read(ch);
      IF ch = "n" THEN OpenDisplay(""); X := 0; Y := Oberon.DisplayHeight(X) END
    END;
    V.handle(V, M); V1 := M.V(Viewers.Viewer);
    Viewers.Open(Viewers.CurDisplay, V1, X, Y);
    N.id := Viewers.restore; V1.handle(V1, N)
  END Copy;

  PROCEDURE Grow*;
    VAR V, V1: Viewers.Viewer; M: Viewers.CopyMsg; N: Viewers.ViewerMsg;
      DW, DH: INTEGER;
  BEGIN V := Oberon.Par.vwr;
    DW := Oberon.DisplayWidth(V.X); DH := Oberon.DisplayHeight(V.X);
    IF V.H < DH - Viewers.CurDisplay.minH THEN Oberon.OpenTrack(V.X, V.W)
    ELSIF V.W < DW THEN Oberon.OpenTrack(Oberon.UserTrack(V.X), DW)
    END;
    IF (V.H < DH - Viewers.CurDisplay.minH) OR (V.W < DW) THEN
      V.handle(V, M); V1 := M.V(Viewers.Viewer);
      Viewers.Open(Viewers.CurDisplay, V1, V.X, DH);;
      N.id := Viewers.restore; V1.handle(V1, N)
    END
  END Grow;

  PROCEDURE ExtendDisplay*;
    VAR V: Viewers.Viewer;
      X, Y, DX, DW, DH: INTEGER;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    IF S.class = Texts.Name THEN
      DX := Viewers.CurDisplay.curW;
      DW := Oberon.DisplayWidth(DX); DH := Oberon.DisplayHeight(DX);
      Oberon.InitTrack(Viewers.CurDisplay, DW DIV 8 * 5, DH);  (*init additional user track*)
      Oberon.InitTrack(Viewers.CurDisplay, DW DIV 8 * 3, DH);  (*init additional system track*)
      Oberon.AllocateSystemViewer(DX, X, Y);
      V := MenuViewers.New(
        TextViewers.NewMenu(S.s, StandardMenu),
        TextViewers.NewText(TextViewers.Text(S.s), 0),
        TextViewers.menuH, X, Y)
    END
  END ExtendDisplay;

  (* ------------- Toolbox for module management ---------------*)

  PROCEDURE Free1 (VAR S: Texts.Scanner);
  BEGIN Texts.WriteString(W, S.s); Texts.WriteString(W, " unloading");
    Modules.Free(S.s);
    IF Modules.res # 0 THEN Texts.WriteString(W, " failed") END;
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
    Tasks.Collect(0)
  END Free;

  PROCEDURE FreeFonts*;
  BEGIN Texts.WriteString(W, "System.FreeFonts"); Fonts.Free; EndLine
  END FreeFonts;

  (* ------------- Toolbox of file system ---------------*)

  PROCEDURE List (name: FileDir.FileName; adr: LONGINT; VAR cont: BOOLEAN);
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
        Texts.WriteInt(W, hp.aleng*FileDir.SectorSize + hp.bleng - FileDir.HeaderSize, 8); (*length*)
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
    IF ch = "!" THEN pat[i+1] := "!" END ;  (*directory option*)
    i := 0;
    WHILE pat[i] > "*" DO pre[i] := pat[i]; INC(i) END;
    pre[i] := 0X;
    Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, X, Y); t := TextViewers.Text("");
    V := MenuViewers.New(
      TextViewers.NewMenu("System.Directory", StandardMenu),
      TextViewers.NewText(t, 0), TextViewers.menuH, X, Y);
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
    Texts.WriteString(W, "  Tasks"); Texts.WriteInt(W, Tasks.NofTasks, 4); EndLine
  END Watch;

  PROCEDURE ShowModules*;
    VAR T: Texts.Text;
      V: Viewers.Viewer;
      M: Modules.Module;
      X, Y: INTEGER;
  BEGIN T := TextViewers.Text("");
    Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, X, Y);
    V := MenuViewers.New(TextViewers.NewMenu("System.ShowModules", StandardMenu),
        TextViewers.NewText(T, 0), TextViewers.menuH, X, Y);
    M := Modules.root;
    WHILE M # NIL DO
      IF M.name[0] # 0X THEN
        Texts.WriteString(W, M.name); Texts.Write(W, 9X); Texts.WriteHex(W, ORD(M));
        Texts.WriteHex(W, M.code); Texts.WriteInt(W, M.refcnt, 4)
      ELSE Texts.WriteString(W, "---")
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
        Oberon.AllocateSystemViewer(Oberon.Par.vwr.X, X, Y); T := TextViewers.Text("");
        V := MenuViewers.New(TextViewers.NewMenu("System.Commands", StandardMenu),
            TextViewers.NewText(T, 0), TextViewers.menuH, X, Y);
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

  PROCEDURE InitMod (name: ARRAY OF CHAR);
    VAR mod: Modules.Module; P: Modules.Command; w: INTEGER;
  BEGIN mod := Modules.root;
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END ;
    IF mod # NIL THEN SYSTEM.GET(mod.ent, w);
      P := SYSTEM.VAL(Modules.Command, mod.code + w); P
    END
  END InitMod;

  PROCEDURE RunInit*;
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
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); Tasks.Reset
    END
  END Trap;

  PROCEDURE Abort;
    VAR n: INTEGER;
  BEGIN n := SYSTEM.REG(15); Texts.WriteString(W, "  ABORT  "); Texts.WriteHex(W, n);
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); Tasks.Reset
  END Abort;

BEGIN Texts.OpenWriter(W);
  IF (Viewers.CurDisplay # NIL) & (Viewers.CurDisplay IS Oberon.DisplayArea) THEN
    Oberon.SetDisplayLog(Viewers.CurDisplay(Oberon.DisplayArea), TextViewers.Text("")); (*create a new log for CurDisplay*)
    Oberon.OpenLog(Viewers.CurDisplay(Oberon.DisplayArea).log)                     (*make Oberon.Log point to it*)
  END;
  OpenViewers;
  Kernel.Install(SYSTEM.ADR(Trap), 20H); Kernel.Install(SYSTEM.ADR(Abort), 0);
  Tasks.Loop
END System.
