unit Level;

interface

uses
  Points, Geometry, Memory, Bitmaps, Collisions, Monsters, Generator, Items, EngineTypes;

type
  FloorPoints = array [-0..LabSize, -0..LabSize, 0..1] of Point;
  SectorArr = array [0..LabSize-1, 0..LabSize-1] of Sector;

const
  CMonsters = 2048;
  CItems    = 8192;
  CConvexes = CItems*8;
  CBullets  = 256;

type Lab = record
  S : array [0..31] of SectorArr;
  P : array [0..31] of FloorPoints;
  SkyS,HellS,EmptyS : Sector;
  SkyP,HellP,EmptyP : array [0..7] of Point;
  Player  : Monster;
  Boss : PMonster;
  Enemies : array [0..CMonsters-1] of Monster;
  Items   : array [0..CItems-1]    of Item;
  Bullets : array [0..CBullets-1]  of Bullet;
end;

procedure InitLevel(var L: Lab);

var
  L: Lab;
  CSectors : integer;

implementation

  uses
    Render, Textures, ItemModels, Engine, Bullets;

  procedure InitLevel(var L: Lab);
  var
    pc : integer;
    fc : integer;        
    pt : array [0..119] of PPoint;
    fn,fna : array [0..7] of integer;
    lfn : integer;
    ltmax,ltmin  : float;
    lightroom : boolean;
    wood : array [0..31, 0..LabSize-1,0..LabSize-1] of boolean;
  const
    ec=4;

    procedure AddF (const P : array of PPoint);
    var
      i : integer;
    begin
      for i := Low(P) to High(P) do begin
        Inc(pc);
        pt[pc-1] := P[i];
      end;
      Inc(pc);
      pt[pc-1] := nil;
      Inc(fc);
    end;

    procedure AddTF (const P1,P2,P3,P4 : PPoint);
    begin
      if Volume(Sub(P2^,P1^), Sub(P3^,P1^), Sub(P4^,P1^))>0 then begin
        AddF([P1,P2,P3]);
        AddF([P1,P3,P4]);
      end else begin
        AddF([P1,P2,P4]);
        AddF([P2,P3,P4]);
      end;
    end;

    procedure SetLtMaxMin(const P:FloorPoints; i,j : integer);
    var
      d : float;
    begin
      d := P[i,j,1].z-P[i,j,0].z;
      if ltmax<d then ltmax := d;
      if ltmin>d then ltmin := d;
    end;

    procedure InitSkyBox(var SkyP : array of Point; var SkyS: Sector; TFloor, TRoof : PTexture);
    var
      i : integer;
    begin
      SkyP[0] := ToPoint( 64,-64,-0.2);
      SkyP[1] := ToPoint( 64,-64, 0.2);
      SkyP[2] := ToPoint( 64, 64, 0.2);
      SkyP[3] := ToPoint( 64, 64,-0.2);
      SkyP[4] := ToPoint(-64,-64,-0.2);
      SkyP[5] := ToPoint(-64,-64, 0.2);
      SkyP[6] := ToPoint(-64, 64, 0.2);
      SkyP[7] := ToPoint(-64, 64,-0.2);    
      pc := 0;
      AddF([@SkyP[0],@SkyP[1],@SkyP[2],@SkyP[3]]);
      AddF([@SkyP[1],@SkyP[0],@SkyP[4],@SkyP[5]]);
      AddF([@SkyP[2],@SkyP[1],@SkyP[5],@SkyP[6]]);
      AddF([@SkyP[3],@SkyP[2],@SkyP[6],@SkyP[7]]);
      AddF([@SkyP[0],@SkyP[3],@SkyP[7],@SkyP[4]]);
      AddF([@SkyP[7],@SkyP[6],@SkyP[5],@SkyP[4]]);
      CreateSector(SkyS, pc, pt);
      SkyS.inProcess := 0;
      SkyS.Skybox := True;
      SkyS.Gravity := 0.03;
      for i := 0 to 5 do begin
        SkyS.Faces[i].Id := i;
        SkyS.Faces[i].NextSector := nil;
        SkyS.Faces[i].Penetrable := false;
        if i=2 then
          SkyS.Faces[i].Texture := TFloor
        else      
          SkyS.Faces[i].Texture := TRoof;
        SkyS.Faces[i].Light := 255;
        SkyS.Faces[i].VTx  := ToPoint(400,0,0);
        SkyS.Faces[i].VTxc := 0;
        SkyS.Faces[i].VTy  := ToPoint(0,400,0);
        SkyS.Faces[i].VTyc := 0;
      end;
    end;

    procedure InitFloor (var cp : PassMap; var P : FloorPoints; index : integer);
    var
      dz : DeltaArr;
      i,j,k : integer;
      sx,sy,sz : integer;
      ld : float;
    begin
      InitLab(cp,index);

      case index and 3 of
        0,1 : sx := LabSize;
        else sx := 0;
      end;
      case index and 3 of
        0,3 : sy := LabSize;
        else sy := 0;
      end;
      sz := index;

      ld := 0.9;
      for i := 0 to LabSize do for j := 0 to LabSize do for k := 0 to 1 do with P[i,j,k] do begin
        x := (i+sx)*1.5-1;
        y := (j+sy)*1.5-1;
        z := (-sz)*ld;
        if k=0 then z := z-1.4;
        case index mod 4 of
          0 : if j=0       then z := z - ld;
          1 : if i=0       then z := z - ld;
          2 : if j=LabSize then z := z - ld;
          3 : if i=LabSize then z := z - ld;
        end;
      end;

      for i := 0 to LabSize do for j := 0 to LabSize do
        dz[i,j] := P[i,j,1].z;

      for i := 1 to LabSize-1 do for j := 1 to LabSize-1 do
        dz[i,j] := dz[i,j]+random-2;

      if index in [10..14] then                    
        GenDeltas(cp, dz, 2) // глобальный уровень пола
      else
        GenDeltas(cp, dz, 0); // глобальный уровень пола

      for i := 1 to LabSize-1 do for j := 1 to LabSize-1 do for k := 0 to 1 do with P[i,j,k] do begin
        z := dz[i,j];
        if k=0 then begin
          if (index in [8..9]) then begin
           if random(3)=0 then
             z := z-2.2
           else
             z := z-1.4;
          end else begin
            if (index in [10..14]) or (random(3)>0)  then
              z := z-2.2
            else
              z := z-1.4;
          end;
        end;
      end;

      for i := 0 to LabSize do for j := 0 to LabSize do
        dz[i,j] := 0;
      if index in [10..14] then begin
        for i := 1 to LabSize-1 do for j := 1 to LabSize-1 do
          dz[i,j] := 0;
        GenDeltas(cp, dz, 0);
      end else if index>=30 then begin
        for i := 1 to LabSize-1 do for j := 1 to LabSize-1 do
          dz[i,j] := 2+random*3;
        GenDeltas(cp, dz, 0); // потолки залов
      end else begin
        for i := 1 to LabSize-1 do for j := 1 to LabSize-1 do
          dz[i,j] := 2;
        GenDeltas(cp, dz, 1); // потолки залов
      end;
      for i := 1 to LabSize-1 do for j := 1 to LabSize-1 do for k := 0 to 1 do with P[i,j,k] do begin
        if index<4 then z := z+100;
        if index>=30 then                
          z := z + dz[i,j]*(k-1)
        else
          z := z + dz[i,j]*(6*k-5.5);
      end;
    end;

    procedure FillLavalLevel (var cp,cpu : PassMap);
    var
      i,j, i2,j2, c: integer;
      p : boolean;
    begin
      for i := 1 to LabSize-2 do for j := 1 to LabSize-2 do
        if (cpu[i,j]<=0) then begin
          cp[i,j] := 0;
          p := true;                   
          if (cpu[i-1,j]<=0) and (cpu[i-1,j-1]<=0) and (cpu[i,j-1]<=0) then p := false;
          if (cpu[i-1,j]<=0) and (cpu[i-1,j+1]<=0) and (cpu[i,j+1]<=0) then p := false;
          if (cpu[i+1,j]<=0) and (cpu[i+1,j-1]<=0) and (cpu[i,j-1]<=0) then p := false;
          if (cpu[i+1,j]<=0) and (cpu[i+1,j+1]<=0) and (cpu[i,j+1]<=0) then p := false;
          if p and (random(15)=0) then
            for i2 := i-1 to i+1 do for j2 := j-1 to j+1 do cp[i2,j2] := 0;
        end else if random(5)=0 then
          cp[i,j] := 0;
          
      for i := 1 to LabSize-2 do for j := 1 to LabSize-2 do
        if (cp[i,j]<=0) and (cpu[i,j]>0) then begin
          c := 0;
          for i2 := i-1 to i+1 do for j2 := j-1 to j+1 do if cpu[i2,j2]<=0 then inc(c);
          if (c>5) and (random(5)>0) then cp[i,j] := 1;
        end;
      for i := 0 to LabSize-1 do begin
        cp[i,0] := 1;
        cp[i,LabSize-1] := 1;
        cp[0,i ] := 1;
        cp[LabSize-1,i] := 1;
      end;
    end;

    procedure CreateHoles (var cpu,cpd : PassMap; var pu,pd : FloorPoints; chanse : integer);
    var
      i,j : integer;
      ok : boolean;
    begin
      for i := 1 to LabSize-2 do for j := 1 to LabSize-2 do begin
        if (cpu[i,j]=1) and (cpd[i,j]<=0) and (cpd[i,j]>-$10000)
        and ((cpd[i,j]=0) or (cpd[i,j] mod ec = 0))  then begin
          if  (pu[i  ,j  ,1].z+2.4<pd[i  ,j  ,1].z)
          and (pu[i  ,j+1,1].z+2.4<pd[i  ,j+1,1].z)
          and (pu[i+1,j  ,1].z+2.4<pd[i+1,j  ,1].z)
          and (pu[i+1,j+1,1].z+2.4<pd[i+1,j+1,1].z) and (random(100)<chanse) then begin
            if (cpu[i-1,j]<0) or (cpu[i+1,j]<0) or (cpu[i,j-1]<0) or (cpu[i,j+1]<0) then
              ok := chanse<100
            else
              ok := true;
            if ok then begin                 
              if cpu[i,j]>0 then
                cpu[i,j] := -$20000
              else
                cpu[i,j] := cpu[i,j]-$20000;
              cpd[i,j] := cpd[i,j]-$10000;
              pd[i  ,j  ,0].z := pu[i  ,j  ,1].z+0.7;
              pd[i+1,j  ,0].z := pu[i+1,j  ,1].z+0.7;
              pd[i  ,j+1,0].z := pu[i  ,j+1,1].z+0.7;
              pd[i+1,j+1,0].z := pu[i+1,j+1,1].z+0.7;
            end;
          end;
        end;
      end;
    end;

    procedure TestWood(fu : integer);
    var
      i,j,c : integer;
    begin
      for i := 1 to LabSize-2 do for j := 1 to LabSize-2 do begin
        if (cp[fu,i,j]<=0) and (cp[fu,i,j]>-$20000) and (cp[fu-4,i,j]<=0) then begin
          wood[fu,i,j] := True;
          if (cp[fu,i-1,j]>-$20000) and (cp[fu,i-1,j-1]>-$20000) and (cp[fu,i,j-1]>-$20000) then wood[fu,i,j] := False;
          if (cp[fu,i-1,j]>-$20000) and (cp[fu,i-1,j+1]>-$20000) and (cp[fu,i,j+1]>-$20000) then wood[fu,i,j] := False;  
          if (cp[fu,i+1,j]>-$20000) and (cp[fu,i+1,j-1]>-$20000) and (cp[fu,i,j-1]>-$20000) then wood[fu,i,j] := False;
          if (cp[fu,i+1,j]>-$20000) and (cp[fu,i+1,j+1]>-$20000) and (cp[fu,i,j+1]>-$20000) then wood[fu,i,j] := False;
          c := 0;
          if (cp[fu,i-1,j]>0) or (cp[fu,i-1,j]<=-$20000) then inc(c);
          if (cp[fu,i,j-1]>0) or (cp[fu,i,j-1]<=-$20000) then inc(c); 
          if (cp[fu,i+1,j]>0) or (cp[fu,i+1,j]<=-$20000) then inc(c);
          if (cp[fu,i,j+1]>0) or (cp[fu,i,j+1]<=-$20000) then inc(c);
          if c>=3 then wood[fu,i,j] := false;
        end;
      end;
    end;

    function GetS (i,j:integer; fu : integer): PSector;
    begin
      Result := nil;
      case fu mod 4 of
        0 : begin if i<0 then begin i:=LabSize-1; dec(fu); end; if j<0 then begin j:=LabSize-1; inc(fu); end; end;
        1 : begin if i<0 then begin i:=LabSize-1; inc(fu); end; if j>=LabSize then begin j:=0;  dec(fu); end; end;
        2 : begin if i>=LabSize then begin i:=0;  dec(fu); end; if j>=LabSize then begin j:=0;  inc(fu); end; end;
        3 : begin if i>=LabSize then begin i:=0;  inc(fu); end; if j<0 then begin j:=LabSize-1; dec(fu); end; end;
      end;
      if (cp[fu,i,j]<=0) then begin
        if (cp[fu,i,j]<=-$20000) or (cp[fu,i,j]>-$10000) then result := @L.S[fu,i,j]
        else if cp[fu+4,i,j]<=0 then result := @L.S[fu+4,i,j];
      end;
    end;

    const MinLight = 1;

    procedure CreateSectors(fu : integer);
    var
      i,j,k : integer;
      fd : integer;

      procedure AddFaces(const cp,cpt : PassMap; const P0,P1,P2 : FloorPoints; pi0,pi1 : integer; fcn : integer; MF : boolean);
      var
        fcna : integer;

        procedure AF (ti,tj,i1,j1,i2,j2 : integer);
        var
          Added : boolean;
          HasNext : boolean;
        begin
          if (cpt[i,j]<=-$20000) and (cpt[ti,tj]<=-$20000) then Added := MF else Added := True;
          HasNext := not ((ti>=0) and (tj>=0) and (ti<LabSize) and (tj<LabSize) and (cp[ti,tj]>0)) and (fcn>=0);
          if (fcn>=0) and Added and HasNext then fn[fcn] := fc;
          fna[fcna] := fc;
          Inc(fcn);
          Inc(fcna);
          if not Added then Exit;
          if (cpt[i,j]<=-$20000) and (cpt[ti,tj]<=-$20000) then begin
            AddF([@P0[i1,j1,pi0],
              @P0[i2,j2,pi0],
              @P1[i2,j2,pi1],
              @P2[i2,j2,pi0],
              @P2[i2,j2,pi1],
                @P2[i1,j1,pi1],
                @P2[i1,j1,pi0],
                @P1[i1,j1,pi1]])
          end else if not HasNext then
            AddTF( @P0[i1  ,j1  ,pi0], @P0[i2  ,j2,pi0], @P1[i2  ,j2,pi1], @P1[i1  ,j1  ,pi1] )
          else
            AddF([ @P0[i1  ,j1  ,pi0], @P0[i2  ,j2,pi0], @P1[i2  ,j2,pi1], @P1[i1  ,j1  ,pi1] ]);
        end;

      begin
        fcna := 0;
        Af(i-1, j  , i  , j  , i  , j+1);
        Af(i  , j-1, i+1, j  , i  , j  );
        Af(i+1, j  , i+1, j+1, i+1, j  );
        Af(i  , j+1, i  , j+1, i+1, j+1);
      end;

      function GetWallTexture (fu,i,j : integer; roof: boolean): PTexture;
      begin
        if fu in [10..14] then begin
          if roof then
            result := @BaseTxr[10]
          else
            result := @TechTxr[(cp[fu,i,j] and $FFFF) mod Length(TechTxr)];
        end else
          result := @AncTxr[(cp[fu,i,j] and $FFFF) mod Length(AncTxr)];
      end;

      procedure SetL(ft : integer);
      var
        roof : boolean;
      begin
        roof := (k>=fc-4) and (k<fc-2);
        L.S[fu,i,j].Faces[k].Texture := GetWallTexture(ft,i,j, roof);
        if roof and (ft in [10..14]) and not wood[ft+4,i,j] and (cp[ft,i,j] mod ec<>0) then
          L.S[fu,i,j].Faces[k].Light := 255;
      end;

    begin
      // генерируем сектора
      fd := fu-4;
      if fd<0 then fd := 0;

      for i := 0 to LabSize-1 do for j := 0 to LabSize-1 do with L do
      if (cp[fu,i,j]<=0) and ((cp[fu,i,j]<=-$20000) or (cp[fu,i,j]>-$10000)) then begin

        for k := 0 to 7 do fn[k] := -1;                                                     
        for k := 0 to 7 do fna[k] := -1;
        pc := 0;
        fc := 0;
        AddFaces(cp[fu],cp[fu], P[fu], P[fu], P[fd], 0, 1, 0, true);

        if (cp[fu,i,j]>-$10000) then begin
          lfn := fc;
          AddTF( @P[fu,i  ,j  ,0], @P[fu,i+1,j  ,0], @P[fu,i+1,j+1,0], @P[fu,i  ,j+1,0] );
          AddTF( @P[fu,i  ,j  ,1], @P[fu,i  ,j+1,1], @P[fu,i+1,j+1,1], @P[fu,i+1,j  ,1] );
        end else if cp[fu,i,j]<=-$20000 then begin
          lfn := fc;
          AddFaces(cp[fd],cp[fu],P[fd],P[fd],P[fd],0,1, 4, false);
          AddFaces(cp[fu],cp[fu],P[fu],P[fd],P[fd],1,0, -100, false);
          AddTF( @P[fu,i  ,j  ,0], @P[fu,i+1,j  ,0], @P[fu,i+1,j+1,0], @P[fu,i  ,j+1,0] );
          AddTF( @P[fd,i  ,j  ,1], @P[fd,i  ,j+1,1], @P[fd,i+1,j+1,1], @P[fd,i+1,j  ,1] );
        end;

        CreateSector(S[fu,i,j], pc, pt);
        if cp[fu,i,j]<=-$20000 then
          S[fu,i,j].ID := ((fu-4) shl 16) or (i shl 8) or j
        else                                             
          S[fu,i,j].ID := (fu shl 16) or (i shl 8) or j;

        if fn[0]>=0 then S[fu,i,j].Faces[fn[0]].NextSector := GetS(i-1,j, fu);
        if fn[1]>=0 then S[fu,i,j].Faces[fn[1]].NextSector := GetS(i,j-1, fu);
        if fn[2]>=0 then S[fu,i,j].Faces[fn[2]].NextSector := GetS(i+1,j, fu);
        if fn[3]>=0 then S[fu,i,j].Faces[fn[3]].NextSector := GetS(i,j+1, fu);

        if cp[fu,i,j]<=-$20000 then begin
          if fn[4]>=0 then S[fu,i,j].Faces[fn[4]].NextSector := GetS(i-1,j, fd);
          if fn[5]>=0 then S[fu,i,j].Faces[fn[5]].NextSector := GetS(i,j-1, fd);
          if fn[6]>=0 then S[fu,i,j].Faces[fn[6]].NextSector := GetS(i+1,j, fd);
          if fn[7]>=0 then S[fu,i,j].Faces[fn[7]].NextSector := GetS(i,j+1, fd);

          if fd<4 then for k := 0 to fc-1 do begin
            if ((k>=lfn) and (k<fna[0])) or (k>=fc-2) then
              S[fu,i,j].Faces[k].NextSector := @L.HellS;
          end;
        end;
        for k := 0 to fc-1 do with S[fu,i,j].Faces[k] do
          Penetrable := (NextSector<>nil) and (NextSector<>@L.SkyS) and (NextSector<>@L.HellS);
        S[fu,i,j].Gravity := 0.003;
        S[fu,i,j].inProcess := 0;
        S[fu,i,j].Skybox := false;


        lightroom := false;
        for k := 0 to fc-1 do begin
          ltmax := 0;
          ltmin := 10;
          SetLtMaxMin(P[fu], i,j);
          SetLtMaxMin(P[fu], i+1,j);
          SetLtMaxMin(P[fu], i,j+1);
          SetLtMaxMin(P[fu], i+1,j+1);

          S[fu,i,j].Faces[k].Light := 0;
          if fu>=24 then
            S[fu,i,j].Faces[k].Texture := @BaseTxr[4]
          else if fu<10 then                           
            S[fu,i,j].Faces[k].Texture := @BaseTxr[11]
          else
            S[fu,i,j].Faces[k].Texture := @BaseTxr[2];

          if cp[fu,i,j]<=-$20000 then begin
            if (k>=lfn) and (k<fc-4) then
              if cp[fd,i,j] mod ec <> 0 then SetL(fd);
          end else begin
            if cp[fu,i,j]<0 then
              if cp[fu,i,j] mod ec <> 0 then SetL(fu);
          end;

          if (cp[fu,i,j]<=-$20000) and (k<fc-4) then begin
            if (k>=fna[3]) then begin
              if wood[fu,i,j+1] then S[fu,i,j].Faces[k].Texture := @BaseTxr[5];
            end else if (k>=fna[2]) then begin
              if wood[fu,i+1,j] then S[fu,i,j].Faces[k].Texture := @BaseTxr[5];
            end else if (k>=fna[1]) then begin
              if wood[fu,i,j-1] then S[fu,i,j].Faces[k].Texture := @BaseTxr[5];
            end else if (k>=fna[0]) then begin
              if wood[fu,i-1,j] then S[fu,i,j].Faces[k].Texture := @BaseTxr[5];
            end;
          end;

          if (k>=fc-2) then begin  // пол
            if (fu<10) or ((cp[fu,i,j]<=-$20000) and (fd<10)) then
              S[fu,i,j].Faces[k].Texture := @BaseTxr[9]
            else
              S[fu,i,j].Faces[k].Texture := @BaseTxr[1];

            if wood[fu,i,j] or ((cp[fu,i,j]<=-$20000) and wood[fu-4,i,j]) then
              S[fu,i,j].Faces[k].Texture := @BaseTxr[5]
            else if fu in [10..14] then
              S[fu,i,j].Faces[k].Texture := @BaseTxr[6]
            else if cp[fu,i,j]<0 then begin
              if cp[fu,i,j]>-$10000 then begin
                if cp[fu,i,j] mod ec<>0 then
                  S[fu,i,j].Faces[k].Texture := @BaseTxr[3];
              end else if cp[fd,i,j] mod ec<>0 then
                S[fu,i,j].Faces[k].Texture := @BaseTxr[3];
            end;
            S[fu,i,j].Faces[k].VTx     := ToPoint(28,14,0);
            S[fu,i,j].Faces[k].VTXc    := 0;
            S[fu,i,j].Faces[k].VTy     := ToPoint(-14,28,0);
            S[fu,i,j].Faces[k].VTYc    := 0;
          end else if k>=fc-4 then begin // потолок
            if ((fu<28) and wood[fu+4,i,j]) then
              S[fu,i,j].Faces[k].Texture := @BaseTxr[5]
            else if (ltmin>=4) and ((fu>=28) or (cp[fu+4,i,j]>=3)) then begin
              S[fu,i,j].Faces[k].NextSector := @L.Skys;
              lightroom := true;
            end;
            S[fu,i,j].Faces[k].VTx     := ToPoint(32,0,0);
            S[fu,i,j].Faces[k].VTXc    := 0;
            S[fu,i,j].Faces[k].VTy     := ToPoint(0,32,0);
            S[fu,i,j].Faces[k].VTYc    := 0;
          end else begin
            S[fu,i,j].Faces[k].VTx     := ToPoint(20,-20,0);
            S[fu,i,j].Faces[k].VTXc    := 0;
            S[fu,i,j].Faces[k].VTy     := ToPoint(0,0,32);
            S[fu,i,j].Faces[k].VTYc    := 0;
          end;
          if S[fu,i,j].Faces[k].Penetrable then S[fu,i,j].Faces[k].Texture := nil;
        end;           
        if (fu in [10..14]) and (cp[fu,i,j]<0) and (cp[fu,i,j] mod ec <> 0) and not wood[fu+4,i,j] then
          lightroom := true;
        if (fu<8) and (cp[fu,i,j]<=-$20000) then
          lightroom := true;
        if lightroom then for k := 0 to fc-1 do
          if S[fu,i,j].Faces[k].Light<255 then S[fu,i,j].Faces[k].Light := 64;
      end;

    end;

    procedure InitLights (fu : integer);
    var
      i,j,k  : integer;
      i1,j1 : integer;
      S : PSector;
    begin
      for i := 0 to LabSize-1 do for j := 0 to LabSize-1 do
      if (cp[fu,i,j]<=0) and ((cp[fu,i,j]<=-$20000) or (cp[fu,i,j]>-$10000)) then begin
        if L.S[fu,i,j].Faces[0].Light<64 then begin
          fc := 0;
          for i1 := i-1 to i+1 do for j1 := j-1 to j+1 do if (i1<>i) or (j1<>j) then begin
            S := GetS(i1,j1,fu);
            if (S<>nil) and (S.Faces[0].Light>=64) then begin
              if (i1=i) or (j1=j) then
                Inc(fc)
              else if (GetS(i1,j,fu)<>nil) or (GetS(i,j1,fu)<>nil) then
                Inc(fc);
            end;
          end;
          for k := 0 to L.S[fu,i,j].CFaces-1 do
            if L.S[fu,i,j].Faces[k].Light<255 then begin
              case fc of
                1..8 : L.S[fu,i,j].Faces[k].Light := 24;
              end;
            end;
        end;
      end;
         {
      for i := 0 to LabSize-1 do for j := 0 to LabSize-1 do
      if (cp[fu,i,j]<=0) and ((cp[fu,i,j]<=-$20000) or (cp[fu,i,j]>-$10000)) then begin
        for k := 0 to L.S[fu,i,j].CFaces-1 do begin
          if L.S[fu,i,j].Faces[k].Light<255 then
            L.S[fu,i,j].Faces[k].Light := ((L.S[fu,i,j].Faces[k].Light+3) div 4)*3 + MinLight;
        end;
      end;  }
    end;

    procedure ShiftGeometry;
    var
      dx,dy : DeltaArr;
      i,j,k,ix,iy : integer;

      procedure ShiftFloor(const cp : PassMap; var P : FloorPoints);
        procedure Mw(x,y,nx,ny:integer);
        var
          k : integer;
        begin
          for k := 0 to 1 do
            P[x,y,k] := Add(P[x,y,k], Scale(Sub(P[nx,ny,k],P[x,y,k]), (random(2)-0.5)*0.14));
        end;
      var
        i,j,k : integer;
      begin
        for i := 1 to LabSize-2 do for j := 1 to LabSize-2 do
        if  (cp[i-1,j-1]>-$10000) and (cp[i-1,j]>-$10000)
        and (cp[i  ,j-1]>-$10000) and (cp[i  ,j]>-$10000)
        then begin
          k := 0;
          if cp[i-1,j-1]>0 then inc(k);
          if cp[i-1,j]>0 then inc(k);
          if cp[i,j-1]>0 then inc(k);
          if cp[i,j]>0 then inc(k);
          if k>=3 then for k := 0 to 1 do with P[i,j,k] do begin
            x := x + (random(2)-0.5)*0.14;
            y := y + (random(2)-0.5)*0.14;
          end else if k=2 then begin
            if (cp[i-1,j-1]>0) and (cp[i,j-1]>0) then Mw(i,j,i,j+1);
            if (cp[i-1,j-1]>0) and (cp[i-1,j]>0) then Mw(i,j,i+1,j);
            if (cp[i-1,j  ]>0) and (cp[i,j  ]>0) then Mw(i,j,i,j-1);
            if (cp[i  ,j-1]>0) and (cp[i  ,j]>0) then Mw(i,j,i-1,j);
          end;
        end;
      end;

    begin
      for i := 0 to 2*LabSize do for j := 0 to 2*LabSize do begin
        dx[i,j] := random*10;
        dy[i,j] := random*10;
      end;
      GenDeltas(cp[0], dx, 3);
      GenDeltas(cp[0], dy, 3);
      for i := 0 to 2*LabSize do for j := 0 to 2*LabSize do begin
        dx[i,j] := dx[i,j]+random*0.14;
        dy[i,j] := dy[i,j]+random*0.14;
      end;
      for k := 0 to 31 do begin
        for i := 0 to LabSize do for j := 0 to LabSize do begin
          ix := -1;
          iy := -1;
          case k mod 4 of
            0 : begin ix := i+LabSize; iy := j+LabSize; end;
            1 : begin ix := i+LabSize; iy := j; end;
            2 : begin ix := i; iy := j; end;
            3 : begin ix := i; iy := j+LabSize; end;
          end;
          L.P[k,i,j,0].x := L.P[k,i,j,0].x + dx[ix,iy]*0.2;
          L.P[k,i,j,0].y := L.P[k,i,j,0].y + dy[ix,iy]*0.2;
          L.P[k,i,j,1].x := L.P[k,i,j,1].x + dx[ix,iy]*0.2;
          L.P[k,i,j,1].y := L.P[k,i,j,1].y + dy[ix,iy]*0.2;
        end;
      end;

      for k := 0 to 31 do if not (k in [10..14]) then ShiftFloor(cp[k],L.P[k]);
    end;

  var
    i,ch : integer;

    function FacesCorrect : boolean;
    var
      NS : PSector;
      i,j,k,f,f2 : integer;
      b : boolean;
    begin
      Result := True;
      for i := 4 to 31 do
        for j := 0 to LabSize-1 do for k := 0 to LabSize-1 do
          if (cp[i,j,k]<=0) and ((cp[i,j,k]>-$10000) or (cp[i,j,k]<=-$20000)) then begin
            for f := 0 to L.S[i,j,k].CFaces-1 do begin
              NS := L.S[i,j,k].Faces[f].NextSector;
              if (NS<>nil) and  (NS<>@L.SkyS) and  (NS<>@L.HellS) then begin
                b := true;
                for f2 := 0 to NS.CFaces-1 do if NS.Faces[f2].NextSector = @L.S[i,j,k] then begin
                  b := false;
                  break;
                end;
                if b then begin
                  Assert(False);
                  Result := False;
                  Exit;
                end;
              end;
            end;
          end;
    end;

    procedure InitMonsters;
    var
      i,j,k,ce,ci : integer;
      d : integer;
      wt,wb : boolean;

      // d:0..27
      procedure AddEnemy;
      var
        M  : PItemModel;
        ml : float;
      begin
        if ce >= CMonsters then Exit;
        
        ml := (d+random*13)/40;
        if ml>1 then ml:=1;
        case d+random(15) of
          0  .. 14 : M := @IMTrilobit[round(ml*High(IMTrilobit))];
          15 .. 22 : M := @IMSnowman [round(ml*High(IMSnowman ))];
          23 .. 30 : M := @IMCock    [round(ml*High(IMCock    ))];
          else       M := @IMGasbag  [round(ml*High(IMGasbag  ))];
        end;
        if (k=4) and (cp[k,i,j]<0) and (cp[k,i,j]>-$10000) and not wb then begin
          M  := @IMBoss[0];
          wb := true;
        end;

        CreateMonster(@L.Enemies[ce], GetS(i,j,k), M);
        if M=@IMBoss[0] then L.Boss := @L.Enemies[ce];

        Inc(ce);
      end;

      procedure AddBox;
      var
        M : PItemModel;
      begin       
        if ci >= CItems then exit;
        case random(25) of
          0      : M := @IMBox[1];
          1 ..20 : M := @IMBox[0];
          else     M := @IMBox[2];
        end;
        if (k in [6,7,8,11,12,13]) and (random(2)=0) then M := @IMBox[2];
        if (k in [19..23]) and (random(10)=0) then M := @IMBox[3];

        if (k=31) and (cp[k,i,j]<0) and (cp[k,i,j]>-$10000) and not wt then begin
          M  := @IMBox[4];
          wt := true;
        end;

        CreateItem(@L.Items[ci], GetS(i,j,k), M);
        Inc(ci);
      end;

    begin
      CreateMonster(@L.Player, GetS(LabSize-2,LabSize-2,16), @IMPlayer);

      ce := 0;
      ci := 0;

      wt := false;
      wb := false;

      for k := 4 to 31 do begin
        if k>=16 then d := k-16
        else if k=15 then d := 1
        else if k<15 then d := 31-k;

        for i := 1 to LabSize-2 do for j := 1 to LabSize-2 do begin
          if (cp[k,i,j]<=0)
          and (cp[k,i,j]>-$10000) and (cp[k,i,j]<>cp[16,LabSize-2,LabSize-2])
          and (Random(7)=0) then begin
            if random(d+40)>=d+20 then AddBox
            else AddEnemy;
          end;
        end;
      end;
    end;

    procedure InitBullets;
    var
      i : integer;
    begin
      for i := 0 to CBullets-1 do
        CreateBullet(@L.Bullets[i]);
    end;

  begin
    pc := 0;

    CSectors := 32*sqr(LabSize)+1;

    FillChar(wood,sizeof(wood),false);

    InitSkyBox(L.SkyP, L.SkyS, @BaseTxr[0], @BaseTxr[0]);
    InitSkyBox(L.HellP, L.HellS, @BaseTxr[7], @BaseTxr[8]);       
    InitSkyBox(L.EmptyP, L.EmptyS, @BaseTxr[0], @BaseTxr[0]);

    for i := 0 to 31 do InitFloor(cp[i], L.P[i], i);
    for i := 0 to 3 do FillLavalLevel(cp[i],cp[i+4]);

    for i := 4 to 31 do begin
      case i of
        4..7   : ch := 99;
        8      : ch := 0;
        9      : ch := 99;
        10..13 : ch := 0;
        14     : ch := 45;
        15..18 : ch := 0;
        19     : ch := 100;
        20     : ch := 0;
        else     ch := 100;
      end;
      CreateHoles(cp[i],cp[i-4],L.P[i],L.P[i-4],ch);
    end;   
    OutLabs;
    for i := 4 to 31 do TestWood(i);
    ShiftGeometry;
    for i := 4 to 31 do
      CreateSectors(i);
    for i := 4 to 31 do InitLights(i);


    Assert(FacesCorrect);

    InitMonsters;
    InitBullets;
    GameTime := 0;
  end;

end.
