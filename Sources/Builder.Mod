MODULE Builder; (*AP 1.11.17  System building tools for Experimenal Oberon*)
(*
  Builder.Load Modules ~                      ... load the regular boot file (Modules.bin) onto the boot area of the local disk
  Builder.WritePROM M.rsc 512 prom.mem ~      ... extract the code section from an object file and write it out in PROM (hex) format
  Builder.WriteCode M.rsc M.code ~            ... extract the code section from an object file and write it out in binary format with with a prefix (size, adr)
  Builder.WriteStream M.bin M.stream 512 0 ~  ... convert a build-up boot file to the stream format used for booting over the data link
*)
  IMPORT Kernel, Files, Texts, Oberon;
  CONST beg = 2; end = 63; nofsecs = end - beg + 1; (*boot area = sectors 2-63 in Oberon 2013*)
    CR = 0DX; maxCode = 8000;

  VAR W: Texts.Writer;

  PROCEDURE WriteBootArea*(s: ARRAY OF CHAR; VAR res, len: INTEGER);
    VAR i, secno: INTEGER; b: BYTE;
      F: Files.File; R: Files.Rider;
      buf: ARRAY Kernel.SectorLength OF BYTE;
  BEGIN F := Files.Old(s);
    IF F # NIL THEN len := Files.Length(F);
      IF len <= nofsecs*Kernel.SectorLength THEN res := 0; (*success*)
        secno := beg; i := 0; Files.Set(R, F, 0); Files.ReadByte(R, b);
        WHILE ~R.eof & (secno <= end) DO buf[i] := b; INC(i);
          IF i = Kernel.SectorLength THEN Kernel.PutSector(secno*29, buf); INC(secno); i := 0 END ;
          Files.ReadByte(R, b)
        END ;
        IF (i > 0) & (secno <= end) THEN
          WHILE i < Kernel.SectorLength DO buf[i] := 0; INC(i) END ;
          Kernel.PutSector(secno*29, buf);
        END
      ELSE res := 2 (*not enough space*)
      END
    ELSE res := 1 (*file not found*)
    END
  END WriteBootArea;

  PROCEDURE MakeFileName(VAR FName: ARRAY OF CHAR; name, ext: ARRAY OF CHAR);
    VAR i, j: INTEGER;
  BEGIN i := 0; j := 0;  (*assume name suffix less than 4 characters*)
    WHILE (i < 32-5) & (name[i] > 0X) DO FName[i] := name[i]; INC(i) END ;
    REPEAT FName[i]:= ext[j]; INC(i); INC(j) UNTIL ext[j] = 0X;
    FName[i] := 0X
  END MakeFileName;

  PROCEDURE Load*; (*load a valid regular Oberon boot file onto the boot area of the local disk*)
    VAR len, res: INTEGER;
      fname: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN
      MakeFileName(fname, S.s, ".bin"); Texts.WriteString(W, " "); WriteBootArea(fname, res, len);
      IF res = 0 THEN
        Texts.WriteString(W, "loaded "); Texts.WriteString(W, fname); Texts.WriteInt(W, len, 6);
        Texts.WriteString(W, " onto disk's boot area (sectors "); Texts.WriteInt(W, beg, 2);
        Texts.WriteString(W, " - "); Texts.WriteInt(W, end, 3); Texts.WriteString(W, ")")
      ELSIF res = 1 THEN Texts.WriteString(W, fname); Texts.WriteString(W, " not found")
      ELSIF res = 2 THEN Texts.WriteString(W, fname); Texts.WriteInt(W, len, 6);
        Texts.WriteString(W, " too large to fit in disk's boot area (sectors "); Texts.WriteInt(W, beg, 2);
        Texts.WriteString(W, " - "); Texts.WriteInt(W, end, 3); Texts.WriteString(W, ")")
      END ;
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
    END
  END Load;

  PROCEDURE LoadCode(VAR R: Files.Rider; VAR code: ARRAY OF LONGINT; VAR size, start, nofimps, res: INTEGER);
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
      WHILE ~R.eof & (data >= 0) DO Files.ReadInt(R, data) END ; (*procedure variables*)
      Files.ReadInt(R, data); (*fixorgP*) Files.ReadInt(R, data); (*fixorgD*)
      Files.ReadInt(R, data); (*fixorgT*) Files.ReadInt(R, start); (*entry*)
      Files.Read(R, ch);
      IF ch # "O" THEN (*corrupted file*) res := 1 ELSE res := 0 END
    END
  END LoadCode;

  PROCEDURE WriteCode*; (*extract code section from object file and write it to output file, with prefix (size, adr)*)
    VAR if, of: Files.File; ir, or: Files.Rider; (*input file, output file*)
      code: ARRAY maxCode OF LONGINT;
      i, size, start, nofimps, res: INTEGER;
      S: Texts.Scanner;
  BEGIN Texts.WriteString(W, "Builder.WriteCode ");
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN Texts.WriteString(W, S.s); if := Files.Old(S.s);
      IF if # NIL THEN Texts.Scan(S);
        IF S.class = Texts.Name THEN Texts.WriteString(W, " "); Texts.WriteString(W, S.s);
          Files.Set(ir, if, 0); LoadCode(ir, code, size, start, nofimps, res);
          IF res = 0 THEN
            IF nofimps = 0 THEN of := Files.New(S.s);
              IF of # NIL THEN Files.Set(or, of, 0); i := 0;
                Texts.WriteInt(W, size*4, 6); Texts.WriteInt(W, start, 6); (*bytes*)
                Files.WriteInt(or, size*4); Files.WriteInt(or, start); (*prefix*)
                WHILE i < size DO Files.WriteInt(or, code[i]); INC(i) END ;
                Files.Register(of); Texts.WriteString(W, "  done")
              ELSE Texts.WriteString(W, "  cannot create output file")
              END
            ELSE Texts.WriteString(W, " imports not allowed")
            END
          ELSIF res = 1 THEN Texts.WriteString(W, "  input file format error")
          ELSIF res = 2 THEN Texts.WriteString(W, "  program too long")
          END
        ELSE Texts.WriteString(W, "  must specify output file")
        END ;
        Files.Close(if)
      ELSE Texts.WriteString(W, "  input file not found")
      END
    ELSE Texts.WriteString(W, "  must specify input file")
    END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END WriteCode;

  PROCEDURE WriteHex*(VAR R: Files.Rider; x: LONGINT); (*write a 4 byte LONGINT in 8 digit hex format*)
    VAR i: INTEGER; y: LONGINT;
      a: ARRAY 10 OF CHAR;
  BEGIN i := 0;
    REPEAT y := x MOD 10H;
      IF y < 10 THEN a[i] := CHR(y + 30H) ELSE a[i] := CHR(y + 37H) END ;
      x := x DIV 10H; INC(i)
    UNTIL i = 8;
    REPEAT DEC(i); Files.Write(R, a[i]) UNTIL i = 0
  END WriteHex;

  PROCEDURE WriteLn*(VAR R: Files.Rider);
  BEGIN Files.Write(R, CR)
  END WriteLn;

  PROCEDURE WritePROM*; (*extract code section from object file and write it in Xilinx PROM format to output file*)
    VAR if, of: Files.File; ir, or: Files.Rider; (*input file, output file*)
      code: ARRAY maxCode OF LONGINT;
      i, len, size, start, nofimps, res: INTEGER;
      S: Texts.Scanner;
  BEGIN Texts.WriteString(W, "Builder.WritePROM ");
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN Texts.WriteString(W, S.s); if := Files.Old(S.s);
      IF if # NIL THEN Texts.Scan(S);
        IF S.class = Texts.Int THEN len := S.i; Texts.WriteInt(W, len, 5);
          IF len > 0 THEN Texts.Scan(S);
            IF S.class = Texts.Name THEN Texts.WriteString(W, " "); Texts.WriteString(W, S.s);
              Files.Set(ir, if, 0); LoadCode(ir, code, size, start, nofimps, res);
              IF res = 0 THEN
                IF nofimps = 0 THEN
                  IF size <= len THEN of := Files.New(S.s);
                    IF of # NIL THEN Files.Set(or, of, 0); i := 0;
                      WHILE i < size DO WriteHex(or, code[i]); WriteLn(or); INC(i) END ;
                      WHILE i < len DO WriteHex(or, 0); WriteLn(or); INC(i) END ;
                      Files.Register(of); Texts.WriteString(W, "  done")
                    ELSE Texts.WriteString(W, "  cannot create output file")
                    END
                  ELSE  Texts.WriteString(W, "  insufficent size")
                  END
                ELSE Texts.WriteString(W, " imports not allowed")               
                END
              ELSIF res = 1 THEN Texts.WriteString(W, "  input file format error")
              ELSIF res = 2 THEN Texts.WriteString(W, "  program too long")
              END
            ELSE Texts.WriteString(W, "  must specify output file")
            END
          ELSE Texts.WriteString(W, "  size must be positive")
          END
        ELSE Texts.WriteString(W, "  must specify size")
        END ;
        Files.Close(if)
      ELSE Texts.WriteString(W, "  input file not found")
      END
    ELSE Texts.WriteString(W, "  must specify input file")
    END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END WritePROM;

  PROCEDURE MakeStream*(VAR ir, or: Files.Rider; blocksize, adr: INTEGER);
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

  PROCEDURE WriteStream*; (*convert input file to stream format used for booting over serial line*)
    VAR if, of: Files.File; ir, or: Files.Rider; (*input file, output file*)
      fname: ARRAY 32 OF CHAR;
      i, len, blocksize, adr: INTEGER;
      S: Texts.Scanner;
  BEGIN Texts.WriteString(W, "Builder.WriteStream ");
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN Texts.WriteString(W, S.s); if := Files.Old(S.s);
      IF if # NIL THEN len := Files.Length(if);
        IF len > 0 THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN fname := S.s; Texts.Scan(S);
            Texts.WriteString(W, " "); Texts.WriteString(W, fname);
            IF S.class = Texts.Int THEN blocksize := S.i; Texts.WriteInt(W, blocksize, 5);
              IF blocksize >= 0 THEN Texts.Scan(S);
                IF blocksize = 0 THEN blocksize := len END ;
                IF S.class = Texts.Int THEN adr := S.i; Texts.WriteInt(W, adr, 5);
                  IF adr >= 0 THEN of := Files.New(fname);
                    IF of # NIL THEN Files.Set(ir, if, 0); Files.Set(or, of, 0); i := 0;
                      MakeStream(ir, or, blocksize, adr);
                      Files.Register(of); Texts.WriteString(W, "  done")
                    ELSE Texts.WriteString(W, "  cannot create output file")
                    END
                  ELSE Texts.WriteString(W, "  address must >= 0")
                  END
                ELSE Texts.WriteString(W, "  must specify address")
                END
              ELSE Texts.WriteString(W, "  block size must be >= 0")
              END
            ELSE Texts.WriteString(W, "  must specify block size")
            END
          ELSE Texts.WriteString(W, "  must specify output file")
          END ;
          Files.Close(if)
        ELSE Texts.WriteString(W, "  size of input file must be >0")
        END
      ELSE Texts.WriteString(W, "  input file not found")
      END
    ELSE Texts.WriteString(W, "  must specify input file")
    END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END WriteStream;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "OR Builder  AP 1.11.17");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
END Builder.
