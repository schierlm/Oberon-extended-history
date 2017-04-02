MODULE Modules;  (*Link and load on RISC; NW 20.10.2013 / 9.4.2016 / AP 12.12.90 / 3.4.17*)
  IMPORT SYSTEM, Kernel, Files;
  CONST versionkey = 1X; MT = 12; DescSize = 84;

  TYPE Module* = POINTER TO ModDesc;
    Command* = PROCEDURE;
    ModuleName* = ARRAY 32 OF CHAR;

    ModDesc* = RECORD
        name*: ModuleName;
        next*: Module;
        key*, num*, size*, refcnt*: INTEGER;
        data*, code*, imp*, cmd*, ent*, ptr*, pvar*: INTEGER;  (*addresses*)
        selected*, hidden*: BOOLEAN
      END ;

  VAR root*, M: Module;
    MTOrg*, AllocPtr*, res*: INTEGER;
    importing*, imported*: ModuleName;
    limit: INTEGER;

  PROCEDURE ThisFile(name: ARRAY OF CHAR): Files.File;
    VAR i: INTEGER;
      filename: ModuleName;
  BEGIN i := 0;
    WHILE name[i] # 0X DO filename[i] := name[i]; INC(i) END ;
    filename[i] := "."; filename[i+1] := "r"; filename[i+2] := "s"; filename[i+3] := "c"; filename[i+4] := 0X;
    RETURN Files.Old(filename)
  END ThisFile;

  PROCEDURE error(n: INTEGER; name: ARRAY OF CHAR);
  BEGIN res := n; importing := name
  END error;

  PROCEDURE check(s: ARRAY OF CHAR);
    VAR i: INTEGER; ch: CHAR;
  BEGIN ch := s[0]; res := 1; i := 1;
    IF (ch >= "A") & (ch <= "Z") OR (ch >= "a") & (ch <= "z") THEN
      REPEAT ch := s[i]; INC(i)
      UNTIL ~((ch >= "0") & (ch <= "9") OR (ch >= "A") & (ch <= "Z")
        OR (ch >= "a") & (ch <= "z") OR (ch = ".")) OR (i = 32);
      IF (i < 32) & (ch = 0X) THEN res := 0 END
    END
  END check;

  PROCEDURE Load*(name: ARRAY OF CHAR; VAR newmod: Module);
    (*search module in list; if not found, load module.
      res = 0: already present or loaded; res = 2: file not available; res = 3: key conflict;
      res = 4: bad file version; res = 5: corrupted file; res = 7: no space*)
    VAR mod, impmod: Module;
      i, n, key, impkey, mno, nofimps, size: INTEGER;
      p, u, v, w: INTEGER;  (*addresses*)
      ch: CHAR;
      body: Command;
      fixorgP, fixorgD, fixorgT: INTEGER;
      disp, adr, inst, pno, vno, dest, offset: INTEGER;
      name1, impname: ModuleName;
      F: Files.File; R: Files.Rider;
      import: ARRAY 16 OF Module;
  BEGIN mod := root; res := 0; nofimps := 0;
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END ;
    IF mod = NIL THEN (*load*)
      check(name);
      IF res = 0 THEN F := ThisFile(name) ELSE F := NIL END ;
      IF F # NIL THEN
        Files.Set(R, F, 0); Files.ReadString(R, name1); Files.ReadInt(R, key); Files.Read(R, ch);
        Files.ReadInt(R, size); importing := name1;
        IF ch = versionkey THEN
          Files.ReadString(R, impname);   (*imports*)
          WHILE (impname[0] # 0X) & (res = 0) DO
            Files.ReadInt(R, impkey);
            Load(impname, impmod); import[nofimps] := impmod; importing := name1;
            IF res = 0 THEN
              IF impmod.key = impkey THEN INC(impmod.refcnt); INC(nofimps)
              ELSE error(3, name1); imported := impname
              END
            END ;
            Files.ReadString(R, impname)
          END
        ELSE error(2, name1)
        END
      ELSE error(1, name)
      END ;
      IF res = 0 THEN (*search for a hole in the list allocate and link*)
        INC(size, DescSize); mod := root;
        WHILE (mod # NIL) & ~((mod.name[0] = 0X) & (mod.size >= size)) DO mod := mod.next END ;
        IF mod = NIL THEN (*no large enough hole was found*)
          IF AllocPtr + size < limit THEN (*allocate*)
            p := AllocPtr; mod := SYSTEM.VAL(Module, p);
            AllocPtr := (p + size + 100H) DIV 20H * 20H; mod.size := AllocPtr - p; mod.num := root.num + 1;
            mod.next := root; root := mod
          ELSE error(7, name1)
          END
        ELSE (*fill hole*) p := SYSTEM.VAL(INTEGER, mod)
        END
      END ;
      IF res = 0 THEN (*read file*)
        INC(p, DescSize); (*allocate descriptor*)
        mod.name := name; mod.key := key; mod.refcnt := 0; mod.selected := FALSE; mod.hidden := FALSE;
        mod.data := p;  (*data*)
        SYSTEM.PUT(mod.num * 4 + MTOrg, p);  (*module table entry*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p, 4); DEC(n, 4) END ;  (*type descriptors*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO SYSTEM.PUT(p, 0); INC(p, 4); DEC(n, 4) END ;  (*variable space*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.Read(R, ch); SYSTEM.PUT(p, ch); INC(p); DEC(n) END ;   (*strings*)
        mod.code := p;  (*program*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p, 4); DEC(n) END ;  (*program code*)
        mod.imp := p;  (*copy imports*)
        i := 0;
        WHILE i < nofimps DO
          SYSTEM.PUT(p, import[i]); INC(p, 4); INC(i)
        END ;
        mod.cmd := p;  (*commands*) Files.Read(R, ch);
        WHILE ch # 0X DO
          REPEAT SYSTEM.PUT(p, ch); INC(p); Files.Read(R, ch) UNTIL ch = 0X;
          REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 4 = 0;
          Files.ReadInt(R, n); SYSTEM.PUT(p, n); INC(p, 4); Files.Read(R, ch)
        END ;
        REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 4 = 0;
        mod.ent := p;  (*entries*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p, 4); DEC(n) END ;
        mod.ptr := p;  (*pointer references*)
        Files.ReadInt(R, w);
        WHILE w >= 0 DO SYSTEM.PUT(p, mod.data + w); INC(p, 4); Files.ReadInt(R, w) END ;
        SYSTEM.PUT(p, 0); INC(p, 4);
        mod.pvar := p;  (*procedure variable references*)
        Files.ReadInt(R, w);
        WHILE w >= 0 DO SYSTEM.PUT(p, mod.data + w); INC(p, 4); Files.ReadInt(R, w) END ;
        SYSTEM.PUT(p, 0); INC(p, 4);
        Files.ReadInt(R, fixorgP); Files.ReadInt(R, fixorgD); Files.ReadInt(R, fixorgT);
        Files.ReadInt(R, w); body := SYSTEM.VAL(Command, mod.code + w);
        Files.Read(R, ch);
        IF ch # "O" THEN (*corrupted file*)  mod := NIL; error(4, name) END
      END ;
      IF res = 0 THEN (*fixup of BL*)
        adr := mod.code + fixorgP*4;
        WHILE adr # mod.code DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV 100000H MOD 10H;
          pno := inst DIV 1000H MOD 100H;
          disp := inst MOD 1000H;
          SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
          SYSTEM.GET(impmod.ent + pno*4, dest); dest := dest + impmod.code;
          offset := (dest - adr - 4) DIV 4;
          SYSTEM.PUT(adr, (offset MOD 1000000H) + 0F7000000H);
          adr := adr - disp*4
        END ;
        (*fixup of LDR/STR/ADD*)
        adr := mod.code + fixorgD*4;
        WHILE adr # mod.code DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV 100000H MOD 10H;
          disp := inst MOD 1000H;
          IF mno = 0 THEN (*global*)
            SYSTEM.PUT(adr, (inst DIV 1000000H * 10H + MT) * 100000H + mod.num * 4)
          ELSE (*import*)
            SYSTEM.GET(mod.imp + (mno-1)*4, impmod); v := impmod.num;
            SYSTEM.PUT(adr, (inst DIV 1000000H * 10H + MT) * 100000H + v*4);
            SYSTEM.GET(adr+4, inst); vno := inst MOD 100H;
            SYSTEM.GET(impmod.ent + vno*4, offset);
            IF ODD(inst DIV 100H) THEN offset := offset + impmod.code - impmod.data END ;
            SYSTEM.PUT(adr+4, inst DIV 10000H * 10000H + offset)
          END ;
          adr := adr - disp*4
        END ;
        (*fixup of type descriptors*)
        adr := mod.data + fixorgT*4;
        WHILE adr # mod.data DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV 1000000H MOD 10H;
          vno := inst DIV 1000H MOD 1000H;
          disp := inst MOD 1000H;
          IF mno = 0 THEN (*global*) inst := mod.data + vno
          ELSE (*import*)
            SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
            SYSTEM.GET(impmod.ent + vno*4, offset);
            inst := impmod.data + offset
          END ;
          SYSTEM.PUT(adr, inst); adr := adr - disp*4
        END ;
        body   (*initialize module*)
      ELSIF res = 3 THEN importing := name;
        WHILE nofimps > 0 DO DEC(nofimps); DEC(import[nofimps].refcnt) END
      END
    END ;
    newmod :=  mod
  END Load;

  PROCEDURE ThisCommand*(mod: Module; name: ARRAY OF CHAR): Command;
    VAR k, adr, w: INTEGER; ch: CHAR;
      s: ARRAY 32 OF CHAR;
  BEGIN res := 5; w := 0;
    IF mod # NIL THEN
      adr := mod.cmd; SYSTEM.GET(adr, ch);
      WHILE (ch # 0X) & (res # 0) DO k := 0; (*read command name*)
        REPEAT s[k] := ch; INC(k); INC(adr); SYSTEM.GET(adr, ch) UNTIL ch = 0X;
        s[k] := 0X;
        REPEAT INC(adr) UNTIL adr MOD 4 = 0;
        SYSTEM.GET(adr, k); INC(adr, 4);
        IF s = name THEN res := 0; w := mod.code + k ELSE SYSTEM.GET(adr, ch) END
      END
    END
    RETURN SYSTEM.VAL(Command, w)
  END ThisCommand;

  PROCEDURE Select*(mod: Module; on: BOOLEAN);
  BEGIN mod.selected := on
  END Select;

  PROCEDURE chkmod(x: LONGINT; VAR continue: BOOLEAN): INTEGER; (*check whether x references module M*)
    VAR i: INTEGER;
  BEGIN IF (M.name[0] # 0X) & (M.data <= x) & (x < M.imp) THEN continue := FALSE; i := 1 ELSE i := 0 END ;
    RETURN i
  END chkmod;

  PROCEDURE chksel(x: LONGINT; VAR continue: BOOLEAN): INTEGER; (*check whether x references selected modules*)
    VAR mod: Module; i: INTEGER;
  BEGIN mod := root; i := 0;
    WHILE (mod # NIL) & (i = 0) DO
      IF mod.selected & (mod.name[0] # 0X) & (mod.data <= x) & (x < mod.imp) THEN continue := FALSE; i := 1 END ;
      mod := mod.next
    END ;
    RETURN i
  END chksel;

  PROCEDURE Check*(mod: Module; VAR res: INTEGER); (*check references to mod # NIL or to selected modules*)
    VAR m: Module; pref, pvadr, r: LONGINT; r0, r1: INTEGER; continue: BOOLEAN;
  BEGIN m := root;
    WHILE m # NIL DO (*mark dynamic records reachable by all other loaded modules*)
      IF (m.name[0] # 0X) & ((mod = NIL) & (~m.selected) OR (mod # NIL) & (m # mod)) THEN Kernel.Mark(m.ptr) END ;
      m := m.next
    END ;
    IF mod # NIL THEN M := mod; Kernel.Scan(chkmod, chkmod, r0, r1) ELSE Kernel.Scan(chksel, chksel, r0, r1) END ;
    IF r0 > 0 THEN res := 1 ELSIF r1 > 0 THEN res := 2
    ELSE res := 0; m := root; continue := TRUE;
      WHILE continue & (m # NIL) DO
        IF (m.name[0] # 0X) & ((mod = NIL) & (~m.selected) OR (mod # NIL) & (m # mod)) THEN
          pref := m.pvar; SYSTEM.GET(pref, pvadr);
          WHILE continue & (pvadr # 0) DO SYSTEM.GET(pvadr, r); (*static procedure references*)
            IF (mod # NIL) & (chkmod(r, continue) > 0) OR (mod = NIL) & (chksel(r, continue) > 0) THEN res := 3 END ;
            INC(pref, 4); SYSTEM.GET(pref, pvadr)
          END
        END ;
        m := m.next
      END
    END
  END Check;

  PROCEDURE Unload(mod: Module); (*from memory*)
    VAR imp: Module; p, q: INTEGER;
  BEGIN mod.name[0] := 0X; mod.hidden := FALSE; p := mod.imp; q := mod.cmd;
    WHILE p < q DO SYSTEM.GET(p, imp); DEC(imp.refcnt); INC(p, 4) END
  END Unload;

  PROCEDURE Hide(mod: Module); (*from module list*)
  BEGIN mod.name[0] := "*"; mod.hidden := TRUE
  END Hide;

  PROCEDURE FreeSel(VAR res: INTEGER);
    VAR m, mod, imp: Module; p, q, impcnt: INTEGER; hasSel, hasUnsel: BOOLEAN;
  BEGIN mod := root; res := 0; hasSel := FALSE; hasUnsel := FALSE;
    WHILE (mod # NIL) & (res = 0) DO
      IF mod.name[0] # 0X THEN
        IF mod.selected THEN hasSel := TRUE;
          IF mod.refcnt > 0 THEN m := root; impcnt := 0;
            WHILE m # NIL DO (*count clients inside selected modules*)
              IF m.selected & (m.name[0] # 0X) THEN p := m.imp; q := m.cmd;
                WHILE p < q DO SYSTEM.GET(p, imp); INC(p, 4);
                  IF imp = mod THEN INC(impcnt) END
                END
              END ;
              m := m.next
            END ;
            IF mod.refcnt # impcnt THEN res := 4 END (*outside clients exist*)
          END
        ELSE hasUnsel := TRUE
        END
      END ;
      mod := mod.next
    END ;
    IF hasSel & (res = 0) THEN mod := root;
      IF hasUnsel THEN Check(NIL, res) END ;
      WHILE mod # NIL DO
        IF mod.selected & (mod.name[0] # 0X) THEN
          IF res = 0 THEN mod.selected := FALSE; Unload(mod) ELSE Hide(mod) END
        END ;
        mod := mod.next
      END
    END
  END FreeSel;

  PROCEDURE Free*(name: ARRAY OF CHAR);
    (*unload module(s) if no references exist in remaining modules; otherwise remove only from module list.
      res = 0: no clients or references; res = 1: types in use in dynamic objects; res = 2: procedures
      in use in dynamic objects; res = 3: procedures in use in static objects; res = 4: clients exist*)
    VAR mod: Module;
  BEGIN
    IF name = "*" THEN FreeSel(res)
    ELSE mod := root; res := 0;
      WHILE (mod # NIL) & (mod.name # name) DO mod := mod.next END ;
      IF (mod # NIL) & (mod.name[0] # 0X) THEN
        IF mod.refcnt = 0 THEN Check(mod, res);
          IF res = 0 THEN Unload(mod) ELSE Hide(mod) END
        ELSE res := 4
        END
      END
    END
  END Free;

  PROCEDURE FirstSel(q: INTEGER); (*first selection of k elements among n hidden modules*)
    VAR mod: Module; p: INTEGER;
  BEGIN (*q = n - k*) mod := root; p := 0;
    WHILE mod # NIL DO
      IF mod.hidden & (mod.name[0] # 0X) THEN INC(p); mod.selected := p > q END ;
      mod := mod.next
    END
  END FirstSel;

  PROCEDURE NextSel(VAR continue: BOOLEAN); (*next selection of k elements among n hidden modules*)
    VAR mod, m: Module; p, q: INTEGER; done: BOOLEAN;
  BEGIN mod := root; done := FALSE;
    WHILE ~done & (mod # NIL) DO
      IF mod.hidden & (mod.name[0] # 0X) THEN
        IF mod.selected THEN mod := mod.next ELSE done := TRUE END
      ELSE mod := mod.next
      END
    END ;
    q := 0; done := FALSE;
    WHILE ~done & (mod # NIL) DO
      IF mod.hidden & (mod.name[0] # 0X) THEN
        IF ~mod.selected THEN INC(q); mod := mod.next ELSE done := TRUE END
      ELSE mod := mod.next
      END
    END ;
    IF mod = NIL THEN continue := FALSE
    ELSE mod.selected := FALSE; m := root; p := 0;
      WHILE (m # NIL) & (m # mod) DO
        IF m.hidden & (m.name[0] # 0X) THEN INC(p); m.selected := p >= q END ;
        m := m.next
      END
    END
  END NextSel;

  PROCEDURE Collect*; (*no longer referenced hidden modules*)
    VAR mod: Module; n, k, res: INTEGER; continue: BOOLEAN;
  BEGIN mod := root; n := 0; k := 0;
    WHILE mod # NIL DO
      IF mod.hidden & (mod.name[0] # 0X) THEN INC(n) END ;
      mod := mod.next
    END ;
    WHILE k < n DO INC(k);
      FirstSel(n - k); continue := TRUE;
      WHILE continue DO Check(NIL, res);
        IF res = 0 THEN k := 0; continue := FALSE; mod := root;
          WHILE mod # NIL DO
            IF mod.selected & (mod.name[0] # 0X) THEN mod.selected := FALSE; Unload(mod); DEC(n) END ;
            mod := mod.next
          END
        ELSE NextSel(continue)
        END
      END
    END
  END Collect;

  PROCEDURE Init*;
  BEGIN Files.Init; MTOrg := SYSTEM.REG(MT);
    SYSTEM.GET(16, AllocPtr); SYSTEM.GET(20, root); SYSTEM.GET(24, limit); DEC(limit, 8000H)
  END Init;

BEGIN Init; Load("Oberon", M);
  LED(res); REPEAT UNTIL FALSE  (*only if load fails*)
END Modules.
