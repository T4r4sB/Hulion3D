unit Textures;

interface

  uses
    Bitmaps, EngineTypes, Points;

  procedure CreateTexture (var T: Texture; osx,osy : integer);
  procedure DestroyTexture (var T: Texture);
  procedure ProcessSkyTxr  (dt: float);
  procedure ProcessHellTxr (dt: float);

  var
    BaseTxr : array [0..13] of Texture;
    AncTxr  : array [0..127] of Texture;
    TechTxr : array [0..63] of Texture;
    MstrTxr : array [0..15] of Texture;     
    BoxTxr  : array [0..15] of Texture;

implementation

  uses
    {$IFOPT D+}
    SysUtils,
    {$ENDIF}
    Memory;

  procedure CreateTexture (var T: Texture; osx,osy : integer);
  begin
    T.Pixels := Alloc((1 shl osx)*(1 shl osy)*sizeof(integer));
    FillChar(T.Pixels[0], (1 shl osx)*(1 shl osy)*sizeof(integer)*sizeof(T.Pixels[0]), 0);
    T.maskx := 1 shl osx - 1;
    T.masky := 1 shl osy - 1;
    T.shlx  := osx;
    T.Dithering := True;
  end;

  procedure DestroyTexture (var T: Texture);
  begin
  end;

  procedure NormalizeNoise (sx,sy : integer; var f: array of single; nw : single=1);
  var
    i : integer;
    min,max : single;
  begin
    min := -1;
    max := -1;
    for i := 0 to sx*sy-1 do begin
      if (i=0) or (f[i]>max) then max:=f[i];  
      if (i=0) or (f[i]<min) then min:=f[i];
    end;
    if max>min then begin
      for i := 0 to sx*sy-1 do f[i] := nw * (f[i]-min)/(max-min) + (1-nw) * f[i];
    end else begin
      for i := 0 to sx*sy-1 do f[i] := nw * random + (1-nw)*f[i];
    end;
  end;

  procedure FillNoise1 (sx,sy : integer; scy : single; wc : integer; fr : single; var f : array of single; const x,y : array of single);
  var
    r,rx,ry : single;
    i,j,k : integer;
  const
    st : array [0..31] of single = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
    first : boolean = true;
  begin
    if first then begin
      for i := 0 to 31 do st[i] := sin(i*2*pi/32);
      first := false;
    end;
    for j := 0 to sy-1 do for i := 0 to sx-1 do begin
      r := 0;
      for k := 0 to wc-1 do begin
        rx := abs(i-x[k]);
        if rx*2>=sx then rx := sx-rx;
        ry := abs(j-y[k]);
        if ry*2>=sy then ry := sy-ry;
        r := r + st[round( fr*(rx+ry*scy)*4 ) and 31];
      end;
      f[i+j*sx] := abs(r);
    end;
    r := sqrt(wc);
    for i := 0 to sx*sy-1 do begin
      if f[i]>r then f[i]:=r else if f[i]<-r then f[i]:=-r;
    end;
    NormalizeNoise(sx,sy,f);
  end;

  procedure FillNoise2 (sx,sy : integer; var f : array of single);
  var
    i,j,k : integer;
    x1,y1,dx,dy : integer;
    c : single;
  begin
    for i := 0 to sx*5-1 do begin
      x1 := random(sx shl 16);
      y1 := random(sy shl 16);
      dx := random(sx shl 16);
      dy := random(sy shl 16);
      if abs(dx)>abs(dy) then k := dx shr 16 else k := dy shr 16;
      if k>0 then begin
        dy := dy div k;
        dx := dx div k;
      end;
      c := random;
      for j := 0 to k-1 do begin
        f[(smallint(x1 shr 16)and(sx-1)) * sx +  (smallint(y1 shr 16)and(sy-1))] := c;
        Inc(x1,dx);
        Inc(y1,dy);
      end;
    end;
    NormalizeNoise(sx,sy,f);
  end;

  procedure FillNoise3 (sx,sy : integer; wc : integer; var f : array of single; const x,y : array of single);
  var
    r1,r2,cr,rx,ry : single;
    i,j,k : integer;
  begin
    for j := 0 to sy-1 do for i := 0 to sx-1 do begin
      r1 := 3*sx;
      r2 := 3*sy;
      for k := 0 to wc-1 do begin
        rx := abs(i-x[k]);
        if rx*2>=sx then rx := sx-rx;
        ry := abs(j-y[k]);
        if ry*2>=sy then ry := sy-ry;
        cr := sqrt(sqr(rx)+sqr(ry));
        if cr<r1 then begin
          r2 := r1;
          r1 := cr;
        end else if cr<r2 then begin
          r2 := cr;
        end;
      end;
      cr := abs(r1-r2);
      if cr>2 then cr:=2;
      f[i+j*sx] := cr;
    end;
    NormalizeNoise(sx,sy,f);
  end;
  
  procedure FillNoise4 (sx,sy : integer; wc : integer; var f : array of single; const x,y : array of single);
  var
    cr,rx,ry : single;
    i,j,k : integer;
  begin
    for j := 0 to sy-1 do for i := 0 to sx-1 do begin
      cr := 3*sx;
      for k := 0 to wc-1 do begin
        rx := abs(i-x[k]);
        if rx*2>=sx then rx := sx-rx;
        ry := abs(j-y[k]);
        if ry*2>=sy then ry := sy-ry;
        if cr>rx then cr := rx;
        if cr>ry then cr := ry;
      end;
      if cr>2 then cr:=2;
      f[i+j*sx] := cr;
    end;                
    NormalizeNoise(sx,sy,f);
  end;

  procedure FillNoise5 (sx,sy : integer; var f : array of single);
  var
    i,j,k: integer;
    r : array [0..63,0..63] of single;
  begin
    for j := 0 to sy-1 do for i := 0 to sx-1 do f[i+j*sx] := 0;

    for k := 5 downto 1 do begin
      for i := 0 to 64 shr k - 1 do for j := 0 to 64 shr k - 1 do r[i,j] := random;
      for j := 0 to sy-1 do for i := 0 to sx-1 do begin
        f[i+j*sx] := f[i+j*sx] +
          (
            (r[ j shr k                      ,  i shr k                        ]
               * (1 shl k - (i-(i shr k shl k)))
           + r[ j shr k                      , (i shr k + 1) and (64 shr k - 1)]
               * (i-(i shr k shl k))) * (1 shl k - (j-(j shr k shl k)))
           +(r[(j shr k+1) and (64 shr k - 1),  i shr k                        ]
               * (1 shl k - (i-(i shr k shl k)))
           + r[(j shr k+1) and (64 shr k - 1), (i shr k + 1) and (64 shr k - 1)]
               * (i-(i shr k shl k))) * (j-(j shr k shl k))
            )

          / (1 shl (k+k)) / (64/(1 shl k));
      end;
    end;
    for j := 0 to sy-1 do for i := 0 to sx-1 do begin
      f[i+j*sx] := trunc(f[i+j*sx]*10);
      if f[i+j*sx]>7 then f[i+j*sx]:=7;
    end;
    NormalizeNoise(sx,sy,f);
  end;

  procedure FillNoise6 (sx,sy : integer; var f : array of single);
  var
    x,y : integer;
  const
    dx : array [0..3] of integer = (-1,0,1,0);
    dy : array [0..3] of integer = (0,1,0,-1);

    procedure Line;
    var
      ix,iy,id,i : integer;
      x,y,d : integer;

      procedure Ray(fst : boolean);
      var
        i,k : integer;
      begin
        repeat
          k := random(32)+16;
          for i := 0 to k-1 do begin
            if fst and (f[x+y*sx]<1) then Exit;
            fst := true;
            f[x+y*64] := 0;
            x := (x+dx[d]) and (sx-1);
            y := (y+dy[d]) and (sy-1);
          end;
          case random(2) of
            0 : begin
              f [(x-dx[d]*2-dy[d]*2) and (sx-1) + ((y-dy[d]*2+dx[d]*2) and (sy-1)) * sx] := 0;
              d := (d+3) and 3;
            end;
            1 : begin
              f [(x-dx[d]*2+dy[d]*2) and (sx-1) + ((y-dy[d]*2-dx[d]*2) and (sy-1)) * sx] := 0;
              d := (d+1) and 3;
            end;
          end;
        until false;
      end;

    begin
      ix := random(sx);
      iy := random(sy);
      id := random(3);
      for i := 0 to 1 do begin
        x := ix;
        y := iy;
        d := id;
        Ray(i=0);
        id := (id+1+random(2)*2) and 3;
      end;
    end;

  begin
    for x := 0 to 63 do for y := 0 to 63 do f[x+y*64] := 1;
    for x := 0 to 3+random(5) do
      Line;
  end;

  procedure FillNoise7 (sx,sy : integer; wc : integer; var f : array of single; const x,y : array of single);
  var
    r1,r2,cr,rx,ry : single;
    i,j,k : integer;
  begin
    for j := 0 to sy-1 do for i := 0 to sx-1 do begin
      r1 := 3*sx;
      r2 := 3*sy;
      for k := 0 to wc-1 do begin
        rx := abs(i-x[k]);
        if rx*2>=sx then rx := sx-rx;
        ry := abs(j-y[k]);
        if ry*2>=sy then ry := sy-ry;
        cr := abs(rx)+abs(ry);
        if cr<r1 then begin
          r2 := r1;
          r1 := cr;
        end else if cr<r2 then begin
          r2 := cr;
        end;
      end;
      cr := abs(r1-r2);
      if cr>2 then cr:=2;
      f[i+j*sx] := cr;
    end;
    NormalizeNoise(sx,sy,f);
  end;

  procedure MakeRandomNoise1 (sx,sy : integer; scy : single; wc : integer; fr : single; var f : array of single);
  var
    x,y : array [0..15] of single;
    k : integer;
  begin
    for k := 0 to wc-1 do begin
      x[k] := random(64);
      y[k] := random(64);
    end;
    FillNoise1(sx,sy,scy,wc,fr,f,x,y);
  end;

  procedure MakeRandomNoise3 (sx,sy : integer; wc : integer; var f : array of single);
  var
    x,y : array [0..63] of single;
    k : integer;
  begin
    for k := 0 to wc-1 do begin
      x[k] := random(64);
      y[k] := random(64);
    end;
    FillNoise3(sx,sy,wc,f,x,y);
  end;

  procedure MakeRandomNoise4 (sx,sy : integer; wc : integer; var f : array of single);
  var
    x,y : array [0..15] of single;
    k : integer;
  begin
    for k := 0 to wc-1 do begin
      x[k] := random(64);
      y[k] := random(64);
    end;
    FillNoise4(sx,sy,wc,f,x,y);
  end;

  procedure MakeRandomNoise7 (sx,sy : integer; wc : integer; var f : array of single);
  var
    x,y : array [0..15] of single;
    k : integer;
  begin
    for k := 0 to wc-1 do begin
      x[k] := random(64);
      y[k] := random(64);
    end;
    FillNoise7(sx,sy,wc,f,x,y);
  end;

  procedure ProcessSkyTxr(dt: float);
  const
    x : array [0..3] of single = (0,3,50,6);
    y : array [0..3] of single = (5,40,7,10);
    colors : array [0..9] of Color = (0,0,0,0,0,0,0,0,0,0);
    first : boolean = true;
  var
    r : array [0..64*64-1] of single;
    i,j : integer;
  begin
    if First then begin
      for i := 0 to 9 do colors[i] := NearestColor(50+i*15, 255, 50);
      First := false;
    end;
    for i := 0 to 3 do begin
      x[i] := x[i]+(i*i*1.8-1.5)*dt;
      y[i] := y[i]+(i*2.1+x[i]*0.03)*dt;
      while x[i]>64 do x[i]:=x[i]-64; while x[i]<0 do x[i]:=x[i]+64;
      while y[i]>64 do y[i]:=y[i]-64; while y[i]<0 do y[i]:=y[i]+64;
    end;

    FillNoise1(64,64,1,4,0.1,r,x,y);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[0] do
      Pixels[i shl shlx or j] := Colors[round(r[i+j*64]*9)];
  end;
  
  procedure ProcessHellTxr(dt: float);
  const
    x : array [0..3] of single = (0,3,50,6);
    y : array [0..3] of single = (5,40,7,10);
    colors : array [0..9] of Color = (0,0,0,0,0,0,0,0,0,0);
    first : boolean = true;
  var
    r : array [0..64*64-1] of single;
    i,j : integer;
  begin
    if First then begin
      for i := 0 to 9 do colors[i] := NearestColor(255, 50+i*15, 50);
      First := false;
    end;
    for i := 0 to 3 do begin
      x[i] := x[i]+(i*i*1.8-1.5)*dt;
      y[i] := y[i]+(i*2.1+x[i]*0.03)*dt;
      while x[i]>64 do x[i]:=x[i]-64; while x[i]<0 do x[i]:=x[i]+64;
      while y[i]>64 do y[i]:=y[i]-64; while y[i]<0 do y[i]:=y[i]+64;
    end;

    FillNoise1(64,64,1,4,0.1,r,x,y);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[7] do
      Pixels[i shl shlx or j] := Colors[round(r[i+j*64]*9)];
  end;
  
  procedure FillMetalTxr;
  var
    i,j,i8,j8 : integer;
    r : single;
  begin
    for j := 0 to 63 do for i := 0 to 63 do begin
      i8 := (i div 2 and 7);
      j8 := (j div 2 and 7);
      r := 0;

      if (j8=0) and (i8 in [0..4,6]) then r := 1;
      if (j8=4) and (i8 in [0,2,4..7]) then r := 1;
      if (i8=2) and (j8 in [0,2..6]) then r := 1;
      if (i8=6) and (j8 in [0..2,4,6..7]) then r := 1;

      r := r*0.7 + random*0.3;

      BaseTxr[6].Pixels[i shl 6 or j] := NearestColor(round(r*255),round(r*192),round(r*128));
    end;
  end;

  procedure revf (sx,sy : integer; var f : array of single);
  var
    i : integer;
  begin
    for i := 0 to sx*sy-1 do f[i]:=1-f[i];
  end;

  function BlackTxr(const T: Texture) : boolean;
  var
    i,j : integer;
    c : integer;
  begin
    result := true;
    for j := 0 to T.masky do for i := 0 to T.maskx do begin
      c := T.Pixels[i+j shl T.shlx];
      if (ColorTable[c].rgbRed>0) or (ColorTable[c].rgbGreen>0) or (ColorTable[c].rgbBlue>0) then begin
        result := false;
        break;
      end;
    end;
  end;

  procedure FillTxrByNoise (var Txr: Texture; const r : array of single; light : boolean);
  var
    i,j : integer;
    rr,rg,rb : array [0..64*64-1] of single;
    r1,r2,g1,g2,b1,b2 : single;
    mc,rc : single;
  begin
    r1 := 0.0+random*0.2;
    g1 := 0.0+random*0.2;
    b1 := 0.0+random*0.2;
    case random(7) of
      0  : begin r2 := 1.0+random*0.0; g2 := 1.0+random*0.0; b2 := 1.0+random*0.0; end;
      1  : begin r2 := 0.2+random*0.4; g2 := 1.0+random*0.0; b2 := 1.0+random*0.0; end;
      2  : begin r2 := 1.0+random*0.0; g2 := 0.4+random*0.4; b2 := 0.2+random*0.4; end;
      3  : begin r2 := 1.0+random*0.0; g2 := 0.2+random*0.4; b2 := 0.2+random*0.4; end;
      4  : begin r2 := 0.5+random*0.4; g2 := 1.0+random*0.0; b2 := 0.2+random*0.4; end;     
      5  : begin r2 := 1.0+random*0.0; g2 := 1.0+random*0.0; b2 := 0.4+random*0.4; end;
      else begin r2 := 0.2+random*0.4; g2 := 0.2+random*0.4; b2 := 1.0+random*0.0; end;
    end;
    for i := 0 to 63 do for j := 0 to 63 do begin
      rr[i+j*64] := r1 + (r2-r1)* r[i+j*64];
      rg[i+j*64] := g1 + (g2-g1)* r[i+j*64];
      rb[i+j*64] := b1 + (b2-b1)* r[i+j*64];
    end;

    if light then for i := 0 to 63 do for j := 0 to 63 do begin
      if rr[i+j*64]>=0.5 then rr[i+j*64] := 1 else rr[i+j*64] := rr[i+j*64]+0.5;
      if rg[i+j*64]>=0.5 then rg[i+j*64] := 1 else rg[i+j*64] := rg[i+j*64]+0.5;
      if rb[i+j*64]>=0.5 then rb[i+j*64] := 1 else rb[i+j*64] := rb[i+j*64]+0.5;
    end;

    if light then begin mc:=0.9;rc:=0.1; end else begin mc:=0.7;rc:=0.3;end;
    
    for i := 0 to 63 do for j := 0 to 63 do begin
      rr[i+j*64] := rr[i+j*64]*(mc+random*rc);
      rg[i+j*64] := rg[i+j*64]*(mc+random*rc);
      rb[i+j*64] := rb[i+j*64]*(mc+random*rc);
    end;

    for i := 0 to 63 do for j := 0 to 63 do begin
      rr[i+j*64] := rr[i+j*64]*255;
      rg[i+j*64] := rg[i+j*64]*255;
      rb[i+j*64] := rb[i+j*64]*255;
    end;

    for i := 0 to 63 do for j := 0 to 63 do with Txr do begin
      Pixels[i+j*64] := NearestColor(round(rr[i+j*64]),round(rg[i+j*64]),round(rb[i+j*64]));
    end;

    Assert(not BlackTxr(Txr));
  end;
  
  procedure FillTechTxr(var Txr: Texture; Light : boolean);
  var
    r : array [0..64*64-1] of single;
    x,y : integer;
  begin
    Txr.Dithering := False;
    case random(2) of
      0 : FillNoise6(64,64,r);
      1 : MakeRandomNoise7(64,64,4+random(5),r);
    end;

    if not Light and (random(2)=0) then begin
      for x := 0 to 63 do for y := 0 to 63 do r[x+y*64] := 1-r[x+y*64];
      Light := True;
    end;

    FillTxrByNoise(Txr, r, Light);
  end;

  procedure FillAncientTxr(var Txr: Texture);
  var
    r : array [0..64*64-1] of single;
  begin
    case random(20) of
      1: FillNoise2(64, 64, r);
      0,2,3,7,8: MakeRandomNoise3(64, 64, 8+random(57), r);
      4,5,6: MakeRandomNoise4(64, 64, 2+random(3), r);
      9..15 : begin
        MakeRandomNoise1(64, 64, 1, 2+random(4), 0.2+random*0.3, r);
        if random(2)=0 then revf(64,64,r);
      end;
      else FillNoise5(64,64,r);
    end;
    FillTxrByNoise(Txr, r, False);
  end;
  
  procedure FillMonsterTxr(var Txr: Texture);
  var
    i,j : integer;
  begin
    FillAncientTxr(Txr);
    Txr.Dithering := False;
    for i := -5 to 5 do for j := -5 to 5 do begin
      if sqr(i)+sqr(j)<=0 then
        Txr.Pixels[ (i+6) + (j+6)*64 ] := NearestColor(0,0,0)
      else if sqr(i)+sqr(j)<=2 then
        Txr.Pixels[ (i+6) + (j+6)*64 ] := NearestColor(255,255,255)
      else if sqr(i)+sqr(j)<=5 then
        Txr.Pixels[ (i+6) + (j+6)*64 ] := NearestColor(0,0,0);
    end;
    for i := 0 to 8 do for j := -1 to 1 do begin
      if (j<>0) and (i mod 2 <> 1) then
        Txr.Pixels[ (i) + (j+12)*64 ] := NearestColor(255,255,255)
      else
        Txr.Pixels[ (i) + (j+12)*64 ] := NearestColor(0,0,0)
    end;
  end;

  procedure fillf (var w : array of single; full, empty : boolean);
  var
    m : single;

    procedure dow(i : integer);
    begin
      w[i] := (random+1)*0.5*m;
      m := m/2;
    end;

  begin
    if full and (random(4)>0) then begin
      w[0]:=0;w[1]:=0;w[2]:=0;w[3]:=0;w[4]:=0.75;w[5]:=0;
    end else if empty and (random(4)>0) then begin
      w[0]:=0;w[1]:=0;w[2]:=0;w[3]:=0;w[4]:=0;w[5]:=0;
    end else begin
      m := 0.4;
      case random(7) of
        0  : dow(1);
        1  : dow(2);
        2  : dow(3);
        else dow(0);
      end;
      dow(4);
      dow(5);  // шум
    end;
  end;

  procedure Init;
  {
   0 небо
   1 трава
   2 стены
   3 каменный пол
   4 стены верхних этажей
   5 дерево
   6 металлический пол
   7 адЏ
   8 чернота
   9 каменный пол в аду
   10 лампы
   11 стены подземель€
   12 кров€ша
   }
  var
    i,j : integer;
    r : array [0..1,0..64*64-1] of single;
    t : integer;
    tr,tg,tb,tm : integer;
  begin

    CreateTexture(BaseTxr[0], 6, 6);
    ProcessSkyTxr (0);

    CreateTexture(BaseTxr[1], 6, 6);
    FillNoise2(64, 64, r[0]);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[1] do
      Pixels[i shl shlx or j] := NearestColor(100,100+round(r[0,i+j*64]*100),40);

    CreateTexture(BaseTxr[2], 6, 6);
    MakeRandomNoise3(64, 64, 32, r[0]);
    MakeRandomNoise3(64, 64, 3, r[1]);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[2] do begin
      tr := round(r[0,i+j*64]*150)+random(55);
      tg := round(r[0,i+j*64]*100)+random(55);     
      tb := round(200-r[1,i+j*64]*200)+random(55);
      tm := (tr+tg+tb) div 3;                                                              
      Pixels[i shl shlx or j] := NearestColor((tr+tm) div 2, (tg+tm) div 2, (tb+tm) div 2);
    end;

    CreateTexture(BaseTxr[3], 6, 6);
    MakeRandomNoise3(64, 64, 16, r[0]);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[3] do
      Pixels[i shl shlx or j] := NearestColor(round(r[0,i+j*64]*250)+random(5),round(r[0,i+j*64]*220),round(r[0,i+j*64]*150)+random(100));

    CreateTexture(BaseTxr[4], 6, 6);
    MakeRandomNoise1(64, 64, 1, 5, 0.2, r[0]);
    MakeRandomNoise3(64, 64, 3, r[1]);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[4] do
      Pixels[i shl shlx or j] := NearestColor(round(r[0,i+j*64]*255),255,155+round(r[0,i+j*64]*100)-round(r[1,i+j*64]*100));

    CreateTexture(BaseTxr[5], 6, 6);
    MakeRandomNoise1(64, 64, 24, 3, 0.2, r[0]);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[5] do
      Pixels[i shl shlx or j] := NearestColor(
        round(r[0,i+j*64]*255),64,0);

    CreateTexture(BaseTxr[6], 6, 6);
    FillMetalTxr;

    CreateTexture(BaseTxr[7], 6, 6);
    ProcessHellTxr(0);

    CreateTexture(BaseTxr[8], 6, 6);  // тупо чЄрна€
    
    CreateTexture(BaseTxr[9], 6, 6);
    MakeRandomNoise3(64, 64, 64, r[0]);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[9] do
      Pixels[i shl shlx or j] := NearestColor(
        round(r[0,i+j*64]*50)+150+random(51),
        round(r[0,i+j*64]*200)+50,
        round(r[0,i+j*64]*250));

    CreateTexture(BaseTxr[10], 6, 6);
    FillTechTxr(BaseTxr[10], True);
    
    CreateTexture(BaseTxr[11], 6, 6);
    MakeRandomNoise3(64, 64, 32, r[0]);
    MakeRandomNoise3(64, 64, 3, r[1]);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[11] do
      Pixels[i shl shlx or j] := NearestColor(round(r[0,i+j*64]*120)+random(55),30,180-round(r[1,i+j*64]*180));

    CreateTexture(BaseTxr[12], 6, 6);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[12] do
      Pixels[i shl shlx or j] := NearestColor(255, random(255), 0);

    CreateTexture(BaseTxr[13], 6, 6);
    for i := 0 to 63 do for j := 0 to 63 do with BaseTxr[13] do
      Pixels[i shl shlx or j] := NearestColor(0, random(255), 255);


    for t := Low(TechTxr) to High(TechTxr) do begin
      CreateTexture(TechTxr[t], 6, 6);
      FillTechTxr(TechTxr[t], False);
    end;
    for t := Low(AncTxr) to High(AncTxr) do begin
      CreateTexture(AncTxr[t], 6, 6);
      FillAncientTxr(AncTxr[t]);
    end;
    for t := Low(MstrTxr) to High(MstrTxr) do begin
      CreateTexture(MstrTxr[t], 6, 6);
      FillMonsterTxr(MstrTxr[t]);
    end;           
    for t := Low(BoxTxr) to High(BoxTxr) do begin
      CreateTexture(BoxTxr[t], 6, 6);
      FillAncientTxr(BoxTxr[t]);
    end;
  end;

  procedure Finl;
    var i: integer;
  begin
    for i := Low(BaseTxr) to High(BaseTxr) do DestroyTexture(BaseTxr[i]);     
    for i := Low(TechTxr) to High(TechTxr) do DestroyTexture(TechTxr[i]);
    for i := Low(AncTxr)  to High(AncTxr)  do DestroyTexture(AncTxr[i]);
    for i := Low(MstrTxr) to High(MstrTxr) do DestroyTexture(MstrTxr[i]);      
    for i := Low(BoxTxr)  to High(BoxTxr) do DestroyTexture(BoxTxr[i]);
  end;

initialization

  Init;

finalization

  Finl;

end.
