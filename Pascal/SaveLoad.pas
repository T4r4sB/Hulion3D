unit SaveLoad;

interface

  uses Points;

  procedure QuickSave;
  procedure QuickLoad;

  var
    LastSave : float = 0;
    LastLoad : float = 0;

implementation

  uses Memory, Level, ItemModels, WeaponModels, Generator, Bullets, Engine;

  procedure QuickSave;
  var
    f : file of byte;
  begin
    Assign(f, 'save');
    IOResult;
    Rewrite(f);
    if IOResult=0 then begin
      BlockWrite(F, Beg, sizeof(Beg));
      BlockWrite(F, Data, PChar(Beg)-PChar(@Data[0]));

      BlockWrite(F, Pool, sizeof(Pool));
      BlockWrite(F, PoolCount, sizeof(PoolCount));
      BlockWrite(F, Free, sizeof(Free));

      BlockWrite(F, cp, sizeof(cp));
      BlockWrite(F, L, sizeof(L));   
      BlockWrite(F, CSectors, sizeof(CSectors));

      BlockWrite(F, IMPlayer, sizeof(IMPlayer));
      BlockWrite(F, IMSnowman, sizeof(IMSnowman));
      BlockWrite(F, IMTrilobit, sizeof(IMTrilobit));
      BlockWrite(F, IMGasbag, sizeof(IMGasbag));
      BlockWrite(F, IMBox, sizeof(IMBox));
      BlockWrite(F, IMCock, sizeof(IMCock));
      BlockWrite(F, IMBoss, sizeof(IMBoss));
      BlockWrite(F, IMBullet, sizeof(IMBullet));
      BlockWrite(F, IMWeapon, sizeof(IMWeapon));

      BlockWrite(F, CActiveBullets, sizeof(CActiveBullets));
      BlockWrite(F, LastActiveBulletIndex, sizeof(LastActiveBulletIndex));
      BlockWrite(F, ActiveBullets, sizeof(ActiveBullets));

      BlockWrite(F, GameTime, sizeof(GameTime));
      BlockWrite(F, CActiveMonsters, sizeof(CActiveMonsters));
      BlockWrite(F, ActiveMonsters, sizeof(ActiveMonsters));

      Close(f);

      LastSave := 1;
    end;
  end;

  procedure QuickLoad;
  var
    f : file of byte;
  begin
    Assign(f, 'save');
    IOResult;
    Reset(f);
    if IOResult=0 then begin
      BlockRead(F, Beg, sizeof(Beg));
      BlockRead(F, Data, PChar(Beg)-PChar(@Data[0]));

      BlockRead(F, Pool, sizeof(Pool));
      BlockRead(F, PoolCount, sizeof(PoolCount));
      BlockRead(F, Free, sizeof(Free));

      BlockRead(F, cp, sizeof(cp));
      BlockRead(F, L, sizeof(L));
      BlockRead(F, CSectors, sizeof(CSectors));

      BlockRead(F, IMPlayer, sizeof(IMPlayer));
      BlockRead(F, IMSnowman, sizeof(IMSnowman));
      BlockRead(F, IMTrilobit, sizeof(IMTrilobit));
      BlockRead(F, IMGasbag, sizeof(IMGasbag));
      BlockRead(F, IMBox, sizeof(IMBox));
      BlockRead(F, IMCock, sizeof(IMCock));
      BlockRead(F, IMBoss, sizeof(IMBoss));
      BlockRead(F, IMBullet, sizeof(IMBullet));
      BlockRead(F, IMWeapon, sizeof(IMWeapon));

      BlockRead(F, CActiveBullets, sizeof(CActiveBullets));
      BlockRead(F, LastActiveBulletIndex, sizeof(LastActiveBulletIndex));
      BlockRead(F, ActiveBullets, sizeof(ActiveBullets));

      BlockRead(F, GameTime, sizeof(GameTime));
      BlockRead(F, CActiveMonsters, sizeof(CActiveMonsters));
      BlockRead(F, ActiveMonsters, sizeof(ActiveMonsters));

      Close(f);    

      LastLoad := 1;
    end;
  end;

end.
