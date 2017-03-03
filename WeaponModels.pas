unit WeaponModels;

interface

uses
  EngineTypes;

  procedure InitBullets;
  procedure InitWeapons;

var
  IMBullet   : array [0.. 5] of ItemModel;
  IMWeapon   : array [0.. 8] of ItemModel;

implementation

uses
  Points, ItemModels, Memory, Textures;

  procedure RotateBullet (var it: Item);
  var
    a1,a2 : float;
  begin
    it.Convexes[0].Shift := ToPoint(0,0,0);
    it.Convexes[0].CanCollide := False;
    // повернуть пулю в зависимост от дельты it.Bullet.DeltaPos
    with it.Bullet.DeltaPos do begin
      a1 := Atan2(y, x)+Pi/2;
      a2 := -Atan2(z, sqrt(sqr(y)+sqr(x)));
    end;
    SetID(it.Position);
    Rotate(it.Position, 0, a2);
    Rotate(it.Position, 2, a1);
    Translate(it.Position, it.Center.P);
  end;

  procedure ProcBullet0 (var it : Item);
  var
    M : Matrix;
  begin
    SetID(M);
    ScaleM(M, Scale(ToPoint(0.1,0.1,0.9), it.Model.HeadR));
    Rotate(M, 0, Pi/2);
    MoveSeg(it.ItemPoints, ToPoint(0,0,0), M, 0, 0);

    RotateBullet (it);
  end;

  procedure ProcBullet1 (var it : Item);
  var
    M : Matrix;
  begin
    SetID(M);
    ScaleM(M, ToPoint(0.001,0.001,0.001));
    Rotate(M, 0, Pi/2);
    MoveSeg(it.ItemPoints, ToPoint(0,0,0), M, 0, 0);

    RotateBullet (it);
  end;

  procedure ProcBullet2 (var it : Item);
  var
    M : Matrix;
  begin
    SetID(M);
    ScaleM(M, Scale(ToPoint(0.9,0.9,0.9), it.Model.HeadR));
    Rotate(M, 0, Pi/2);
    MoveSeg(it.ItemPoints, ToPoint(0,0,0), M, 0, 0);
    RotateBullet (it);
  end;

  procedure InitBullets;
  var
    j : integer;
    r : float;
    CC : integer;
  begin
    {
    0 меч
    1 невидимые клыки
    2 кров€ша
    3 пулька
    4 энергошар
    5 транклюкатор
    }


    for j := Low(IMBullet) to High(IMBullet) do with IMBullet[j] do begin
      Kind        := mkBullet;
      Name        := 'Bullet';
      CPoints     := 5;
      CConvexes   := 1;
      Connections := Alloc((4*6+1)*sizeof(Integer));
      CC := 0;
      AddSeg(0, CC, Connections);

      case j of
        0,5   : ItemProc := ProcBullet0;
        1     : ItemProc := ProcBullet1;
        2,3,4 : ItemProc := ProcBullet2;
        else ItemProc := nil;
      end;
           
      case j of
        0,3  : Texture     := @TechTxr[0];
        1    : Texture     := @BaseTxr[12];
        2    : Texture     := @BaseTxr[12];
        4,5  : Texture     := @BaseTxr[13];
        else Texture       := nil;
      end;

      case j of
        0,5 : r := 4;
        4   : r := 0.7;
        else  r := 0.3;
      end;
      HeadR     := 0.25*r;
      BodyR     := 0.15*r;
      LegsR     := 0.15*r;
    end;
  end;

  procedure ProcWeapon(var It : Item);
  begin
  end;

  procedure InitSabre;
  begin
    with IMWeapon[0] do begin
      Kind := mkWeapon;
      Name := 'Ўашка';
      CPoints   := 0;
      CConvexes := 1;
      Connections := Alloc(1*sizeof(Integer));
      Connections[0] := -2;
      ItemProc := ProcWeapon;
      Texture     := @TechTxr[0];

      HeadR          := 0.5;
      BulletSpeed    := 100;
      Range          := 2;
      Damage         := 2000;
      BulletsPerShot := 1;
      Dispersion     := 0;
      ReloadTime     := 0.3;
      Sabre          := True;
      BulletModel    := @IMBullet[0];

      Instrument := 126;
      Nota       := 99;
    end;
  end;

  procedure InitBlood;
  begin
    with IMWeapon[1] do begin
      Kind := mkWeapon;
      Name := 'Blood';
      CPoints   := 0;
      CConvexes := 1;
      Connections := Alloc(1*sizeof(Integer));
      Connections[0] := -2;
      ItemProc := ProcWeapon;
      Texture     := @BaseTxr[7];

      HeadR          := 0.1;
      BulletSpeed    := 5;
      Range          := 0.5;
      Damage         := 0;
      BulletsPerShot := 1;
      Dispersion     := 0;
      ReloadTime     := 0;
      Sabre          := False;
      BulletModel := @IMBullet[2];   

      Instrument := 128;
      Nota       := 0;
    end;
  end;

  procedure InitClawsSmall;
  begin
    with IMWeapon[2] do begin
      Kind := mkWeapon;
      Name := 'Claws Small';
      CPoints   := 0;
      CConvexes := 1;
      Connections := Alloc(1*sizeof(Integer));
      Connections[0] := -2;
      ItemProc := ProcWeapon;
      Texture     := @BaseTxr[7];

      HeadR          := 0.1;
      BulletSpeed    := 100;
      Range          := 0.5;
      Damage         := 10;
      BulletsPerShot := 1;
      Dispersion     := 0;
      ReloadTime     := 0.5;
      Sabre          := False;
      BulletModel := @IMBullet[1]; 

      Instrument := 128;
      Nota       := 0;
    end;
  end;

  procedure InitClawsBig;
  begin
    with IMWeapon[3] do begin
      Kind := mkWeapon;
      Name := 'Claws big';
      CPoints   := 0;
      CConvexes := 1;
      Connections := Alloc(1*sizeof(Integer));
      Connections[0] := -2;
      ItemProc := ProcWeapon;
      Texture     := @BaseTxr[7];

      HeadR          := 0.1;
      BulletSpeed    := 100;
      Range          := 0.5;
      Damage         := 18;
      BulletsPerShot := 1;
      Dispersion     := 0;
      ReloadTime     := 0.5;
      Sabre          := False;
      BulletModel := @IMBullet[1];  

      Instrument := 128;
      Nota       := 0;
    end;
  end;

  procedure InitEnergyBall;
  begin
    with IMWeapon[4] do begin
      Kind := mkWeapon;
      Name := 'Energy ball';
      CPoints   := 0;
      CConvexes := 1;
      Connections := Alloc(1*sizeof(Integer));
      Connections[0] := -2;
      ItemProc := ProcWeapon;
      Texture     := @BaseTxr[7];

      HeadR          := 0.1;
      BulletSpeed    := 6;
      Range          := 50;
      Damage         := 9;
      BulletsPerShot := 1;
      Dispersion     := 0;
      ReloadTime     := 1;
      Sabre          := False;
      BulletModel := @IMBullet[4];   

      Instrument := 112;
      Nota       := 70;
    end;
  end;

  procedure InitEnergyBallBig;
  begin
    with IMWeapon[5] do begin
      Kind := mkWeapon;
      Name := 'Energy ball big';
      CPoints   := 0;
      CConvexes := 1;
      Connections := Alloc(1*sizeof(Integer));
      Connections[0] := -2;
      ItemProc := ProcWeapon;
      Texture     := @BaseTxr[7];

      HeadR          := 0.1;
      BulletSpeed    := 8;
      Range          := 50;
      Damage         := 17;
      BulletsPerShot := 1;
      Dispersion     := 0;
      ReloadTime     := 1;
      Sabre          := False;
      BulletModel := @IMBullet[4];

      Instrument := 112;
      Nota       := 75;
    end;
  end;

  procedure InitSatanClaws;
  begin              
    with IMWeapon[6] do begin
      Kind := mkWeapon;
      Name := 'Satan Claws';
      CPoints   := 0;
      CConvexes := 1;
      Connections := Alloc(1*sizeof(Integer));
      Connections[0] := -2;
      ItemProc := ProcWeapon;
      Texture     := @BaseTxr[7];

      HeadR          := 0.1;
      BulletSpeed    := 7;
      Range          := 50;
      Damage         := 55;
      BulletsPerShot := 1;
      Dispersion     := 0;
      ReloadTime     := 1;
      Sabre          := False;
      BulletModel := @IMBullet[5];

      Instrument := 112;
      Nota       := 70;
    end;
  end;

  procedure InitGun;
  begin         
    with IMWeapon[7] do begin
      Kind := mkWeapon;
      Name := '√армата';
      CPoints   := 0;
      CConvexes := 1;
      Connections := Alloc(1*sizeof(Integer));
      Connections[0] := -2;
      ItemProc := ProcWeapon;
      Texture     := @BaseTxr[7];

      HeadR          := 0.1;
      BulletSpeed    := 30;
      Range          := 50;
      Damage         := 14;
      BulletsPerShot := 1;
      Dispersion     := 0;
      ReloadTime     := 0.1;
      Sabre          := False;
      BulletModel := @IMBullet[3];
      Instrument := 127;
      Nota       := 60;
    end;
  end;

  procedure InitBFG;
  begin          
    with IMWeapon[8] do begin
      Kind := mkWeapon;
      Name := '“ранклюкатор';
      CPoints   := 0;
      CConvexes := 1;
      Connections := Alloc(1*sizeof(Integer));
      Connections[0] := -2;
      ItemProc := ProcWeapon;
      Texture     := @BaseTxr[7];

      HeadR          := 0.1;
      BulletSpeed    := 15;
      Range          := 20;
      Damage         := 6666;
      BulletsPerShot := 1;
      Dispersion     := 0;
      ReloadTime     := 5;
      Sabre          := False;
      BulletModel := @IMBullet[5]; 
      Instrument := 123;
      Nota       := 60;
    end;
  end;

  procedure InitWeapons;
  begin
    InitSabre;
    InitBlood;
    InitClawsSmall;
    InitClawsBig;
    InitEnergyBall;
    InitEnergyBallBig;
    InitSatanClaws;
    InitGun;
    InitBFG;
  end;

end.
