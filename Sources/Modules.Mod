MODULE Modules;  (*Link and load on RISC; NW 20.10.2013 / 9.4.2016 / AP 12.12.18 Experimental Oberon*)
  IMPORT SYSTEM, Kernel, Files;
  CONST versionkey = 1X; MT = 12; DescSize = 84; context = "EO";

  TYPE Module* = POINTER TO ModDesc;
    Command* = PROCEDURE;
    ModuleName* = ARRAY 32 OF CHAR;

    ModDesc* = RECORD
      name*: ModuleName;
      next*: Module;
      key*, num*, size*, refcnt*: INTEGER;
      data*, code*, imp*, cmd*, ent*, ptr*, pvr*: INTEGER;  (*addresses*)
      selected, marked, hidden, sel: BOOLEAN
    END ;

    RefHandler* = PROCEDURE(x: LONGINT; s: ARRAY OF CHAR; VAR continue: BOOLEAN): INTEGER;
    ModHandler* = PROCEDURE(client, import, prev: Module; VAR continue: BOOLEAN): INTEGER;

  VAR root*, M: Module;
    MTOrg*, AllocPtr*, res*: INTEGER;
    importing*, imported*: ModuleName;
    limit, NofSelected*, NofHidden*: INTEGER;

  PROCEDURE ThisFile(name, context: ARRAY OF CHAR): Files.File;
    VAR i, j: INTEGER;
      filename: ModuleName;
  BEGIN i := 0; j := 0;
    WHILE context[i] # 0X DO filename[i] := context[i]; INC(i) END ;
    IF i > 0 THEN  filename[i] := "."; INC(i) END ;
    WHILE name[j] # 0X DO filename[i] := name[j]; INC(i); INC(j) END ;
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
      i, n, key, impkey, mno, nofimps, size, tdx: INTEGER;
      p, u, v, w: INTEGER;  (*addresses*)
      ch: CHAR;
      body: Command;
      fixorgP, fixorgD, fixorgT, fixorgM: INTEGER;
      disp, adr, inst, pno, vno, dest, offset: INTEGER;
      name1, impname: ModuleName;
      F: Files.File; R: Files.Rider;
      import: ARRAY 16 OF Module;
  BEGIN mod := root; res := 0; nofimps := 0;
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END ;
    IF mod = NIL THEN (*load*)
      check(name);
      IF res # 0 THEN F := NIL ELSE F := ThisFile(name, context);
        IF F = NIL THEN F := ThisFile(name, "") END
      END ;
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
            AllocPtr := (p + size + 3) DIV 4 * 4; mod.size := AllocPtr - p;
            IF root = NIL THEN mod.num := 1 ELSE mod.num := root.num + 1 END ;
            mod.next := root; root := mod
          ELSE error(7, name1)
          END
        ELSE (*fill hole*) p := SYSTEM.VAL(INTEGER, mod)
        END
      END ;
      IF res = 0 THEN (*read file*)
        INC(p, DescSize); (*allocate descriptor*)
        mod.name := name; mod.key := key; mod.refcnt := 0;
        mod.selected := FALSE; mod.marked := FALSE; mod.hidden := FALSE; mod.sel := FALSE;
        mod.data := p;  (*data*)
        SYSTEM.PUT(mod.num * 4 + MTOrg, p);  (*module table entry*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO SYSTEM.PUT(p, 0); INC(p, 4); DEC(n, 4) END ;  (*variable space*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.Read(R, ch); SYSTEM.PUT(p, ch); INC(p); DEC(n) END ;   (*strings*)
        tdx := p;  (*type descriptors*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p, 4); DEC(n, 4) END ;
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
        mod.pvr := p;  (*procedure variable references*)
        Files.ReadInt(R, w);
        WHILE w >= 0 DO SYSTEM.PUT(p, mod.data + w); INC(p, 4); Files.ReadInt(R, w) END ;
        SYSTEM.PUT(p, 0); INC(p, 4);
        Files.ReadInt(R, fixorgP); Files.ReadInt(R, fixorgD);
        Files.ReadInt(R, fixorgT); Files.ReadInt(R, fixorgM);
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
        adr := tdx + fixorgT*4;
        WHILE adr # tdx DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV 1000000H MOD 10H;
          vno := inst DIV 1000H MOD 1000H;
          disp := inst MOD 1000H;
          IF mno = 0 THEN (*global*) inst := tdx + vno
          ELSE (*import*)
            SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
            SYSTEM.GET(impmod.ent + vno*4, offset);
            inst := impmod.data + offset
          END ;
          SYSTEM.PUT(adr, inst); adr := adr - disp*4
        END ;
        (*fixup of method tables*)
        adr := tdx + fixorgM*4;
        WHILE adr # tdx DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV 10000000H;
          vno := inst DIV 4000H MOD 4000H;
          disp := inst MOD 4000H;
          IF mno = 0 THEN (*global*) inst := mod.code + vno
          ELSE (*import*)
            SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
            SYSTEM.GET(impmod.ent + vno*4, offset);
            inst := impmod.code + offset
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

  PROCEDURE select(mod: Module; clients, imports: BOOLEAN);
    VAR imp, m: Module; p, q: INTEGER;
  BEGIN (*~mod.sel & mod.name[0] # 0X*) mod.sel := TRUE;
    IF clients THEN m := root;
      WHILE m # NIL DO
        IF (m.name[0] # 0X) & (m # mod) & ~m.sel THEN p := m.imp; q := m.cmd;
          WHILE p < q DO SYSTEM.GET(p, imp);
            IF imp = mod THEN select(m, clients, imports); p := q ELSE INC(p, 4) END
          END
        END ;
        m := m.next
      END
    END ;
    IF imports THEN p := mod.imp; q := mod.cmd;
      WHILE p < q DO SYSTEM.GET(p, imp); INC(p, 4);
        IF (imp.name[0] # 0X) & ~imp.sel THEN select(imp, clients, imports) END
      END
    END
  END select;

  PROCEDURE Select*(name: ARRAY OF CHAR; on, this, clients, imports: BOOLEAN);
    VAR mod, m: Module;
  BEGIN mod := root; m := NIL;
    WHILE mod # NIL DO mod.sel := FALSE;
      IF (mod.name[0] # 0X) & (mod.name = name) THEN m := mod END ;
      mod := mod.next
    END ;
    IF m # NIL THEN select(m, clients, imports); mod := root;
      WHILE mod # NIL DO
        IF mod.sel & ((mod # m) OR this) THEN
          IF on THEN
            IF ~mod.selected THEN mod.selected := TRUE; INC(NofSelected) END
          ELSIF mod.selected THEN mod.selected := FALSE; DEC(NofSelected)
          END
        END ;
        mod := mod.next
      END
    END
  END Select;

  PROCEDURE Selected*(mod: Module): BOOLEAN;
  BEGIN RETURN mod.selected
  END Selected;

  PROCEDURE Deselect*; (*all modules*)
    VAR mod: Module;
  BEGIN mod := root; NofSelected := 0;
    WHILE mod # NIL DO mod.selected := FALSE; mod := mod.next END
  END Deselect;

  (*--------------------------- reference checking ---------------------------*)

  PROCEDURE FindClients*(proc: ModHandler; VAR res: INTEGER);
    VAR mod, imp, prev, m: Module; p, q: INTEGER; continue: BOOLEAN;
  BEGIN res := 0; mod := root; continue := proc # NIL; prev := NIL;
    WHILE continue & (mod # NIL) DO
      IF (mod.name[0] # 0X) & mod.selected & (mod.refcnt > 0) THEN m := root;
        WHILE continue & (m # NIL) DO
          IF (m.name[0] # 0X) & ~m.selected THEN p := m.imp; q := m.cmd;
            WHILE p < q DO SYSTEM.GET(p, imp);
              IF imp = mod THEN INC(res, proc(m, mod, prev, continue)); prev := mod; p := q ELSE INC(p, 4) END
            END
          END ;
          m := m.next
        END
      END ;
      mod := mod.next
    END
  END FindClients;

  PROCEDURE FindDynamicRefs*(type, proc: RefHandler; VAR resType, resProc: INTEGER; all: BOOLEAN);
    VAR mod: Module;
  BEGIN mod := root;
    WHILE mod # NIL DO
      IF (mod.name[0] # 0X) & ~mod.selected THEN Kernel.Mark(mod.ptr);
        IF ~all THEN Kernel.Scan(type, proc, mod.name, resType, resProc) END
      END ;
      mod := mod.next
    END ;
    IF all THEN Kernel.Scan(type, proc, "", resType, resProc) END
  END FindDynamicRefs;

  PROCEDURE FindStaticRefs*(proc: RefHandler; VAR res: INTEGER);
    VAR mod: Module; pref, pvadr, r: LONGINT; continue: BOOLEAN;
  BEGIN res := 0; mod := root; continue := proc # NIL;
    WHILE continue & (mod # NIL) DO
      IF (mod.name[0] # 0X) & ~mod.selected THEN
        pref := mod.pvr; SYSTEM.GET(pref, pvadr);
        WHILE continue & (pvadr # 0) DO SYSTEM.GET(pvadr, r);
          INC(res, proc(r, mod.name, continue));
          INC(pref, 4); SYSTEM.GET(pref, pvadr)
        END
      END ;
      mod := mod.next
    END
  END FindStaticRefs;

  PROCEDURE HandleClient(client, mod, prev: Module; VAR continue: BOOLEAN): INTEGER;
  BEGIN continue := FALSE; RETURN 1 (*stop when the first client is found*)
  END HandleClient;

  PROCEDURE HandleRef(x: LONGINT; s: ARRAY OF CHAR; VAR continue: BOOLEAN): INTEGER;
    VAR mod: Module; i: INTEGER;
  BEGIN mod := root; i := 0;
    WHILE continue & (mod # NIL) DO (*stop when the first reference is found*)
      IF (mod.name[0] # 0X) & mod.selected & (mod.data <= x) & (x < mod.imp) THEN INC(i); continue := FALSE END ;
      mod := mod.next
    END ;
    RETURN i
  END HandleRef;

  PROCEDURE Check*(VAR res: INTEGER);
    (*check whether external clients or type or procedure references to selected modules exist.
      res = 0: no clients or references; res = 1: clients exist; res = 2: types in use in dynamic objects;
      res = 3: procedures in use in dynamic objects; res = 4: procedures in use in static objects*)
    VAR resType, resProc: INTEGER;
  BEGIN FindClients(HandleClient, res);
    IF res > 0 THEN res := 1
    ELSE FindDynamicRefs(HandleRef, HandleRef, resType, resProc, TRUE);
      IF resType > 0 THEN res := 2
      ELSIF resProc > 0 THEN res := 3
      ELSE FindStaticRefs(HandleRef, res);
        IF res > 0 THEN res := 4 END
      END
    END
  END Check;

  (*--------------------------- unloading ---------------------------*)

  PROCEDURE Unload(mod: Module); (*module and selected imports from memory*)
    VAR imp: Module; p, q: INTEGER;
  BEGIN (*mod.refcnt = 0 & mod.name[0] # 0X*)
    mod.name[0] := 0X; p := mod.imp; q := mod.cmd;
    WHILE p < q DO SYSTEM.GET(p, imp); DEC(imp.refcnt); INC(p, 4);
      IF (imp.name[0] # 0X) & imp.selected & (imp.refcnt = 0) THEN Unload(imp) END
    END ;
    IF mod.hidden THEN mod.hidden := FALSE; DEC(NofHidden) END ;
    IF mod.selected THEN mod.selected := FALSE; DEC(NofSelected) END ;
    IF mod = root THEN (*increase size of available module space*)
      p := mod.size; mod := mod.next;
      WHILE (mod # NIL) & (mod.name[0] = 0X) DO INC(p, mod.size); mod := mod.next END ;
      AllocPtr := AllocPtr - p; root := mod
    END
  END Unload;

  PROCEDURE Hide(mod: Module); (*module from module list*)
    VAR i: INTEGER;
  BEGIN (*~mod.hidden & mod.name[0] # 0X*) i := 0;
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
    VAR mod, m, m1: Module; continue: BOOLEAN;
      p, q, k, res: INTEGER;
  BEGIN
    IF NofHidden > 0 THEN k := 0;
      IF NofSelected > 0 THEN (*save selection*) mod := root;
        WHILE mod # NIL DO mod.sel := mod.selected; mod.selected := FALSE; mod := mod.next END
      END ;
      WHILE k < NofHidden DO INC(k);
        mod := root; p := 0; continue := TRUE;
        WHILE mod # NIL DO (*set first selection of k modules among hidden modules*)
          IF (mod.name[0] # 0X) & mod.hidden THEN mod.selected := p < k; INC(p) END ;
          mod := mod.next
        END ;
        WHILE continue DO Check(res);
          IF res = 0 THEN (*unload current selection of k modules and start over*)
            mod := root; k := 0; continue := FALSE;
            WHILE mod # NIL DO
              IF (mod.name[0] # 0X) & mod.hidden & mod.selected & (mod.refcnt = 0) THEN Unload(mod) END ;
              mod := mod.next
            END
          ELSIF k < NofHidden THEN
            mod := root; q := 0; m1 := NIL;
            WHILE mod # NIL DO (*determine whether there is a next selection of k modules*)
              IF (mod.name[0] # 0X) & mod.hidden THEN
                IF mod.selected THEN m := mod; INC(q) (*number of selected modules at end of list*)
                ELSIF q > 0 THEN q := 0; m1 := m (*last selected module before last unselected group*)
                END
              END ;
              mod := mod.next
            END ;
            IF m1 # NIL THEN (*if there is a next selection of k modules*)
              mod := m1.next; p := 0; m1.selected := FALSE;
              WHILE mod # NIL DO (*set next selection of k modules*)
                IF (mod.name[0] # 0X) & mod.hidden THEN mod.selected := p <= q; INC(p) END ;
                mod := mod.next
              END
            ELSE (*otherwise continue with selections of k+1 modules*) continue := FALSE
            END
          ELSE (*all combinations of k modules chosen from n hidden modules checked*) continue := FALSE
          END
        END
      END ;
      IF NofSelected > 0 THEN (*restore selection without re-selecting the just unloaded hidden modules*)
        mod := root; NofSelected := 0;
        WHILE mod # NIL DO
          IF mod.sel & (mod.name[0] # 0X) THEN mod.selected := TRUE; INC(NofSelected)
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
    END
  END Collect;

  PROCEDURE Init*;
  BEGIN Files.Init; MTOrg := SYSTEM.REG(MT);
    SYSTEM.GET(16, AllocPtr); SYSTEM.GET(20, root); SYSTEM.GET(24, limit); DEC(limit, 8000H);
    NofHidden := 0; Deselect
  END Init;

BEGIN Init; Load("Oberon", M);
  LED(res); REPEAT UNTIL FALSE  (*only if load fails*)
END Modules.
