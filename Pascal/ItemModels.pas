unit ItemModels;

interface

uses
  Points, EngineTypes;

var
  IMPlayer   : ItemModel;
  IMSnowman  : array [0.. 7] of ItemModel;
  IMTrilobit : array [0..15] of ItemModel;
  IMGasbag   : array [0.. 7] of ItemModel;
  IMBox      : array [0.. 4] of ItemModel;
  IMCock     : array [0.. 7] of ItemModel;
  IMBoss     : array [0.. 0] of ItemModel;

  procedure AddPc(LI : integer; var Pc : integer; Pts : PAInt; i1,i2,i3 : integer; k,m : integer); 
  procedure AddSphere (LI : integer; var Pc : integer; Pts : PAInt);           
  procedure MoveSphere (Pts : PAItemPoint; const C: Point; const M: Matrix; txsx,txsy : float);
  procedure AddSeg (LI : integer; var Pc : integer; Pts : PAInt);               
  procedure MoveSeg (Pts : PAItemPoint; const C: Point; const M: Matrix; txsx,txsy : float);

implementation

uses
  Textures, Memory, Monsters, WeaponModels;

  procedure AddPc(LI : integer; var Pc : integer; Pts : PAInt; i1,i2,i3 : integer; k,m : integer);
  var
    t : integer;
  begin
    if k=1 then begin
      i1 := m-1-i1;
      i2 := m-1-i2;
      i3 := m-1-i3;
      t := i2; i2 := i1; i1 := t;
    end;

    Pts[Pc+0] := i1+LI;
    Pts[Pc+1] := i2+LI;
    Pts[Pc+2] := i3+LI;
    Pts[Pc+3] := -1;
    Inc(Pc,4);
  end;

  procedure AddSphere (LI : integer; var Pc : integer; Pts : PAInt);
  var
    i,k : integer;
  begin             
    for k := 0 to 1 do begin
      AddPc(LI,Pc,Pts, 1,6,2, k,12);
      AddPc(LI,Pc,Pts, 0,5,9, k,12);
      AddPc(LI,Pc,Pts, 0,9,1, k,12);
      for i := 0 to 3 do AddPc(LI,Pc,Pts, 0, i+1, i+2,  k, 12);
      for i := 0 to 2 do AddPc(LI,Pc,Pts, 1, i+7, i+6,  k, 12);
    end;
    Pts[Pc+0] := -2;
    Inc(Pc);
  end;

  procedure MoveSphere (Pts : PAItemPoint; const C: Point; const M: Matrix; txsx,txsy : float);
  var
    i : integer;
  begin
    Pts[ 0].iP := ToPoint( 0.0, 0.5, 1.0);
    Pts[ 1].iP := ToPoint( 0.0,-0.5, 1.0);
    Pts[10].iP := ToPoint( 0.0, 0.5,-1.0);
    Pts[11].iP := ToPoint( 0.0,-0.5,-1.0);

    for i := 0 to 3 do
      Pts[i+2].iP := ToPoint(cos( (i+0)*2*Pi/8), sin( (i+0)*2*Pi/8), 0.0);
    for i := 0 to 3 do
      Pts[i+6].iP := ToPoint(cos(-(i+1)*2*Pi/8), sin(-(i+1)*2*Pi/8), 0.0);

    for i := 0 to 11 do begin
      Pts[i].tx := (Pts[i].iP.y+1)*12 + txsx;
      Pts[i].ty := (Pts[i].iP.z+1)*12 + txsy;
      Pts[i].iP := Add(C,  RotateP(M, Pts[i].iP));
    end;
  end;

  procedure AddSeg (LI : integer; var Pc : integer; Pts : PAInt);
  begin
    AddPC(LI,Pc,Pts, 0,1,2, 0,0);
    AddPC(LI,Pc,Pts, 0,2,3, 0,0);
    AddPC(LI,Pc,Pts, 0,3,1, 0,0);
    AddPC(LI,Pc,Pts, 4,2,1, 0,0);
    AddPC(LI,Pc,Pts, 4,3,2, 0,0);
    AddPC(LI,Pc,Pts, 4,1,3, 0,0);
    Pts[Pc+0] := -2;
    Inc(Pc);
  end;

  procedure MoveSeg (Pts : PAItemPoint; const C: Point; const M: Matrix; txsx,txsy : float);
  var
    i : integer;
  begin
    Pts[ 0].iP := ToPoint( 0.0, 0.0, 1.0);
    for i := 0 to 2 do
      Pts[i+1].iP := ToPoint(cos(i*2*Pi/3), sin(i*2*Pi/3), 0);
    Pts[ 4].iP := ToPoint( 0.0, 0.0,-1.0);

    for i := 0 to 4 do begin
      Pts[i].tx := (Pts[i].iP.y+1)*12 + txsx;
      Pts[i].ty := (Pts[i].iP.z+1)*12 + txsy;
      Pts[i].iP := Add(C,  RotateP(M, Pts[i].iP));
    end;
  end;

  const
    cnPlayer : array [0..2] of integer = (-2,-2,-2);

  procedure CorrectMonsterColliders (var it : Item);
  begin
    it.Monster.Head := @it.Convexes[0].Center;
    it.Monster.Body := @it.Convexes[1].Center;
    it.Monster.Legs := @it.Convexes[2].Center;
    it.Center := it.Monster.Legs^;
    it.Convexes[0].CanCollide := Live(it.Monster^);
    it.Convexes[0].Shift      := Sub(it.Monster.Head.P, it.Monster.Legs.P);
    it.Convexes[0].R          := it.Model.HeadR;
    it.Convexes[1].CanCollide := Live(it.Monster^);
    it.Convexes[1].Shift      := Sub(it.Monster.Body.P, it.Monster.Legs.P); 
    it.Convexes[1].R          := it.Model.BodyR;
    it.Convexes[2].CanCollide := Live(it.Monster^);
    it.Convexes[2].Shift      := ToPoint(0,0,0);
    it.Convexes[2].R          := it.Model.LegsR;
  end;

  procedure ProcPlayer (var it : Item);
  begin
    CorrectMonsterColliders(it);
    SetID(it.Position);
    Translate(it.Position, it.Center.P);
  end;

  procedure InitPlayers;
  var
    i : integer;
  begin
    with IMPlayer do begin
      Kind        := mkMonster;
      Name        := 'Player';
      CPoints     := 0;
      CConvexes   := 3;
      Connections := PAInt(@cnPlayer);
      ItemProc    := ProcPlayer;
      Texture     := nil;

      Player    := True;
      InitialHealths := 100;
      Mass      := 1.0;
      HeadR     := 0.25;
      BodyR     := 0.35;
      LegsR     := 0.35;
      HB        := 0.5;
      MinBL     := 0;
      MaxBL     := 0.6;
      Speed     := 5;
      Spring    := 6;
      Lightness := 0;
      for i := 0 to 9 do begin
        WeaponModels[i]     := nil;
        DefaultHasWeapon[i] := false;
      end;
      WeaponModels     [1] := @IMWeapon[0];
      DefaultHasWeapon [1] := true;
    end;
  end;

  procedure ProcSnowman (var it : Item);
  var
    M: Matrix;
  begin
    if it.Monster.DeathStage=0 then begin
      it.Position[3] := it.Center.P;
      Exit;
    end;

    CorrectMonsterColliders(it);
    SetID(M);
    ScaleM(M, ToPoint(it.Model.HeadR+0.02,it.Model.HeadR+0.02,it.Model.HeadR+0.02));
    MoveSphere(PAItemPoint(@it.ItemPoints[ 0]), Sub(it.Monster.Head.P, it.Monster.Legs.P), M, 0,0);
    SetID(M);
    ScaleM(M, ToPoint(it.Model.BodyR+0.02,it.Model.BodyR+0.02,it.Model.BodyR+0.02));
    MoveSphere(PAItemPoint(@it.ItemPoints[12]), Sub(it.Monster.Body.P, it.Monster.Legs.P), M, 0,16);
    MoveSphere(PAItemPoint(@it.ItemPoints[24]), ToPoint(0,0,0), M, 0,32);

    SetID(it.Position);
    Rotate(it.Position, 2, Pi-it.Monster.anglez);
    Translate(it.Position, it.Center.P);
  end;

  procedure InitSnowmans;
  var
    i,j : integer;
    r : float;
    CC : integer;
  begin
    for j := Low(IMSnowman) to High(IMSnowman) do with IMSnowman[j] do begin               
      Kind        := mkMonster;
      Name        := 'Snowman';
      CPoints     := 36;
      CConvexes   := 3;
      Connections := Alloc((4*20+1)*3*sizeof(Integer));
      CC := 0;
      for i := 0 to 2 do AddSphere(i*12, CC, Connections);
      ItemProc    := ProcSnowman;
      Texture     := @MstrTxr[random(Length(MstrTxr))];

      r := 0.8+random*0.5;

      InitialHealths := 20+80*j/High(IMSnowman);
      Player    := False;
      Mass      := 0.1*r;
      HeadR     := 0.15*r;
      BodyR     := 0.25*r;
      LegsR     := 0.25*r;
      HB        := 0.45*r;
      MinBL     := 0.001*r;
      MaxBL     := 0.4*r;
      Speed     := 2;
      Spring    := 0;
      Lightness := 0;
      for i := 0 to 9 do begin
        WeaponModels[i]     := nil;
        DefaultHasWeapon[i] := false;
      end;
      WeaponModels     [1] := @IMWeapon[4];
      DefaultHasWeapon [1] := true;
    end;
  end;

  procedure ProcTrilobit (var it : Item);
  var
    M : Matrix;
    i : integer;
    s : float;
    o : boolean;
  begin
    if it.Monster.DeathStage=0 then begin
      it.Position[3] := it.Center.P;
      Exit;
    end;

    s := Sin(it.Monster.Stepstage*15);
    CorrectMonsterColliders(it);
    for i := 3 to 8 do begin
      o := (i mod 2 = 0) xor (i<6);
      it.Convexes[i].CanCollide := False;
      it.Convexes[i].Shift      := Scale(ToPoint(
        (i div 6 - 0.5)*0.7,
        (i mod 3-1)*0.1 - (Integer(o) - 0.5)*0.2*s*(i div 6-0.5),
        0.1), it.Model.HeadR*4);
      it.Convexes[i].R          := it.Model.HeadR;
    end;
    SetID(M);
    ScaleM(M, Scale(ToPoint(1.0,1.0,0.6),it.Model.HeadR));
    Translate(M, ToPoint(0,0,0));
    MoveSphere(PAItemPoint(@it.ItemPoints[0]), ToPoint(0, 0, 0), M, 0,4);
    for i := 0 to 5 do begin
      o := (i mod 2 = 0) xor (i<3);
      SetID(M);
      ScaleM(M, Scale(ToPoint(0.03,0.03,0.2),it.Model.HeadR*4));
      Rotate(M, 0, Pi/2);
      Rotate(M, 2, Pi/2 + (Integer(o) - 0.5)*s);
      Translate(M, it.Convexes[i+3].Shift);
      MoveSeg(PAItemPoint(@it.ItemPoints[12+i*5]), ToPoint(0, 0, 0), M, 0,32);
    end;

    SetID(it.Position);           
    if not Live(it.Monster^) then
      Rotate(it.Position, 1, (it.Monster.DeathStage+1)*Pi);
    Rotate(it.Position, 2, Pi-it.Monster.anglez);
    Translate(it.Position, it.Center.P);
  end;

  procedure InitTrilobits;
  var
    i,j       : integer;
    CC,MaxCC  : integer;
    r         : float;
  begin
    for j := Low(IMTrilobit) to High(IMTrilobit) do with IMTrilobit[j] do begin          
      Kind        := mkMonster;
      Name        := 'Trilobit';
      CPoints     := 12+6*5;
      CConvexes   := 9;
      MaxCC := 4*20+3 + (6*4+1)*6;
      Connections := Alloc(MaxCC*sizeof(Integer));
      CC := 0;
      Connections[CC+0] := -2;
      Connections[CC+1] := -2;
      Inc(CC,2);
      AddSphere(0, CC, Connections);
      for i := 0 to 5 do AddSeg(12+i*5, CC, Connections);
      Assert(CC<=MaxCC);
      ItemProc    := ProcTrilobit;
      Texture     := @MstrTxr[random(Length(MstrTxr))];

      r := 1.0;// + random*1.0;
                                  
      InitialHealths := 30+100*j/High(IMTrilobit);
      Player    := False;
      Mass      := 0.1*r;
      HeadR     := 0.3*r;
      BodyR     := 0.3*r;
      LegsR     := 0.3*r;
      HB        := 0.1*r;
      MinBL     := 0*r;
      MaxBL     := 0.0*r;
      Speed     := 2;
      Spring    := 0;
      Lightness := 0;
      for i := 0 to 9 do begin
        WeaponModels[i]     := nil;
        DefaultHasWeapon[i] := false;
      end;
      WeaponModels     [1] := @IMWeapon[2];
      DefaultHasWeapon [1] := true;
    end;
  end;

  function HealthApplyItemProc (M : PMonster; It : PItem) : boolean;
  begin
    Result := M.Health<M.Item.Model.InitialHealths;
    if Result then begin
      M.Health := M.Health+10;
      if M.Health>M.Item.Model.InitialHealths then
        M.Health := M.Item.Model.InitialHealths;
    end;
  end;

  function BigHealthApplyItemProc (M : PMonster; It : PItem) : boolean;
  begin
    Result := M.Health<M.Item.Model.InitialHealths+100;
    M.Health := M.Health+100;
    if M.Health>M.Item.Model.InitialHealths+100 then
      M.Health := M.Item.Model.InitialHealths+100;
  end;

  function ArmorApplyItemProc (M : PMonster; It : PItem) : boolean;
  begin
    Result := M.Armor<100;
    M.Armor := M.Armor+10;
    if M.Armor>100 then
      M.Armor := 100;
  end;

  function GunApplyItemProc (M : PMonster; It : PItem) : boolean;
  begin
    Result := True;
    M.Weapons[2].IsWeapon   := True;
    M.Weapons[2].Item.Model := @IMWeapon[7];
  end;

  function BFGApplyItemProc (M : PMonster; It : PItem) : boolean;
  begin
    Result := True;
    M.Weapons[3].IsWeapon   := True;
    M.Weapons[3].Item.Model := @IMWeapon[8];
  end;

  procedure ProcBox (var it : Item);
  var
    i : integer;
    sx,sy,sz : float;
  begin

    sx := 0.12 + frac(it.Model.HeadR*sqrt(2))*0.38;
    sy := 0.12 + frac(it.Model.HeadR*sqrt(3))*0.38;
    sz := 0.50;

    for i := 0 to 7 do with it.ItemPoints[i] do begin
      iP := ToPoint (
        (      (i and 1)*2-1) *it.Model.HeadR*sx,
        (      (i and 2)  -1) *it.Model.HeadR*sy,
        ((3.00-(i and 4)/2-1))*it.Model.HeadR*sz);
      tx := (iP.y+iP.z)*32;
      ty := (iP.x+iP.z)*32;
    end;
    it.Convexes[0].R          := it.Model.HeadR;
    it.Convexes[0].Shift      := ToPoint(0,0,0);
    it.Convexes[0].CanCollide := True;

    SetID(it.Position);
    Translate(it.Position, it.Center.P);
  end;

  procedure InitBoxes;
  var
    j     : integer;
    MaxCC : integer;
    CC    : integer;
    r     : float;
  begin
    for j := Low(IMBox) to High(IMBox) do with IMBox[j] do begin
      Kind        := mkBox;
      Name        := 'Box';
      CPoints     := 8;
      CConvexes   := 1;
      MaxCC       := 4*12+1;
      Connections := Alloc(MaxCC*sizeof(Integer));
      CC := 0;
      AddPc(0, CC, Connections, 1,3,0, 0, 0);
      AddPc(0, CC, Connections, 2,0,3, 0, 0);
      AddPc(0, CC, Connections, 0,4,1, 0, 0);
      AddPc(0, CC, Connections, 5,1,4, 0, 0);
      AddPc(0, CC, Connections, 1,5,3, 0, 0);
      AddPc(0, CC, Connections, 7,3,5, 0, 0);
      AddPc(0, CC, Connections, 7,6,3, 0, 0);
      AddPc(0, CC, Connections, 2,3,6, 0, 0);
      AddPc(0, CC, Connections, 2,6,0, 0, 0);
      AddPc(0, CC, Connections, 4,0,6, 0, 0);
      AddPc(0, CC, Connections, 5,4,7, 0, 0);
      AddPc(0, CC, Connections, 6,7,4, 0, 0);   
      Connections[CC] := -2;
      Inc(CC);
      Assert(CC<=MaxCC);

      ItemProc    := ProcBox;
      Texture     := @BoxTxr[j];

      r := 0.3 + 0.1*j/High(IMBox);
      Mass  := 1;
      HeadR := r*2;

      case j of
        0 : ApplyItemProc := HealthApplyItemProc;
        1 : ApplyItemProc := BigHealthApplyItemProc;
        2 : ApplyItemProc := ArmorApplyItemProc;
        3 : ApplyItemProc := GunApplyItemProc;
        4 : ApplyItemProc := BFGApplyItemProc;
        else ApplyItemProc := nil;
      end;
    end;
  end;

  procedure ProcGasbag (var it : Item);
  var
    M : Matrix;
  begin             
    if it.Monster.DeathStage=0 then begin
      it.Position[3] := it.Center.P;
      Exit;
    end;
    CorrectMonsterColliders(it);
    SetID(M);
    ScaleM(M, ToPoint(it.Model.HeadR+0.02,it.Model.HeadR+0.02,it.Model.HeadR+0.02));
    MoveSphere(it.ItemPoints, ToPoint(0,0,0), M, 2, -8);
    SetID(it.Position);
    Rotate(it.Position, 2, Pi-it.Monster.anglez);
    Translate(it.Position, it.Center.P);
  end;

  procedure InitGasbags;
  var
    j,i : integer;
    r : float;
    CC : integer;
  begin
    for j := Low(IMGasbag) to High(IMGasbag) do with IMGasbag[j] do begin
      Kind        := mkMonster;
      Name        := 'Gasbag';
      CPoints     := 12;
      CConvexes   := 3;
      Connections := Alloc((4*20+3)*sizeof(Integer));
      CC := 0;
      AddSphere(0, CC, Connections);
      Connections[CC+0] := -2;
      Connections[CC+1] := -2;
      Inc(CC,2);

      ItemProc    := ProcGasbag;
      Texture     := @MstrTxr[random(Length(MstrTxr))];

      r := 1+random;

      InitialHealths := 120+100*j/High(IMGasbag);
      Player    := False;
      Mass      := 0.1*r;
      HeadR     := 0.25*r;
      BodyR     := 0.25*r;
      LegsR     := 0.25*r;
      HB        := 0*r;
      MinBL     := 0*r;
      MaxBL     := 0*r;
      Speed     := 3;
      Spring    := 0;
      Lightness := 1;
      for i := 0 to 9 do begin
        WeaponModels[i]     := nil;
        DefaultHasWeapon[i] := false;
      end;   
      WeaponModels     [1] := @IMWeapon[4+integer(j*2>High(IMCOck))];
      DefaultHasWeapon [1] := true;
    end;
  end;

  procedure ProcCock(var it:Item);
  var
    M : Matrix;
    i : integer;
    s : float;
  begin           
    if it.Monster.DeathStage=0 then begin
      it.Position[3] := it.Center.P;
      Exit;
    end;
    s := Sin(it.Monster.Stepstage*15);
    CorrectMonsterColliders(it);
    for i := 0 to 1 do begin
      it.Convexes[i+3].CanCollide := False;
      it.Convexes[i+3].Shift      := Scale(ToPoint(
        (i-0.5)*0.2, 0, 0.0
      ), it.Model.HeadR*4);
      it.Convexes[i+3].R          := it.Model.HeadR;
    end;
    SetID(M);
    ScaleM(M, Scale(ToPoint(0.6,1.0,1.0),it.Model.HeadR));
    Translate(M, it.Convexes[0].Shift);
    MoveSphere(PAItemPoint(@it.ItemPoints[0]), ToPoint(0, 0, 0), M, -2,0);
    for i := 0 to 1 do begin
      SetID(M);
      Rotate(M, 1, s*0.5);
      ScaleM(M, Scale(ToPoint(0.32,0.32,0.8),it.Model.HeadR));
      Translate(M, it.Convexes[i+3].Shift);
      MoveSeg(PAItemPoint(@it.ItemPoints[12+i*5]), ToPoint(0, 0, 0), M, 0,32);
    end;

    SetID(it.Position);                            
    if not Live(it.Monster^) then
      Rotate(it.Position, 1, (it.Monster.DeathStage+1)*Pi/2);
    Rotate(it.Position, 2, Pi-it.Monster.anglez);
    Translate(it.Position, it.Center.P);
  end;

  procedure InitCocks;
  var
    i,j       : integer;
    CC,MaxCC  : integer;
    r         : float;
  begin
    for j := Low(IMCock) to High(IMCock) do with IMCock[j] do begin
      Kind        := mkMonster;
      Name        := 'Cock';
      CPoints     := 12+2*5;
      CConvexes   := 5;
      MaxCC := 4*20+3 + (6*4+1)*2;
      Connections := Alloc(MaxCC*sizeof(Integer));
      CC := 0;
      AddSphere(0, CC, Connections);
      Connections[CC+0] := -2;
      Connections[CC+1] := -2;
      Inc(CC,2);
      for i := 0 to 1 do AddSeg(12+i*5, CC, Connections);
      Assert(CC<=MaxCC);
      ItemProc    := ProcCock;
      Texture     := @MstrTxr[random(Length(MstrTxr))];

      r := 0.7 + random*0.6;

      InitialHealths := 20+120*j/High(IMCock);
      Player    := False;
      Mass      := 0.1*r;
      HeadR     := 0.3*r;
      BodyR     := 0.3*r;
      LegsR     := 0.3*r;
      HB        := 0.3*r;
      MinBL     := 0*r;
      MaxBL     := 0.0*r;
      Speed     := 2;
      Spring    := 8;
      Lightness := 0;
      for i := 0 to 9 do begin
        WeaponModels[i]     := nil;
        DefaultHasWeapon[i] := false;
      end;
      WeaponModels     [1] := @IMWeapon[2+integer(j*2>High(IMCOck))];
      DefaultHasWeapon [1] := true;
    end;
  end;


  procedure ProcBoss (var it : Item);
  var
    M : Matrix;
    i : integer;
    a,c,s : array [0..2] of float;
  begin
    CorrectMonsterColliders(it);


    for i := 0 to 2 do begin
      a[i] := it.Monster.StepStage*4+i*2*Pi/3;
      c[i] := cos(a[i]);
      s[i] := sin(a[i]);
      it.Convexes[i+3].CanCollide := False;
      it.Convexes[i+3].Shift      := Scale(ToPoint(s[i],0,c[i]), it.Model.HeadR*1.7);
      it.Convexes[i+3].R          := it.Model.HeadR;
    end;

    SetID(M);
    ScaleM(M, ToPoint(it.Model.HeadR+0.02,it.Model.HeadR+0.02,it.Model.HeadR+0.02));
    Rotate(M,0,Pi/2);
    MoveSphere(it.ItemPoints, ToPoint(0,0,0), M, -1, -12);

    for i := 0 to 2 do begin     
      SetID(M);
      ScaleM(M,Scale(ToPoint(0.3,0.3,0.6), it.Model.HeadR));
      Rotate(M,1,a[i]);
      Translate(M, it.Convexes[i+3].Shift);
      MoveSeg(PAItemPoint(@it.ItemPoints[12+i*5]), ToPoint(0,0,0), M, 0,32);
    end;

    SetID(it.Position);
    Rotate(it.Position, 2, Pi-it.Monster.anglez);
    Translate(it.Position, it.Center.P);
  end;

  procedure InitBosses;
  var
    i, j     : integer;
    r        : float;
    CC,MaxCC : integer;
  begin
    for j := Low(IMBoss) to High(IMBoss) do with IMBoss[j] do begin
      Kind        := mkMonster;
      Name        := 'Boss';
      CPoints     := 12+3*5;
      CConvexes   := 6;
      MaxCC := 4*20+3+(6*4+1)*3;
      Connections := Alloc(MaxCC*sizeof(Integer));
      CC := 0;
      AddSphere(0, CC, Connections);
      Connections[CC+0] := -2;
      Connections[CC+1] := -2;
      Inc(CC,2);
      for i := 0 to 2 do AddSeg(12+i*5, CC, Connections);
      Assert(CC<=MaxCC);
      ItemProc    := ProcBoss;
      Texture     := @MstrTxr[random(Length(MstrTxr))];

      r := 2;

      InitialHealths := 20000;
      Player    := False;
      Mass      := 0.1*r;
      HeadR     := 0.25*r;
      BodyR     := 0.25*r;
      LegsR     := 0.25*r;
      HB        := 0*r;
      MinBL     := 0*r;
      MaxBL     := 0*r;
      Speed     := 1;
      Spring    := 0;
      Lightness := 1;
      for i := 0 to 9 do begin
        WeaponModels[i]     := nil;
        DefaultHasWeapon[i] := false;
      end;
      WeaponModels     [1] := @IMWeapon[6];
      DefaultHasWeapon [1] := true;
    end;
  end;

  procedure InitModels;
  begin
    InitPlayers;
    InitSnowmans;
    InitTrilobits;
    InitBoxes;
    InitGasbags;
    InitCocks;
    InitBosses;
    InitBullets;
    InitWeapons;
  end;

initialization
  InitModels;
end.
