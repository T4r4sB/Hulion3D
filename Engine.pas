unit Engine;

interface
  uses
    Points, Level, Monsters, Textures, EngineTypes, Items, Collisions, Sounds;

  procedure EnginePhys (dt : float); 
  procedure SetMonsterActive (M: PMonster);

  var
    GameTime : float;

  var
    CActiveMonsters : integer = 0;
    ActiveMonsters : array [0..CMonsters-1] of PMonster;

implementation

  uses
    Memory, Bullets;
  const
    ProcessMonsterTime = 2;

  function MustContinue (const M: Monster): boolean;
  begin
    if M.Item.Model.Player then Result := True
    else Result := Visible(M.Head^, L.Player.Head^);
  end;

  procedure IIMonster (var M: Monster);
  var
    DP : Point;
    NeedA : float;
  begin
    if not Live(M) then Exit;

    M.Controls.Forw := True; // tmp
    DP := Sub(M.Body.P, L.Player.Body.P);
    NeedA := Atan2(DP.x,DP.y)+Pi-M.anglez;
    while NeedA> Pi do NeedA := NeedA-2*Pi;
    while NeedA<-Pi do NeedA := NeedA+2*Pi;

    M.Controls.daz := NeedA*1000;
    if M.Controls.daz>+3 then M.Controls.daz := +3;
    if M.Controls.daz<-3 then M.Controls.daz := -3;
    
    NeedA := Atan2(DP.z,sqrt(sqr(DP.x)+sqr(DP.y)))+(Pi/2-M.anglex);
    while NeedA> Pi do NeedA := NeedA-2*Pi;
    while NeedA<-Pi do NeedA := NeedA+2*Pi;

    M.Controls.dax := NeedA*1000;
    if M.Controls.dax>+3 then M.Controls.dax := +3;
    if M.Controls.dax<-3 then M.Controls.dax := -3;

    if M.Item.Model.Lightness>0.1 then begin
      M.Controls.Jump := M.Item.Center.P.z>L.Player.Head.P.z+0.3;
      M.Controls.Sit  := M.Item.Center.P.z<L.Player.Head.P.z-0.3;
    end else if M.Item.Model.Spring>0.1 then
      M.Controls.Jump := True;

    M.Controls.WeaponNumber := 9;
    while (M.Controls.WeaponNumber>=0) and (not M.Weapons[M.Controls.WeaponNumber].IsWeapon) do
      Dec(M.Controls.WeaponNumber);

    M.Controls.Shot := True;
  end;

  function IsMonsterActive (M: PMonster) : boolean;
  begin
    Result := M.ProcessTime>0;
  end;

  procedure SetMonsterActive (M: PMonster);
  var
    wa : boolean;
  begin
    wa := IsMonsterActive(M);
    M.ProcessTime := ProcessMonsterTime;
    if not wa then begin
      Inc(CActiveMonsters);
      ActiveMonsters[CActiveMonsters-1] := M;
    end;
  end;

  procedure MoveActiveMonsters (dt : float);
  var
    i,j : integer;
  begin
    j := 0;
    for i := 0 to CActiveMonsters-1 do begin
      if not ActiveMonsters[i].Item.Model.Player then IIMonster(ActiveMonsters[i]^);
      MoveMonster(ActiveMonsters[i], dt);
      UpdateItem(ActiveMonsters[i].Item);
      if MustContinue (ActiveMonsters[i]^) then
        SetMonsterActive(ActiveMonsters[i]); // оно не влияет на массив
      ActiveMonsters[i].ProcessTime := ActiveMonsters[i].ProcessTime - dt;

      if IsMonsterActive(ActiveMonsters[i]) then begin
        ActiveMonsters[j] := ActiveMonsters[i];
        Inc(j);
      end else
        ActiveMonsters[i].Controls.Jump := False;   // tmp
    end;
    CActiveMonsters := j;
  end;

  procedure FindVisibleMonsters (VP : SPoint);
  var
    CIS : integer;
    IP : PAPItem;
    DP : Point;
    h,r,a : float;
    i : integer;
    MS : MemoryState;
    tryes : integer;
  begin
    SetMonsterActive(@L.Player);   
    for tryes := 0 to 4 do begin
      SaveState(MS);
      h := random*2-1;
      r := sqrt(1-h*h);
      a := random*2*pi;
      DP.x := r*cos(a);
      DP.y := r*sin(a);
      DP.z := h;
      DP := Scale(DP,100); // на 100 метров палим монстров азаза
      CIS := 0;
      IP := Alloc(CItems * sizeof(PItem));
      TraceWithItems(VP, DP, CIS, IP, True);
      // чётто сделать  с монстрами
      for i := 0 to CIS-1 do
        if (IP[i].Monster<>nil) and Live(IP[i].Monster^) and Visible(VP, IP[i].Monster.Head^) then
          SetMonsterActive(IP[i].Monster);

      for i := 0 to CIS-1 do IP[i].inProcess := False;
      RestoreState(MS);
    end;
  end;

  procedure EnginePhys (dt : float);
  begin
    GameTime := GameTime + dt;
    FindVisibleMonsters(L.Player.Item.Convexes[0].Center);     
    ProcessBullets     (dt);
    MoveActiveMonsters (dt); // да-да, это включая и игрока!
    ProcessSkyTxr      (dt);
    ProcessHellTxr     (dt);
  end;

end.
