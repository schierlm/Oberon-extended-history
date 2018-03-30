MODULE Modules;  (*Link and load on RISC; NW 20.10.2013 / 9.4.2016 / AP 22.12.17*)
  IMPORT SYSTEM, Kernel, Files;
  CONST versionkey = 1X; MT = 12; DescSize = 88;

  TYPE Module* = POINTER TO ModDesc;
    Command* = PROCEDURE;
    ModuleName* = ARRAY 32 OF CHAR;

    ModDesc* = RECORD
      name*: ModuleName;
      next*: Module;
      key*, num*, size*, refcnt*: INTEGER;
      data*, code*, imp*, cmd*, ent*, ptr*, pvar*: INTEGER;  (*addresses*)
      selected, hidden, marked, unused: BOOLEAN;
      count: INTEGER
    END ;

  VAR root*, M: Module;
    MTOrg*, AllocPtr*, res*: INTEGER;
    importing*, imported*: ModuleName;
    limit, NofSelected, NofHidden: INTEGER;

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
      res = 0: already present or loaded; res = 1: file not available; res = 2: bad file version;
      res = 3: key conflict; res = 4: corrupted file; res = 7: insufficient space*)
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
            Load(impname, impmod); import[nofimps] := impmod;
            IF res = 0 THEN importing := name1;
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

  (*--------------------------- selections ---------------------------*)

  PROCEDURE Mark(mod: Module; clients, imports: BOOLEAN);
    VAR imp, m: Module; p, q: INTEGER;
  BEGIN (*~mod.marked & mod.name[0] # 0X*) mod.marked := TRUE;
    IF clients THEN m := root;
      WHILE m # NIL DO
        IF (m.name[0] # 0X) & (m # mod) & ~m.marked THEN p := m.imp; q := m.cmd;
          WHILE p < q DO SYSTEM.GET(p, imp);
            IF imp = mod THEN (*m imports mod*) Mark(m, clients, imports); p := q ELSE INC(p, 4) END
          END
        END ;
        m := m.next
      END
    END ;
    IF imports THEN p := mod.imp; q := mod.cmd;
      WHILE p < q DO SYSTEM.GET(p, imp); INC(p, 4);
        IF (imp.name[0] # 0X) & ~imp.marked THEN Mark(imp, clients, imports) END
      END
    END
  END Mark;

  PROCEDURE Select*(name: ARRAY OF CHAR; on, this, clients, imports: BOOLEAN); (*module, clients, imports*)
    VAR mod, m: Module;
  BEGIN mod := root; m := NIL;
    WHILE mod # NIL DO mod.marked := FALSE;
      IF (mod.name[0] # 0X) & (mod.name = name) THEN m := mod END ;
      mod := mod.next
    END ;
    IF m # NIL THEN Mark(m, clients, imports); mod := root;
      WHILE mod # NIL DO
        IF mod.marked & ((mod # m) OR this) THEN
          IF on THEN
            IF ~mod.selected THEN mod.selected := TRUE; INC(NofSelected) END
          ELSIF mod.selected THEN mod.selected := FALSE; DEC(NofSelected)
          END
        END ;
        mod := mod.next
      END
    END
  END Select;

  PROCEDURE SelectAll*(on: BOOLEAN); (*modules*)
    VAR mod: Module;
  BEGIN mod := root; NofSelected := 0;
    WHILE mod # NIL DO
      IF on & (mod.name[0] # 0X) THEN mod.selected := TRUE; INC(NofSelected) ELSE mod.selected := FALSE END ;
      mod := mod.next
    END
  END SelectAll;

  PROCEDURE Selected*(mod: Module): BOOLEAN;
  BEGIN RETURN mod.selected
  END Selected;

  PROCEDURE ShrinkSelection*; (*until no outside clients exist*)
    VAR mod, imp: Module; p, q: INTEGER; continue: BOOLEAN;
  BEGIN mod := root; continue := TRUE;
    WHILE mod # NIL DO
      IF (mod.name[0] # 0X) & mod.selected THEN mod.marked := TRUE; mod.count := mod.refcnt
      ELSE mod.marked := FALSE
      END ;
      mod := mod.next
    END ;
    WHILE continue DO mod := root; continue := FALSE;
      WHILE mod # NIL DO
        IF mod.marked & (mod.count = 0) THEN (*no client*)
          mod.marked := FALSE; continue := TRUE; p := mod.imp; q := mod.cmd;
          WHILE p < q DO SYSTEM.GET(p, imp); INC(p, 4);
            IF imp.marked THEN DEC(imp.count) END
          END
        END ;
        mod := mod.next
      END
    END ;
    mod := root;
    WHILE mod # NIL DO
      IF mod.selected & mod.marked THEN mod.selected := FALSE; DEC(NofSelected) END ;
      mod := mod.next
    END
  END ShrinkSelection;

  (*--------------------------- reference checking ---------------------------*)

  PROCEDURE ChkSel(x: LONGINT; VAR continue: BOOLEAN): INTEGER; (*check whether x references selected modules*)
    VAR mod: Module; i: INTEGER;
  BEGIN mod := root; i := 0;
    WHILE (mod # NIL) & (i = 0) DO (*stop when the first reference to any of the selected modules is found*)
      IF (mod.name[0] # 0X) & mod.selected & (mod.data <= x) & (x < mod.imp) THEN continue := FALSE; i := 1 END ;
      mod := mod.next
    END ;
    RETURN i
  END ChkSel;

  PROCEDURE Check*(VAR res: INTEGER);
    (*check whether outside clients or references to selected modules exist.
      res = 0: no clients or references; res = 1: clients exist; res = 2: types in use in dynamic objects;
      res = 3: procedures in use in dynamic objects; res = 4: procedures in use in static objects*)
    VAR mod, imp, m: Module; continue: BOOLEAN;
      pref, pvadr, r: LONGINT; p, q, impcnt, resType, resProc: INTEGER;
  BEGIN res := 0; mod := root;
    WHILE (mod # NIL) & (res = 0) DO
      IF (mod.name[0] # 0X) & mod.selected & (mod.refcnt > 0) THEN m := root; impcnt := 0;
        WHILE m # NIL DO (*count clients within selected modules*)
          IF (m.name[0] # 0X) & (m # mod) & m.selected THEN p := m.imp; q := m.cmd;
            WHILE p < q DO SYSTEM.GET(p, imp);
              IF imp = mod THEN (*m imports mod*) INC(impcnt); p := q ELSE INC(p, 4) END
            END
          END ;
          m := m.next
        END ;
        IF mod.refcnt # impcnt THEN res := 1 END (*outside clients exist*)
      END ;
      mod := mod.next
    END ;
    IF res = 0 THEN mod := root;
      WHILE mod # NIL DO (*mark dynamic records reachable by all other modules*)
        IF (mod.name[0] # 0X) & ~mod.selected THEN Kernel.Mark(mod.ptr) END ;
        mod := mod.next
      END ;
      Kernel.Scan(ChkSel, ChkSel, resType, resProc); (*check dynamic type and procedure references*)
      IF resType > 0 THEN res := 2 ELSIF resProc > 0 THEN res := 3
      ELSE mod := root; continue := TRUE;
        WHILE continue & (mod # NIL) DO (*check static procedure references*)
          IF (mod.name[0] # 0X) & ~mod.selected THEN
            pref := mod.pvar; SYSTEM.GET(pref, pvadr);
            WHILE continue & (pvadr # 0) DO SYSTEM.GET(pvadr, r);
              IF ChkSel(r, continue) > 0 THEN res := 4 END ;
              INC(pref, 4); SYSTEM.GET(pref, pvadr)
            END
          END ;
          mod := mod.next
        END
      END
    END
  END Check;

  (*--------------------------- unloading ---------------------------*)

  PROCEDURE Unload(mod: Module); (*module and selected imports from memory*)
    VAR imp: Module; p, q: INTEGER;
  BEGIN (*mod.refcnt = 0*) mod.name[0] := 0X; p := mod.imp; q := mod.cmd;
    WHILE p < q DO SYSTEM.GET(p, imp); DEC(imp.refcnt); INC(p, 4);
      IF (imp.name[0] # 0X) & imp.selected & (imp.refcnt = 0) THEN Unload(imp) END
    END ;
    IF mod.hidden THEN mod.hidden := FALSE; DEC(NofHidden) END ;
    IF mod.selected THEN mod.selected := FALSE; DEC(NofSelected) END
  END Unload;

  PROCEDURE Hide(mod: Module); (*module from module list*)
    VAR i: INTEGER;
  BEGIN (*~mod.hidden*) i := 0;
    WHILE mod.name[i] # 0X DO INC(i) END ;
    IF i = LEN(ModuleName) - 1 THEN DEC(i) ELSE mod.name[i+1] := 0X END ;
    WHILE i > 0 DO DEC(i); mod.name[i+1] := mod.name[i] END ;
    mod.name[0] := "*"; mod.hidden := TRUE; INC(NofHidden)
  END Hide;

  PROCEDURE FreeSelection*(hide: BOOLEAN); (*unload or hide selected modules*)
    VAR mod: Module;
  BEGIN res := 0;
    IF NofSelected > 0 THEN Check(res);
      IF res = 0 THEN (*unload*) mod := root;
        WHILE mod # NIL DO
          IF (mod.name[0] # 0X) & mod.selected & (mod.refcnt = 0) THEN Unload(mod) END ;
          mod := mod.next
        END
      ELSIF (res > 1) & hide THEN (*hide*) mod := root;
        WHILE mod # NIL DO
          IF (mod.name[0] # 0X) & mod.selected & ~mod.hidden THEN Hide(mod) END ;
          mod := mod.next
        END
      END
    END
  END FreeSelection;

  PROCEDURE Free*(name: ARRAY OF CHAR; hide: BOOLEAN); (*unload or hide specified module*)
    VAR mod: Module;
  BEGIN mod := root; NofSelected := 0;
    WHILE mod # NIL DO
      IF (mod.name[0] # 0X) & (mod.name = name) THEN mod.selected := TRUE; INC(NofSelected)
      ELSE mod.selected := FALSE
      END ;
      mod := mod.next
    END ;
    FreeSelection(hide)
  END Free;

  (*--------------------------- garbage collection ---------------------------*)

  PROCEDURE Collect*; (*no longer referenced hidden modules*)
    VAR mod, m, M: Module; continue: BOOLEAN;
      p, q, k, res: INTEGER;
  BEGIN
    IF NofHidden > 0 THEN k := 0;
      IF NofSelected > 0 THEN (*save selection*) mod := root;
        WHILE mod # NIL DO mod.marked := mod.selected; mod.selected := FALSE; mod := mod.next END
      END ;
      WHILE k < NofHidden DO INC(k);
        mod := root; p := 0; continue := TRUE;
        WHILE mod # NIL DO (*set first selection of k modules among hidden modules*)
          IF (mod.name[0] # 0X) & mod.hidden THEN mod.selected := p < k; INC(p) END ;
          mod := mod.next
        END ;
        WHILE continue DO Check(res);
          IF res = 0 THEN (*unload current selection and start over*)
            mod := root; k := 0; continue := FALSE;
            WHILE mod # NIL DO
              IF (mod.name[0] # 0X) & mod.hidden & mod.selected & (mod.refcnt = 0) THEN Unload(mod) END ;
              mod := mod.next
            END
          ELSIF k < NofHidden THEN (*determine whether there is a next selection of k modules*)
            mod := root; q := 0; M := NIL;
            WHILE mod # NIL DO
              IF (mod.name[0] # 0X) & mod.hidden THEN
                IF mod.selected THEN m := mod; INC(q) (*number of selected modules at the end of the list*)
                ELSIF q > 0 THEN q := 0; M := m (*last selected module before the last unselected group*)
                END
              END ;
              mod := mod.next
            END ;
            IF M # NIL THEN (*if there is a next selection of k modules*)
              mod := M.next; p := 0; M.selected := FALSE;
              WHILE mod # NIL DO (*set next selection of k modules*)
                IF (mod.name[0] # 0X) & mod.hidden THEN mod.selected := p <= q; INC(p) END ;
                mod := mod.next
              END
            ELSE (*otherwise continue with selections of k+1 modules*) continue := FALSE
            END
          ELSE (*done*) continue := FALSE
          END
        END
      END ;
      IF NofSelected > 0 THEN (*restore selection without re-selecting unloaded hidden modules*)
        mod := root; NofSelected := 0;
        WHILE mod # NIL DO
          IF mod.marked & (mod.name[0] # 0X) THEN mod.selected := TRUE; INC(NofSelected)
          ELSE mod.selected := FALSE
          END ;
          mod := mod.next
        END
      ELSE (*cleanup*) mod := root;
        WHILE mod # NIL DO
          IF mod.hidden THEN mod.selected := FALSE END ;
          mod := mod.next
        END
      END
    END ;
    mod := root;
    WHILE (mod # NIL) & (mod.name[0] = 0X) DO mod := mod.next END ;
    IF mod # root THEN (*return free blocks*) AllocPtr := SYSTEM.VAL(LONGINT, mod) + mod.size; root := mod END
  END Collect;

  PROCEDURE Init*;
  BEGIN Files.Init; MTOrg := SYSTEM.REG(MT);
    SYSTEM.GET(16, AllocPtr); SYSTEM.GET(20, root); SYSTEM.GET(24, limit); DEC(limit, 8000H);
    NofHidden := 0; SelectAll(FALSE)
  END Init;

BEGIN Init; Load("Oberon", M);
  LED(res); REPEAT UNTIL FALSE  (*only if load fails*)
END Modules.
