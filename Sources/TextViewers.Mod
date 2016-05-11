MODULE TextViewers; (*JG 8.10.90 / NW 16.11.15 / AP 9.5.16*)
  IMPORT Kernel, Modules, Input, Display, Fonts, Texts, Cursors, Viewers, Oberon;

  CONST replace* = 0; insert* = 1; delete* = 2; unmark* = 3; (*update message ids*)
    BS = 8X; TAB = 9X; CR = 0DX; DEL = 7FX; inf = 32767;

  TYPE Line = POINTER TO LineDesc;
    LineDesc = RECORD
      len: LONGINT;
      wid: INTEGER;
      eot: BOOLEAN;
      lsp, asr, dsr: INTEGER; (*largest line space, ascender and descender in the line*)
      next: Line
    END;

    Location* = RECORD
      org*, pos*: LONGINT;
      dx*, x*, y*: INTEGER;
      lin: Line
    END;

    Viewer* = POINTER TO ViewerDesc;
    ViewerDesc* = RECORD (Viewers.ViewerDesc)
      text*: Texts.Text;
      org*: LONGINT;
      col*: INTEGER;
      lsp*: INTEGER;
      left*, right*, top*, bot*: INTEGER;
      markH*: INTEGER;
      time*: LONGINT;
      hasCar*, hasSel*, hasMark: BOOLEAN;
      carloc*: Location;
      selbeg*, selend*: Location;
      trailer: Line;
      voff: INTEGER; (*vertical offset relative to baseline*)
      pool: Line (*line pool to minimize heap usage*)
    END;

    UpdateMsg* = RECORD (Viewers.Msg)
      id*: INTEGER;       (*replace, insert, delete, unmark*)
      text*: Texts.Text;
      beg*, end*: LONGINT
    END;

    CopyOverMsg* = RECORD (Viewers.Msg)
      text*: Texts.Text;
      beg*, end*: LONGINT
    END;

  VAR TBuf*, DelBuf: Texts.Buffer;
    menuH*, barW*, left*, right*, top*, bot*, lsp*: INTEGER; (*standard sizes*)
    asr, dsr, selH, markW, eolW: INTEGER;
    nextCh: CHAR;
    ScrollMarker: Cursors.Marker;
    W, KW: Texts.Writer; (*keyboard writer*)

  PROCEDURE Min (i, j: INTEGER): INTEGER;
  BEGIN IF i < j THEN j := i END ; RETURN j
  END Min;

  PROCEDURE Max (i, j: INTEGER): INTEGER;
  BEGIN IF i > j THEN j := i END ; RETURN j
  END Max;

  PROCEDURE NewLine (F: Viewer; VAR L: Line); (*reuse line from line pool if possible*)
  BEGIN IF F.pool # NIL THEN L := F.pool; F.pool := L.next ELSE NEW(L) END
  END NewLine;

  PROCEDURE LastLine (F: Viewer; L: Line); (*move lines after L to line pool*)
    VAR L0: Line;
  BEGIN (*L in closed F.trailer ring*)
    IF L.next # F.trailer THEN L0 := L;
      WHILE L0.next # F.trailer DO L0 := L0.next END;
      L0.next := F.pool; F.pool:= L.next; L.next := F.trailer
    END
  END LastLine;

  (*------------------display support------------------------*)

  PROCEDURE ReplConst (col: INTEGER; F: Viewer; X, Y, W, H: INTEGER; mode: INTEGER);
    VAR topY, botY: INTEGER;
  BEGIN
    IF W > 0 THEN topY := F.Y + F.H - F.top; botY := F.Y + F.bot;
      IF Y < botY THEN H := H - botY + Y; Y := botY END;
      IF Y + H > topY THEN H := topY - Y END;
      IF H > 0 THEN
        IF X + W <= F.X + F.W THEN Display.ReplConst(col, X, Y, W, H, mode)
        ELSIF X < F.X + F.W THEN Display.ReplConst(col, X, Y, F.X + F.W - X, H, mode)
        END
      END
    END
  END ReplConst;

  PROCEDURE FlipSM(X, Y: INTEGER);
    VAR DW, DH, CL: INTEGER;
  BEGIN DW := Display.Width; DH := Display.Height; CL := DW;
    IF X < CL THEN
      IF X < 3 THEN X := 3 ELSIF X > DW - 4 THEN X := DW - 4 END
    ELSE
      IF X < CL + 3 THEN X := CL + 4 ELSIF X > CL + DW - 4 THEN X := CL + DW - 4 END
    END ;
    IF Y < 6 THEN Y := 6 ELSIF Y > DH - 6 THEN Y := DH - 6 END;
    Display.CopyPattern(Display.white, Display.updown, X-4, Y-4, Display.invert)
  END FlipSM;

  PROCEDURE UpdateMark (F: Viewer);  (*in scroll bar*)
    VAR oldH: INTEGER;
  BEGIN oldH := F.markH; F.markH := F.org * F.H DIV (F.text.len + 1);
    IF F.hasMark & (F.left >= barW) & (F.markH # oldH) THEN
      Display.ReplConst(Display.white, F.X + 1, F.Y + F.H - 1 - oldH, markW, 1, Display.invert);
      Display.ReplConst(Display.white, F.X + 1, F.Y + F.H - 1 - F.markH, markW, 1, Display.invert)
    END
  END UpdateMark;

  PROCEDURE SetChangeMark (F: Viewer; on: BOOLEAN);  (*in corner*)
  BEGIN
    IF F.H > menuH THEN
      IF on THEN Display.CopyPattern(Display.white, Display.block, F.X+F.W-12, F.Y+F.H-12, Display.paint)
      ELSE Display.ReplConst(F.col, F.X+F.W-12, F.Y+F.H-12, 8, 8, Display.replace)
      END
    END
  END SetChangeMark;

  PROCEDURE Width (VAR R: Texts.Reader; len: LONGINT): INTEGER;
    VAR patadr, pos: LONGINT; ox, dx, x, y, w, h: INTEGER;
  BEGIN pos := 0; ox := 0;
    WHILE pos < len DO
      Fonts.GetPat(R.fnt, nextCh, dx, x, y, w, h, patadr);
      ox := ox + dx; INC(pos); Texts.Read(R, nextCh)
    END;
    RETURN ox
  END Width;

  PROCEDURE PrepareLine (L: Line; VAR R: Texts.Reader); (*pass 1, reads data from file*)
  BEGIN L.asr := asr; L.dsr := -dsr; L.len := 0;
    WHILE (nextCh # CR) & (R.fnt # NIL) DO
      IF R.fnt.maxY > L.asr THEN L.asr := R.fnt.maxY END;
      IF R.fnt.minY < L.dsr THEN L.dsr := R.fnt.minY END;
      INC(L.len); Texts.Read(R, nextCh)
    END;
    INC(L.len); L.dsr := -L.dsr; L.lsp := L.asr + L.dsr;
    L.eot := R.fnt = NIL; Texts.Read(R, nextCh)
  END PrepareLine;

  PROCEDURE DisplayLine (F: Viewer; L: Line; (*pass 2, reads data from file buffer*)
    VAR R: Texts.Reader; X, Y, topY, botY: INTEGER; len: LONGINT);
    VAR patadr, NX, dx, x, y, w, h, thid, bhid, y0: INTEGER;
  BEGIN NX := F.X + F.W;
    IF (topY <= 0) OR (topY > F.Y + F.H - F.top) THEN topY := F.Y + F.H - F.top END;
    IF (botY <= 0) OR (botY < F.Y + F.bot) THEN botY := F.Y + F.bot END;
    WHILE (nextCh # CR) & (R.fnt # NIL) DO
      Fonts.GetPat(R.fnt, nextCh, dx, x, y, w, h, patadr);
      IF (X + x + w <= NX) & (h # 0) THEN y0 := Y + y;
        IF y0 + h <= topY THEN thid := 0 ELSIF y0 >= topY THEN thid := h ELSE thid := y0 + h - topY END;
        IF y0 >= botY THEN bhid := 0 ELSIF y0 + h <= botY THEN bhid := h ELSE bhid := botY - y0 END;
        IF thid + bhid < h THEN
          Display.CopyPattern1(R.col, patadr, X + x, y0, thid, bhid, Display.invert)
        END
      END;
      X := X + dx; INC(len); Texts.Read(R, nextCh)
    END;
    L.len := len + 1; L.wid := X + eolW - (F.X + F.left);
    L.eot := R.fnt = NIL; Texts.Read(R, nextCh)
  END DisplayLine;
 
  PROCEDURE Validate (T: Texts.Text; VAR pos: LONGINT);
    VAR R: Texts.Reader;
  BEGIN
    IF pos > T.len THEN pos := T.len
    ELSIF pos > 0 THEN
      DEC(pos); Texts.OpenReader(R, T, pos);
      REPEAT Texts.Read(R, nextCh); INC(pos) UNTIL R.eot OR (nextCh = CR)
    ELSE pos := 0
    END
  END Validate;

  PROCEDURE Mark* (F: Viewer; on: BOOLEAN);
  BEGIN
    IF (F.H > 0) & (F.left >= barW) & ((F.hasMark & ~on) OR (~F.hasMark & on)) THEN
      Display.ReplConst(Display.white, F.X + 1, F.Y + F.H - 1 - F.markH, markW, 1, Display.invert)
    END;
    F.hasMark := on
  END Mark;

  (*------------------frame modifiers------------------------*)

  PROCEDURE Restore* (F: Viewer);
    VAR R: Texts.Reader; L, l: Line;
      org: LONGINT; curY, topY, botY: INTEGER;
  BEGIN Display.ReplConst(F.col, F.X, F.Y, F.W, F.H, Display.replace);
    IF F.left >= barW THEN
      Display.ReplConst(Display.white, F.X + barW - 1, F.Y, 1, F.H, Display.invert)
    END;
    Validate(F.text, F.org);
    topY := F.Y + F.H - F.top; botY := F.Y + F.bot; L := F.trailer;
    IF topY > botY THEN org := F.org; curY := topY + F.voff;
      Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
      WHILE ~L.eot & (curY > botY) DO
        NewLine(F, l);
        PrepareLine(l, R);
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        DisplayLine(F, l, R, F.X + F.left, curY - l.asr, 0, 0, 0);
        L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
      END
    END;
    L.next := F.trailer;
    F.markH := F.org * F.H DIV (F.text.len + 1)
  END Restore;

  PROCEDURE Suspend* (F: Viewer);
  BEGIN F.trailer.next := F.trailer
  END Suspend;

  PROCEDURE Extend* (F: Viewer; newY: INTEGER);
    VAR R: Texts.Reader; L, l: Line;
      org: LONGINT; curY, topY, botY: INTEGER;
  BEGIN Display.ReplConst(F.col, F.X, newY, F.W, F.Y - newY, Display.replace);
    IF F.left >= barW THEN
      Display.ReplConst(Display.white, F.X + barW - 1, newY, 1, F.Y - newY, Display.invert)
    END;
    topY := F.Y + F.H - F.top; botY := F.Y + F.bot;
    F.H := F.H + F.Y - newY; F.Y := newY;
    IF F.trailer.next = F.trailer THEN Validate(F.text, F.org) END;
    L := F.trailer; org := F.org; curY := topY + F.voff;
    WHILE (L.next # F.trailer) & (curY > botY) DO
      L := L.next; org := org + L.len; curY := curY - L.lsp
    END;
    IF (L # F.trailer) & (curY < botY) THEN (*old bottom line was fractional*)
      Texts.OpenReader(R, F.text, org - L.len); Texts.Read(R, nextCh);
      DisplayLine(F, L, R, F.X + F.left, curY + L.dsr, botY, 0, 0)
    ELSE Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh)
    END;
    botY := F.Y + F.bot;
    IF topY > botY THEN
      WHILE ~L.eot & (curY > botY) DO
        NewLine(F, l);
        PrepareLine(l, R);
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        DisplayLine(F, l, R, F.X + F.left, curY - l.asr, 0, 0, 0);
        L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
      END
    END;
    L.next := F.trailer;
    F.markH := F.org * F.H DIV (F.text.len + 1)
  END Extend;

  PROCEDURE Reduce* (F: Viewer; newY: INTEGER);
    VAR L: Line; curY, topY, botY: INTEGER;
  BEGIN F.H := F.H + F.Y - newY; F.Y := newY;
    topY := F.Y + F.H - F.top; botY := F.Y + F.bot; L := F.trailer; 
    IF topY > botY THEN curY := topY + F.voff;
      WHILE (L.next # F.trailer) & (curY > botY) DO
        L := L.next; curY := curY - L.lsp
      END
    END;
    LastLine(F, L);
    IF F.H >= F.top + F.bot THEN
      Display.ReplConst(F.col, F.X + F.left, F.Y, F.W - F.left, F.bot, Display.replace)
    ELSIF F.H > F.top THEN
      Display.ReplConst(F.col, F.X + F.left, F.Y, F.W - F.left, F.H - F.top, Display.replace)
    END;
    F.markH := F.org * F.H DIV (F.text.len + 1); Mark(F, TRUE)
  END Reduce;

  (*------------------fractional line scroll support------------------------*)

  PROCEDURE ScrollDown (F: Viewer; pos: LONGINT; dY, voff: INTEGER);
    VAR R: Texts.Reader; L, L0, l: Line;
      topY, botY, curY, dy, dy1, h, h1: INTEGER;
  BEGIN (*dY > 0 & 0 <= pos <= F.org*)
    topY := F.Y + F.H - F.top; botY := F.Y + F.bot;
    L := F.trailer; curY := topY + F.voff - dY;
    WHILE (L.next # F.trailer) & (curY > botY) DO
      L := L.next; curY := curY - L.lsp
    END;
    LastLine(F, L);
    dy1 := Max(topY - dY, botY); dy := Max(curY, botY); h := dy1 - dy; h1 := topY - dy1;
    IF h > 0 THEN Display.CopyBlock(F.X + F.left, topY - h, F.W - F.left, h, F.X + F.left, dy, 0) END;
    IF h1 > 0 THEN ReplConst(F.col, F, F.X + F.left, dy1, F.W - F.left, h1, Display.replace) END;
    curY := topY + voff; botY := Max(topY + F.voff - dY, botY);
    F.org := pos; F.voff := voff; L := F.trailer; L0 := L.next;
    Texts.OpenReader(R, F.text, pos); Texts.Read(R, nextCh);
    WHILE ~L.eot & (curY > botY) DO (*read from file buffer*)
      NewLine(F, l);
      PrepareLine(l, R);
      Texts.OpenReader(R, F.text, pos); Texts.Read(R, nextCh);
      DisplayLine(F, l, R, F.X + F.left, curY - l.asr, 0, 0, 0);
      L.next := l; L := l; pos := pos + L.len; curY := curY - L.lsp
    END;
    L.next := L0;
    IF (L0 # F.trailer) & (curY > dy1) THEN (*old top line was fractional*)
      DisplayLine(F, L0, R, F.X + F.left, curY - L0.asr, 0, dy1, 0)
    END;
    UpdateMark(F)
  END ScrollDown;

  PROCEDURE ScrollUp (F: Viewer; pos: LONGINT; dY: INTEGER; VAR full: BOOLEAN);
    VAR R: Texts.Reader; L, L0, l: Line; org: LONGINT;
      topY, botY, curY, Y0, sy, dy, h, h1: INTEGER;
  BEGIN (*dY > 0 & pos unknown OR pos > F.org & dY unknown*)
    IF dY > 0 THEN (*use dY*) pos := -1 ELSE (*use pos*) dY := -inf END;
    org := F.org; L0 := F.trailer; L := F.trailer.next; dy := 0;
    WHILE (L # F.trailer) & ((org < pos) OR (dy + L.lsp <= dY + F.voff)) DO
      org := org + L.len; dy := dy + L.lsp; L0 := L; L := L.next
    END;
    IF L # F.trailer THEN full := FALSE; F.org := org;
      topY := F.Y + F.H - F.top; botY := F.Y + F.bot; curY := topY + F.voff - dy; Y0 := curY;
      IF dY > 0 THEN F.voff := F.voff + dY - dy ELSE dY := dy - F.voff; F.voff := 0 END;
      IF L0 # F.trailer THEN L0.next := F.pool; F.pool := F.trailer.next; F.trailer.next := L END;
      WHILE L.next # F.trailer DO
        org := org + L.len; curY := curY - L.lsp; L := L.next
      END;
      sy := Max(curY - L.lsp, botY); dy := Min(sy + dY, topY); h := Y0 - sy - F.voff; h1 := dy - sy;
      IF h > 0 THEN Display.CopyBlock(F.X + F.left, sy, F.W - F.left, h, F.X + F.left, dy, 0) END;
      IF h1 > 0 THEN ReplConst(F.col, F, F.X + F.left, sy, F.W - F.left, h1, Display.replace) END;
      org := org + L.len; Y0 := curY; curY := curY + dY - L.lsp;
      IF Y0 - L.lsp < botY THEN (*old bottom line was fractional*)
        Texts.OpenReader(R, F.text, org - L.len); Texts.Read(R, nextCh);
        DisplayLine(F, L, R, F.X + F.left, curY + L.dsr, dy, 0, 0)
      ELSE Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh)
      END;
      WHILE ~L.eot & (curY > botY) DO
        NewLine(F, l);
        PrepareLine(l, R);
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        DisplayLine(F, l, R, F.X + F.left, curY - l.asr, 0, 0, 0);
        L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
      END;
      L.next := F.trailer; UpdateMark(F)
    ELSE full := org < F.text.len
    END
  END ScrollUp;

  PROCEDURE Scroll (F: Viewer; dY: INTEGER); (*scroll displayed text dY pixels up or down*)
    CONST P = 100; len = 75; (*assumed average line length*)
    VAR R: Texts.Reader; b: BOOLEAN; L: Line;
      org, q: LONGINT; k, dy: INTEGER; p: ARRAY P OF LONGINT; ls: ARRAY P OF INTEGER;
  BEGIN (*dY # 0*)
    IF F.trailer.next # F.trailer THEN
      IF dY < 0 THEN dY := -dY;
        IF dY <= F.voff THEN ScrollDown(F, F.org, dY, F.voff - dY)
        ELSE NEW(L); b := FALSE; 
          q := Max(F.org - len*(1 + (dY - F.voff - 1) DIV lsp), 0); (*first guess using len and lsp*)
          REPEAT org := q; Validate(F.text, org); k := 0; dy := 0;
            Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh); (*read to file buffer*)
            WHILE (org < F.org) & (k < P) DO PrepareLine(L, R);
              dy := dy + L.lsp; p[k] := org; ls[k] := L.lsp; org := org + L.len; INC(k)
            END;
            IF org < F.org THEN (*k = P*) q := p[1] (*next guess forward*)
            ELSIF q = 0 THEN ScrollDown(F, 0, dy + F.voff, 0); b := TRUE
            ELSIF (k = 0) OR (dy + F.voff < dY) THEN q := Max(q - len, 0) (*next guess backward*)
            ELSE k := 0;
              WHILE dy - ls[k] + F.voff >= dY DO dy := dy - ls[k]; INC(k) END;
              ScrollDown(F, p[k], dY, F.voff + dy - dY); b := TRUE
            END
          UNTIL b
        END
      ELSIF dY > 0 THEN ScrollUp(F, 0, dY, b)
      END;
      SetChangeMark(F, F.text.changed)
    END
  END Scroll;

  PROCEDURE Show* (F: Viewer; pos: LONGINT); (*scroll specified text position to the top*)
    VAR R: Texts.Reader; full: BOOLEAN; L: Line;
      org: LONGINT; botY, k, dy, m: INTEGER;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      Validate(F.text, pos); full := FALSE;
      IF pos < F.org THEN NEW(L);
        org := pos; k := 0; dy := 0; m := F.H - F.top - F.bot + F.voff;
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh); (*read to file buffer*)
        WHILE (org < F.org) & (dy < m) DO PrepareLine(L, R);
          dy := dy + L.lsp; org := org + L.len; INC(k)
        END;
        IF (org = F.org) & (k > 0) & (dy < m) THEN ScrollDown(F, pos, dy + F.voff, 0)
        ELSE full := TRUE
        END
      ELSIF pos > F.org THEN ScrollUp(F, pos, 0, full)
      ELSIF F.voff > 0 THEN ScrollDown(F, pos, F.voff, 0)
      END;
      IF full THEN Mark(F, FALSE);
        Display.ReplConst(F.col, F.X + F.left, F.Y, F.W - F.left, F.H, Display.replace);
        botY := F.Y; F.Y := F.Y + F.H; F.H := 0; F.voff := 0;
        F.org := pos; LastLine(F, F.trailer); Extend(F, botY); Mark(F, TRUE)
      END;
      SetChangeMark(F, F.text.changed)
    END
  END Show;

  (*------------------locators------------------------*)

  PROCEDURE LocateLine (F: Viewer; y: INTEGER; VAR loc: Location);
    VAR L: Line; org: LONGINT; cury: INTEGER;
  BEGIN org := F.org; L := F.trailer.next; cury := F.H - F.top + F.voff; 
    WHILE (L.next # F.trailer) & (cury > y + L.lsp) DO
      org := org + L.len; cury := cury - L.lsp; L := L.next
    END;
    loc.org := org; loc.lin := L; loc.y := cury - L.asr
  END LocateLine;

  PROCEDURE LocateString (F: Viewer; x, y: INTEGER; VAR loc: Location);
    VAR R: Texts.Reader;
      patadr, bpos, pos, lim: LONGINT;
      bx, ex, ox, dx, u, v, w, h: INTEGER;
  BEGIN LocateLine(F, y, loc);
    lim := loc.org + loc.lin.len - 1;
    bpos := loc.org; bx := F.left;
    pos := loc.org; ox := F.left;
    Texts.OpenReader(R, F.text, loc.org); Texts.Read(R, nextCh);
    REPEAT
      WHILE (pos # lim) & (nextCh > " ") DO (*scan string*)
        Fonts.GetPat(R.fnt, nextCh, dx, u, v, w, h, patadr);
        INC(pos); ox := ox + dx; Texts.Read(R, nextCh)
      END;
      ex := ox;
      WHILE (pos # lim) & (nextCh <= " ") DO (*scan gap*)
        Fonts.GetPat(R.fnt, nextCh, dx, u, v, w, h, patadr);
        INC(pos); ox := ox + dx; Texts.Read(R, nextCh)
      END;
      IF (pos # lim) & (ox <= x) THEN
        Fonts.GetPat(R.fnt, nextCh, dx, u, v, w, h, patadr);
        bpos := pos; bx := ox;
        INC(pos); ox := ox + dx; Texts.Read(R, nextCh)
      ELSE pos := lim
      END
    UNTIL pos = lim;
    loc.pos := bpos; loc.dx := ex - bx; loc.x := bx
  END LocateString;

  PROCEDURE LocateChar (F: Viewer; x, y: INTEGER; VAR loc: Location);
    VAR R: Texts.Reader;
      patadr, pos, lim: LONGINT;
      ox, dx, u, v, w, h: INTEGER;
  BEGIN LocateLine(F, y, loc);
    lim := loc.org + loc.lin.len - 1;
    pos := loc.org; ox := F.left; dx := eolW;
    Texts.OpenReader(R, F.text, loc.org);
    WHILE pos # lim DO
      Texts.Read(R, nextCh);
      Fonts.GetPat(R.fnt, nextCh, dx, u, v, w, h, patadr);
      IF ox + dx <= x THEN
        INC(pos); ox := ox + dx;
        IF pos = lim THEN dx := eolW END
      ELSE lim := pos
      END
    END ;
    loc.pos := pos; loc.dx := dx; loc.x := ox
  END LocateChar;

  PROCEDURE LocatePos (F: Viewer; pos: LONGINT; VAR loc: Location);
    VAR T: Texts.Text; R: Texts.Reader; L: Line;
      org: LONGINT; cury: INTEGER;  
  BEGIN T := F.text;
    org := F.org; L := F.trailer.next; cury := F.H - F.top + F.voff;
    IF pos < org THEN pos := org END;
    WHILE (L.next # F.trailer) & (pos >= org + L.len) DO
      org := org + L.len; cury := cury - L.lsp; L := L.next
    END;
    IF pos >= org + L.len THEN pos := org + L.len - 1 END;    
    Texts.OpenReader(R, T, org); Texts.Read(R, nextCh);
    loc.org := org; loc.pos := pos; loc.lin := L;
    loc.x := F.left + Width(R, pos - org); loc.y := cury - L.asr
  END LocatePos;

  PROCEDURE Pos* (F: Viewer; X, Y: INTEGER): LONGINT;
    VAR loc: Location;
  BEGIN LocateChar(F, X - F.X, Y - F.Y, loc); RETURN loc.pos
  END Pos;

  (*------------------caret and selection, mouse tracking------------------------*)

  PROCEDURE FlipCaret (F: Viewer);
  BEGIN
    IF (F.carloc.x < F.W) & (F.carloc.y >= 10) & (F.carloc.x + 12 < F.W) THEN
      Display.CopyPattern(Display.white, Display.hook,
          F.X + F.carloc.x, F.Y + F.carloc.y - 10, Display.invert)
    END
  END FlipCaret;

  PROCEDURE SetCaret* (F: Viewer; pos: LONGINT);
  BEGIN LocatePos(F, pos, F.carloc); FlipCaret(F); F.hasCar := TRUE
  END SetCaret;

  PROCEDURE TrackCaret* (F: Viewer; X, Y: INTEGER; VAR keysum: SET);
    VAR loc: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      LocateChar(F, X - F.X, Y - F.Y, F.carloc);
      FlipCaret(F);
      keysum := {};
      REPEAT Input.Mouse(keys, X, Y); keysum := keysum + keys;
        Cursors.DrawMouseArrow(X, Y); LocateChar(F, X - F.X, Y - F.Y, loc);
        IF loc.pos # F.carloc.pos THEN FlipCaret(F); F.carloc := loc; FlipCaret(F) END
      UNTIL keys = {};
      F.hasCar := TRUE
    END
  END TrackCaret;

  PROCEDURE RemoveCaret* (F: Viewer);
  BEGIN IF F.hasCar THEN FlipCaret(F); F.hasCar := FALSE END
  END RemoveCaret;

  PROCEDURE FlipSelection (F: Viewer; VAR beg, end: Location);
    VAR L: Line; Y: INTEGER; org: LONGINT; beg0: Location;
  BEGIN
    IF end.org >= F.org THEN
      org := F.org; L := F.trailer.next; Y := F.Y + F.H - F.top - L.lsp + F.voff;
      WHILE (L # F.trailer) & (org < beg.org) DO
        org := org + L.len; L := L.next; Y := Y - L.lsp
      END;
      IF L # F.trailer THEN
        IF beg.org < F.org THEN beg0.org := F.org; beg0.x := F.left ELSE beg0 := beg END;
        IF beg0.org = end.org THEN
          ReplConst(Display.white, F, F.X + beg0.x, Y, end.x - beg0.x, L.lsp, Display.invert)
        ELSE
          ReplConst(Display.white, F, F.X + beg0.x, Y, F.left + L.wid - beg0.x, L.lsp, Display.invert);
          org := org + L.len; L := L.next; Y := Y - L.lsp;
          WHILE (L # F.trailer) & (org < end.org) DO
            ReplConst(Display.white, F, F.X + F.left, Y, L.wid, L.lsp, Display.invert);
            org := org + L.len; L := L.next; Y := Y - L.lsp
          END;
          IF (L # F.trailer) & (org = end.org) THEN
            ReplConst(Display.white, F, F.X + F.left, Y, end.x - F.left, L.lsp, Display.invert)
          END
        END
      END
    END
  END FlipSelection;

  PROCEDURE SetSelection* (F: Viewer; beg, end: LONGINT);
  BEGIN
    IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend) END;
    LocatePos(F, beg, F.selbeg); LocatePos(F, end, F.selend);
    IF F.selbeg.pos < F.selend.pos THEN
      FlipSelection(F, F.selbeg, F.selend); F.time := Kernel.Time(); F.hasSel := TRUE
    END
  END SetSelection;

  PROCEDURE TrackSelection* (F: Viewer; X, Y: INTEGER; VAR keysum: SET);
    VAR loc, L, R: Location; keys: SET; start, prev: LONGINT;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend) END;
      LocateChar(F, X - F.X, Y - F.Y, loc);
      F.selbeg := loc; start := loc.pos;
      INC(loc.pos); loc.x := loc.x + loc.dx; F.selend := loc;
      FlipSelection(F, F.selbeg, F.selend); keysum := {};
      REPEAT prev := loc.pos;
        Input.Mouse(keys, X, Y);
        keysum := keysum + keys;
        IF Y < F.Y + F.bot THEN (*scroll text up*)
          IF (F.selbeg.org = F.selend.org) OR (prev <= start) THEN L := F.selbeg; R := F.selend
          ELSE R := F.selend; L.org := F.selend.org; L.pos := L.org; L.x := F.left
          END;
          FlipSelection(F, L, R); Cursors.FadeMouse;
          Scroll(F, F.Y + F.bot - Y); Y := F.Y + F.bot;
          FlipSelection(F, L, R)
        ELSIF (Y > F.Y + F.H - F.top - 1) & ((F.org > 0) OR (F.voff > 0)) THEN (*scroll text down*)
          IF (F.selbeg.org = F.selend.org) OR (prev > start) THEN L := F.selbeg; R := F.selend
          ELSE L := F.selbeg; R.org := F.selbeg.org; R.pos := F.selbeg.lin.len; R.x := F.left + F.selbeg.lin.wid
          END;
          FlipSelection(F, L, R); Cursors.FadeMouse;
          Scroll(F, F.Y + F.H - F.top - 1 - Y); Y := F.Y + F.H - F.top - 1;
          FlipSelection(F, L, R)
        END;
        Cursors.DrawMouseArrow(X, Y);
        LocateChar(F, X - F.X, Y - F.Y, loc);
        IF prev > start THEN INC(loc.pos); loc.x := loc.x + loc.dx;
          IF loc.pos > start THEN
            IF loc.pos < F.selend.pos THEN FlipSelection(F, loc, F.selend); F.selend := loc
            ELSIF loc.pos > F.selend.pos THEN FlipSelection(F, F.selend, loc); F.selend := loc
            END
          ELSE (*switch to left of start*) FlipSelection(F, F.selbeg, F.selend);
            F.selend := F.selbeg; F.selbeg := loc; FlipSelection(F, F.selbeg, F.selend)
          END
        ELSIF loc.pos > start THEN (*switch to right of start*) FlipSelection(F, F.selbeg, F.selend);
          F.selbeg := F.selend; F.selend := loc; FlipSelection(F, F.selbeg, F.selend)
        ELSIF loc.pos > F.selbeg.pos THEN FlipSelection(F, F.selbeg, loc); F.selbeg := loc
        ELSIF loc.pos < F.selbeg.pos THEN FlipSelection(F, loc, F.selbeg); F.selbeg := loc
        END
      UNTIL keys = {};
      F.time := Kernel.Time(); F.hasSel := TRUE
    END
  END TrackSelection;

  PROCEDURE RemoveSelection* (F: Viewer);
  BEGIN IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend); F.hasSel := FALSE END
  END RemoveSelection;

  PROCEDURE TrackLine* (F: Viewer; X, Y: INTEGER; VAR org: LONGINT; VAR keysum: SET);
    VAR old, new: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      LocateLine(F, Y - F.Y, old);
      ReplConst(Display.white, F, F.X + F.left, F.Y + old.y - old.lin.dsr, old.lin.wid, 2, Display.invert);
      keysum := {};
      REPEAT Input.Mouse(keys, X, Y);
        keysum := keysum + keys;
        Cursors.DrawMouse(ScrollMarker, X, Y);
        LocateLine(F, Y - F.Y, new);
        IF new.org # old.org THEN
          ReplConst(Display.white, F, F.X + F.left, F.Y + old.y - old.lin.dsr, old.lin.wid, 2, Display.invert);
          ReplConst(Display.white, F, F.X + F.left, F.Y + new.y - new.lin.dsr, new.lin.wid, 2, Display.invert);
          old := new
        END
       UNTIL keys = {};
       ReplConst(Display.white, F, F.X + F.left, F.Y + new.y - new.lin.dsr, new.lin.wid, 2, Display.invert);
       org := new.org
    ELSE org := 0
    END
  END TrackLine;

  PROCEDURE TrackWord* (F: Viewer; X, Y: INTEGER; VAR pos: LONGINT; VAR keysum: SET);
    VAR old, new: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      LocateString(F, X - F.X, Y - F.Y, old);
      ReplConst(Display.white, F, F.X + old.x, F.Y + old.y - old.lin.dsr, old.dx, 2, Display.invert);
      keysum := {};
      REPEAT
        Input.Mouse(keys, X, Y); keysum := keysum + keys;
        Cursors.DrawMouseArrow(X, Y);
        LocateString(F, X - F.X, Y - F.Y, new);
        IF new.pos # old.pos THEN
          ReplConst(Display.white, F, F.X + old.x, F.Y + old.y - old.lin.dsr, old.dx, 2, Display.invert);
          ReplConst(Display.white, F, F.X + new.x, F.Y + new.y - new.lin.dsr, new.dx, 2, Display.invert);
          old := new
        END
      UNTIL keys = {};
      ReplConst(Display.white, F, F.X + new.x, F.Y + new.y - new.lin.dsr, new.dx, 2, Display.invert);
      pos := new.pos
    ELSE pos := 0
    END
  END TrackWord;

  (*------------------text modifiers------------------------*)

  PROCEDURE Replace* (F: Viewer; beg, end: LONGINT);
    VAR R: Texts.Reader; L, L0, l: Line;
      org, len: LONGINT; curY, botY, wid, oldlsp, oldasr, dy: INTEGER;
  BEGIN
    IF end > F.org THEN
      IF beg < F.org THEN beg := F.org END;
      org := F.org; L0 := F.trailer; L := F.trailer.next; curY := F.Y + F.H - F.top + F.voff; 
      WHILE (L # F.trailer) & (org + L.len <= beg) DO
        org := org + L.len; curY := curY - L.lsp; L0 := L; L := L.next
      END;
      IF L # F.trailer THEN
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        oldlsp := L.lsp; oldasr := L.asr;
        PrepareLine(L, R); (*set L.lsp, L.asr, L.dsr*)
        dy := L.lsp - oldlsp;
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        IF dy # 0 THEN
          ReplConst(F.col, F, F.X + F.left, curY - Max(oldlsp, L.lsp),
              F.W - F.left, Max(oldlsp, L.lsp), Display.replace);
          DisplayLine(F, L, R, F.X + F.left, curY - L.asr, 0, 0, 0)
        ELSE
          len := beg - org; wid := Width(R, len);
          ReplConst(F.col, F, F.X + F.left + wid, curY - oldlsp, L.wid - wid, oldlsp, Display.replace);
          DisplayLine(F, L, R, F.X + F.left + wid, curY - oldasr, 0, 0, len)
        END;
        org := org + L.len; curY := curY - L.lsp; L0 := L; L := L.next;
        WHILE (L # F.trailer) & (org <= end) & (dy = 0) DO
          oldlsp := L.lsp; oldasr := L.asr;
          PrepareLine(L, R); (*set L.lsp, L.asr, L.dsr*)
          dy := L.lsp - oldlsp;
          Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
          ReplConst(F.col, F, F.X + F.left, curY - Max(oldlsp, L.lsp),
              F.W - F.left, Max(oldlsp, L.lsp), Display.replace);
          DisplayLine(F, L, R, F.X + F.left, curY - L.asr, 0, 0, 0);
          org := org + L.len; curY := curY - L.lsp; L0 := L; L := L.next
        END;
        botY := F.Y + F.bot;
        IF ~L0.eot & (curY > botY) & (dy # 0) THEN
          Display.ReplConst(F.col, F.X + F.left, botY, F.W - F.left, curY - botY, Display.replace);
          LastLine(F, L0);
          WHILE ~L0.eot & (curY > botY) DO
            NewLine(F, l);
            PrepareLine(l, R);
            Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
            DisplayLine(F, l, R, F.X + F.left, curY - l.asr, 0, 0, 0);
            L0.next := l; L0:= l; org := org + L0.len; curY := curY - L0.lsp
          END;
          L0.next := F.trailer
        END
      END
    END;
    UpdateMark(F)
  END Replace;

  PROCEDURE Insert* (F: Viewer; beg, end: LONGINT);
    VAR R: Texts.Reader; L, L0, l: Line;
      org, len: LONGINT; curY, botY, wid, oldlsp, oldasr, dy: INTEGER;
  BEGIN
    IF beg < F.org THEN F.org := F.org + (end - beg)
    ELSE
      org := F.org; L := F.trailer.next; curY := F.Y + F.H - F.top + F.voff;
      WHILE (L # F.trailer) & (org + L.len <= beg) DO
        org := org + L.len; curY := curY - L.lsp; L := L.next
      END;
      IF L # F.trailer THEN
        botY := F.Y + F.bot;
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        oldlsp := L.lsp; oldasr := L.asr;
        PrepareLine(L, R); (*set L.lsp, L.asr, L.dsr*)
        dy := L.lsp - oldlsp;
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        IF dy # 0 THEN
          ReplConst(F.col, F, F.X + F.left, curY - Max(oldlsp, L.lsp),
              F.W - F.left, Max(oldlsp, L.lsp), Display.replace);
          DisplayLine(F, L, R, F.X + F.left, curY - L.asr, 0, 0, 0)
        ELSE
          len := beg - org; wid := Width(R, len);
          ReplConst(F.col, F, F.X + F.left + wid, curY - oldlsp, L.wid - wid, oldlsp, Display.replace);
          DisplayLine(F, L, R, F.X + F.left + wid, curY - oldasr, 0, 0, len)
        END;
        org := org + L.len; curY := curY - L.lsp; L0 := L.next;
        WHILE (org <= end) & (curY > botY) DO (*note: new lines may have variable line spaces*)
          NewLine(F, l);
          PrepareLine(l, R);
          Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
          ReplConst(F.col, F, F.X + F.left, curY - l.lsp, F.W - F.left, l.lsp, Display.replace);
          DisplayLine(F, l, R, F.X + F.left, curY - l.asr, 0, 0, 0);
          L.next := l; L := l;
          org := org + L.len; curY := curY - L.lsp
        END;
        IF (dy # 0) OR (L0 # L.next) THEN (*if it is not a one line update with unchanged line space*)
          IF curY - F.Y - F.bot > 0 THEN
            Display.ReplConst(F.col, F.X + F.left, F.Y + F.bot,
                F.W - F.left, curY - F.Y - F.bot, Display.replace)
          END;
          WHILE ~L.eot & (curY > botY) DO (*restore remaining lines*)
            NewLine(F, l);
            PrepareLine(l, R);
            Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
            DisplayLine(F, l, R, F.X + F.left, curY - l.asr, 0, 0, 0);
            L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
          END;
          L.next := F.trailer
        END
      END
    END;
    UpdateMark(F)
  END Insert;

  PROCEDURE Delete* (F: Viewer; beg, end: LONGINT);
    VAR R: Texts.Reader; L, L0, l: Line;
      org, org0, len: LONGINT; curY, botY, Y0, Y1, wid, bvis, oldlsp, oldasr, dy: INTEGER;
  BEGIN
    IF end <= F.org THEN F.org := F.org - (end - beg)
    ELSE
      IF beg < F.org THEN
        F.trailer.next.len := F.trailer.next.len + (F.org - beg);
        F.org := beg
      END;
      org := F.org; L := F.trailer.next; curY := F.Y + F.H - F.top + F.voff;
      WHILE (L # F.trailer) & (org + L.len <= beg) DO
        org := org + L.len; curY := curY - L.lsp; L := L.next
      END;
      IF L # F.trailer THEN
        botY := F.Y + F.bot;
        org0 := org; L0 := L; l := L; Y0 := curY;
        WHILE (L # F.trailer) & (org <= end) DO
          org := org + L.len; curY := curY - L.lsp; l := L; L := L.next
        END;
        Y1 := curY;
        Texts.OpenReader(R, F.text, org0); Texts.Read(R, nextCh);
        oldlsp := L0.lsp; oldasr := L0.asr;
        PrepareLine(L0, R); (*set L0.lsp, L0.asr, L0.dsr*)
        dy := L0.lsp - oldlsp;
        Texts.OpenReader(R, F.text, org0); Texts.Read(R, nextCh);
        IF dy # 0 THEN
          ReplConst(F.col, F, F.X + F.left, Y0 - Max(oldlsp, L0.lsp),
              F.W - F.left, Max(oldlsp, L0.lsp), Display.replace);
          DisplayLine(F, L0, R, F.X + F.left, Y0 - L0.asr, 0, 0, 0)
        ELSE
          len := beg - org0; wid := Width(R, len);
          ReplConst(F.col, F, F.X + F.left + wid, Y0 - oldlsp, L0.wid - wid, oldlsp, Display.replace);
          DisplayLine(F, L0, R, F.X + F.left + wid, Y0 - oldasr, 0, 0, len)
        END;
        org := org0 + L0.len;
        Y0 := Y0 - L0.lsp;
        IF dy # 0 THEN (*if the line space of the first line has changed*)
          curY := Y0; L := L0;
          IF curY - F.Y - F.bot > 0 THEN
            Display.ReplConst(F.col, F.X + F.left, F.Y + F.bot,
                F.W - F.left, Y0 - F.Y - F.bot, Display.replace)
          END;
          WHILE ~L.eot & (curY > botY) DO (*restore remaining lines*)
            NewLine(F, l);
            PrepareLine(l, R);
            Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
            DisplayLine(F, l, R, F.X + F.left, curY - l.asr, 0, 0, 0);
            L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
          END;
          L.next := F.trailer
        ELSIF L # L0.next THEN (*if it is a multi-line update, but the lines are still aligned*)
          IF l.next = L THEN l.next := F.pool; F.pool := L0.next; L0.next := L END;
          L := L0; org := org0 + L0.len;
          WHILE L.next # F.trailer DO
            L := L.next; org := org + L.len; curY := curY - L.lsp
          END;
          IF curY < F.Y + F.bot THEN
            IF Y1 > curY THEN bvis := (curY + L.lsp - F.Y - F.bot) MOD L.lsp;
              Display.CopyBlock(F.X + F.left, curY + bvis, F.W - F.left, Y1 - curY - bvis,
                  F.X + F.left, curY + (Y0 - Y1) + bvis, 0)
            END;
            curY := curY + (Y0 - Y1) + L.lsp;  (*!*)
            ReplConst(F.col, F, F.X + F.left, F.Y,
                F.W - F.left, curY + L.lsp - L.asr - (F.Y + L.dsr), Display.replace);
            Texts.OpenReader(R, F.text, org - L.len); Texts.Read(R, nextCh);
            DisplayLine(F, L, R, F.X + F.left, curY - L.asr, 0, 0, 0); (*old fractional bottom line*)
            curY := curY - L.lsp
          ELSE
            Display.CopyBlock(F.X + F.left, curY, F.W - F.left, Y1 - curY,
                F.X + F.left, curY + (Y0 - Y1), 0);
            curY := curY + (Y0 - Y1);
            ReplConst(F.col, F, F.X + F.left, F.Y,
                F.W - F.left, curY + L.lsp - L.asr - (F.Y + L.dsr), Display.replace)
          END;
          Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
          WHILE ~L.eot & (curY > botY) DO
            NewLine(F, l);
            PrepareLine(l, R);
            Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
            DisplayLine(F, l, R, F.X + F.left, curY - l.asr, 0, 0, 0);
            L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
          END;
          L.next := F.trailer
        END
      END
    END;
    UpdateMark(F)
  END Delete;

  PROCEDURE Recall*(VAR B: Texts.Buffer);
  BEGIN B := TBuf; NEW(TBuf); Texts.OpenBuf(TBuf)
  END Recall;

  (*------------------message handling------------------------*)

  PROCEDURE RemoveMarks (F: Viewer);
  BEGIN RemoveCaret(F); RemoveSelection(F)
  END RemoveMarks;

  PROCEDURE NotifyDisplay* (T: Texts.Text; op: INTEGER; beg, end: LONGINT);
    VAR M: UpdateMsg;
  BEGIN M.id := op; M.text := T; M.beg := beg; M.end := end; Viewers.Broadcast(M)
  END NotifyDisplay;

  PROCEDURE Call* (F: Viewer; pos: LONGINT; new: BOOLEAN);
    VAR S: Texts.Scanner; res: INTEGER;
  BEGIN
    Texts.OpenScanner(S, F.text, pos); Texts.Scan(S);
    IF (S.class = Texts.Name) & (S.line = 0) THEN
      Oberon.SetPar(F, F.text, pos + S.len); Oberon.Call(S.s, res);
      IF res > 0 THEN
        Texts.WriteString(W, "Call error: "); Texts.WriteString(W, Modules.importing);
        IF res = 1 THEN Texts.WriteString(W, " module not found")
        ELSIF res = 2 THEN  Texts.WriteString(W, " bad version")
        ELSIF res = 3 THEN Texts.WriteString(W, " imports ");
          Texts.WriteString(W, Modules.imported); Texts.WriteString(W, " with bad key");
        ELSIF res = 4 THEN Texts.WriteString(W, " corrupted obj file")
        ELSIF res = 5 THEN Texts.WriteString(W, " command not found")
        ELSIF res = 7 THEN Texts.WriteString(W, " insufficient space")
        END;
        Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
      END
    END
  END Call;

  PROCEDURE Write* (F: Viewer; ch: CHAR; fnt: Fonts.Font; col, voff: INTEGER);
    VAR buf: Texts.Buffer;
  BEGIN (*F.hasCar*)
    IF ch = BS THEN (*backspace*)
      IF F.carloc.pos > F.org THEN
        Texts.Delete(F.text, F.carloc.pos - 1, F.carloc.pos, DelBuf); SetCaret(F, F.carloc.pos - 1)
      END
    ELSIF ch = 1X THEN (*ctrl-a select-all*)
      IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend) END;
      F.selbeg.org := 0; F.selbeg.pos := 0; F.selbeg.x := F.left;
      F.selend.org := F.text.len; F.selend.pos := F.text.len; F.selend.x := F.left;
      FlipSelection(F, F.selbeg, F.selend); F.time := Kernel.Time(); F.hasSel := TRUE
    ELSIF ch = 3X THEN (*ctrl-c copy*)
      IF F.hasSel THEN
        NEW(TBuf); Texts.OpenBuf(TBuf); Texts.Save(F.text, F.selbeg.pos, F.selend.pos, TBuf)
      END
    ELSIF ch = 16X THEN (*ctrl-v paste*)
      NEW(buf); Texts.OpenBuf(buf); Texts.Copy(TBuf, buf); Texts.Insert(F.text, F.carloc.pos, buf);
      SetCaret(F, F.carloc.pos + TBuf.len)
    ELSIF ch = 18X THEN (*ctrl-x cut*)
      IF F.hasSel THEN
        NEW(TBuf); Texts.OpenBuf(TBuf); Texts.Delete(F.text, F.selbeg.pos, F.selend.pos, TBuf)
      END
    ELSIF (20X <= ch) & (ch <= DEL) OR (ch = CR) OR (ch = TAB) THEN
      KW.fnt := fnt; KW.col := col; KW.voff := voff; Texts.Write(KW, ch);
      Texts.Insert(F.text, F.carloc.pos, KW.buf);
      SetCaret(F, F.carloc.pos + 1)
    END
  END Write;

  PROCEDURE Defocus* (F: Viewer);
  BEGIN RemoveCaret(F)
  END Defocus;

  PROCEDURE Neutralize* (F: Viewer);
  BEGIN RemoveMarks(F)
  END Neutralize;

  PROCEDURE Modify* (F: Viewer; id, dY, Y, H: INTEGER);
    VAR hasSel, hasCar: BOOLEAN;
  BEGIN hasSel := F.hasSel; hasCar := F.hasCar;
    Mark(F, FALSE); RemoveMarks(F); SetChangeMark(F,  FALSE);
    IF id = Viewers.restore THEN
      Display.ReplConst(F.col, F.X, F.Y, F.W, F.H, Display.replace);
      Restore(F)
    ELSIF id = Viewers.extend THEN
      IF dY > 0 THEN Display.CopyBlock(F.X, F.Y, F.W, F.H, F.X, F.Y + dY, 0); F.Y := F.Y + dY END;
      Extend(F, Y)
    ELSIF id = Viewers.reduce THEN
      Reduce(F, Y + dY);
      IF dY > 0 THEN Display.CopyBlock(F.X, F.Y, F.W, F.H, F.X, Y, 0); F.Y := Y END
    END;
    IF F.H > 0 THEN Mark(F, TRUE); SetChangeMark(F,  F.text.changed) END;
    IF hasSel THEN SetSelection(F, F.selbeg.pos, F.selend.pos) END;
    IF hasCar THEN SetCaret(F, F.carloc.pos) END
  END Modify;

  PROCEDURE Open* (F: Viewer; H: Viewers.Handler; T: Texts.Text; org: LONGINT;
        col, left, right, top, bot, lsp: INTEGER);
    VAR L: Line;
  BEGIN NEW(L);
    L.len := 0; L.wid := 0; L.eot := FALSE; L.next := L; L.lsp := lsp; L.asr := asr; L.dsr := dsr;
    F.handle := H; F.text := T; F.org := org; F.trailer := L;
    F.left := left; F.right := right; F.top := top; F.bot := bot;
    F.lsp := lsp; F.col := col; F.hasMark := FALSE; F.hasCar := FALSE; F.hasSel := FALSE;
    F.pool := NIL; F.voff := 0; F.parent := NIL
  END Open;

  PROCEDURE Copy* (F: Viewer; VAR F1: Viewer);
  BEGIN NEW(F1);
    Open(F1, F.handle, F.text, F.org, F.col, F.left, F.right, F.top, F.bot, F.lsp)
  END Copy;

  PROCEDURE CopyOver(F: Viewer; text: Texts.Text; beg, end: LONGINT);
    VAR buf: Texts.Buffer;
  BEGIN
    IF F.hasCar THEN
      NEW(buf); Texts.OpenBuf(buf);
      Texts.Save(text, beg, end, buf); Texts.Insert(F.text, F.carloc.pos, buf);
      SetCaret(F, F.carloc.pos + (end - beg))
    END
  END CopyOver;

  PROCEDURE GetSelection* (F: Viewer; VAR text: Texts.Text; VAR beg, end, time: LONGINT);
  BEGIN
    IF F.hasSel THEN
      IF F.time > time THEN
        text := F.text; beg := F.selbeg.pos; end := F.selend.pos; time := F.time
      ELSIF F.text = text THEN
        IF (F.time < time) & (F.selbeg.pos < beg) THEN beg := F.selbeg.pos
          ELSIF (F.time > time) & (F.selend.pos > end) THEN end := F.selend.pos; time := F.time
        END
      END
    END
  END GetSelection;

  PROCEDURE Update* (F: Viewer; VAR M: UpdateMsg);
  BEGIN (*F.text = M.text*) SetChangeMark(F, FALSE);
    RemoveMarks(F); Cursors.RemoveMarks(F.X, F.Y, F.W, F.H);
    IF M.id = replace THEN Replace(F, M.beg, M.end)
    ELSIF M.id = insert THEN Insert(F, M.beg, M.end)
    ELSIF M.id = delete THEN Delete(F, M.beg, M.end)
    END ;
    SetChangeMark(F,  F.text.changed)
  END Update;

  PROCEDURE Edit* (F: Viewer; X, Y: INTEGER; Keys: SET);
    VAR M: CopyOverMsg;
      text: Texts.Text;
      buf: Texts.Buffer;
      v: Viewers.Viewer;
      beg, end, time, pos: LONGINT;
      keysum: SET;
      fnt: Fonts.Font;
      col, voff, Y0, SL, SR: INTEGER;
  BEGIN SL := F.X + Min(F.left, barW);
    IF X < SL THEN  (*cursor starts in scroll bar*)
      Cursors.DrawMouse(ScrollMarker, X, Y); keysum := Keys;
      IF Keys = {2} THEN  (*ML: continuous scroll*)
        Y0 := F.Y + F.H - 1 - F.markH; SR := SL + Min(100, F.W DIV 2);
        WHILE Keys # {} DO Cursors.DrawMouse(ScrollMarker, X, Y);
          IF Y # Y0 THEN
            SetChangeMark(F, FALSE);
            RemoveMarks(F); Cursors.RemoveMarks(F.X, F.Y, F.W, F.H);
            IF X < SR THEN (*cursor stays near scroll bar*)
              Show(F, (F.Y + F.H - Y) * (F.text.len) DIV F.H)
            ELSE (*cursor moves into text area*)
              Scroll(F, Y0 - Y)
            END ;
            Y0 := Y
          END ;
          Input.Mouse(Keys, X, Y)
        END
      ELSIF Keys = {1} THEN  (*MM: positional scrolling*)   keysum := Keys;
        REPEAT Input.Mouse(Keys, X, Y); keysum := keysum + Keys;
          Cursors.DrawMouse(ScrollMarker, X, Y)
        UNTIL Keys = {};
        IF keysum # {0, 1, 2} THEN
          IF 0 IN keysum THEN pos := 0
          ELSIF 2 IN keysum THEN pos := Max(F.text.len - 40, 0)
          ELSE pos := (F.Y + F.H - Y) * (F.text.len) DIV F.H
          END ;
          SetChangeMark(F, FALSE);
          RemoveMarks(F); Cursors.RemoveMarks(F.X, F.Y, F.W, F.H);
          Show(F, pos)
        END
      ELSIF Keys = {0} THEN  (*MR: track line and scroll up or down*)
        TrackLine(F, X, Y, pos, keysum);
        IF keysum # {0, 1, 2} THEN
          IF (pos >= 0) & (keysum = {0}) THEN (*MR, scroll up*)
            SetChangeMark(F, FALSE);
            RemoveMarks(F); Cursors.RemoveMarks(F.X, F.Y, F.W, F.H);
            Show(F, pos)
          ELSIF (keysum = {0,1}) THEN (*MR and MM, scroll down*)
            SetChangeMark(F, FALSE);
            RemoveMarks(F); Cursors.RemoveMarks(F.X, F.Y, F.W, F.H);
            Show(F, F.org*2 - pos - 100)
          END
        END
      END
    ELSE  (*cursor is in text area*)
      Cursors.DrawMouseArrow(X, Y);
      IF 0 IN Keys THEN  (*MR: select*)
        TrackSelection(F, X, Y, keysum);
        IF F.hasSel THEN
          IF keysum = {0, 2} THEN (*MR, ML: delete text*)
            Oberon.GetSelection(text, beg, end, time);
            Texts.Delete(text, beg, end, TBuf);
            Viewers.PassFocus(Viewers.ThisViewer(F)); SetCaret(F, beg)
          ELSIF keysum = {0, 1} THEN  (*MR, MM: copy to caret*)
            Oberon.GetSelection(text, beg, end, time);
            M.text := text; M.beg := beg; M.end := end;
            Viewers.FocusViewer.handle(Viewers.FocusViewer, M)
          END
        END
      ELSIF 1 IN Keys THEN  (*MM: call*)
        TrackWord(F, X, Y, pos, keysum);
        IF (pos >= 0) & ~(0 IN keysum) THEN Call(F, pos, 2 IN keysum) END
      ELSIF 2 IN Keys THEN  (*ML: set caret*)
        Viewers.PassFocus(Viewers.ThisViewer(F));
        TrackCaret(F, X, Y, keysum);
        IF keysum = {2, 1} THEN (*ML, MM: copy from selection to caret*)
           Oberon.GetSelection(text, beg, end, time);
           IF time >= 0 THEN
            NEW(TBuf); Texts.OpenBuf(TBuf);
            Texts.Save(text, beg, end, TBuf); Texts.Insert(F.text, F.carloc.pos, TBuf);
            SetSelection(F, F.carloc.pos, F.carloc.pos + (end  - beg));
            SetCaret(F, F.carloc.pos + (end - beg))
          ELSIF TBuf # NIL THEN
            NEW(buf); Texts.OpenBuf(buf);
            Texts.Copy(TBuf, buf); Texts.Insert(F.text, F.carloc.pos, buf);
            SetCaret(F, F.carloc.pos + buf.len)
          END
        ELSIF keysum = {2, 0} THEN (*ML, MR: copy looks*)
          Oberon.GetSelection(text, beg, end, time);
          IF time >= 0 THEN
            Texts.Attributes(F.text, F.carloc.pos, fnt, col, voff);
            IF fnt # NIL THEN Texts.ChangeLooks(text, beg, end, {0,1,2}, fnt, col, voff) END
          END
        END
      END
    END
  END Edit;

  PROCEDURE Handle* (F: Viewers.Viewer; VAR M: Viewers.Msg);
    VAR F1: Viewer; buf: Texts.Buffer;
  BEGIN
    CASE F OF Viewer:
      CASE M OF
      Viewers.ControlMsg:
        IF M.id = Viewers.defocus THEN Defocus(F)
        ELSIF M.id = Viewers.neutralize THEN Neutralize(F)
        END |
      Viewers.CopyMsg: Copy(F, F1); M.V := F1 |
      Viewers.ViewerMsg: Modify(F, M.id, M.dY, M.Y, M.H) |
      Viewers.InputMsg:  (*uses Oberon.CurFnt, Oberon.CurCol, Oberon.CurOff*)
        IF M.id = Viewers.track THEN Edit(F, M.X, M.Y, M.keys)
        ELSIF M.id = Viewers.consume THEN
          IF F.hasCar THEN Write(F, M.ch, Oberon.CurFnt, Oberon.CurCol, Oberon.CurOff) END
        END |
      Oberon.SelectionMsg: GetSelection(F, M.text, M.beg, M.end, M.time) |
      CopyOverMsg: CopyOver(F, M.text, M.beg, M.end) |
      UpdateMsg: IF F.text = M.text THEN Update(F, M) END
      END
    END
  END Handle;

  (*creation*)

  PROCEDURE Menu (name, commands: ARRAY OF CHAR): Texts.Text;
    VAR T: Texts.Text;
  BEGIN NEW(T); T.notify := NotifyDisplay;  Texts.Open(T, "");
    Texts.WriteString(W, name); Texts.WriteString(W, " | ");  Texts.WriteString(W, commands);
    Texts.Append(T, W.buf); RETURN T
  END Menu;

  PROCEDURE Text* (name: ARRAY OF CHAR): Texts.Text;
    VAR T: Texts.Text;
  BEGIN NEW(T); T.notify := NotifyDisplay; Texts.Open(T, name); RETURN T
  END Text;

  PROCEDURE NewMenu* (name, commands: ARRAY OF CHAR): Viewer;
    VAR F: Viewer; T: Texts.Text;
  BEGIN NEW(F); T := Menu(name, commands);
    Open(F, Handle, T, 0, Display.white, left DIV 4, 0, 0, 0, lsp); RETURN F
  END NewMenu;

  PROCEDURE NewText* (text: Texts.Text; pos: LONGINT): Viewer;
    VAR F: Viewer;
  BEGIN NEW(F);
    Open(F, Handle, text, pos, Display.black, left, right, top, bot, lsp); RETURN F
  END NewText;

BEGIN NEW(TBuf); NEW(DelBuf);
  Texts.OpenBuf(TBuf); Texts.OpenBuf(DelBuf);
  lsp := Fonts.Default.height; menuH := lsp + 2; barW := menuH;
  left := barW + lsp DIV 2;
  right := lsp DIV 2;
  top := lsp DIV 2; bot := lsp DIV 2;
  asr := Fonts.Default.maxY;
  dsr := -Fonts.Default.minY;
  selH := lsp; markW := lsp DIV 2;
  eolW := lsp DIV 2;
  ScrollMarker.Fade := FlipSM; ScrollMarker.Draw := FlipSM;
  Texts.OpenWriter(W); Texts.OpenWriter(KW)
END TextViewers.
