MODULE Boot;  (*Oberon boot linker/loader for RISC; CP 21.5.14 / AP 12.12.17 Experimental Oberon*)
  IMPORT SYSTEM, Kernel, Files, Modules, Texts, Oberon;
  CONST versionkey = 1X; versionkey0 = 0X; MT = 12; DescSize = 88; CR = 0DX; maxCode = 8000;
    beg = 2; end = 63; NofSecs = end - beg + 1; (*boot area = sectors 2-63 in Oberon 2013*)

  TYPE (*copied from Modules to enable upgrades to Experimental Oberon*)
    Module* = POINTER TO ModDesc;
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

  VAR root: Module;
    MTOrg, AllocPtr, Start, limit, res*: INTEGER;
    importing*, imported*: ModuleName;
    nocheck: BOOLEAN;
    W: Texts.Writer;

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

  PROCEDURE Link1(name: ARRAY OF CHAR; VAR newmod: Module);
    VAR mod, impmod: Module;
      i, n, key, impkey, mno, nofimps, size: INTEGER;
      p, u, v, w: INTEGER;  (*addresses*)
      ch: CHAR;
      body: Command;
      fixorgP, fixorgD, fixorgT: INTEGER;
      disp, adr, imgadr, inst, pno, vno, dest, offset: INTEGER;
      name1, impname: ModuleName;
      F: Files.File; R: Files.Rider;
      import: ARRAY 16 OF Module;
  BEGIN mod := root; res := 0; nofimps := 0;
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END ;
    IF mod = NIL THEN (*load*)
      F := ThisFile(name);
      IF F # NIL THEN
        Files.Set(R, F, 0); Files.ReadString(R, name1); Files.ReadInt(R, key); Files.Read(R, ch);
        Files.ReadInt(R, size); importing := name1;
        IF (ch = versionkey) OR (ch = versionkey0) (*standalone program*) THEN
          Files.ReadString(R, impname);   (*imports*)
          WHILE (impname[0] # 0X) & (res = 0) DO
            Files.ReadInt(R, impkey);
            Link1(impname, impmod); import[nofimps] := impmod;
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
      IF res = 0 THEN
        INC(size, DescSize);
        IF AllocPtr + size < limit THEN (*allocate*)
          p := AllocPtr; i := p;
          WHILE i < ((p + size + 100H) DIV 20H * 20H) DO SYSTEM.PUT(i, 0); INC(i, 4) END ;
          mod := SYSTEM.VAL(Module, p);
          AllocPtr := (p + size + 100H) DIV 20H * 20H; mod.size := AllocPtr - p;
          IF root = NIL THEN mod.num := 1 ELSE mod.num := root.num + 1 END ;
          mod.next := root; root := mod
        ELSE error(7, name1)
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
        WHILE w >= 0 DO SYSTEM.PUT(p, mod.data + w - Start); INC(p, 4); Files.ReadInt(R, w) END ;
        SYSTEM.PUT(p, 0); INC(p, 4);
        mod.pvar := p;  (*procedure variable references*)
        Files.ReadInt(R, w);
        WHILE w >= 0 DO SYSTEM.PUT(p, mod.data + w - Start); INC(p, 4); Files.ReadInt(R, w) END ;
        SYSTEM.PUT(p, 0); INC(p, 4);
        Files.ReadInt(R, fixorgP); Files.ReadInt(R, fixorgD); Files.ReadInt(R, fixorgT);
        Files.ReadInt(R, w); body := SYSTEM.VAL(Command, mod.code + w - Start);
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
          SYSTEM.GET(impmod.ent + pno*4, dest); dest := dest + impmod.code - Start;
          offset := (dest - (adr - Start) - 4) DIV 4;
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
          IF mno = 0 THEN (*global*) inst := mod.data - Start + vno
          ELSE (*import*)
            SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
            SYSTEM.GET(impmod.ent + vno*4, offset);
            inst := impmod.data + offset - Start
          END ;
          SYSTEM.PUT(adr, inst); adr := adr - disp*4
        END ;
        SYSTEM.PUT(Start, body) (*module initialization body*)
      ELSIF res = 3 THEN importing := name;
        WHILE nofimps > 0 DO DEC(nofimps); DEC(import[nofimps].refcnt) END
      END
    END ;
    newmod :=  mod
  END Link1;

  PROCEDURE Link*;
    VAR F: Files.File; R: Files.Rider;
      M, p: Module;
      name: ModuleName;
      i, x: INTEGER;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S); res := -1;
    IF S.class = Texts.Name THEN name := S.s; Texts.Scan(S);
      IF S.class = Texts.Name THEN res := 0; F := ThisFile(name); (*input file*)
        IF F # NIL THEN F := Files.New(S.s); (*output file*)
          IF F # NIL THEN
            Start := Modules.AllocPtr; MTOrg := Start + 32; AllocPtr :=  Start + 256;
            limit := Kernel.heapOrg; DEC(limit, 8000H); root := NIL; i := 0;
            WHILE i < DescSize + 256 DO SYSTEM.PUT(Start + i, 0); INC(i, 4) END ;
            Link1(name, M);
            IF res = 0 THEN
              Texts.WriteString(W, "  linking "); Texts.WriteString(W, name); Texts.WriteString(W, " into binary ");
              Texts.WriteString(W, S.s); Texts.WriteInt(W, AllocPtr - Start, 7); Texts.WriteLn(W);
              SYSTEM.PUT(Start + 20, SYSTEM.VAL(INTEGER, root) - Start);
              SYSTEM.PUT(Start + 252, 12345678H); (*fingerprint*)
              p := root;
              WHILE p # NIL DO (*fix up module chain of pointers*)
                Texts.WriteString(W, "    "); Texts.WriteString(W, p.name); Texts.WriteInt(W, p.num, 3);
                Texts.WriteHex(W, p.data - Start); Texts.WriteInt(W, (p.imp - p.code) DIV 4, 6);
                Texts.WriteInt(W, p.code - p.data, 6); Texts.WriteHex(W, p.key); Texts.WriteLn(W);
                M := p; p := p.next;
                IF M.next # NIL THEN M.next := SYSTEM.VAL(Module, SYSTEM.VAL(INTEGER, M.next) - Start) END ;
                M.data := M.data - Start;
                SYSTEM.PUT(M.num * 4 + MTOrg, M.data); (*module table entry*)
                M.code := M.code - Start;
                i := M.imp;
                WHILE i < M.cmd DO SYSTEM.GET(i, x); SYSTEM.PUT(i, x - Start); INC(i, 4) END ;
                M.imp := M.imp - Start;
                M.cmd := M.cmd - Start;
                M.ent := M.ent - Start;
                M.ptr := M.ptr - Start;
                M.pvar := M.pvar - Start
              END ;
              Files.Set(R, F, 0); i := Start;
              SYSTEM.PUT(Start + 16, AllocPtr - Start); (*size of linked binary file*)
              SYSTEM.PUT(Start + 24, 40000H); (*limit / heapOrg*)
              SYSTEM.GET(Start, x);
              SYSTEM.PUT(Start, 0E7H * 1000000H + (x DIV 4) - 1); (*branch to module body*)
              WHILE i < AllocPtr DO SYSTEM.GET(i, x); Files.WriteInt(R, x); INC(i, 4) END ;
              Files.Register(F)
            END
          END
        ELSE error(1, name)
        END
      END
    END ;
    IF res # 0 THEN
      IF res = -1 THEN Texts.WriteString(W, "Usage: Boot.Link modulename filename")
      ELSE Texts.WriteString(W, "Link error:  "); Texts.WriteString(W, importing);
        IF res = 1 THEN Texts.WriteString(W, " module not found")
        ELSIF res = 2 THEN Texts.WriteString(W, " bad version")
        ELSIF res = 3 THEN Texts.WriteString(W, " imports ");
          Texts.WriteString(W, imported); Texts.WriteString(W, " with bad key")
        ELSIF res = 4 THEN Texts.WriteString(W, " corrupted obj file")
        ELSIF res = 7 THEN Texts.WriteString(W, " insufficient space")
        END
      END ;
      Texts.WriteLn(W)
    END ;
    Texts.Append(Oberon.Log, W.buf)
  END Link;

  PROCEDURE Load*; (*load boot file onto the boot area of the local disk*)
    VAR i, len, secno: INTEGER; b: BYTE;
      F: Files.File; R: Files.Rider;
      buf: ARRAY Kernel.SectorLength OF BYTE;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN F := Files.Old(S.s);
      IF F # NIL THEN len := Files.Length(F);
        IF nocheck OR (len <= NofSecs*Kernel.SectorLength) THEN
          Texts.WriteString(W, "  loading "); Texts.WriteString(W, S.s); Texts.WriteInt(W, len, 7);
          Texts.WriteString(W, " onto the boot area of the local disk");
          secno := beg; i := 0; Files.Set(R, F, 0); Files.ReadByte(R, b);
          WHILE ~R.eof & (nocheck OR (secno <= end)) DO buf[i] := b; INC(i);
            IF i = Kernel.SectorLength THEN Kernel.PutSector(secno*29, buf); INC(secno); i := 0 END ;
            Files.ReadByte(R, b)
          END ;
          IF (i > 0) & (nocheck OR (secno <= end)) THEN
            WHILE i < Kernel.SectorLength DO buf[i] := 0; INC(i) END ;
            Kernel.PutSector(secno*29, buf);
          END
        ELSE Texts.WriteString(W, S.s); Texts.WriteInt(W, len, 7);
          Texts.WriteString(W, " too large to fit in the boot area of the local disk")
        END
      ELSE Texts.WriteString(W, S.s); Texts.WriteString(W, " not found")
      END
    ELSE Texts.WriteString(W, "Usage: Boot.Load inputfile")
    END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END Load;

  PROCEDURE LoadNoCheck*; (*same as Load, but without checking whether the boot file fits into the boot area*)
  BEGIN nocheck := TRUE; Load; nocheck := FALSE
  END LoadNoCheck;

  PROCEDURE ReadCode(VAR R: Files.Rider; VAR code: ARRAY OF LONGINT; VAR size, start, nofimps, res: INTEGER);
    VAR n, data: INTEGER; ch: CHAR; b: BYTE;               (*size in words, start in bytes*)
      name: ARRAY 32 OF CHAR;
  BEGIN Files.ReadString(R, name); Files.ReadInt(R, data); (*key*)
    Files.ReadByte(R, b); (*version*) Files.ReadInt(R, data); (*size*)
    Files.ReadString(R, name); (*imports*) nofimps := 0;
    WHILE ~R.eof & (name[0] # 0X) DO INC(nofimps); Files.ReadInt(R, data); (*key*) Files.ReadString(R, name) END ;
    Files.ReadInt(R, n);
    WHILE ~R.eof & (n > 0) DO Files.ReadInt(R, data); DEC(n, 4) END ; (*type descriptors*)
    Files.ReadInt(R, n); (*variable space*)
    Files.ReadInt(R, n);
    WHILE ~R.eof & (n > 0) DO Files.Read(R, ch); DEC(n) END ; (*strings*)
    Files.ReadInt(R, size);
    IF size > LEN(code) THEN (*program too long*) res := 2
    ELSE n := 0;
      WHILE ~R.eof & (n < size) DO Files.ReadInt(R, data); code[n] := data; INC(n) END ; (*code*)
      Files.ReadString(R, name);
      WHILE ~R.eof & (name[0] # 0X) DO Files.ReadInt(R, data); Files.ReadString(R, name) END ; (*commands*)
      Files.ReadInt(R, n);
      WHILE ~R.eof & (n > 0) DO Files.ReadInt(R, data); DEC(n) END ; (*entries*)
      Files.ReadInt(R, data);
      WHILE ~R.eof & (data >= 0) DO Files.ReadInt(R, data) END ; (*pointer references*)
      Files.ReadInt(R, data);
      WHILE ~R.eof & (data >= 0) DO Files.ReadInt(R, data) END ; (*procedure variable references*)
      Files.ReadInt(R, data); (*fixorgP*) Files.ReadInt(R, data); (*fixorgD*)
      Files.ReadInt(R, data); (*fixorgT*) Files.ReadInt(R, start); (*entry*)
      Files.Read(R, ch);
      IF ch # "O" THEN (*corrupted file*) res := 1 ELSE res := 0 END
    END
  END ReadCode;

  PROCEDURE WriteCode*; (*write code section of M.rsc in binary format with prefix (size, adr) to output file*)
    VAR if, of: Files.File; ir, or: Files.Rider; (*input file, output file*)
      code: ARRAY maxCode OF LONGINT;
      i, size, start, nofimps, res: INTEGER;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S); res := -1;
    IF S.class = Texts.Name THEN name := S.s; Texts.Scan(S);
      IF S.class = Texts.Name THEN res := 0; Texts.WriteString(W, "  WriteCode ");
        Texts.WriteString(W, name); Texts.Write(W, " "); Texts.WriteString(W, S.s);
        if := Files.Old(name);
        IF if # NIL THEN of := Files.New(S.s);
          IF of # NIL THEN Files.Set(ir, if, 0); ReadCode(ir, code, size, start, nofimps, res);
            IF res = 0 THEN
              IF nofimps = 0 THEN Files.Set(or, of, 0); i := 0;
                Texts.WriteInt(W, size*4, 6); Texts.WriteInt(W, start, 6); (*bytes*)
                Files.WriteInt(or, size*4); Files.WriteInt(or, start); (*prefix*)
                WHILE i < size DO Files.WriteInt(or, code[i]); INC(i) END ;
                Files.Register(of); Texts.WriteString(W, "  done")
              ELSE Texts.WriteString(W, "  imports not allowed")
              END
            ELSIF res = 1 THEN Texts.WriteString(W, "  input file format error")
            ELSIF res = 2 THEN Texts.WriteString(W, "  program too long")
            END
          ELSE Texts.WriteString(W, "  cannot create output file")
          END ;
          Files.Close(if)
        ELSE Texts.WriteString(W, "  input file not found")
        END
      END
    END ;
    IF res = -1 THEN Texts.WriteString(W, "Usage: Boot.WriteCode M.rsc M.code") END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END WriteCode;

  PROCEDURE WriteHex(VAR R: Files.Rider; x: LONGINT); (*write a 4 byte LONGINT in 8 digit hex format*)
    VAR i: INTEGER; y: LONGINT;
      a: ARRAY 10 OF CHAR;
  BEGIN i := 0;
    REPEAT y := x MOD 10H;
      IF y < 10 THEN a[i] := CHR(y + 30H) ELSE a[i] := CHR(y + 37H) END ;
      x := x DIV 10H; INC(i)
    UNTIL i = 8;
    REPEAT DEC(i); Files.Write(R, a[i]) UNTIL i = 0
  END WriteHex;

  PROCEDURE WritePROM*; (*write code section of M.rsc in PROM format with specified size to output file*)
    VAR if, of: Files.File; ir, or: Files.Rider; (*input file, output file*)
      code: ARRAY maxCode OF LONGINT;
      i, len, size, start, nofimps, res: INTEGER;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S); res := -1;
    IF S.class = Texts.Name THEN name := S.s; Texts.Scan(S);
      IF S.class = Texts.Int THEN len := S.i; Texts.Scan(S);
        IF S.class = Texts.Name THEN res := 0; Texts.WriteString(W, "  WritePROM ");
          Texts.WriteString(W, name); Texts.WriteInt(W, len, 5); Texts.Write(W, " "); Texts.WriteString(W, S.s);
          IF len > 0 THEN if := Files.Old(name);
            IF if # NIL THEN of := Files.New(S.s);
              IF of # NIL THEN Files.Set(ir, if, 0); ReadCode(ir, code, size, start, nofimps, res);
                IF res = 0 THEN
                  IF nofimps = 0 THEN
                    IF size <= len THEN Files.Set(or, of, 0); i := 0;
                      WHILE i < size DO WriteHex(or, code[i]); Files.Write(or, CR); INC(i) END ;
                      WHILE i < len DO WriteHex(or, 0); Files.Write(or, CR); INC(i) END ;
                      Files.Register(of); Texts.WriteString(W, "  done")
                    ELSE  Texts.WriteString(W, "  insufficent size")
                    END
                  ELSE Texts.WriteString(W, " imports not allowed")
                  END
                ELSIF res = 1 THEN Texts.WriteString(W, "  input file format error")
                ELSIF res = 2 THEN Texts.WriteString(W, "  program too long")
                END
              ELSE Texts.WriteString(W, "  cannot create output file")
              END ;
              Files.Close(if)
            ELSE Texts.WriteString(W, "  input file not found")
            END
          ELSE Texts.WriteString(W, "  size must be positive")
          END
        END
      END
    END ;
    IF res = -1 THEN Texts.WriteString(W, "Usage: Boot.WritePROM M.rsc 512 prom.mem") END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END WritePROM;

  PROCEDURE MakeStream(VAR ir, or: Files.Rider; blocksize, adr: INTEGER);
    VAR i, a: INTEGER; b: BYTE;
  BEGIN Files.ReadByte(ir, b); i := 0; a := adr;
    WHILE ~ir.eof DO
      IF (i MOD blocksize = 0) THEN i := 0;
        Files.WriteInt(or, blocksize); Files.WriteInt(or, a); INC(a, blocksize)
      END ;
      Files.WriteByte(or, b); INC(i); Files.ReadByte(ir, b)
    END ;
    WHILE i < blocksize DO Files.WriteByte(or, 0); INC(i) END ;
    Files.WriteInt(or, 0)  (*size of last block*)
  END MakeStream;

  PROCEDURE WriteStream*; (*convert boot file to stream format with specified blocksize and dest adr*)
    VAR if, of: Files.File; ir, or: Files.Rider; (*input file, output file*)
      i, len, blocksize, res: INTEGER;
      name, name1: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S); res := -1;
    IF S.class = Texts.Name THEN name := S.s; Texts.Scan(S);
      IF S.class = Texts.Name THEN name1 := S.s; Texts.Scan(S);
        IF S.class = Texts.Int THEN blocksize := S.i; Texts.Scan(S);
          IF S.class = Texts.Int THEN res := 0; Texts.WriteString(W, "  WriteStream ");
            Texts.WriteString(W, name); Texts.Write(W, " "); Texts.WriteString(W, name1);
            Texts.WriteInt(W, blocksize, 5); Texts.WriteInt(W, S.i, 5);
            IF blocksize >= 0 THEN
              IF S.i >= 0 THEN if := Files.Old(name);
                IF if # NIL THEN len := Files.Length(if);
                  IF len > 0 THEN of := Files.New(name1);
                    IF of # NIL THEN 
                      IF blocksize = 0 THEN blocksize := len END ;
                      Files.Set(ir, if, 0); Files.Set(or, of, 0); i := 0;
                      MakeStream(ir, or, blocksize, S.i);
                      Files.Register(of); Texts.WriteString(W, "  done")
                    ELSE Texts.WriteString(W, "  cannot create output file")
                    END
                  ELSE Texts.WriteString(W, "  input file empty")
                  END ;
                  Files.Close(if)
                ELSE Texts.WriteString(W, "  input file not found")
                END
              ELSE Texts.WriteString(W, "  destination address must >= 0")
              END
            ELSE Texts.WriteString(W, "  block size must be >= 0")
            END
          END
        END
      END
    END ;
    IF res = -1 THEN Texts.WriteString(W, "Usage: Boot.WriteStream inputfile outputfile 512 0") END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END WriteStream;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "OR Boot linker/loader  AP 12.12.17");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); nocheck := FALSE
END Boot.
