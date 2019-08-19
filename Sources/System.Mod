MODULE System; (*JG 3.10.90 / NW 12.10.93 / NW 20.6.2016 / AP 1.8.19 Experimental Oberon*)
  IMPORT SYSTEM, Kernel, FileDir, Files, Modules,
    Input, Viewers, Fonts, Texts, Oberon, MenuViewers, TextFrames;

  CONST
    StandardMenu = "System.Close System.Copy System.Grow Edit.Search Edit.Store | System.Expand System.Spread System.Clone";
    LogMenu = "Edit.Locate Edit.Search System.Copy System.Grow System.Clear | System.Expand System.Spread System.Clone";

  TYPE Handler = PROCEDURE(name: ARRAY OF CHAR);

  VAR W: Texts.Writer; M: Modules.Module;
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
    IF S.class = Texts.Name THEN Oberon.SetFont(Fonts.Load(S.s)) END
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

  (* ------------- Toolbox for logical displays ---------------*)

  PROCEDURE MakeDisplayName(prefix: ARRAY OF CHAR; id: INTEGER; VAR name: ARRAY OF CHAR);  (*0 <= id < 10^5*)
    VAR i, j: INTEGER; buf: ARRAY 5 OF INTEGER;
  BEGIN i := 0; j := 0;
    WHILE (i < Viewers.DnLength-1) & (prefix[i] # 0X) DO name[i] := prefix[i]; INC(i) END ;
    REPEAT buf[j] := id MOD 10; id := id DIV 10; INC(j) UNTIL id = 0;
    WHILE (i < Viewers.DnLength-1) & (j > 0) DO DEC(j); name[i] := CHR(buf[j] + ORD("0")); INC(i) END ;
    name[i] := 0X
  END MakeDisplayName;

  PROCEDURE OpenViewers;  (*open log and system tool viewer in system track of current display*)
    VAR logV, toolV, menu, main: Viewers.Frame; X, Y: INTEGER;
  BEGIN
    IF Viewers.CurDisplay # NIL THEN
      Texts.WriteString(W, "Experimental Oberon  AP 1.8.19 / Display ");
      Texts.WriteInt(W, Viewers.CurDisplay.id, 3); Texts.Write(W, " ");
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
  BEGIN NEW(D); Oberon.InitDisplay(D, name); Oberon.SetDisplay(D); OpenViewers
  END CreateDisplay;

  PROCEDURE OpenDisplay*;  (*display name is provided as parameter*)
    VAR S: Texts.Scanner; prev: INTEGER;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S); prev := Viewers.CurDisplay.id;
    IF S.class # Texts.Name THEN MakeDisplayName("opened from display ", prev, S.s) END ;
    CreateDisplay(S.s);
    Texts.WriteString(W, " now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 3);
    Texts.WriteString(W,", to return: System.SetDisplay "); Texts.WriteInt(W, prev, 3); EndLine
  END OpenDisplay;

  PROCEDURE CloseDisplay*;  (*display id and (optionally) a hint are provided as parameters*)
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
        IF (id = prev) & (Viewers.CurDisplay.id = prev) THEN Texts.WriteString(W, " last display")
        ELSE Texts.WriteString(W, " display "); Texts.WriteInt(W, id, 3); Texts.WriteString(W, " closed");
          IF id = prev THEN Texts.WriteString(W, ", now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 3) END
        END
      END
    ELSE Texts.WriteString(W, " invalid display number")
    END ;
    EndLine
  END CloseDisplay;

  PROCEDURE SwitchDisplay(D: Viewers.Display);  (*switch to the specified display*)
    VAR prev: INTEGER;
  BEGIN prev := Viewers.CurDisplay.id;
    IF (D # NIL) & (D.id # prev) THEN Oberon.SetDisplay(D);
      Texts.WriteString(W, " now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 3);
      Texts.WriteString(W,", to return: System.SetDisplay "); Texts.WriteInt(W, prev, 3); EndLine
    END
  END SwitchDisplay;

  PROCEDURE SetDisplay*;  (*display id is provided as parameter*)
    VAR S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN SwitchDisplay(Viewers.GetDisplay(S.i)) END
  END SetDisplay;

  PROCEDURE NextDisplay*;  (*switch to display on the "right"*)
    VAR D: Viewers.Viewer;
  BEGIN D := Viewers.Next(Viewers.CurDisplay); SwitchDisplay(D(Viewers.Display))
  END NextDisplay;

  PROCEDURE PrevDisplay*;  (*switch to display on the "left"*)
    VAR D: Viewers.Viewer;
  BEGIN D := Viewers.Prev(Viewers.CurDisplay); SwitchDisplay(D(Viewers.Display))
  END PrevDisplay;

  PROCEDURE SetDisplayName*;  (*display id and name are provided as parameters*)
    VAR D: Viewers.Display; S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN  Texts.Scan(S);
      IF S.class = Texts.Name THEN D := Viewers.GetDisplay(S.i);
        IF D = NIL THEN Texts.WriteString(W, " no such display ")
        ELSE D.name := S.s; Texts.WriteString(W, " display "); Texts.WriteInt(W, D.id, 3);
          Texts.WriteString(W, " renamed to "); Texts.WriteString(W, D.name)
        END
      ELSE Texts.WriteString(W, " no display name provided (SetDisplayName id name)")
      END
    ELSE Texts.WriteString(W, " no display id provided (SetDisplayName id name)")
    END ;
    EndLine
  END SetDisplayName;

  PROCEDURE ThisDisplay*;
    VAR D: Viewers.Display;
  BEGIN D := Viewers.ThisDisplay(Oberon.Par.vwr); Texts.WriteString(W, " current display ");
    Texts.WriteInt(W, D.id, 3); Texts.Write(W, " "); Texts.WriteString(W, D.name); EndLine
  END ThisDisplay;

  PROCEDURE ShowDisplays*;
    VAR D: Viewers.Display;
  BEGIN D := Viewers.root; Texts.WriteString(W, "System.ShowDisplays"); EndLine;
    WHILE D # NIL DO Texts.WriteString(W, " display "); Texts.WriteInt(W, D.id, 3);
      Texts.WriteString(W, " "); Texts.WriteString(W, D.name);
      IF D = Viewers.CurDisplay THEN Texts.WriteString(W, "      (current display)") END ;
      EndLine; D := D.next(Viewers.Display)
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
        TextFrames.NewMenu(S.s, StandardMenu),
        TextFrames.NewText(TextFrames.Text(S.s), 0), TextFrames.menuH, X, Y)
    END
  END Open;

  PROCEDURE Clear*;  (*clear Log*)
    VAR T: Texts.Text; F: Viewers.Frame; buf: Texts.Buffer;
  BEGIN F := Oberon.Par.frame;
    IF (F # NIL) & (F.next IS TextFrames.Frame) & (F = Oberon.Par.vwr.dsc) THEN
      NEW(buf); Texts.OpenBuf(buf); T := F.next(TextFrames.Frame).text; Texts.Delete(T, 0, T.len, buf)
    END
  END Clear;

  PROCEDURE OpenLog*;  (*open another viewer for Log*)
    VAR V: Viewers.Viewer; X, Y: INTEGER;
  BEGIN Oberon.AllocateSystemViewer(0, X, Y);
    IF Oberon.Log = NIL THEN Oberon.OpenLog(TextFrames.Text("")) END ;
    V := MenuViewers.New(
      TextFrames.NewMenu("System.Log", LogMenu),
      TextFrames.NewText(Oberon.Log, 0), TextFrames.menuH, X, Y)
  END OpenLog;

  PROCEDURE Close*;  (*viewer*)
    VAR V: Viewers.Viewer;
  BEGIN
    IF Oberon.Par.frame = Oberon.Par.vwr.dsc THEN V := Oberon.Par.vwr
    ELSE V := Oberon.MarkedViewer()
    END;
    Viewers.Close(V)
  END Close;

  PROCEDURE CloseTrack*;
    VAR D: Viewers.Display; V: Viewers.Viewer;
  BEGIN V := Oberon.MarkedViewer(); D := Viewers.ThisDisplay(V); Viewers.CloseTrack(D, V.X)
  END CloseTrack;

  PROCEDURE Recall*;  (*recover the last closed viewer of the current display*)
    VAR V: Viewers.Viewer; curDisplay: Viewers.Display; M: Viewers.ViewerMsg;
  BEGIN curDisplay := Viewers.CurDisplay; Viewers.Recall(curDisplay, V);
    IF (V # NIL) & (V.state = 0) THEN
      Viewers.Open(curDisplay, V, V.X, V.Y + V.H); M.id := Viewers.restore; V.handle(V, M)
    END
  END Recall;

  PROCEDURE Flush*;  (*clear the last closed viewer of the current display*)
  BEGIN Viewers.Flush(Viewers.CurDisplay)
  END Flush;

  PROCEDURE RecallFocus*;  (*recover the focus viewer of the current display*)
    VAR V: Viewers.Viewer; M: Viewers.ViewerMsg;
  BEGIN V := Viewers.FocusViewer;
    IF (V # NIL) & (V.state = 0) THEN
      Viewers.Open(Viewers.CurDisplay, V, V.X, V.Y + V.H); M.id := Viewers.restore; V.handle(V, M)
    END
  END RecallFocus;

  PROCEDURE Copy*;  (*create a copy of the viewer in the current display*)
    VAR V, V1: Viewers.Viewer; M: Viewers.CopyMsg; N: Viewers.ViewerMsg;
  BEGIN V := Oberon.Par.vwr; V.handle(V, M); V1 := M.F(Viewers.Viewer);
    Viewers.Open(Viewers.CurDisplay, V1, V.X, V.Y + V.H DIV 2);
    N.id := Viewers.restore; V1.handle(V1, N)
  END Copy;

  PROCEDURE Grow*;  (*create a copy of the viewer in a newly created overlaying track*)
    VAR D: Viewers.Display; V, V1: Viewers.Viewer; M: Viewers.CopyMsg; N: Viewers.ViewerMsg;
  BEGIN V := Oberon.Par.vwr; D := Viewers.ThisDisplay(V);
    IF V.H < D.H - D.minH THEN Oberon.OpenTrack(D, V.X, V.W)
    ELSIF V.W < D.W THEN Oberon.OpenTrack(D, Oberon.UserTrack(V.X), D.W)
    END ;
    IF (V.H < D.H - D.minH) OR (V.W < D.W) THEN
      V.handle(V, M); V1 := M.F(Viewers.Viewer);
      Viewers.Open(D, V1, V.X, D.H);
      N.id := Viewers.restore; V1.handle(V1, N)
    END
  END Grow;

  PROCEDURE Clone*;  (*create a copy of the viewer in a newly created display*)
    VAR D: Viewers.Display; V, V1: Viewers.Viewer;
      M: Viewers.CopyMsg; N: Viewers.ViewerMsg; prev: INTEGER;
      name: ARRAY Viewers.DnLength OF CHAR;
  BEGIN V := Oberon.Par.vwr; V.handle(V, M); V1 := M.F(Viewers.Viewer); prev := Viewers.CurDisplay.id;
    MakeDisplayName("cloned from display ", prev, name); CreateDisplay(name);
    Viewers.Open(Viewers.CurDisplay, V1, 0, Oberon.DisplayHeight(0));
    N.id := Viewers.restore; V1.handle(V1, N);
    Texts.WriteString(W, " now in display "); Texts.WriteInt(W, Viewers.CurDisplay.id, 3);
    Texts.WriteString(W,", to return: System.SetDisplay ");
    Texts.WriteInt(W, prev, 3); Texts.WriteLn(W);
    Texts.WriteString(W," to close this cloned display and then return: System.CloseDisplay ");
    Texts.WriteInt(W, Viewers.CurDisplay.id, 3); Texts.WriteInt(W, prev, 3);
    EndLine
  END Clone;

  PROCEDURE Expand*;  (*expand the viewer vertically as much as possible*)
    VAR V: Viewers.Viewer; y, h: INTEGER;
  BEGIN V := Oberon.Par.vwr; y := 0; h := Oberon.DisplayHeight(0);
    Viewers.Validate(V, y, h); Viewers.Change(V, y, h)
  END Expand;

  PROCEDURE Spread*;  (*redistribute viewers vertically*)
    VAR D: Viewers.Display; V: Viewers.Viewer;
  BEGIN V := Oberon.Par.vwr; D := Viewers.ThisDisplay(V); Viewers.Spread(D, V.X, V.W)
  END Spread;

  PROCEDURE ExtendDisplay*;  (*extend the current display to the right*)
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

  PROCEDURE Select(VAR S: Texts.Scanner; on, this, clients, imports: BOOLEAN; handle: Handler);
    VAR T: Texts.Text;
      beg, end, time: LONGINT;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF (S.class = Texts.Char) & (S.c = "^") THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN
        Texts.OpenScanner(S, T, beg); Texts.Scan(S);
        IF (S.class = Texts.Name) OR (S.class = Texts.String) THEN
          Modules.Select(S.s, on, this, clients, imports); handle(S.s); Texts.Scan(S)
        END
      END
    ELSE
      WHILE (S.class = Texts.Name) OR (S.class = Texts.String) DO
        Modules.Select(S.s, on, this, clients, imports); handle(S.s); Texts.Scan(S)
      END
    END
  END Select;

  PROCEDURE WriteName(name: ARRAY OF CHAR);  (*handler*)
  BEGIN Texts.Write(W, " "); Texts.WriteString(W, name)
  END WriteName;

  PROCEDURE WriteSelection;
    VAR mod: Modules.Module;
  BEGIN mod := Modules.root;
    WHILE mod # NIL DO
      IF (mod.name[0] # 0X) & mod.selected THEN WriteName(mod.name) END ;
      mod := mod.next
    END
  END WriteSelection;

  PROCEDURE WriteRef(src, dst: LONGINT; s: ARRAY OF CHAR; VAR continue: BOOLEAN): INTEGER;  (*handler*)
    VAR mod: Modules.Module; i: INTEGER;
  BEGIN i := 0;
    IF dst # 0 THEN mod := Modules.root;
      WHILE (mod # NIL) & ~((mod.name[0] # 0X) & mod.selected & (mod.data <= dst) & (dst < mod.imp)) DO mod := mod.next END ;
      IF mod # NIL THEN (*reference exists*) i := 1;
        IF (M # mod) OR (pat # s) THEN M := mod; pat := s;
          IF dst < mod.code THEN Texts.WriteString(W, "  types of ") ELSE Texts.WriteString(W, "  procedures of ") END ;
          Texts.WriteString(W, mod.name); Texts.WriteString(W, " in use in ");
          IF src < Modules.AllocPtr THEN Texts.WriteString(W, "global procedures variables of ")
          ELSE Texts.WriteString(W, "dynamic objects reachable by ")
          END ;
          Texts.WriteString(W, s); Texts.WriteLn(W)
        END
      END
    END ;
    RETURN i
  END WriteRef;

  PROCEDURE WriteRefs;  (*write references from each unselected module to any of the selected modules*)
    VAR res: INTEGER;
  BEGIN Oberon.SetPar(NIL, NIL, 0);  (*exclude viewers that are reachable only via Oberon.Par.vwr*)
    M := NIL; Modules.FindDynamicRefs(WriteRef, WriteRef, res, res, FALSE);  (*dynamic type and procedure variable refs*)
    M := NIL; Modules.FindStaticRefs(WriteRef, res); Texts.Append(Oberon.Log, W.buf)  (*static procedure variable refs*)
  END WriteRefs;

  PROCEDURE ShowRef(name: ARRAY OF CHAR);  (*handler*)
  BEGIN IF Modules.NofSelected > 0 THEN WriteRefs; Modules.Deselect END
  END ShowRef;

  PROCEDURE ShowRefs*;  (*show references from all modules to any of the specified modules individually*)
    VAR S: Texts.Scanner;
  BEGIN Texts.WriteString(W, "System.ShowRefs"); EndLine; Modules.Deselect; Select(S, TRUE, TRUE, FALSE, FALSE, ShowRef)
  END ShowRefs;

  PROCEDURE ShowGroupRefs*;  (*show references from all modules (outside the group) to the specified module group*)
    VAR S: Texts.Scanner;
  BEGIN Texts.WriteString(W, "System.ShowGroupRefs");
    Modules.Deselect; Select(S, TRUE, TRUE, FALSE, FALSE, WriteName); EndLine;
    IF Modules.NofSelected > 0 THEN WriteRefs; Modules.Deselect END
  END ShowGroupRefs;

  PROCEDURE ShowMods(this, clients, imports: BOOLEAN);
    VAR S: Texts.Scanner;
  BEGIN Modules.Deselect; Select(S, TRUE, this, clients, imports, WriteName); EndLine;
    IF Modules.NofSelected > 0 THEN Texts.Write(W, " "); WriteSelection; EndLine; Modules.Deselect END
  END ShowMods;

  PROCEDURE Show*;  (*show the specified modules if they are loaded*)
  BEGIN Texts.WriteString(W, "System.Show"); ShowMods(TRUE, FALSE, FALSE)
  END Show;

  PROCEDURE ShowImports*;  (*show the specified modules and all their direct and indirect imports*)
  BEGIN Texts.WriteString(W, "System.ShowImports"); ShowMods(TRUE, FALSE, TRUE)
  END ShowImports;

  PROCEDURE ShowClients*;  (*show the specified modules and all their direct and indirect clients*)
  BEGIN Texts.WriteString(W, "System.ShowClients"); ShowMods(TRUE, TRUE, FALSE)
  END ShowClients;

  PROCEDURE WriteClient(mod, imp: Modules.Module; VAR continue: BOOLEAN): INTEGER;  (*handler*)
  BEGIN (*mod imports imp*)
    IF M = imp THEN Texts.Write(W, " ")
    ELSE M := imp; EndLine; Texts.WriteString(W, "  "); Texts.WriteString(W, imp.name); Texts.WriteString(W, " imported by ")
    END ;
    Texts.WriteString(W, mod.name); RETURN 1
  END WriteClient;

  PROCEDURE FreeMods(this, clients, imports: BOOLEAN);
    VAR S: Texts.Scanner; hide: BOOLEAN; res: INTEGER;
  BEGIN Modules.Deselect; Select(S, TRUE, this, clients, imports, WriteName); EndLine;
    hide := (S.class = Texts.Char) & (S.c = "/") & (S.nextCh = "f");  (*force option*)
    Modules.Select("System", FALSE, TRUE, FALSE, TRUE);  (*deselect module "System" and its imports*)
    IF Modules.NofSelected > 0 THEN Texts.Write(W, " "); WriteSelection; Modules.FreeSelection(hide);
      IF Modules.res = Modules.noref THEN Texts.WriteString(W, " unloading"); EndLine
      ELSE
        IF hide & (Modules.res > Modules.clients) THEN Texts.WriteString(W, " removing from module list")
        ELSE Texts.WriteString(W, " unloading failed");
          IF Modules.res = Modules.clients THEN M := NIL; Modules.FindClients(WriteClient, res) END
        END ;
        EndLine; WriteRefs
      END ;
      Modules.Deselect; Oberon.Collect(0)
    END
  END FreeMods;

  PROCEDURE Free*;  (*free the specified modules as a group; if refs exist and the /f option is specified, hide the modules*)
  BEGIN Texts.WriteString(W, "System.Free"); FreeMods(TRUE, FALSE, FALSE)
  END Free;

  PROCEDURE FreeImports*;  (*free the specified modules and all their direct and indirect imports as a group*)
  BEGIN Texts.WriteString(W, "System.FreeImports"); FreeMods(TRUE, FALSE, TRUE)
  END FreeImports;

  PROCEDURE FreeClients*;  (*free the specified modules and all their direct and indirect clients as a group*)
  BEGIN Texts.WriteString(W, "System.FreeClients"); FreeMods(TRUE, TRUE, FALSE)
  END FreeClients;

  PROCEDURE FreeFonts*;
  BEGIN Texts.WriteString(W, "System.FreeFonts"); Fonts.Free; EndLine
  END FreeFonts;

  (* ------------- Toolbox of file system ---------------*)

  PROCEDURE List(name: FileDir.FileName; adr: LONGINT; VAR cont: BOOLEAN);
    VAR i0, i, j0, j: INTEGER; hp: FileDir.FileHeader;
  BEGIN i := 0;
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
        Texts.WriteHex(W, adr)
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
    WHILE ch = " " DO Texts.Read(R, ch) END ; (*spaces*)
    IF (ch = "^") OR (ch = 0DX) THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN
        Texts.OpenReader(R, T, beg); Texts.Read(R, ch);
        WHILE ch <= " " DO Texts.Read(R, ch) END
      END
    END ;
    i := 0;
    WHILE ch > " " DO (*pattern*)
      IF ch = "!" THEN pat[i] := 0X; INC(i) END ; (*directory option*)
      pat[i] := ch; INC(i);
      Texts.Read(R, ch)
    END ;
    WHILE i < LEN(pat) DO pat[i] := 0X; INC(i) END ;
    i := 0;
    WHILE pat[i] > "*" DO pre[i] := pat[i]; INC(i) END ; (*prefix*)
    WHILE i < LEN(pre) DO pre[i] := 0X; INC(i) END ;
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
      IF M.selected THEN Texts.WriteString(W, " *") END ;
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

  (* ------------- Toolbox for standalone and prelinked programs ---------------*)

  PROCEDURE ReadCode(VAR R: Files.Rider; VAR code: ARRAY OF LONGINT; VAR size, start, nofimps, res: INTEGER);
    VAR n, data: INTEGER; ch: CHAR; b: BYTE;               (*size in words, start in bytes*)
      name: ARRAY 32 OF CHAR;
  BEGIN Files.ReadString(R, name); Files.ReadInt(R, data); (*key*)
    Files.ReadByte(R, b); (*version*) Files.ReadInt(R, data); (*size*)
    Files.ReadString(R, name); (*imports*) nofimps := 0;
    WHILE name[0] # 0X DO INC(nofimps); Files.ReadInt(R, data); (*key*) Files.ReadString(R, name) END ;
    Files.ReadInt(R, n); (*variable space*)
    Files.ReadInt(R, n);
    WHILE n > 0 DO Files.Read(R, ch); DEC(n) END ; (*strings*)
    Files.ReadInt(R, n);
    WHILE n > 0 DO Files.ReadInt(R, data); DEC(n, 4) END ; (*type descriptors*)
    Files.ReadInt(R, size);
    IF size > LEN(code) THEN (*program too long*) res := 2
    ELSE n := 0;
      WHILE n < size DO Files.ReadInt(R, data); code[n] := data; INC(n) END ; (*code*)
      Files.ReadString(R, name);
      WHILE name[0] # 0X DO Files.ReadInt(R, data); Files.ReadString(R, name) END ; (*commands*)
      Files.ReadInt(R, n);
      WHILE n > 0 DO Files.ReadInt(R, data); DEC(n) END ; (*entries*)
      Files.ReadInt(R, data);
      WHILE data >= 0 DO Files.ReadInt(R, data) END ; (*pointer references*)
      Files.ReadInt(R, data);
      WHILE data >= 0 DO Files.ReadInt(R, data) END ; (*procedure variable references*)
      Files.ReadInt(R, data); (*fixorgP*) Files.ReadInt(R, data); (*fixorgD*)
      Files.ReadInt(R, data); (*fixorgT*) Files.ReadInt(R, data); (*fixorgM*)
      Files.ReadInt(R, start); (*entry*)
      Files.Read(R, ch);
      IF ch # "O" THEN (*corrupted file*) res := 1 ELSE res := 0 END
    END
  END ReadCode;

  PROCEDURE RunRsc*;  (*extract, load and execute code section of standalone program  M.rsc*)
    CONST maxCode = 8000;
    VAR code: ARRAY maxCode OF LONGINT;
      size, start, nofimps, res: INTEGER;
      F: Files.File; R: Files.Rider;
      S: Texts.Scanner;
      body: Modules.Command;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.RunRsc ");
    IF S.class = Texts.Name THEN (*name of object file*)
      Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
      F := Files.Old(S.s);
      IF F # NIL THEN Files.Set(R, F, 0);
        ReadCode(R, code, size, start, nofimps, res);
        IF res = 0 THEN
          IF nofimps = 0 THEN
            Texts.WriteInt(W, size*4, 6); Texts.WriteInt(W, start, 6); (*bytes*)
            body := SYSTEM.VAL(Modules.Command, SYSTEM.ADR(code) + start);
            body (*call module initialization body*)
          ELSE Texts.WriteString(W, "  imports not allowed")
          END
        ELSIF res = 1 THEN Texts.WriteString(W, "  input file format error")
        ELSIF res = 2 THEN Texts.WriteString(W, "  program too long")
        END
      ELSE Texts.WriteString(W, " failed")
      END ;
      EndLine
    END
  END RunRsc;

  PROCEDURE Trap1(VAR a: INTEGER; b, c, d: INTEGER);  (*trap routine installed by RunBin*)
    VAR u, v, w: INTEGER;
  BEGIN u := SYSTEM.REG(15); SYSTEM.GET(u - 4, v); w := v DIV 10H MOD 10H; (*trap number*)
    LED(w + 192); REPEAT UNTIL FALSE
  END Trap1;

  PROCEDURE RunBin*;  (*load and execute pre-linked binary  M.bin*)
    CONST maxBin = 16000; MT = 12;
    VAR bin: ARRAY maxBin OF INTEGER;
      MTOrg, Start, i, x: INTEGER;
      M, p: Modules.Module;
      F: Files.File; R: Files.Rider;
      S: Texts.Scanner;
      body: Modules.Command;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.RunBin ");
    IF S.class = Texts.Name THEN (*name of binary file*)
      Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
      F := Files.Old(S.s);
      IF F # NIL THEN
        IF Files.Length(F) < maxBin * 4 THEN
          Files.Set(R, F, 0); Files.ReadInt(R, x); i := 0;
          WHILE ~R.eof DO bin[i] := x; INC(i); Files.ReadInt(R, x) END ;
          Texts.WriteInt(W, i*4, 6); (*bytes*) Texts.Append(Oberon.Log, W.buf);
          Start := SYSTEM.ADR(bin);
          MTOrg := Start + 32;  (*module table MT*)
          p := SYSTEM.VAL(Modules.Module, Start + bin[5]); (*current root of the links of loaded  modules / root*)
          WHILE p # NIL DO (*fixup*)
            M := p; p := p.next;
            IF M.next # NIL THEN M.next := SYSTEM.VAL(Modules.Module, SYSTEM.VAL(INTEGER, M.next) + Start) END ;
            M.data := M.data + Start;
            bin[M.num + 8] := M.data; (*module table entry*)
            M.code := M.code + Start;
            M.imp := M.imp + Start;
            M.cmd := M.cmd + Start;
            i := M.imp;
            WHILE i < M.cmd DO SYSTEM.GET(i, x); SYSTEM.PUT(i, x + Start); INC(i, 4) END ;
            M.ent := M.ent + Start;
            M.ptr := M.ptr + Start;
            M.pvr := M.pvr + Start
          END ;
          Kernel.Install(SYSTEM.ADR(Trap1), MTOrg); (*install trap in MTOrg[0]*)
          x := SYSTEM.REG(MT); (*save MT register*)
          SYSTEM.LDREG(MT, MTOrg);
          body := SYSTEM.VAL(Modules.Command, Start);
          body; (*call initialization body of the top module*)
          SYSTEM.LDREG(MT, x) (*restore MT register*)
        ELSE Texts.WriteString(W, " program too long")
        END
      ELSE Texts.WriteString(W, " failed")
      END ;
      EndLine
    END
  END RunBin;

  PROCEDURE Trap(VAR a: INTEGER; b, c, d: INTEGER);
    VAR u, v, w: INTEGER; mod: Modules.Module;
  BEGIN u := SYSTEM.REG(15); SYSTEM.GET(u - 4, v); w := v DIV 10H MOD 10H; (*trap number*)
    IF w = 0 THEN Kernel.New(a, b, c, d)
    ELSE (*trap*) Texts.WriteLn(W); Texts.WriteString(W, "  pos "); Texts.WriteInt(W, v DIV 100H MOD 10000H, 4);
      Texts.WriteString(W, "  TRAP"); Texts.WriteInt(W, w, 4); mod := Modules.root;
      WHILE (mod # NIL) & ((u < mod.code) OR (u >= mod.imp)) DO mod := mod.next END ;
      IF mod # NIL THEN Texts.WriteString(W, " in "); Texts.WriteString(W, mod.name) END ;
      Texts.WriteString(W, " at"); Texts.WriteHex(W, u);
      IF mod # NIL THEN Texts.WriteString(W, "  obj pos "); Texts.WriteInt(W, (u - mod.code - 4) DIV 4, 4) END ;
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); Oberon.Reset
    END
  END Trap;

  PROCEDURE Abort;
    VAR n: INTEGER; mod: Modules.Module;
  BEGIN n := SYSTEM.REG(15); Texts.WriteString(W, "  ABORT"); mod := Modules.root;
    WHILE (mod # NIL) & ((n < mod.code) OR (n >= mod.imp)) DO mod := mod.next END ;
    IF mod # NIL THEN Texts.WriteString(W, " in "); Texts.WriteString(W, mod.name) END ;
    Texts.WriteString(W, " at"); Texts.WriteHex(W, n);
    IF mod # NIL THEN Texts.WriteString(W, "  obj pos "); Texts.WriteInt(W, (n - mod.code - 4) DIV 4, 4) END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); Oberon.Reset
  END Abort;

BEGIN Texts.OpenWriter(W);
  Oberon.OpenLog(TextFrames.Text("")); CreateDisplay("Oberon");
  Kernel.Install(SYSTEM.ADR(Trap), 20H); Kernel.Install(SYSTEM.ADR(Abort), 0)
END System.
