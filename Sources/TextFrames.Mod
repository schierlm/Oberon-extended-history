MODULE TextFrames; (*JG 8.10.90 / NW 16.11.2015 / AP 9.1.19*)
  IMPORT Input, Display, Viewers, Fonts, Texts, Oberon;

  CONST replace* = 0; insert* = 1; delete* = 2; unmark* = 3; (*message ids*)
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

    Frame* = POINTER TO FrameDesc;
    FrameDesc* = RECORD (Viewers.FrameDesc)
      text*: Texts.Text;
      org*: LONGINT;
      col*, lsp*: INTEGER;
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

    UpdateMsg* = RECORD (Viewers.FrameMsg)
      id*: INTEGER;       (*replace, insert, delete, unmark*)
      text*: Texts.Text;
      beg*, end*: LONGINT
    END;

    CopyOverMsg* = RECORD (Viewers.FrameMsg)
      text*: Texts.Text;
      beg*, end*: LONGINT
    END;

  VAR TBuf*, DelBuf: Texts.Buffer;
    menuH*, barW*, left*, right*, top*, bot*, lsp*: INTEGER; (*standard sizes*)
    asr, dsr, selH, markW, eolW: INTEGER;
    nextCh: CHAR;
    ScrollMarker: Oberon.Marker;
    W, KW: Texts.Writer; (*keyboard writer*)

  PROCEDURE Min (i, j: INTEGER): INTEGER;
  BEGIN IF i < j THEN j := i END ;
    RETURN j
  END Min;

  PROCEDURE Max (i, j: INTEGER): INTEGER;
  BEGIN IF i > j THEN j := i END ;
    RETURN j
  END Max;

  PROCEDURE NewLine (F: Frame; VAR L: Line); (*reuse line from line pool if possible*)
  BEGIN IF F.pool # NIL THEN L := F.pool; F.pool := L.next ELSE NEW(L) END
  END NewLine;

  PROCEDURE LastLine (F: Frame; L: Line); (*move lines after L to line pool*)
    VAR l: Line;
  BEGIN (*L in closed F.trailer ring*)
    IF L.next # F.trailer THEN l := L;
      WHILE l.next # F.trailer DO l := l.next END;
      l.next := F.pool; F.pool:= L.next; L.next := F.trailer
    END
  END LastLine;

  (*------------------display support------------------------*)

  PROCEDURE ReplConst (col: INTEGER; F: Frame; X, Y, W, H: INTEGER; mode: INTEGER);
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
    END;
    IF Y < 6 THEN Y := 6 ELSIF Y > DH - 6 THEN Y := DH - 6 END;
    Display.CopyPattern(Display.white, Display.updown, X-4, Y-4, 0, 0, Display.invert)
  END FlipSM;

  PROCEDURE UpdateMark (F: Frame); (*in scroll bar*)
    VAR h, oldH: INTEGER;
  BEGIN oldH := F.markH; h := Min(F.H - 2, 20); F.markH := Max(F.org * F.H DIV (F.text.len + 1), 1);
    IF (h > 0) & F.hasMark & (F.left >= barW) & (F.markH # oldH) THEN
      Display.ReplConst(Display.white, F.X + 2, Max(F.Y + F.H - 1 - oldH - h, F.Y + 1), markW, h, Display.invert);
      Display.ReplConst(Display.white, F.X + 2, Max(F.Y + F.H - 1 - F.markH - h, F.Y + 1), markW, h, Display.invert)
    END
  END UpdateMark;

  PROCEDURE Mark* (F: Frame; on: BOOLEAN); (*in scroll bar*)
    VAR h: INTEGER;
  BEGIN h := Min(F.H - 2, 20);
    IF (F.H > 0) & (F.left >= barW) & ((F.hasMark & ~on) OR (~F.hasMark & on)) THEN
      Display.ReplConst(Display.white, F.X + 2, Max(F.Y + F.H - 1 - F.markH - h, F.Y + 1), markW, h, Display.invert)
    END;
    F.hasMark := on
  END Mark;

  PROCEDURE SetChangeMark (F: Frame; on: BOOLEAN); (*in corner*)
  BEGIN
    IF F.H > menuH THEN
      IF on THEN Display.CopyPattern(Display.white, Display.block, F.X+F.W-12, F.Y+F.H-12, 0, 0, Display.paint)
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

  PROCEDURE PrepareLine (L: Line; VAR R: Texts.Reader); (*pass 1*)
  BEGIN L.asr := asr; L.dsr := -dsr; L.len := 0;
    WHILE (nextCh # CR) & (R.fnt # NIL) DO
      IF R.fnt.maxY > L.asr THEN L.asr := R.fnt.maxY END;
      IF R.fnt.minY < L.dsr THEN L.dsr := R.fnt.minY END;
      INC(L.len); Texts.Read(R, nextCh)
    END;
    INC(L.len); L.dsr := -L.dsr; L.lsp := L.asr + L.dsr;
    L.eot := R.fnt = NIL; Texts.Read(R, nextCh)
  END PrepareLine;

  PROCEDURE DisplayLine (F: Frame; L: Line; (*pass 2*)
    VAR R: Texts.Reader; X, Y, topY, botY: INTEGER; len: LONGINT);
    VAR patadr, NX, dx, x, y, w, h, t, b: INTEGER;
  BEGIN NX := F.X + F.W - F.right;
    WHILE (nextCh # CR) & (R.fnt # NIL) DO
      Fonts.GetPat(R.fnt, nextCh, dx, x, y, w, h, patadr);
      IF (X + x + w <= NX) & (h # 0) THEN y := Y + y;
        IF y + h <= topY THEN t := 0 ELSIF y >= topY THEN t := h ELSE t := y + h - topY END;
        IF y >= botY THEN b := 0 ELSIF y + h <= botY THEN b := h ELSE b := botY - y END;
        IF t + b < h THEN Display.CopyPattern(R.col, patadr, X + x, y, t, b, Display.invert) END
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

  (*------------------frame modifiers------------------------*)

  PROCEDURE Restore* (F: Frame);
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
        DisplayLine(F, l, R, F.X + F.left, curY - l.asr, topY, botY, 0);
        L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
      END
    END;
    L.next := F.trailer;
    F.markH := F.org * F.H DIV (F.text.len + 1)
  END Restore;

  PROCEDURE Suspend* (F: Frame);
  BEGIN F.trailer.next := F.trailer
  END Suspend;

  PROCEDURE Extend* (F: Frame; newY: INTEGER);
    VAR R: Texts.Reader; L, l: Line;
      org: LONGINT; curY, topY, botY, botY0: INTEGER;
  BEGIN Display.ReplConst(F.col, F.X, newY, F.W, F.Y - newY, Display.replace);
    IF F.left >= barW THEN
      Display.ReplConst(Display.white, F.X + barW - 1, newY, 1, F.Y - newY, Display.invert)
    END;
    topY := F.Y + F.H - F.top; botY0 := F.Y + F.bot;
    F.H := F.H + F.Y - newY; F.Y := newY; botY := F.Y + F.bot;
    IF F.trailer.next = F.trailer THEN Validate(F.text, F.org) END;
    L := F.trailer; org := F.org; curY := topY + F.voff;
    WHILE (L.next # F.trailer) & (curY > botY0) DO
      L := L.next; org := org + L.len; curY := curY - L.lsp
    END;
    IF (L # F.trailer) & (curY < botY0) THEN
      Texts.OpenReader(R, F.text, org - L.len); Texts.Read(R, nextCh);
      DisplayLine(F, L, R, F.X + F.left, curY + L.dsr, botY0, botY, 0) (*old fractional bottom line*)
    ELSE Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh)
    END;
    IF topY > botY THEN
      WHILE ~L.eot & (curY > botY) DO
        NewLine(F, l);
        PrepareLine(l, R);
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        DisplayLine(F, l, R, F.X + F.left, curY - l.asr, topY, botY, 0);
        L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
      END
    END;
    L.next := F.trailer;
    F.markH := F.org * F.H DIV (F.text.len + 1)
  END Extend;

  PROCEDURE Reduce* (F: Frame; newY: INTEGER);
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

  PROCEDURE ScrollDown (F: Frame; org: LONGINT; voff, dY: INTEGER);
    VAR R: Texts.Reader; L, L0, l: Line;
      curY, topY, botY, Y0, Y1, y, h: INTEGER;
  BEGIN topY := F.Y + F.H - F.top; botY := F.Y + F.bot;
    curY := topY + F.voff - dY; Y0 := Max(curY, botY); Y1 := Max(topY - dY, botY);
    F.org := org; F.voff := voff; L := F.trailer;
    WHILE (L.next # F.trailer) & (curY > botY) DO
      L := L.next; curY := curY - L.lsp
    END;
    LastLine(F, L);
    y := Max(curY, botY); h := Y1 - y;
    IF h > 0 THEN Display.CopyBlock(F.X + F.left, topY - h, F.W - F.left, h, F.X + F.left, y, 0) END;
    ReplConst(F.col, F, F.X + F.left, Y1, F.W - F.left, topY - Y1, Display.replace);
    L := F.trailer; L0 := L.next; curY := topY + voff;
    Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
    WHILE ~L.eot & (curY > Y0) DO
      NewLine(F, l);
      PrepareLine(l, R);
      Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
      DisplayLine(F, l, R, F.X + F.left, curY - l.asr, topY, Y0, 0);
      L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
    END;
    L.next := L0;
    IF (L0 # F.trailer) & (curY > Y1) THEN
      DisplayLine(F, L0, R, F.X + F.left, curY - L0.asr, topY, Y1, 0) (*old fractional top line*)
    END;
    UpdateMark(F)
  END ScrollDown;

  PROCEDURE ScrollUp (F: Frame; org: LONGINT; voff, dY, curY: INTEGER);
    VAR R: Texts.Reader; L, l: Line;
      topY, botY, Y0, Y1, y, h: INTEGER;
  BEGIN topY := F.Y + F.H - F.top; botY := F.Y + F.bot;
    F.org := org; F.voff := voff; L := F.trailer.next; Y0 := curY;
    WHILE L.next # F.trailer DO
      org := org + L.len; curY := curY - L.lsp; L := L.next
    END;
    y := Max(curY - L.lsp, botY); Y1 := Min(y + dY, topY); h := Y0 - y - F.voff;
    IF h > 0 THEN Display.CopyBlock(F.X + F.left, y, F.W - F.left, h, F.X + F.left, Y1, 0) END;
    ReplConst(F.col, F, F.X + F.left, y, F.W - F.left, Y1 - y, Display.replace);
    org := org + L.len; curY := curY - L.lsp + dY;
    IF curY - dY < botY THEN Texts.OpenReader(R, F.text, org - L.len); Texts.Read(R, nextCh);
      DisplayLine(F, L, R, F.X + F.left, curY + L.dsr, Y1, botY, 0) (*old fractional bottom line*)
    ELSE Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh)
    END;
    WHILE ~L.eot & (curY > botY) DO
      NewLine(F, l);
      PrepareLine(l, R);
      Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
      DisplayLine(F, l, R, F.X + F.left, curY - l.asr, topY, botY, 0);
      L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
    END;
    L.next := F.trailer; UpdateMark(F)
  END ScrollUp;

  PROCEDURE Scroll (F: Frame; dY: INTEGER); (*scroll displayed text dY pixels up or down*)
    CONST P = 100; len = 75; (*assumed average line length*)
    VAR R: Texts.Reader; L, L0: Line; done: BOOLEAN;
      org, q: LONGINT; dy, k: INTEGER; p: ARRAY P OF LONGINT; d: ARRAY P OF INTEGER;
  BEGIN (*dY # 0*)
    IF F.trailer.next # F.trailer THEN
      IF dY < 0 THEN dY := -dY;
        IF dY <= F.voff THEN ScrollDown(F, F.org, F.voff - dY, dY)
        ELSE NewLine(F, L); done := FALSE;
          q := Max(F.org - len*((dY + lsp - F.voff - 1) DIV lsp), 0); (*first guess*)
          REPEAT org := q; Validate(F.text, org); k := 0; dy := 0;
            Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
            WHILE (org < F.org) & (k < P) DO PrepareLine(L, R);
              dy := dy + L.lsp; p[k] := org; d[k] := L.lsp; org := org + L.len; INC(k)
            END;
            IF org < F.org THEN q := p[1] (*next guess forward*)
            ELSIF q = 0 THEN (*reached beginning of text*) done := TRUE;
              IF dy + F.voff > 0 THEN ScrollDown(F, 0, 0, dy + F.voff) END
            ELSIF (k = 0) OR (dy + F.voff < dY) THEN q := Max(q - len, 0) (*next guess backward*)
            ELSE (*found, now scroll*) k := 0; done := TRUE;
              WHILE dy - d[k] + F.voff >= dY DO dy := dy - d[k]; INC(k) END;
              ScrollDown(F, p[k], F.voff + dy - dY, dY)
            END
          UNTIL done
        END
      ELSIF dY > 0 THEN
        org := F.org; L0 := F.trailer; L := F.trailer.next; dy := 0;
        WHILE (L # F.trailer) & (dy + L.lsp <= dY + F.voff) DO
          org := org + L.len; dy := dy + L.lsp; L0 := L; L := L.next
        END;
        IF L # F.trailer THEN
          IF L0 # F.trailer THEN L0.next := F.pool; F.pool := F.trailer.next; F.trailer.next := L END;
          ScrollUp(F, org, F.voff + dY - dy, dY, F.Y + F.H - F.top + F.voff - dy)
        ELSIF org < F.text.len THEN NewLine(F, L);
          Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh); PrepareLine(L, R);
          WHILE ~L.eot & (org < F.text.len) & (dy + L.lsp <= dY + F.voff) DO
            org := org + L.len; dy := dy + L.lsp; PrepareLine(L, R)
          END;
          IF (org < F.text.len) & (dy + L.lsp > dY + F.voff) THEN Mark(F, FALSE);
            F.org := org; F.voff := F.voff + dY - dy; LastLine(F, F.trailer); Restore(F); Mark(F, TRUE)
          END
        END
      END;
      SetChangeMark(F, F.text.changed)
    END
  END Scroll;

  PROCEDURE Show* (F: Frame; pos: LONGINT); (*scroll specified text position to the top*)
    VAR R: Texts.Reader; L, L0: Line;
      org: LONGINT; dy, k, m: INTEGER;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      Validate(F.text, pos);
      IF pos < F.org THEN NewLine(F, L);
        org := pos; k := 0; dy := 0; m := F.H - F.top - F.bot + F.voff;
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        WHILE (org < F.org) & (dy < m) DO PrepareLine(L, R);
          dy := dy + L.lsp; org := org + L.len; INC(k)
        END;
        IF (org = F.org) & (k > 0) & (dy < m) THEN ScrollDown(F, pos, 0, dy + F.voff)
        ELSE Mark(F, FALSE); F.org := pos; F.voff := 0; LastLine(F, F.trailer); Restore(F); Mark(F, TRUE)
        END
      ELSIF pos > F.org THEN
        org := F.org; L0 := F.trailer; L := F.trailer.next; dy := 0;
        WHILE (L # F.trailer) & (org < pos) DO
          org := org + L.len; dy := dy + L.lsp; L0 := L; L := L.next
        END;
        IF L # F.trailer THEN
          IF L0 # F.trailer THEN L0.next := F.pool; F.pool := F.trailer.next; F.trailer.next := L END;
          ScrollUp(F, org, 0, dy - F.voff, F.Y + F.H - F.top + F.voff - dy)
        ELSIF pos < F.text.len THEN Mark(F, FALSE);
          F.org := pos; F.voff := 0; LastLine(F, F.trailer); Restore(F); Mark(F, TRUE)
        END
      ELSIF F.voff > 0 THEN ScrollDown(F, pos, 0, F.voff)
      END;
      SetChangeMark(F, F.text.changed)
    END
  END Show;

  (*------------------locators------------------------*)

  PROCEDURE LocateLine (F: Frame; y: INTEGER; VAR loc: Location);
    VAR L: Line; org: LONGINT; cury: INTEGER;
  BEGIN org := F.org; L := F.trailer.next; cury := F.H - F.top + F.voff; 
    WHILE (L.next # F.trailer) & (cury > y + L.lsp) DO
      org := org + L.len; cury := cury - L.lsp; L := L.next
    END;
    loc.org := org; loc.lin := L; loc.y := cury - L.asr
  END LocateLine;

  PROCEDURE LocateString (F: Frame; x, y: INTEGER; VAR loc: Location);
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

  PROCEDURE LocateChar (F: Frame; x, y: INTEGER; VAR loc: Location);
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
    END;
    loc.pos := pos; loc.dx := dx; loc.x := ox
  END LocateChar;

  PROCEDURE LocatePos (F: Frame; pos: LONGINT; VAR loc: Location);
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

  PROCEDURE Pos* (F: Frame; X, Y: INTEGER): LONGINT;
    VAR loc: Location;
  BEGIN LocateChar(F, X - F.X, Y - F.Y, loc); RETURN loc.pos
  END Pos;

  (*------------------caret, selection, mouse tracking------------------------*)

  PROCEDURE FlipCaret (F: Frame);
  BEGIN
    IF (F.carloc.x < F.W) & (F.carloc.y >= 10) & (F.carloc.x + 12 < F.W) THEN
      Display.CopyPattern(Display.white, Display.hook, F.X + F.carloc.x, F.Y + F.carloc.y - 10, 0, 0, Display.invert)
    END
  END FlipCaret;

  PROCEDURE SetCaret* (F: Frame; pos: LONGINT);
  BEGIN LocatePos(F, pos, F.carloc); FlipCaret(F); F.hasCar := TRUE
  END SetCaret;

  PROCEDURE TrackCaret* (F: Frame; X, Y: INTEGER; VAR keysum: SET);
    VAR loc: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      LocateChar(F, X - F.X, Y - F.Y, F.carloc);
      FlipCaret(F);
      keysum := {};
      REPEAT Input.Mouse(keys, X, Y); keysum := keysum + keys;
        Oberon.DrawMouseArrow(X, Y); LocateChar(F, X - F.X, Y - F.Y, loc);
        IF loc.pos # F.carloc.pos THEN FlipCaret(F); F.carloc := loc; FlipCaret(F) END
      UNTIL keys = {};
      F.hasCar := TRUE
    END
  END TrackCaret;

  PROCEDURE RemoveCaret* (F: Frame);
  BEGIN IF F.hasCar THEN FlipCaret(F); F.hasCar := FALSE END
  END RemoveCaret;

  PROCEDURE FlipSelection (F: Frame; VAR beg, end: Location);
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

  PROCEDURE SetSelection* (F: Frame; beg, end: LONGINT);
  BEGIN
    IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend) END;
    LocatePos(F, beg, F.selbeg); LocatePos(F, end, F.selend);
    IF F.selbeg.pos < F.selend.pos THEN
      FlipSelection(F, F.selbeg, F.selend); F.time := Oberon.Time(); F.hasSel := TRUE
    END
  END SetSelection;

  PROCEDURE TrackSelection* (F: Frame; X, Y: INTEGER; VAR keysum: SET);
    VAR loc, L, R: Location; keys: SET; start, prev: LONGINT; topY, botY: INTEGER;
  BEGIN
    IF F.trailer.next # F.trailer THEN topY := F.Y + F.H - F.top; botY := F.Y + F.bot;
      IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend) END;
      LocateChar(F, X - F.X, Y - F.Y, loc);
      IF F.hasSel & (loc.pos = F.selbeg.pos) & (F.selend.pos = F.selbeg.pos + 1) THEN
        LocateChar(F, F.left, Y - F.Y, F.selbeg)
      ELSE F.selbeg := loc
      END;
      INC(loc.pos); loc.x := loc.x + loc.dx; F.selend := loc;
      FlipSelection(F, F.selbeg, F.selend); keysum := {}; start := F.selbeg.pos;
      REPEAT prev := loc.pos;
        Input.Mouse(keys, X, Y);
        keysum := keysum + keys;
        IF Y < botY THEN (*scroll text up*)
          IF (F.selbeg.org = F.selend.org) OR (prev <= start) THEN L := F.selbeg; R := F.selend
          ELSE R := F.selend; L.org := F.selend.org; L.pos := L.org; L.x := F.left
          END;
          FlipSelection(F, L, R); Oberon.FadeMouse;
          Scroll(F, botY - Y); Y := botY;
          FlipSelection(F, L, R)
        ELSIF (Y > topY - 1) & ((F.org > 0) OR (F.voff > 0)) THEN (*scroll text down*)
          IF (F.selbeg.org = F.selend.org) OR (prev > start) THEN L := F.selbeg; R := F.selend
          ELSE L := F.selbeg; R.org := F.selbeg.org; R.pos := F.selbeg.lin.len; R.x := F.left + F.selbeg.lin.wid
          END;
          FlipSelection(F, L, R); Oberon.FadeMouse;
          Scroll(F, topY - 1 - Y); Y := topY - 1;
          FlipSelection(F, L, R)
        END;
        Oberon.DrawMouseArrow(X, Y);
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
      F.time := Oberon.Time(); F.hasSel := TRUE
    END
  END TrackSelection;

  PROCEDURE RemoveSelection* (F: Frame);
  BEGIN IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend); F.hasSel := FALSE END
  END RemoveSelection;

  PROCEDURE TrackLine* (F: Frame; X, Y: INTEGER; VAR org: LONGINT; VAR keysum: SET);
    VAR old, new: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      LocateLine(F, Y - F.Y, old);
      ReplConst(Display.white, F, F.X + F.left, F.Y + old.y - old.lin.dsr, old.lin.wid, 2, Display.invert);
      keysum := {};
      REPEAT Input.Mouse(keys, X, Y);
        keysum := keysum + keys;
        Oberon.DrawMouse(ScrollMarker, X, Y);
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

  PROCEDURE TrackWord* (F: Frame; X, Y: INTEGER; VAR pos: LONGINT; VAR keysum: SET);
    VAR old, new: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      LocateString(F, X - F.X, Y - F.Y, old);
      ReplConst(Display.white, F, F.X + old.x, F.Y + old.y - old.lin.dsr, old.dx, 2, Display.invert);
      keysum := {};
      REPEAT
        Input.Mouse(keys, X, Y); keysum := keysum + keys;
        Oberon.DrawMouseArrow(X, Y);
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

  PROCEDURE Replace* (F: Frame; beg, end: LONGINT);
    VAR R: Texts.Reader; L, L0, l: Line;
      org: LONGINT; curY, topY, botY, dy: INTEGER;
  BEGIN
    IF end > F.org THEN topY := F.Y + F.H - F.top;
      IF beg < F.org THEN beg := F.org END;
      org := F.org; L0 := F.trailer; L := L0.next; curY := topY + F.voff; 
      WHILE (L # F.trailer) & (org + L.len <= beg) DO
        org := org + L.len; curY := curY - L.lsp; L0 := L; L := L.next
      END;
      IF L # F.trailer THEN botY := F.Y + F.bot; dy := 0;
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        WHILE (L # F.trailer) & (org <= end) & (dy = 0) DO
          dy := L.lsp; PrepareLine(L, R); dy := L.lsp - dy;
          Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
          ReplConst(F.col, F, F.X + F.left, curY - L.lsp, F.W - F.left, L.lsp, Display.replace);
          DisplayLine(F, L, R, F.X + F.left, curY - L.asr, topY, botY, 0);
          org := org + L.len; curY := curY - L.lsp; L0 := L; L := L.next
        END;
        IF ~L0.eot & (curY > botY) & (dy # 0) THEN
          ReplConst(F.col, F, F.X + F.left, botY, F.W - F.left, curY - botY, Display.replace);
          LastLine(F, L0);
          WHILE ~L0.eot & (curY > botY) DO
            NewLine(F, l);
            PrepareLine(l, R);
            Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
            DisplayLine(F, l, R, F.X + F.left, curY - l.asr, topY, botY, 0);
            L0.next := l; L0:= l; org := org + L0.len; curY := curY - L0.lsp
          END;
          L0.next := F.trailer
        END
      END
    END;
    UpdateMark(F)
  END Replace;

  PROCEDURE Insert* (F: Frame; beg, end: LONGINT);
    VAR R: Texts.Reader; L, L0, l: Line;
      org: LONGINT; curY, topY, botY, dy: INTEGER;
  BEGIN
    IF beg < F.org THEN F.org := F.org + (end - beg)
    ELSE topY := F.Y + F.H - F.top;
      org := F.org; L := F.trailer.next; curY := topY + F.voff;
      WHILE (L # F.trailer) & (org + L.len <= beg) DO
        org := org + L.len; curY := curY - L.lsp; L := L.next
      END;
      IF L # F.trailer THEN botY := F.Y + F.bot;
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        dy := L.lsp; PrepareLine(L, R); dy := L.lsp - dy;
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        ReplConst(F.col, F, F.X + F.left, curY - L.lsp, F.W - F.left, L.lsp, Display.replace);
        DisplayLine(F, L, R, F.X + F.left, curY - L.asr, topY, botY, 0);
        org := org + L.len; curY := curY - L.lsp; L0 := L.next;
        WHILE (org <= end) & (curY > botY) DO
          NewLine(F, l);
          PrepareLine(l, R);
          Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
          ReplConst(F.col, F, F.X + F.left, curY - l.lsp, F.W - F.left, l.lsp, Display.replace);
          DisplayLine(F, l, R, F.X + F.left, curY - l.asr, topY, botY, 0);
          L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
        END;
        IF (dy # 0) OR (L0 # L.next) THEN
          ReplConst(F.col, F, F.X + F.left, botY, F.W - F.left, curY - botY, Display.replace);
          WHILE ~L.eot & (curY > botY) DO
            NewLine(F, l);
            PrepareLine(l, R);
            Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
            DisplayLine(F, l, R, F.X + F.left, curY - l.asr, topY, botY, 0);
            L.next := l; L := l; org := org + L.len; curY := curY - L.lsp
          END;
          L.next := F.trailer
        END
      END
    END;
    UpdateMark(F)
  END Insert;

  PROCEDURE Delete* (F: Frame; beg, end: LONGINT);
    VAR R: Texts.Reader; L, L0, l: Line;
      org, org0: LONGINT; curY, topY, botY, Y0, Y1, dy: INTEGER;
  BEGIN
    IF end <= F.org THEN F.org := F.org - (end - beg)
    ELSE topY := F.Y + F.H - F.top;
      IF beg < F.org THEN
        F.trailer.next.len := F.trailer.next.len + (F.org - beg);
        F.org := beg
      END;
      org := F.org; L := F.trailer.next; curY := topY + F.voff;
      WHILE (L # F.trailer) & (org + L.len <= beg) DO
        org := org + L.len; curY := curY - L.lsp; L := L.next
      END;
      IF L # F.trailer THEN botY := F.Y + F.bot;
        org0 := org; L0 := L; l := L; Y0 := curY;
        WHILE (L # F.trailer) & (org <= end) DO
          org := org + L.len; curY := curY - L.lsp; l := L; L := L.next
        END;
        Y1 := curY;
        Texts.OpenReader(R, F.text, org0); Texts.Read(R, nextCh);
        dy := L0.lsp; PrepareLine(L0, R); dy := L0.lsp - dy;
        Texts.OpenReader(R, F.text, org0); Texts.Read(R, nextCh);
        ReplConst(F.col, F, F.X + F.left, Y0 - L0.lsp, F.W - F.left, L0.lsp, Display.replace);
        DisplayLine(F, L0, R, F.X + F.left, Y0 - L0.asr, topY, botY, 0);
        IF (dy # 0) OR (l # L0) THEN
          IF l # L0 THEN l.next := F.pool; F.pool := L0.next; L0.next := L END;
          org := org0 + L0.len; Y0 := Y0 - L0.lsp; L := L0;
          WHILE L.next # F.trailer DO
            L := L.next; org := org + L.len; curY := curY - L.lsp
          END;
          IF curY < botY THEN
            IF Y1 > botY THEN
              Display.CopyBlock(F.X + F.left, botY,
                  F.W - F.left, Y1 - botY, F.X + F.left, botY + Y0 - Y1, 0)
            END;
            dy := L.lsp - (botY - curY); curY := curY + Y0 - Y1 + L.lsp;
            ReplConst(F.col, F, F.X + F.left, botY, F.W - F.left, curY - dy - botY, Display.replace);
            Texts.OpenReader(R, F.text, org - L.len); Texts.Read(R, nextCh);
            DisplayLine(F, L, R, F.X + F.left, curY - L.asr, curY - dy, botY, 0);
            curY := curY - L.lsp
          ELSE
            Display.CopyBlock(F.X + F.left, curY,
                F.W - F.left, Y1 - curY, F.X + F.left, curY + Y0 - Y1, 0);
            curY := curY + Y0 - Y1;
            ReplConst(F.col, F, F.X + F.left, botY, F.W - F.left, curY - botY, Display.replace)
          END;
          Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
          WHILE ~L.eot & (curY > botY) DO
            NewLine(F, l);
            PrepareLine(l, R);
            Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
            DisplayLine(F, l, R, F.X + F.left, curY - l.asr, topY, botY, 0);
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

  PROCEDURE RemoveMarks (F: Frame);
  BEGIN RemoveCaret(F); RemoveSelection(F)
  END RemoveMarks;

  PROCEDURE NotifyDisplay* (T: Texts.Text; op: INTEGER; beg, end: LONGINT);
    VAR M: UpdateMsg;
  BEGIN M.id := op; M.text := T; M.beg := beg; M.end := end; Viewers.Broadcast(M)
  END NotifyDisplay;

  PROCEDURE Write* (F: Frame; ch: CHAR; fnt: Fonts.Font; col, voff: INTEGER);
    VAR buf: Texts.Buffer;
  BEGIN (*F.hasCar*)
    IF ch = BS THEN (*backspace*)
      IF F.carloc.pos > F.org THEN
        Texts.Delete(F.text, F.carloc.pos - 1, F.carloc.pos, DelBuf); SetCaret(F, F.carloc.pos - 1)
      END
    ELSIF ch = 1X THEN (*ctrl-a  select-all*)
      IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend) END;
      F.selbeg.org := 0; F.selbeg.pos := 0; F.selbeg.x := F.left;
      F.selend.org := F.text.len; F.selend.pos := F.text.len; F.selend.x := F.left;
      FlipSelection(F, F.selbeg, F.selend); F.time := Oberon.Time(); F.hasSel := TRUE
    ELSIF ch = 3X THEN (*ctrl-c  copy*)
      IF F.hasSel THEN
        NEW(TBuf); Texts.OpenBuf(TBuf); Texts.Save(F.text, F.selbeg.pos, F.selend.pos, TBuf)
      END
    ELSIF ch = 16X THEN (*ctrl-v  paste*)
      NEW(buf); Texts.OpenBuf(buf); Texts.Copy(TBuf, buf); Texts.Insert(F.text, F.carloc.pos, buf);
      SetCaret(F, F.carloc.pos + TBuf.len)
    ELSIF ch = 18X THEN (*ctrl-x  cut*)
      IF F.hasSel THEN
        NEW(TBuf); Texts.OpenBuf(TBuf); Texts.Delete(F.text, F.selbeg.pos, F.selend.pos, TBuf)
      END
    (*ELSIF ch = 11X THEN (*cursor left*)
      IF F.carloc.pos > 0 THEN RemoveCaret(F); SetCaret(F, F.carloc.pos - 1) END
    ELSIF ch = 12X THEN (*cursor right*)
      IF F.carloc.pos < F.text.len THEN RemoveCaret(F); SetCaret(F, F.carloc.pos + 1) END
    ELSIF ch = 13X THEN (*cursor up*)
      RemoveCaret(F); SetCaret(F, Pos(F, F.X + F.carloc.x, F.Y + F.carloc.y + F.lsp))
    ELSIF ch = 14X THEN (*cursor down*)
      RemoveCaret(F); SetCaret(F, Pos(F, F.X + F.carloc.x, F.Y + F.carloc.y - F.lsp))*)
    ELSIF (20X <= ch) & (ch <= DEL) OR (ch = CR) OR (ch = TAB) THEN
      KW.fnt := fnt; KW.col := col; KW.voff := voff; Texts.Write(KW, ch);
      Texts.Insert(F.text, F.carloc.pos, KW.buf);
      SetCaret(F, F.carloc.pos + 1)
    END
  END Write;

  PROCEDURE Defocus* (F: Frame);
  BEGIN RemoveCaret(F)
  END Defocus;

  PROCEDURE Neutralize* (F: Frame);
  BEGIN RemoveMarks(F)
  END Neutralize;

  PROCEDURE Modify* (F: Frame; id, Y, H: INTEGER);
    VAR dY: INTEGER;
  BEGIN
    Mark(F, FALSE); RemoveMarks(F); SetChangeMark(F, FALSE);
    IF id = Viewers.restore THEN Restore(F)
    ELSIF id = Viewers.modify THEN dY := Y + H - F.Y - F.H;
      IF H > F.H THEN (*extend*)
        IF dY # 0 THEN Display.CopyBlock(F.X, F.Y, F.W, F.H, F.X, F.Y + dY, 0); F.Y := F.Y + dY END;
        Extend(F, Y)
      ELSIF H < F.H THEN (*reduce*)
        Reduce(F, F.Y + F.H - H);
        IF dY # 0 THEN Display.CopyBlock(F.X, F.Y, F.W, F.H, F.X, Y, 0); F.Y := Y END
      ELSIF dY # 0 THEN (*move*) Display.CopyBlock(F.X, F.Y, F.W, F.H, F.X, Y, 0); F.Y := Y
      END
    END;
    IF F.H > 0 THEN Mark(F, TRUE); SetChangeMark(F, F.text.changed) END
  END Modify;

  PROCEDURE Open* (F: Frame; H: Viewers.Handler; T: Texts.Text; org: LONGINT;
      col, left, right, top, bot, lsp: INTEGER);
    VAR L: Line;
  BEGIN NEW(L);
    L.len := 0; L.wid := 0; L.eot := FALSE; L.next := L; L.lsp := lsp; L.asr := asr; L.dsr := dsr;
    F.handle := H; F.text := T; F.org := org; F.trailer := L;
    F.left := left; F.right := right; F.top := top; F.bot := bot;
    F.lsp := lsp; F.col := col; F.hasMark := FALSE; F.hasCar := FALSE; F.hasSel := FALSE;
    F.pool := NIL; F.voff := 0
  END Open;

  PROCEDURE Copy* (F: Frame; VAR F1: Frame);
  BEGIN NEW(F1);
    Open(F1, F.handle, F.text, F.org, F.col, F.left, F.right, F.top, F.bot, F.lsp)
  END Copy;

  PROCEDURE CopyOver(F: Frame; text: Texts.Text; beg, end: LONGINT);
    VAR buf: Texts.Buffer;
  BEGIN
    IF F.hasCar THEN
      NEW(buf); Texts.OpenBuf(buf);
      Texts.Save(text, beg, end, buf); Texts.Insert(F.text, F.carloc.pos, buf);
      SetCaret(F, F.carloc.pos + (end - beg))
    END
  END CopyOver;

  PROCEDURE GetSelection* (F: Frame; VAR text: Texts.Text; VAR beg, end, time: LONGINT);
  BEGIN
    IF F.hasSel THEN
      IF F.text = text THEN
        IF F.selbeg.pos < beg THEN beg := F.selbeg.pos END ; (*leftmost*)
        IF F.time > time THEN end := F.selend.pos; time := F.time END (*last selected*)
      ELSIF F.time > time THEN
        text := F.text; beg := F.selbeg.pos; end := F.selend.pos; time := F.time
      END
    END
  END GetSelection;

  PROCEDURE Update* (F: Frame; VAR M: UpdateMsg);
  BEGIN (*F.text = M.text*) SetChangeMark(F, FALSE);
    RemoveMarks(F); Oberon.RemoveMarks(F.X, F.Y, F.W, F.H);
    IF M.id = replace THEN Replace(F, M.beg, M.end)
    ELSIF M.id = insert THEN Insert(F, M.beg, M.end)
    ELSIF M.id = delete THEN Delete(F, M.beg, M.end)
    END ;
    SetChangeMark(F, F.text.changed)
  END Update;

  PROCEDURE Edit* (F: Frame; X, Y: INTEGER; Keys: SET);
    VAR M: CopyOverMsg;
      text: Texts.Text;
      buf: Texts.Buffer;
      v: Viewers.Viewer;
      beg, end, time, pos: LONGINT;
      keysum: SET;
      fnt: Fonts.Font;
      col, voff, Y0, SL, SR: INTEGER;
  BEGIN SL := F.X + Min(F.left, barW);
    IF X < SL THEN (*cursor starts in scroll bar*)
      Oberon.DrawMouse(ScrollMarker, X, Y); keysum := Keys;
      IF Keys = {2} THEN (*ML: continuous scroll*)
        Y0 := F.Y + F.H - 1 - F.markH; SR := SL + Min(100, F.W DIV 2);
        WHILE Keys # {} DO Oberon.DrawMouse(ScrollMarker, X, Y);
          IF Y # Y0 THEN
            SetChangeMark(F, FALSE);
            RemoveMarks(F); Oberon.RemoveMarks(F.X, F.Y, F.W, F.H);
            IF X < SR THEN Show(F, (F.Y + F.H - Y) * (F.text.len) DIV F.H) ELSE Scroll(F, Y0 - Y) END;
            Y0 := Y
          END;
          Input.Mouse(Keys, X, Y)
        END
      ELSIF Keys = {1} THEN (*MM: positional scrolling*) keysum := Keys;
        REPEAT Input.Mouse(Keys, X, Y); keysum := keysum + Keys;
          Oberon.DrawMouse(ScrollMarker, X, Y)
        UNTIL Keys = {};
        IF keysum # {0, 1, 2} THEN
          IF 0 IN keysum THEN pos := 0
          ELSIF 2 IN keysum THEN pos := Max(F.text.len - 40, 0)
          ELSE pos := (F.Y + F.H - Y) * (F.text.len) DIV F.H
          END;
          SetChangeMark(F, FALSE);
          RemoveMarks(F); Oberon.RemoveMarks(F.X, F.Y, F.W, F.H);
          Show(F, pos)
        END
      ELSIF Keys = {0} THEN (*MR: track line and scroll up or down*)
        TrackLine(F, X, Y, pos, keysum);
        IF keysum # {0, 1, 2} THEN
          IF (pos >= 0) & (keysum = {0}) THEN (*MR, scroll up*)
            SetChangeMark(F, FALSE);
            RemoveMarks(F); Oberon.RemoveMarks(F.X, F.Y, F.W, F.H);
            Show(F, pos)
          ELSIF (keysum = {0,1}) THEN (*MR and MM, scroll down*)
            SetChangeMark(F, FALSE);
            RemoveMarks(F); Oberon.RemoveMarks(F.X, F.Y, F.W, F.H);
            Show(F, F.org*2 - pos - 100)
          END
        END
      END
    ELSE (*cursor is in text area*)
      Oberon.DrawMouseArrow(X, Y);
      IF 0 IN Keys THEN (*MR: select*)
        TrackSelection(F, X, Y, keysum);
        IF F.hasSel THEN
          IF keysum = {0, 2} THEN (*MR, ML: delete text*)
            Oberon.GetSelection(text, beg, end, time);
            Texts.Delete(text, beg, end, TBuf);
            Viewers.PassFocus(Viewers.ThisViewer(F)); SetCaret(F, beg)
          ELSIF keysum = {0, 1} THEN (*MR, MM: copy to caret*)
            Oberon.GetSelection(text, beg, end, time);
            M.text := text; M.beg := beg; M.end := end;
            Viewers.FocusViewer.handle(Viewers.FocusViewer, M)
          END
        END
      ELSIF 1 IN Keys THEN (*MM: call*)
        TrackWord(F, X, Y, pos, keysum);
        IF (pos >= 0) & ~(0 IN keysum) THEN Oberon.Activate(F, F.text, pos) END
      ELSIF 2 IN Keys THEN (*ML: set caret*)
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

  PROCEDURE Handle* (F: Viewers.Frame; VAR M: Viewers.FrameMsg);
    VAR F1: Frame;
  BEGIN
    CASE F OF Frame:
      CASE M OF
      Viewers.InputMsg:
        IF M.id = Viewers.track THEN Edit(F, M.X, M.Y, M.keys)
        ELSIF F.hasCar & (M.id = Viewers.consume) THEN
          CASE M OF
            Oberon.InputMsg: Write(F, M.ch, M.fnt, M.col, M.voff) |
            Viewers.InputMsg: Write(F, M.ch, Oberon.CurFnt, Oberon.CurCol, Oberon.CurOff)
          END
        END |
      Viewers.ControlMsg:
        IF M.id = Viewers.defocus THEN Defocus(F)
        ELSIF M.id = Viewers.neutralize THEN Neutralize(F)
        END |
      Viewers.CopyMsg: Copy(F, F1); M.F := F1 |
      Viewers.ViewerMsg: Modify(F, M.id, M.Y, M.H) |
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

  PROCEDURE NewMenu* (name, commands: ARRAY OF CHAR): Frame;
    VAR F: Frame; T: Texts.Text;
  BEGIN NEW(F); T := Menu(name, commands);
    Open(F, Handle, T, 0, Display.white, left DIV 4, 0, 0, 0, lsp); RETURN F
  END NewMenu;

  PROCEDURE NewText* (text: Texts.Text; pos: LONGINT): Frame;
    VAR F: Frame;
  BEGIN NEW(F);
    Open(F, Handle, text, pos, Display.black, left, right, top, bot, lsp); RETURN F
  END NewText;

BEGIN NEW(TBuf); NEW(DelBuf);
  Texts.OpenBuf(TBuf); Texts.OpenBuf(DelBuf);
  lsp := Fonts.Default.height; menuH := lsp + 2; barW := lsp - 2;
  left := barW + lsp DIV 2;
  right := lsp DIV 2;
  top := lsp DIV 2; bot := lsp DIV 2;
  asr := Fonts.Default.maxY;
  dsr := -Fonts.Default.minY;
  selH := lsp; markW := barW - 5;
  eolW := lsp DIV 2;
  ScrollMarker.Fade := FlipSM; ScrollMarker.Draw := FlipSM;
  Texts.OpenWriter(W); Texts.OpenWriter(KW)
END TextFrames.
