unit Monsters;

interface

uses
  Points, Collisions, EngineTypes;

  procedure CreateMonster (M: PMonster; S: PSector; Model : PItemModel);
  procedure TraceMonster (var M: Monster);
  procedure PushMonster (var M: Monster);
  procedure MoveMonster (M: PMonster; dt: float);
  function CenterMonster (const M: Monster): Point;
  function Live (const M: Monster): boolean;

implementation

uses
  Geometry, Items, Bullets, Sounds;

  procedure TraceMonster (var M: Monster);
  var
    ml,mh : Point;
  begin
    ml := M.DeltaPos;
    mh := M.DeltaPos;
    if Live(M) then begin
      if M.Controls.Sit then ml.z := ml.z-0.064 else ml.z := ml.z+0.064;
      if M.Controls.Sit then mh.z := mh.z+0.036 else mh.z := mh.z-0.036;
    end else begin
      mh.z := mh.z + 0.1;
    end;
    Trace(M.Head^, mh);
    Trace(M.Body^, mh);
    Trace(M.Legs^, ml);
  end;

  function CenterMonster (const M: Monster): Point;
  begin
    Result := Add(Add(Scale(M.Head.P,0.28), Scale(M.Body.P,0.36)), Scale(M.Legs.P,0.36));
  end;

  procedure PushMonster (var M: Monster);
  var
    x,y,zh,zb,zl,dz : float;
  begin
    with M, Item.Model^ do begin
      // теперь костыльно шарики приводим друг к другу
      x := Body.P.x*0.36 + Legs.P.x*0.36 + Head.P.x*0.28;
      y := Body.P.y*0.36 + Legs.P.y*0.36 + Head.P.y*0.28;
      zh := Head.P.z;
      zl := Legs.P.z;
      dz := zl - (zh+(HB+MaxBL));
      if dz>0 then begin
        zh := zh + dz*0.36;
        zl := zl - dz*0.64;
      end;
      dz := (zh+(HB+MinBL)) - zl;
      if dz>0 then begin
        zh := zh - dz*0.36;
        zl := zl + dz*0.64;
      end;
      zb := zh + HB;
      Trace(Head^, Sub(ToPoint(x,y,zh), Head.P));
      Trace(Body^, Sub(ToPoint(x,y,zb), Body.P));
      Trace(Legs^, Sub(ToPoint(x,y,zl), Legs.P));

      PushConvex(Item.Convexes[0]);
      PushConvex(Item.Convexes[1]);
      PushConvex(Item.Convexes[2]);
    end;
  end;  

  procedure DoShot (M: PMonster);

    procedure CreateSound;
    begin
       with M.Weapons[M.CurrentWeapon].Item.Model^ do if Instrument<128 then begin
        SetChanel(0);
        NoSound;
        SetVolume(127);
        SetStyle(Instrument);
        Sound(Nota);
      end;
    end;

  begin
    with M.Weapons[M.CurrentWeapon] do if isWeapon then begin
      if Item.Model.Sabre then begin
        if ReloadLeft<=0 then begin
          ReloadLeft := Item.Model.ReloadTime;
          CreateSound;
        end;
        Shot(M, Item.Model, (ReloadLeft/Item.Model.ReloadTime)-1/2);       // Item.Monster вместо M, потому что так корректнее брать указатель
      end else begin
        if ReloadLeft<=0 then begin
          CreateSound;
          ReloadLeft := Item.Model.ReloadTime;
          Shot(M, Item.Model, 0);
        end;
      end;
    end;
  end;
  
  function Live (const M: Monster): boolean;
  begin
    Result := M.DeathStage<0;
  end;
  
  procedure MoveMonster (M: PMonster; dt : float);
  var
    Move : Point;
    l,c,s : float;
    st : float;
    BefT, BefP, AftP, dP : Point;
    NewM : Monster;
    NewC : array [0..2] of Convex;
    i : integer;
  begin
    with M^, Item.Model^ do begin
      // контролы
      if Live(M^) then begin
        anglex := anglex + Controls.dax*dt;
        if anglex<0  then anglex := 0;
        if anglex>Pi then anglex := Pi;
        anglez := anglez + Controls.daz*dt;
        while anglez<0    do anglez := anglez + 2*Pi;
        while anglex>2*Pi do anglez := anglez - 2*Pi;
      end;

      c := cos(anglez);
      s := sin(anglez);
      Move := ToPoint(0,0,0);

      if Live(M^) then begin
        if Controls.Forw then Move := Add(Move, ToPoint( s, c,0));
        if Controls.Back then Move := Add(Move, ToPoint(-s,-c,0));
        if Controls.StrL then Move := Add(Move, ToPoint(-c, s,0));
        if Controls.StrR then Move := Add(Move, ToPoint( c,-s,0));
        if Controls.Jump then Move := Add(Move, ToPoint(0,0,-Lightness));
        if Controls.Sit  then Move := Add(Move, ToPoint(0,0, Lightness));
      end else begin
        DeathStage := DeathStage - dt;
        if DeathStage<0 then DeathStage := 0;
      end;
      // сдвинуть с учётом трения
      l := LengthP(Move);
      if l>0 then Move := Scale(Move, 0.03/l);
      st := (Legs.P.z-Body.P.z+0.4)/(MaxBL+0.4);


      Move := Scale(Move, (Fr*0.95+0.05));
      if Live(M^) then begin
        if Controls.Jump then Move := Add(Move, ToPoint(0,0,-Spring*dt*st*Fr));
      end;
      // применить ускорение
      DeltaPos := Add(DeltaPos, Move);
      DeltaPos := Add(DeltaPos, ToPoint(0, 0, Legs.S.Gravity*(1-Lightness)));
      // вычислить сдвиг
      // создаём фальшивую копию монстра
      NewM := M^;
      for i := 0 to 2 do begin
        NewC[i] := Item.Convexes[i];
        NewC[i].Mass := 0;
        NewM.Item.Convexes := PAConvex(@NewC);
      end;
      NewM.Head := @NewC[0].Center;
      NewM.Body := @NewC[1].Center;
      NewM.Legs := @NewC[2].Center;

      BefT := CenterMonster(NewM);
      TraceMonster(NewM);
      BefP := CenterMonster(NewM);
      PushMonster(NewM);
      AftP := CenterMonster(NewM);

      DeltaPos := Sub(AftP, BefT);
                                          
      // пересчитать силу трения
      dP := Sub(BefP, AftP);
      Fr := (dp.z - sqrt(sqr(dp.x)+sqr(dp.y))*0.3)*1000;
      if Fr<0 then Fr := 0;
      if Fr>1 then Fr := 1;
      Fr := Fr*(1-Lightness)+Lightness;
      // применить силу трения
      l := LengthP(DeltaPos);
      s := l-(Speed*dt+(1-Fr))*st; // превышение скорости
      if s<0 then s:=0;
      s := Fr*0.01+s;
      if l>s then DeltaPos := Scale(DeltaPos, 1-s/l) else DeltaPos := ToPoint(0,0,0);


      for i := 0 to 9 do with Weapons[i] do begin
        ReloadLeft := ReloadLeft-dt;
        if ReloadLeft<0 then ReloadLeft:=0;
      end;

      if Live(M^) then begin
        LastDamage := LastDamage+dt;
        if LastDamage>1 then LastDamage := 1;

        if (Controls.WeaponNumber>=0) and (Controls.WeaponNumber<=9)
        and (Weapons[Controls.WeaponNumber].IsWeapon) then
          CurrentWeapon := Controls.WeaponNumber;

        if Fr>0 then StepStage := StepStage + LengthP(DeltaPos);
        if Controls.Shot then
          DoShot(M);
      end;

      if PrevShot and not Controls.Shot then begin
        SetChanel(0);
        NoSound;
      end;
      PrevShot := Controls.Shot;
    end;
    TraceMonster(M^);
    PushMonster(M^);
  end;

  procedure CreateMonster (M: PMonster; S: PSector; Model : PItemModel);
  var
    i : integer;
  begin
    FillChar(M^, sizeof(M^), 0);
    M.AngleX        := Pi/2;
    M.AngleZ        := Pi;
    M.StepStage     := 0;
    M.Item.Monster  := M;
    M.DeathStage    := -1;
    M.Health        := Model.InitialHealths;
    M.Armor         := 0;
    M.CurrentWeapon := 0;
    M.LastDamage    := 1;
    M.PrevShot      := False;
    CreateItem(@M.Item, S, Model);

    M.Item.Convexes[0].R    := Model.HeadR;
    M.Item.Convexes[1].R    := Model.BodyR;
    M.Item.Convexes[2].R    := Model.LegsR;

    for i := 0 to 9 do begin
      M.Weapons[i].IsWeapon := (Model.DefaultHasWeapon[i]) and (Model.WeaponModels[i]<>nil);
      if Model.WeaponModels[i]<>nil then
        CreateWeapon(@M.Weapons[i], Model.WeaponModels[i], M);
    end;
  end;

end.
