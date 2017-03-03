unit Render;

interface

uses
  Bitmaps, Points, Level, EngineTypes;

const
  mind = 0.001;

type
  ScreenLine = record
    f1,f2 : PFace;
    y1,y2: integer;
    x : PAInt;
  end;

  ShowSectorInfo = record
    B: Bitmap;
    M: Matrix;
    NTest : Point;
    PLT, DX,DY : Point;
    CPF : integer;
    PF : PAPFace;
    OnlyAff : boolean;
  end;
                                 
  procedure NewScreenLine (var SL: ScreenLine; f1,f2 : PFace; y1,y2: integer);
  procedure ShowLevel(var B: Bitmap; var L: Lab; vx,vy : float);
  procedure ShowSector (var SI: ShowSectorInfo; const S: Sector; const Left,Right : ScreenLine);

  var
    MainL, MainR : ScreenLine;
                  
implementation

  uses
    Memory, Fillrate, Collisions;

  type
    AScreenLine = array [0 .. MaxInt div sizeof(ScreenLine) - 1] of ScreenLine;
    PAScreenLine = ^AScreenLine;
    PInt = ^integer;

  procedure NewScreenLine (var SL: ScreenLine; f1,f2 : PFace; y1,y2: integer);
  begin
    {$IFOPT R+} {$DEFINE OLD_R} {$R-} {$ENDIF}
    SL.f1 := f1;
    SL.f2 := f2;
    SL.y1 := y1;
    SL.y2 := y2;
    SL.x := PAInt(@(PAInt(Alloc((y2-y1+1)*sizeof(integer)))[-y1]));
    {$IFDEF OLD_R} {$R+} {$UNDEF OLD_R} {$ENDIF}
  end;

  procedure ShowSector (var SI: ShowSectorInfo; const S: Sector; const Left,Right : ScreenLine);
  var
    i : integer;
    CL : integer;
    Lines : PAScreenLine;
    MS : MemoryState;

    CC : integer;
    CP : PAPConvex;
    CS : PConvexInSector;

    procedure ShowLine (const L : Line);
    const
      projeps = 0.001;
    var
      p1,p2 : Point;
      f1,f2 : PFace;
      i,j: integer;
      t1,t2: float;
      x1,y1,x2,y2,x : float;
      ty1,ty2,py1,py2 : integer;
      MW,MH: float;
      lx : PInt;
      x16,dx16 : integer;

      procedure SwapFloat (var f1,f2: float);  var tmp : float;
        begin tmp := f1;f1 := f2;f2 := tmp; end;
      procedure SwapPFace (var f1,f2: PFace);  var tmp : PFace;
        begin tmp := f1;f1 := f2;f2 := tmp; end;
      procedure SwapPoint (var f1,f2: Point);  var tmp : Point;
        begin tmp := f1;f1 := f2;f2 := tmp; end;

      procedure CheckBorders (var L: ScreenLine; ty1, ty2 : integer);
      begin
        if L.y1>ty1 then L.y1:=ty1;
        if L.y2<ty2-1 then L.y2:=ty2-1;
      end;

      const
        cut  : array [0..4] of Point = ((x:0;y:0;z:1),(x:0;y:-1;z:1),(x:0;y:1;z:1),(x:-1;y:0;z:1),(x:1;y:0;z:1));
        cutd : array [0..4] of float = (-mind, 0, 0, 0, 0);

      procedure Correct(var P: Point; const Cut : Point; cutd : float);
      begin
        P.z := (cutd - p.x*cut.x - p.y*cut.y)/cut.z;
      end;

    begin
      p1 := RotateP(SI.M, L.p1^, S.Skybox);
      p2 := RotateP(SI.M, L.p2^, S.Skybox);
      f1 := L.f1;
      f2 := L.f2;
      MW := SI.B.sizeX-projeps*2;
      MH := SI.B.sizeY-projeps*2;
      py1 := SI.B.sizeY; py2 := -1;
      for i := Low(cut) to High(cut) do begin
        t1 := Dot(p1, cut[i]) + cutd[i];
        t2 := Dot(p2, cut[i]) + cutd[i];
        if (t1<0) and (t2<0) then begin
          if i=3 then for j := py1 to py2-1 do Lines[CL-1].x[j] := Right.x[j];
          if i=4 then for j := py1 to py2-1 do Lines[CL-1].x[j] := Left.x[j];
          exit;
        end;
        if t1<0 then begin p1 := Mid(p1, -t1, p2, t2); Correct(p1, cut[i], cutd[i]); end;
        if t2<0 then begin p2 := Mid(p2, -t2, p1, t1); Correct(p2, cut[i], cutd[i]); end;

        if i=2 then begin
          y1 := MH*(p1.y+p1.z)/(p1.z+p1.z)-0.5+projeps;
          y2 := MH*(p2.y+p2.z)/(p2.z+p2.z)-0.5+projeps;
          if y1>y2 then begin SwapFloat(y1,y2); SwapPFace(f1,f2); SwapPoint(p1,p2); end;
          // подстрахериться надо, потому что single такой single...
          py1 := trunc(y1+1);
          py2 := trunc(y2+1);

          if py1<Left.y1   then py1 := Left.y1;
          if py2>Left.y2+1 then py2 := Left.y2+1;

          if py1<py2 then begin
            Inc(CL);
            NewScreenLine(Lines[CL-1], f1, f2, py1, py2-1);
            CheckBorders(Lines[f1.Id*2], py1,py2);
            CheckBorders(Lines[f2.Id*2], py1,py2);
          end else exit;
        end;
      end;
      x1 := MW*(p1.x+p1.z)/(p1.z+p1.z)-0.5+projeps;
      y1 := MH*(p1.y+p1.z)/(p1.z+p1.z)-0.5+projeps;
      x2 := MW*(p2.x+p2.z)/(p2.z+p2.z)-0.5+projeps;
      y2 := MH*(p2.y+p2.z)/(p2.z+p2.z)-0.5+projeps;

      // это границы по вертикали от той части, что чисто в экране
      ty1 := trunc(y1+1);
      ty2 := trunc(y2+1);

      if ty1<Left.y1   then ty1 := Left.y1;
      if ty1>Left.y2+1 then ty1 := Left.y2+1;
      if ty2<Left.y1   then ty2 := Left.y1;
      if ty2>Left.y2+1 then ty2 := Left.y2+1;


      // и по между истиными и видимыми границами надо заполнить пространство
      if      x1<           0 then for j := py1 to ty1-1 do Lines[CL-1].x[j] := Left.x[j]
      else if x1>SI.B.sizeX-1 then for j := py1 to ty1-1 do Lines[CL-1].x[j] := Right.x[j];
      if      x2<           0 then for j := ty2 to py2-1 do Lines[CL-1].x[j] := Left.x[j]
      else if x2>SI.B.sizeX-1 then for j := ty2 to py2-1 do Lines[CL-1].x[j] := Right.x[j];

      if ty1<ty2 then begin
        x := x1 + (x2-x1)*(ty1-y1)/(y2-y1);
        LX := @Lines[CL-1].x[ty1];
        LX^ := round(x);
        if ty1+1<ty2 then begin
          x16 := round(x*$10000);
          dx16 := round((x2-x1)/(y2-y1)*$10000);
          for j := ty1+1 to ty2-1 do begin
            x16 := x16 + dx16;
            Inc(LX);
            LX^ := SmallInt(x16 shr 16);
          end;
        end;
      end;
    end;

    procedure DrawLine (const L: ScreenLine);
    var
      i:integer;
      Lx, Rx, Cx : PInt;
    begin
      Assert(Lines[L.f1.Id*2  ].y1<=L.y1);
      Assert(Lines[L.f1.Id*2  ].y2>=L.y2);
      Assert(Lines[L.f2.Id*2+1].y1<=L.y1);
      Assert(Lines[L.f2.Id*2+1].y2>=L.y2);
      Cx := @L.x[L.y1];
      Rx := @Lines[L.f1.Id*2  ].x[L.y1];
      Lx := @Lines[L.f2.Id*2+1].x[L.y1];
      for i := L.y1 to L.y2 do begin
        if Rx^<Cx^ then Rx^ := Cx^;
        if Lx^>Cx^ then Lx^ := Cx^;
        Inc(Cx);
        Inc(Rx);
        Inc(Lx);
      end;
    end;

    procedure MarkLine (var B: Bitmap; const L: ScreenLine);
    var
      i: integer;
      Line : PAColor;
    begin
      Line := B.Pixels;
      Line := PAColor(@Line[L.y1*B.stride]);
      for i := L.y1 to L.y2 do begin
        if L.x[i]<B.sizeX then Line[L.x[i]] := $FF;
        Line := PAColor(@Line[B.stride]);
      end;
    end;

    procedure Init2Lines (var L1, L2 : ScreenLine; const Left, Right : ScreenLine);
    begin
      if L1.y1<=L1.y2 then begin
        NewScreenLine(L1, nil, nil, L1.y1, L1.y2);
        NewScreenLine(L2, nil, nil, L1.y1, L1.y2);
        Move(Left .x[L1.y1], L1.x[L1.y1], (L1.y2-L1.y1+1)*sizeof(integer));
        Move(Right.x[L2.y1], L2.x[L2.y1], (L2.y2-L2.y1+1)*sizeof(integer));
      end;
    end;

    // я использую шаблоны ололо
    type T=PConvex;

    function Less(L,R:PConvex):boolean;
    var
      p1,p2 : Point;
    begin
      p1 := RotateP(SI.M, L.Center.P, S.Skybox);
      p2 := RotateP(SI.M, R.Center.P, S.Skybox);
      Result := p1.z>p2.z;
    end;

    {$I qsort.inc}

  begin
    SaveState(MS);

    Lines := Alloc((S.CLines*2+S.CFaces*2)*sizeof(ScreenLine));
    CL := S.CFaces*2; // зарезервируем запас для линий-границ зон
    for i := 0 to S.CFaces*2-1 do begin      // изначально - типа пустые линии
      Lines[i].y1 := Left.y2+1;
      Lines[i].y2 := Left.y1-1;
    end;
    
    for i := 0 to S.CLines-1 do begin
      Assert(S.Lines[i].f1.id in [0..S.CFaces-1]);
      Assert(S.Lines[i].f2.id in [0..S.CFaces-1]);
      ShowLine (S.Lines[i]);
    end;
          
    for i := 0 to S.CFaces-1 do
      Init2Lines(Lines[i*2], Lines[i*2+1], Left, Right);

    for i := S.CFaces*2 to CL-1 do if Lines[i].y1<=Lines[i].y2 then
      DrawLine(Lines[i]);

    // тут надо отметить все предметы
    CC := 0;
    CS := S.FConvex;
    while CS<>nil do begin
      if not CS.Convex.inProcess then Inc(CC);
      CS := CS.NC;
    end;
    // загоняем в массив
    CP := Alloc(CC*sizeof(PConvex));
    i := 0;              
    CS := S.FConvex;
    while CS<>nil do begin
      if not CS.Convex.inProcess then begin
        CP[i] := CS.Convex;
        Inc(i);
      end;
      CS := CS.NC;
    end;
    Sort(CP^, 0, CC-1);

    for i := 0 to CC-1 do CP[i].inProcess := True;

    for i := 0 to S.CFaces-1 do with S.Faces[i] do begin
      if (NextSector<>nil) and (NextSector.inProcess=1) then begin
        NextSector.inProcess := 2;
        ShowSector(SI, NextSector^, MainL, MainR);
      end;
    end;
    
    for i := 0 to S.CFaces-1 do with S.Faces[i] do begin
      if Dot(SI.NTest, INorm)-INormC<0 then
        Fill(SI, @S.Faces[i], Lines[i*2], Lines[i*2+1]);
    end;

    // тут надо снять отметки с предметов и отрисовать их
    SI.OnlyAff := True;
    for i := 0 to CC-1 do begin
      Assert(not CP[i].G.Skybox);
      ShowSector(SI, CP[i].G, Left, Right);
      CP[i].inProcess := False;
    end;   
    SI.OnlyAff := False;
                  {
    for i := S.CFaces*2 to CL-1 do if Lines[i].y1<=Lines[i].y2 then
      MarkLine(B, Lines[i]);  }

    RestoreState(MS);
  end;

  procedure ShowLevel(var B: Bitmap; var L: Lab; vx,vy : float);
  var
    RevM : Matrix;
    i : integer;
    MS : MemoryState;
    ViewP: Point;     
    CPS : integer;
    PS  : PAPSector;
    ax,az : float;

    SI : ShowSectorInfo;

    RB : Bitmap;

  begin
    RB := B;
    RB.Pixels := PAColor(@B.Pixels[(B.sizeY div 4)*B.stride]);
    RB.sizeY  := (B.sizeY - B.sizeY div 4);


    SetID(SI.M);

    ViewP := L.Player.Item.Convexes[0].Center.P;
    ax := L.Player.anglex;
    az := L.Player.anglez;

    Translate(SI.M, Scale(ViewP,-1));
    Rotate(SI.M, 2, az);
    Rotate(SI.M, 0, ax);
    ScaleM(SI.M, ToPoint(1/vx,1/vy,1));

    SetID(RevM);
    ScaleM(RevM, ToPoint(vx,vy,1));
    Rotate(RevM, 0, -ax);
    Rotate(RevM, 2, -az);

    SaveState(MS);
    NewScreenLine(MainL, nil, nil, 0, RB.sizeY-1);
    NewScreenLine(MainR, nil, nil, 0, RB.sizeY-1);
    for i := 0 to RB.sizeY-1 do begin
      MainL.x[i] := 0;
      MainR.x[i] := RB.sizeX;
    end;

    SI.B     := RB;
    SI.NTest := ViewP;
    SI.PLT   := RotateP(RevM, ToPoint(-1,-1, 1));
    SI.DX    := RotateP(RevM, ToPoint( 2, 0, 0));
    SI.DY    := RotateP(RevM, ToPoint( 0, 2, 0));
    SI.CPF   := 0;
    SI.PF    := Alloc(CSectors*14*sizeof(PFace));
    SI.OnlyAff := False;

    // это знаете что? это костыль такой, на случай, если мы сидим на стыке секторов

    PS := Alloc(CSectors*sizeof(PSector));
    GetSectors (L.Player.Item.Convexes[0].Center, Render.mind*2, False, CPS, PS);

    L.Player.Item.Convexes[0].Center.S.inProcess := 2;
    ShowSector(SI, L.Player.Item.Convexes[0].Center.S^, MainL, MainR);

    Unprocess(CPS, PS);
    for i := 0 to SI.CPF-1 do SI.PF[i].inProcess := false;

    RestoreState(MS);
  end;

end.
