MODULE Fonts; (*JG 18.11.90; PDR 8.6.12; NW 18.1.2019 / AP 1.9.20 Extended Oberon*)
  IMPORT SYSTEM, Files;

  CONST FontFileId = 0DBH;

  TYPE Raster = POINTER TO RasterDesc;
    RasterDesc = ARRAY OF BYTE;

    Font* = POINTER TO FontDesc;
    FontDesc* = RECORD
      name*: ARRAY 32 OF CHAR;
      height*, minX*, maxX*, minY*, maxY*, base: INTEGER;
      next*: Font;
      raster: Raster
    END ;

    RunRec = RECORD beg, end: BYTE END ;
    BoxRec = RECORD dx, x, y, w, h: BYTE END ;

  (* raster sizes: Syntax8 1367, Syntax10 1628, Syntax12 1688, Syntax14 1843, Syntax14b 1983,
      Syntax16 2271, Syntax20 3034, Syntac24 4274, Syntax24b 4302  *)

  VAR Default*, root*: Font;

  PROCEDURE Put(r: Raster; i, x: INTEGER);
  BEGIN (*put an 4 byte integer into a byte array, least significant byte first*)
    r[i] := x MOD 100H;
    r[i+1] := x DIV 100H MOD 100H;
    r[i+2] := x DIV 10000H MOD 100H;
    r[i+3] := x DIV 1000000H MOD 100H
  END Put;

  PROCEDURE Get(r: Raster; i: INTEGER; VAR x: INTEGER);
  BEGIN (*get a 4 byte integer from a byte array*)
    x := ((r[i+3] * 100H + r[i+2]) * 100H + r[i+1]) * 100H + r[i]
  END Get;

  PROCEDURE GetPat*(fnt: Font; ch: CHAR; VAR dx, x, y, w, h, patadr: INTEGER);
    VAR pa: INTEGER; dxb, xb, yb, wb, hb: BYTE;
  BEGIN Get(fnt.raster, (ORD(ch) MOD 80H)*4, pa); patadr := fnt.base + pa;
    dxb := fnt.raster[pa-3]; xb := fnt.raster[pa-2]; yb := fnt.raster[pa-1]; wb := fnt.raster[pa]; hb := fnt.raster[pa+1];
    dx := dxb; x := xb; y := yb; w := wb; h := hb;
    IF yb < 128 THEN y := yb ELSE y := yb - 256 END
  END GetPat;

  PROCEDURE Load*(name: ARRAY OF CHAR): Font;
    VAR F: Font;
      f: Files.File; R: Files.Rider;
      NofRuns, NofBoxes, height, minX, maxX, minY, maxY, b: BYTE;
      NofBytes, i, j, k, n, a, a0: INTEGER;
      run: ARRAY 16 OF RunRec;
      box: ARRAY 512 OF BoxRec;

    PROCEDURE RdInt16(VAR R: Files.Rider; VAR b0: BYTE);
      VAR b1: BYTE;
    BEGIN Files.ReadByte(R, b0); Files.ReadByte(R, b1)
    END RdInt16;

  BEGIN F := root;
    WHILE (F # NIL) & (name # F.name) DO F := F.next END ;
    IF F = NIL THEN
      f := Files.Old(name);
      IF f # NIL THEN
        Files.Set(R, f, 0); Files.ReadByte(R, b);
        IF b = FontFileId THEN
          Files.ReadByte(R, b); (*abstraction*)
          Files.ReadByte(R, b); (*family*)
          Files.ReadByte(R, b); (*variant*)
          RdInt16(R, height); RdInt16(R, minX); RdInt16(R, maxX); RdInt16(R, minY); RdInt16(R, maxY); RdInt16(R, NofRuns);
          NofBoxes := 0; k := 0;
          WHILE k # NofRuns DO
            RdInt16(R, run[k].beg); RdInt16(R, run[k].end);
            NofBoxes := NofBoxes + run[k].end - run[k].beg;
            INC(k)
          END ;
          NofBytes := 512 + 5; i := 0;
          WHILE i # NofBoxes DO
            RdInt16(R, box[i].dx); RdInt16(R, box[i].x); RdInt16(R, box[i].y);
            RdInt16(R, box[i].w); RdInt16(R, box[i].h);
            NofBytes := NofBytes + 5 + (box[i].w + 7) DIV 8 * box[i].h;
            INC(i)
          END ;
          NEW(F); NEW(F.raster, NofBytes);
          F.name := name;
          F.height := height; F.minX := minX; F.maxX := maxX; F.maxY := maxY;
          IF minY >= 80H THEN F.minY := minY - 100H ELSE F.minY := minY END ;
          F.base := SYSTEM.ADR(F.raster^); a0 := 512;
          F.raster[a0] := 0; F.raster[a0+1] := 0; F.raster[a0+2] := 0; F.raster[a0+3] := 0; F.raster[a0+4] := 0;
          (*null pattern for characters not in a run*)
          INC(a0, 3); a := a0+2; i := 0; j := 0; k := 0;
          WHILE k < NofRuns DO
            WHILE (j < run[k].beg) & (j < 128) DO Put(F.raster, j*4, a0); INC(j) END ;
            WHILE (j < run[k].end) & (j < 128) DO Put(F.raster, j*4, a+3);
              F.raster[a] := box[i].dx; F.raster[a+1] := box[i].x; F.raster[a+2] := box[i].y;
              F.raster[a+3] := box[i].w; F.raster[a+4] := box[i].h; INC(a, 5);
              n := (box[i].w + 7) DIV 8 * box[i].h;
              WHILE n # 0 DO DEC(n); Files.ReadByte(R, b); F.raster[a] := b; INC(a) END ;
              INC(i); INC(j)
            END ;
            INC(k)
          END ;
          WHILE j < 128 DO Put(F.raster, j*4, a0); INC(j) END ;
          F.next := root; root := F
        ELSE (*bad file id*) F := Default
        END
      ELSE (*font file not available*) F := Default
      END
    END ;
    RETURN F
  END Load;

  PROCEDURE This*(name: ARRAY OF CHAR): Font;  (*for backward compatibility*)
  BEGIN RETURN Load(name)
  END This;

  PROCEDURE Free*;  (*remove all but first two from font list*)
  BEGIN IF root.next # NIL THEN root.next.next := NIL END
  END Free;

BEGIN root := NIL; Default := Load("Oberon10.Scn.Fnt")
END Fonts.
