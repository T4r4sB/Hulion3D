unit Bullets;

interface

uses
  Points, EngineTypes, Level;

  procedure CreateBullet (B: PBullet);
  procedure CreateWeapon (W : PWeapon; ItemModel : PItemModel; M : PMonster);
  procedure ProcessBullets (dt : float);
  procedure Shot(M : PMonster; WPModel : PItemModel; Dx : float);
  
  var
    CActiveBullets : integer = 0;
    LastActiveBulletIndex : integer = -1;
    ActiveBullets : array [0..CBullets-1] of PBullet;

implementation

  uses
    Items, ItemModels, WeaponModels, Collisions, Geometry, Memory, Engine, Sounds, Config;


  procedure DischargeNewBullet (
    const InitPos : SPoint; const DeltaPos : Point; const Owner : PMonster;
    WPModel : PItemModel);
  var
    newIndex : integer;
    c,f : integer;
  // где куда чья какой модели
  begin
    newIndex := LastActiveBulletIndex;
    Inc(newIndex);
    if newIndex>=CBullets then newIndex := 0;
    if (not L.Bullets[newIndex].Active) and (CactiveBullets<CBullets) then begin
      Inc(CActiveBullets);
      ActiveBullets[CActiveBullets-1] := @L.Bullets[newIndex];
      ActiveBullets[CActiveBullets-1].Active      := True;
      ActiveBullets[CActiveBullets-1].Item.Center := InitPos;
      ActiveBullets[CActiveBullets-1].DeltaPos    := DeltaPos;
      ActiveBullets[CActiveBullets-1].TripDist    := 0;
      ActiveBullets[CActiveBullets-1].Owner       := Owner;
      ActiveBullets[CActiveBullets-1].WPModel     := WPModel;
      ActiveBullets[CActiveBullets-1].Item.Model  := WPModel.BulletModel;
      with ActiveBullets[CActiveBullets-1].Item do begin   // перекраско
        for c := 0 to CConvexes-1 do with Convexes[c].G do
          for f := 0 to CFaces-1 do Faces[f].Texture := Model.Texture;
      end;
      UpdateItem(ActiveBullets[CActiveBullets-1].Item);
      LastActiveBulletIndex := newIndex;
    end;
  end;

  procedure CreateBullet (B: PBullet);
  begin
    FillChar(B^, sizeof(B^), 0);
    B.Item.Bullet := B;
    CreateItem(@B.Item, @L.EmptyS, @IMBullet[0]);
    B.Item.Model := nil;
  end;

  procedure Shot(M : PMonster; WPModel : PItemModel; Dx : float);
  var
    NewBulletPos : SPoint;
    Dh, Dir      : Point;
    cx,sx,cz,sz  : float;
  begin
    cx := cos(M.anglex);
    sx := sin(M.anglex);
    cz := cos(M.anglez+Dx*2);
    sz := sin(M.anglez+Dx*2);

    NewBulletPos := M.Body^;
    Dh  := ToPoint (sz   ,cz   , 0);
    Dir := ToPoint (sz*sx,cz*sx, cx);

    Trace(NewBulletPos, Add(Scale(Dh, M.Item.Model.BodyR+0.1), Scale(Dir, WPModel.HeadR)));
    DischargeNewBullet (NewBulletPos, Dir, M, WPModel);
  end;
  
  procedure CreateWeapon (W : PWeapon; ItemModel : PItemModel; M : PMonster);
  begin
    W.ReloadLeft  := 0;
    W.Item.Weapon := W;
    CreateItem(@W.Item, @L.EmptyS, ItemModel);
  end;

  procedure DeactivateBullet (B : PBullet);
  begin
    B.Active := False;
    B.Item.Center.S := @L.EmptyS;
    B.Item.Center.P := CenterSector(B.Item.Center.S^);
  end;

  procedure DoDamage (M : PMonster; const From : SPoint; Damage : float; dt: float);
  var
    i : integer;
    a,c,s,h,r : float;
    d : float;
  begin

    SetMonsterActive(M);
    M.DeltaPos := Add(M.DeltaPos, Scale(Sub(M.Body.P, From.P), dt/M.Item.Model.Mass));

    M.LastDamage := 0;

    if not (M.Item.Model.Player and (god>0)) then
      M.Health := M.Health-Damage*(1-M.Armor/100);
    if M.Health<=0 then begin
      M.DeathStage := 1;
      SetChanel(1);
      NoSound;
      SetStyle(118);
      SetVolume(60);
      Sound(80);
    end;
    M.Armor := M.Armor-2;
    if M.Armor<0 then M.Armor := 0;

    d := Damage;
    for i := 0 to trunc(d)+integer(random<frac(d))-1 do begin
      a := random*2*pi;
      c := cos(a);
      s := sin(a);
      h := random*2-1;
      r := sqrt(1-h*h);
      DischargeNewBullet(From, ToPoint(c*r,s*r,h), nil, @IMWeapon[1]);
    end;
  end;

  procedure TraceBullet(B : PBullet; dt : float);
  var
    CIS, i : integer;
    IP     : PAPItem;
    OC     : SPoint;
    s      : float;
    MS     : MemoryState;
    Dmg    : float;
  begin
    SaveState(MS);
    s := dt * B.WPModel.BulletSpeed;
    if B.TripDist+s>B.WPModel.Range then begin
      s := B.WPModel.Range-B.TripDist;
      B.Active := False;
    end;

    if B.WPModel.Damage>0 then begin
      CIS := 0;
      IP  := Alloc(CItems*sizeof(PItem));
      OC  := B.Item.Center;
      if not TraceWithItems(B.Item.Center, Scale(B.DeltaPos, s), CIS, IP, false) then
        B.Active := False;

      if B.WPModel.Sabre then Dmg := B.WPModel.Damage*dt else Dmg := B.WPModel.Damage;

      for i := 0 to CIS-1 do if (IP[i].Monster<>nil) and (IP[i].Monster.DeathStage<0) then begin
        DoDamage(IP[i].Monster, OC, Dmg, dt);
        if not B.WPModel.Sabre then B.Active := False;
      end;
      for i := 0 to CIS-1 do IP[i].inProcess := False;
    end else begin 
      if not Trace(B.Item.Center, Scale(B.DeltaPos, s)) then
        B.Active := False;
    end;
    B.TripDist := B.TripDist + s;
    RestoreState(MS);
  end;

  procedure ProcessBullets (dt : float);
  var
    i,j : integer;
  begin
    j := 0;
    i := 0;
    while i<CActiveBullets do begin  // гавнацикол
      // сдвинуть пулю
      // рассчитать всех монстров от пули
      TraceBullet(ActiveBullets[i], dt);
      // если пуля ок, то
      if ActiveBullets[i].Active then begin
        ActiveBullets[j] := ActiveBullets[i];
        Inc(j);
      end else
        DeactivateBullet(ActiveBullets[i]);     
      UpdateItem(ActiveBullets[i].Item);
      Inc(i);
    end;
    CActiveBullets := j;
  end;

end.
