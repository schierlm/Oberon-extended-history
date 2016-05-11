(*  ORP.Compile @
     Builder.WriteFile BootLoad.rsc 512 "D:/Verilog/RISC5/prom.mem" ~
     Builder.ExtractBootROM BootLoad.rsc BootLoad.bin ~
     Builder.CreateBootTrack Modules.bin ~
     Builder.CreateBootTrack Oberon0.bin ~      *)

MODULE Builder;   (*AP 1.12.15*)
  IMPORT Kernel, Files, Texts, Oberon;

  CONST beg = 2; end = 63; nofsecs = end - beg + 1; (*boot area = sectors 2-63*)

  VAR W: Texts.Writer;

  PROCEDURE WriteBootTrack* (s: ARRAY OF CHAR; VAR res, len: INTEGER);
    VAR i, secno: INTEGER; b: BYTE;
      F: Files.File; R: Files.Rider;
      buf: ARRAY Kernel.SectorLength OF BYTE;
  BEGIN F := Files.Old(s);
    IF F # NIL THEN len := Files.Length(F);
       IF len <= nofsecs*Kernel.SectorLength THEN res := 0; (*success*)
        secno := beg; i := 0; Files.Set(R, F, 0); Files.ReadByte(R, b);
        WHILE ~R.eof & (secno <= end) DO buf[i] := b; INC(i);
          IF i = Kernel.SectorLength THEN
            Kernel.PutSector(secno*29, buf); INC(secno); i := 0
          END ;
          Files.ReadByte(R, b)
        END ;
        IF (i > 0) & (secno <= end) THEN
          WHILE i < Kernel.SectorLength DO buf[i] := 0; INC(i) END ;
          Kernel.PutSector(secno*29, buf);
        END ;
      ELSE res := 2 (*not enough space in boot area*)
      END
    ELSE res := 1 (*file not found*)
    END
  END WriteBootTrack;

  PROCEDURE CreateBootTrack*; (*WARNING: overwrites the local disk's boot area*)
    VAR S: Texts.Scanner; len, res: INTEGER;
  BEGIN
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN
      Texts.WriteString(W, "  "); WriteBootTrack(S.s, res, len);
      IF res = 0 THEN
        Texts.WriteString(W, "loaded "); Texts.WriteString(W, S.s); Texts.WriteInt(W, len, 6);
        Texts.WriteString(W, " onto disk's boot area (sectors "); Texts.WriteInt(W, beg, 2);
        Texts.WriteString(W, " - "); Texts.WriteInt(W, end, 3); Texts.WriteString(W, ")")
      ELSIF res = 1 THEN Texts.WriteString(W, S.s); Texts.WriteString(W, " not found")
      ELSIF res = 2 THEN Texts.WriteString(W, S.s); Texts.WriteInt(W, len, 6);
        Texts.WriteString(W, " too large to fit in disk's boot area (sectors "); Texts.WriteInt(W, beg, 2);
        Texts.WriteString(W, " - "); Texts.WriteInt(W, end, 3); Texts.WriteString(W, ")")
      END ;
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
    END
  END CreateBootTrack;
  
 PROCEDURE ExtractBootROM*;
    CONST codepos = 35; BS = 2048;
    VAR if, of: Files.File; ir, or: Files.Rider; b: BYTE; i, len: INTEGER;
      S: Texts.Scanner;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    Texts.WriteString(W, "Builder.ExtractBootROM  ");
    IF S.class = Texts.Name THEN Texts.WriteString(W, S.s); if := Files.Old(S.s);
      IF if # NIL THEN
        Texts.Scan(S);
        IF S.class = Texts.Name THEN
          Texts.WriteString(W, "  "); Texts.WriteString(W, S.s); of := Files.New(S.s);
          Files.Set(ir, if, codepos); Files.Set(or, of, 0); len := Files.Length(if); i := 0;
          WHILE (i < BS) & (i < len) DO
            Files.ReadByte(ir, b); Files.WriteByte(or, b); INC(i)
          END ;
          WHILE i < BS DO Files.WriteByte(or, 0); INC(i) END ;
          Files.Close(if); Files.Register(of);
          Texts.WriteString(W, "  done")
        ELSE Texts.WriteString(W, "  output file must be specified")
        END
      ELSE Texts.WriteString(W, "  input file not found")
      END ;
    ELSE Texts.WriteString(W, "  input file must be specified")
    END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END ExtractBootROM;

  PROCEDURE WriteFile*;
  BEGIN (*to be implemented (creates Xilinx *.mem file)*)
  END WriteFile;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "OR Builder  AP 1.12.2015");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
END Builder.
