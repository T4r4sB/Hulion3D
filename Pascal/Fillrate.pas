unit Fillrate;

interface

uses
  Bitmaps,Render,Points,EngineTypes;

  procedure Fill (var SI: ShowSectorInfo; F : PFace; const L1,L2 : ScreenLine);

  var
    opId : integer = 0;

implementation

  uses
    Textures;

  function GetRenderFuncValue (const R : RenderFunc; x,y : integer) : float;
  begin
    Result := R.vplt + R.vdx*x + R.vdy*y;
  end;

  procedure CorrectRenderFunc (var R : RenderFunc; sx,sy : integer);
  begin
    R.vdx := R.vdx / sx;
    R.vdy := R.vdy / sy;
    R.vplt := R.vplt + R.vdx*1.0 + R.vdy*0.5;
  end;

  type RenderPoint = record
    x,y : integer;
    w,tx,ty,txw,tyw : float;
  end;

  procedure ShiftRenderPoint(var P: RenderPoint; dx : integer; dw,dtx,dty : float);
  begin
    Inc(P.x, dx);
    P.w  := P.w  + dw;
    P.tx := P.tx + dtx;
    P.ty := P.ty + dty;
  end;

  procedure MakeRenderPoint(var P : RenderPoint; const R : RenderInfo; x,y : integer);
  begin
    P.x  := x;
    P.y  := y;
    P.w  := GetRenderFuncValue(R.w , x, y);
    P.tx := GetRenderFuncValue(R.tx, x, y);
    P.ty := GetRenderFuncValue(R.ty, x, y);
  end;

  procedure PrecomputeRenderPoint (var P: RenderPoint);
  var
    z : float;
  const
    minw = 0.0001;
  begin
    if P.w<minw then z := 1/minw else z := 1/P.w;
    P.txw := P.tx*z;
    P.tyw := P.ty*z;
  end;
                         
  {$IFOPT Q+} {$DEFINE OLD_Q} {$Q-} {$ENDIF}
  procedure LoopDith (
    Px : PColor; w, dw :integer; Pixels : PAInt; cnt : integer;
    tx,dtx,ty,dty,odx,ody,mx,my,sx : integer);
  var
    i : integer;
  begin
    for i := 0 to cnt-1 do begin
      Px^ := FogTable[w shr 16,
        Pixels[
          (((tx+odx) shr 16)and mx) +
          (((ty+odx) shr 16)and my) shl sx
        ]
      ]; 
      Inc(tx,dtx);
      Inc(ty,dty);
      Inc(w, dw);
      odx := odx xor $8000;
      Inc(Px);
    end;
  end;

  procedure LoopNoDith (
    Px : PColor; w, dw :integer; Pixels : PAInt; cnt : integer;
    tx,dtx,ty,dty,mx,my,sx : integer);
  var
    i : integer;
  begin
    // фиксируем уровень тумана
    // выглядит странновато, зато сэкономили ещё 10% от скорости заливки

    for i := 0 to cnt-1 do begin
      Px^ := FogTable[w shr 16,
        Pixels[
          ((tx shr 16)and mx) +
          ((ty shr 16)and my) shl sx
        ]
      ];
      Inc(tx,dtx);
      Inc(ty,dty); 
      Inc(w, dw);
      Inc(Px);
    end;
  end;
  {$IFDEF OLD_Q} {$Q+} {$UNDEF OLD_Q} {$ENDIF}

  function trunc16 (f : single) : integer;
  // for floor(f*65536)
  // FUCKING HACK
  var
    d : integer absolute f;
    e,m : integer;
  begin
    e := (d shr 23) and $FF;
    if e<>0 then
      m := (d and $7FFFFF) or $800000
    else
      m := (d and $7FFFFF) shr 1;
    e := 134-e;    // 127 + 23 - 16 - e
    if e>=32 then result := 0
    else if e>0 then result := m shr e else result := m shl (-e);
    if d<0 then result := -result;
  end;

  procedure RenderLine (var p1, p2 : RenderPoint; withTail : integer; const R : RenderInfo; Px : PColor);
  var
    w,dw,tx,ty,dtx,dty  : integer;
    dx : float;
    odx,ody : integer;
    {
    w1,w2,t : float;
    nx : integer;
    Mid : RenderPoint;
    good : boolean;    }

  const
    MaxAff = 1.1;
  begin
    Inc(opID);
       {
    if p1.x>=p2.x+withTail then exit;
    // diff-depth test
    w1 := p1.w;
    if withTail=1 then w2 := p2.w else w2 := p2.w - R.w.vdx;
    if p1.x<p2.x+withTail-1  then
      dx := 1/(p2.x-p1.x)
    else
      dx := 0;
    nx := p1.x+1;
    if (p1.x+32<p2.x+withTail) and ((w1*MaxAff<w2) or (w2*MaxAff<w1)) then begin         
      nx := p1.x + round( (p2.x-p1.x) * p1.w/(p1.w+p2.w);// (sqrt(p1.w*p2.w)-p1.w) / (p2.w-p1.w) ;
      if nx<=p1.x then nx := p1.x+1;
      MakeRenderPoint(Mid, R, nx, p1.y);
      PrecomputeRenderPoint(Mid);
      t := (nx-p1.x)*dx;
      good
        := ((abs(Mid.txw - (p1.txw + (p2.txw-p1.txw)*t))<0.4)
        and (abs(Mid.tyw - (p1.tyw + (p2.tyw-p1.tyw)*t))<0.4));
    end else
      good := true;
    if good then begin  }
      {$IFOPT Q+} {$DEFINE OLD_Q} {$Q-} {$ENDIF} // один хуй, оно по модулю
      if p1.x<p2.x+withTail-1 then begin
        dx := 1/(p2.x-p1.x);
        dtx := trunc16((p2.txw-p1.txw)*dx);
        dty := trunc16((p2.tyw-p1.tyw)*dx);
        dw  := trunc16((p2.w-p1.w)*dx*32);
      end else begin
        dtx := 0;
        dty := 0;
        dw  := 0;
      end;
      // p[i].w<=8
      w  := trunc16(p1.w*32) + R.Light shl 14;
      if w< 0        then w := 0;
      if w>=$1400000 then w := $13FFFFF;
      // а это блядозащита
      while w+(p2.x+withTail-p1.x-1)*dw <         0 do inc(dw);
      while w+(p2.x+withTail-p1.x-1)*dw >= $1400000 do dec(dw);
      tx := trunc16(p1.txw);
      ty := trunc16(p1.tyw);
      odx   := (p1.x+p1.y) and 1 shl 15;
      ody   := (p1.y+p1.x) and 1 shl 15;
      if R.Txr.Dithering then
        LoopDith(Px, w, dw, R.Txr.Pixels, p2.x+withTail-p1.x, tx,dtx,ty,dty,odx,ody,R.Txr.maskx,R.Txr.masky,R.Txr.shlx)
      else
        LoopNoDith(Px, w, dw, R.Txr.Pixels, p2.x+withTail-p1.x, tx,dtx,ty,dty,R.Txr.maskx,R.Txr.masky,R.Txr.shlx);
      //Px^ := $FF;
      {$IFDEF OLD_Q} {$Q+} {$UNDEF OLD_Q} {$ENDIF}
      {
    end else begin
      RenderLine(p1, Mid, 0       , R, Px);
      Inc(Px, nx-p1.x);
      RenderLine(Mid, p2, WithTail, R, Px);
    end;         }
  end;

  procedure Fill (var SI: ShowSectorInfo; F : PFace; const L1,L2 : ScreenLine);
  var
    // заполнение
    i: integer;
    Line : PAColor;
    y1,y2 : integer;
    P1,P2 : RenderPoint;
    ONTest : Point;
    den : float;
    badLine : boolean;
    Px : PColor;

    nx : integer;
    LAL : integer;
    Mid : RenderPoint;

    RL1, RL2 : ScreenLine;
                       {
    ldx : integer;
    ldw,ldtx,ldty : float;  }
  begin


    Assert((L1.y1=L2.y1) and (L1.y2=L2.y2), 'Borders incompatible!');
    if L1.y1>L2.y1 then y1 := L1.y1 else y1 := L2.y1;
    if L1.y2<L2.y2 then y2 := L1.y2 else y2 := L2.y2;
    Assert((y1>y2) or ((y1>=0) and (y2<SI.B.SizeY)));

    while (y1<=y2) and (L1.x[y1]>=L2.x[y1]) do Inc(y1);
    while (y2>=y1) and (L1.x[y2]>=L2.x[y2]) do Dec(y2);

    if SI.B.sizeX<=400 then LAL :=16 else LAL := 32;

    if y1<=y2 then begin
      if F.NextSector=nil then begin


        Line := PAColor(@SI.B.Pixels[y1*SI.B.stride]);

        if not F.inProcess then begin
          den := 1/(F.INormC-Dot(SI.NTest,F.INorm));

          F.RI.w .vdx  := Dot(SI.DX , F.INorm)*den;
          F.RI.w .vdy  := Dot(SI.DY , F.INorm)*den;
          F.RI.w .vplt := Dot(SI.PLT, F.INorm)*den;

          F.RI.tx.vdx  := Dot(SI.NTest, F.VTx)*F.RI.w.vdx  + Dot(SI.DX ,F.VTx) - F.VTxc*F.RI.w.vdx;
          F.RI.tx.vdy  := Dot(SI.NTest, F.VTx)*F.RI.w.vdy  + Dot(SI.DY ,F.VTx) - F.VTxc*F.RI.w.vdy;
          F.RI.tx.vplt := Dot(SI.NTest, F.VTx)*F.RI.w.vplt + Dot(SI.PLT,F.VTx) - F.VTxc*F.RI.w.vplt;

          F.RI.ty.vdx  := Dot(SI.NTest, F.VTy)*F.RI.w.vdx  + Dot(SI.DX ,F.VTy) - F.VTyc*F.RI.w.vdx;
          F.RI.ty.vdy  := Dot(SI.NTest, F.VTy)*F.RI.w.vdy  + Dot(SI.DY ,F.VTy) - F.VTyc*F.RI.w.vdy;
          F.RI.ty.vplt := Dot(SI.NTest, F.VTy)*F.RI.w.vplt + Dot(SI.PLT,F.VTy) - F.VTyc*F.RI.w.vplt;

          CorrectRenderFunc(F.RI.w , SI.B.sizeX, SI.B.sizeY);
          CorrectRenderFunc(F.RI.tx, SI.B.sizeX, SI.B.sizeY);
          CorrectRenderFunc(F.RI.ty, SI.B.sizeX, SI.B.sizeY);

          F.RI.Txr   := F.Texture;
          F.RI.Light := F.Light;

          F.inProcess := True;
          Inc(SI.CPF);
          SI.PF[SI.CPF-1] := F;
        end;

        for i := y1 to y2 do begin

          Assert((L1.x[i]>=0) and (L2.x[i]<=SI.B.sizeX));

          if L1.x[i]<L2.x[i] then begin
            MakeRenderPoint(P1, F.RI, L1.x[i]  , i);
            MakeRenderPoint(P2, F.RI, L2.x[i]-1, i);

            badLine := false;
            while (P1.w<0) or (P1.w>8) do begin   // 0.125 - минимальная глубина в поле зрения
              Inc(P1.x);
              if P1.x>P2.x then begin badLine := True; break; end;
              P1.w  := P1.w  + F.RI.w .vdx;
              P1.tx := P1.tx + F.RI.tx.vdx;
              P1.ty := P1.ty + F.RI.ty.vdx;
            end;
            if not badLine then begin
              while (P2.w<0) or (P2.w>8) do begin
                Dec(P2.x);
                if P1.x>P2.x then begin badLine := True; break; end;
                P2.w  := P2.w  - F.RI.w .vdx;
                P2.tx := P2.tx - F.RI.tx.vdx;
                P2.ty := P2.ty - F.RI.ty.vdx;
              end;

              if not badLine then begin
                PrecomputeRenderPoint(P1);
                PrecomputeRenderPoint(P2);
                Px := @Line[P1.x];
                                      {
                ldx  := LAL;
                ldw  := F.RI.w .vdx*LAL;
                ldtx := F.RI.tx.vdx*LAL;
                ldty := F.RI.ty.vdx*LAL;   }

                if SI.OnlyAff then
                  RenderLine(P1,P2,1,F.RI,Px)
                else repeat
                  nx := (p1.x+LAL) and not (LAL-1);
                  if nx<=P2.x then begin
                    {if nx=P1.x+LAL then begin
                      Mid := P1;                  
                      ShiftRenderPoint(Mid, ldx,ldw,ldtx,ldty);
                    end else       }
                      MakeRenderPoint(Mid, F.RI, nx, p1.y);
                    PrecomputeRenderPoint(Mid);
                    RenderLine(P1, Mid, 0, F.RI, Px);
                    Inc(Px, nx-p1.x);
                    P1 := Mid;
                  end else begin
                    RenderLine(P1,P2,1,F.RI,Px);
                    break;
                  end;
                until false; 
              end;
            end;
          end;
          Line := PAColor(@Line[SI.B.stride]);
        end;
      end else begin
        if F.NextSector.inProcess=0 then begin
          // тадададам
          RL1 := L1;
          RL2 := L2;
          RL1.y1 := y1; RL1.y2 := y2;
          RL2.y1 := y1; RL2.y2 := y2;

          if F.NextSector.Skybox then begin
            ONTest := SI.NTest;
            SI.NTest := ToPoint(0,0,0);
            ShowSector(SI, F.NextSector^, RL1, RL2);
            SI.NTest := ONTest;
          end else begin
            ShowSector(SI, F.NextSector^, RL1, RL2);
          end;
        end;
      end;
    end;      
  end;

end.

