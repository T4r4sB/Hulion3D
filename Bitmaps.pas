unit Bitmaps;

interface

uses
  Windows, Messages;

type
  Color = byte;  

  PAColor = ^AColor;
  PColor = ^Color;
  AColor = array [0 .. MaxInt div sizeof(Color)-1] of Color;

  Bitmap = record
    H  : HWND;
    DC : HDC;
    sizeX, sizeY, stride : integer;
    Pixels : PAColor;
  end;

  procedure CreateBitmap (var B: Bitmap; sizeX, sizeY: integer);
  procedure DestroyBitmap (var B: Bitmap);
  function NearestColor(r,g,b: integer): Color;
  procedure SetFogTable (fogr, fogg, fogb : integer);

var
  ColorTable : array [0..255] of TRGBQuad;
  FogTable : array [0..319,0..255] of Color;

implementation

  uses
    Memory;
    
  procedure SetFogTable (fogr, fogg, fogb : integer);
  var
    i,j,f,r,g,b: integer;
  begin
    for i := 0 to 319 do begin   // уровень тумана
      if i<64 then f := i*4 else f := 256;
      f := (f*(256*2-f)) div (1*256);

      for j := 0 to 255 do begin // цвет
        r := (ColorTable[j].rgbRed   * f + fogr * (256-f)) div 256;
        g := (ColorTable[j].rgbGreen * f + fogg * (256-f)) div 256;
        b := (ColorTable[j].rgbBlue  * f + fogb * (256-f)) div 256;
        FogTable[i,j] := NearestColor(r,g,b);
      end;
    end;
  end;

  function IndexToRGB (i: integer): TRGBQuad;        
  const MainColors : array [0..15] of TRGBQuad = (
    (rgbBlue:   0; rgbGreen: 255; rgbRed: 255),
    (rgbBlue:  64; rgbGreen: 255; rgbRed: 192),
    (rgbBlue: 128; rgbGreen: 255; rgbRed: 128),
    (rgbBlue: 192; rgbGreen: 255; rgbRed:  64),
    (rgbBlue: 255; rgbGreen: 255; rgbRed:   0),

    (rgbBlue:   0; rgbGreen: 128; rgbRed: 255),
    (rgbBlue: 128; rgbGreen: 192; rgbRed: 255),
    (rgbBlue: 255; rgbGreen: 255; rgbRed: 255),
    (rgbBlue: 255; rgbGreen: 192; rgbRed: 128),
    (rgbBlue: 255; rgbGreen: 128; rgbRed:   0),

    (rgbBlue:   0; rgbGreen:   0; rgbRed: 255),
    (rgbBlue: 128; rgbGreen:  64; rgbRed: 255),
    (rgbBlue: 255; rgbGreen: 128; rgbRed: 255),
    (rgbBlue: 255; rgbGreen:  64; rgbRed: 128),
    (rgbBlue: 255; rgbGreen:   0; rgbRed:   0),

    (rgbBlue:   0; rgbGreen:   0; rgbRed:   0));
  var
    l,c : integer;
    //cr,cg,cb : integer;
  begin
    if i=0 then Result := MainColors[15]
    else begin
      l := (i-1) div 15+1; // 1..17
      c := (i-1) mod 15;
      result.rgbBlue  := (MainColors[c].rgbBlue *1+0) div 1 * l div 17;
      result.rgbGreen := (MainColors[c].rgbGreen*1+0) div 1 * l div 17;
      result.rgbRed   := (MainColors[c].rgbRed  *1+0) div 1 * l div 17;
    end;
    Result.rgbReserved := 0;     
                 {
    cr := i and 7;
    cg := (i shr 3) and 3;
    cb := i shr 5;
    result.rgbRed   := cr*36;
    result.rgbGreen := (cr+cb)*14+cg*14;
    result.rgbBlue  := cb*36;
    result.rgbReserved := 0;  }

  end;

  procedure CreateBitmap (var B: Bitmap; sizeX, sizeY: integer);
  var
    BI : ^TBitmapInfo;
    MS : MemoryState;
    ScreenDC: HDC;
    i : integer;
  begin
    SaveState(MS);
    BI := Alloc(sizeof(TBitmapInfo) + 255*sizeof(tagRGBQuad));
    FillChar(BI^, SizeOf(BI^), 0);
    B.sizeX  := sizeX;
    B.sizeY  := sizeY;
    B.stride := (sizeX+3) and not 3;
    with BI.bmiHeader do begin
      biSize := SizeOf(BI.bmiHeader);
      biWidth := sizeX;
      biHeight := sizeY;
      biPlanes := 1;
      biBitCount := sizeof(Color)*8;
    end;
    {$IFOPT R+} {$DEFINE OLD_R} {$R-} {$ENDIF}
    for i := 0 to 255 do begin
      BI.bmiColors[i] := ColorTable[i];
      BI.bmiColors[i].rgbGreen :=
        (BI.bmiColors[i].rgbRed + BI.bmiColors[i].rgbBlue + BI.bmiColors[i].rgbGreen) div 3;
    end;
    {$IFDEF OLD_R} {$R+} {$UNDEF OLD_R} {$ENDIF}
    ScreenDC := GetDC(0);
    with B do begin
      DC := CreateCompatibleDC(ScreenDC);
      H  := CreateDIBSection(DC, BI^, DIB_RGB_COLORS, pointer(Pixels), 0, 0);
      SelectObject(DC, H);
      ReleaseDC(0, ScreenDC);
    end;

    RestoreState(MS);
  end;
  
  procedure DestroyBitmap (var B: Bitmap);
  begin
    with B do if H <> 0 then begin
      SelectObject(DC, 0);
      DeleteDC(DC);
      DeleteObject(H);
      H := 0;
    end;
  end;
  
  function NearestColor(r,g,b: integer): Color;
  var
    i : integer;
    dst,adst : integer;
  begin
    dst := 1024;
    Result := 0;
    for i := 0 to 255 do begin
      adst := abs(r-ColorTable[i].rgbRed) + abs(g-ColorTable[i].rgbGreen) + abs(b-ColorTable[i].rgbBlue);
      if adst<dst then begin
        Result := i;
        dst := adst;
      end;
    end;
    //Result := r or g shl 8 or b shl 16;
  end;

var
  i: integer;
initialization
  for i := 0 to 255 do ColorTable[i] := IndexToRGB(i);
end.
