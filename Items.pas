unit Items;

interface

uses
  Geometry, Monsters, EngineTypes, Points;

  procedure PutItemToSectors (var it: Item);
  procedure DelItemFromSectors (var it: Item);
  procedure UpdateItem (var it : Item);
  procedure CreateItem (it : PItem; S : PSector; Model : PItemModel);

implementation

  uses
    Memory, Collisions, Level, Textures, Engine;

  type PPConvexInSector = ^PConvexInSector;

  function PtrFromNextC (const CS : ConvexInSector) : PPConvexInSector;
  begin
    if CS.NC = nil then
      Result := @CS.Sector.LConvex
    else
      Result := @CS.NC.PC;
  end;

  function PtrFromPrevC (const CS : ConvexInSector) : PPConvexInSector;
  begin
    if CS.PC = nil then
      Result := @CS.Sector.FConvex
    else
      Result := @CS.PC.NC;
  end;

  function PtrFromNextS (const CS : ConvexInSector) : PPConvexInSector;
  begin
    if CS.NS = nil then
      Result := @CS.Convex.LSector
    else
      Result := @CS.NS.PS;
  end;

  function PtrFromPrevS (const CS : ConvexInSector) : PPConvexInSector;
  begin
    if CS.PS = nil then
      Result := @CS.Convex.FSector
    else
      Result := @CS.PS.NS;
  end;

  procedure PutItemToSectors (var it: Item);   
  var
    i,j : integer;
    MS : MemoryState;
    CPS : integer;
    PP : PAPSector;
    PCS : PConvexInSector;

    function NoInThisSector (const S: Sector; PC : PConvex) : boolean;
    begin
      Result := False;
      PCS := S.FConvex;
      while PCS <> nil do begin
        if PCS.Convex=PC then Exit;
        PCS := PCS.NC;
      end;
      Result := True;
    end;

  begin
    SaveState(MS);
    PP := Alloc(CSectors*sizeof(PSector));
    for i := 0 to it.CConvexes-1 do with it.Convexes[i] do begin
      CPS := 0;
      GetSectors(Center, R, False, CPS, PP);
      if CPS>10 then begin
        CPS := CPS;
      end;
      for j := 0 to CPS-1 do begin
        Assert(NoInThisSector(PP[j]^, @it.Convexes[i]));
        PCS := GetPtr;
        PCS.Convex := @it.Convexes[i];
        PCS.Sector := PP[j];

        if FSector=nil then FSector := PCS else LSector.NS := PCS;
        PCS.PS := LSector;
        LSector := PCS;

        if PP[j].FConvex=nil then PP[j].FConvex := PCS else PP[j].LConvex.NC := PCS;
        PCS.PC := PP[j].LConvex;
        PP[j].LConvex := PCS;

        PCS.NS := nil;
        PCS.NC := nil;
      end;
      Unprocess(CPS, PP);
    end;
    RestoreState(MS);
  end;

  procedure DelItemFromSectors (var it: Item);
  var
    i : integer;
    CS,OCS : PConvexInSector;
    P1,P2 : PPConvexInSector;
  begin
    for i := 0 to it.CConvexes-1 do begin
      CS := it.Convexes[i].FSector;
      while CS<>nil do begin
        P1 := PtrFromNextC(CS^);
        P2 := PtrFromPrevC(CS^);
        P1^ := CS.PC;
        P2^ := CS.NC;
        
        P1 := PtrFromNextS(CS^);
        P2 := PtrFromPrevS(CS^);
        P1^ := CS.PS;
        P2^ := CS.NS;

        OCS := CS;
        CS := CS.NS;
        FreePtr(OCS);
      end;
      Assert(it.Convexes[i].FSector=nil);   
      Assert(it.Convexes[i].LSector=nil);
    end;
  end;

  procedure MovePoints (var it : Item);    
  var
    i : integer;
  begin
    for i := 0 to it.CPoints-1 do
      it.ItemPoints[i].cP := RotateP(it.Position, it.ItemPoints[i].iP);

    for i := 0 to it.CConvexes-1 do with it.Convexes[i] do begin
      Center := it.Center;
      Trace(Center, RotateP(it.Position, Shift, True));
    end;
  end;

  procedure RegroupItemTxr (var it : Item);
  var
    i,j,k : integer;
    s12,s13,tpx,tpy : Point;
    rev : array [0..2] of Point;
    ip1,ip2,ip3 : PItemPoint;
    a11,a22,a12,v : float;
  begin
    MovePoints(it);
    for i := 0 to it.CConvexes-1 do with it.Convexes[i] do begin
      InitSectorNormals(G);
      with G do begin
        for j := 0 to CFaces-1 do with Faces[j] do begin
          // смарите, это же ќќѕшный даункаст!!!!
          ip1 := PItemPoint(Points[0]);
          ip2 := PItemPoint(Points[1]);
          ip3 := PItemPoint(Points[2]);
          // хитровыебанный переворот матрицы
          tpx := ToPoint(ip1.tx, ip2.tx, ip3.tx);
          tpy := ToPoint(ip1.ty, ip2.ty, ip3.ty);

          s12 := Sub(ip2.cP, ip1.cP);
          s13 := Sub(ip3.cP, ip1.cP);

          a11 := Dot(s12,s12);
          a12 := Dot(s12,s13);
          a22 := Dot(s13,s13);

          v := 1/(a11*a22-a12*a12);

          a11 := a11*v; 
          a12 := a12*v;
          a22 := a22*v;

          for k := 0 to 2 do
            rev[k] := ToPoint(
              s12.c[k]*(-a22+a12) + s13.c[k]*(-a11+a12),
              s12.c[k]*(+a22    ) + s13.c[k]*(    -a12),
              s12.c[k]*(    -a12) + s13.c[k]*(+a11    ));

          for k := 0 to 2 do Vtx.c[k] := Dot(rev[k], tpx);
          VtxC := Dot(ip1.cP, Vtx)-ip1.tx;
          for k := 0 to 2 do Vty.c[k] := Dot(rev[k], tpy);
          VtyC := Dot(ip1.cP, Vty)-ip1.ty;

        end;
      end;
    end;
  end;
  
  procedure UpdateItem (var it : Item);
  begin
    DelItemFromSectors(it);
    it.Model.ItemProc(it);
    RegroupItemTxr(it);
    PutItemToSectors(it);
  end;

  procedure CreateItem (it : PItem; S : PSector; Model : PItemModel);
  var
    i,j,k : integer;
    Ptc   : integer;
    Pts   : array [0..127] of PPoint;

  begin
    if Model.Kind<>mkMonster then it.Monster := nil;
    if Model.Kind<>mkBullet  then it.Bullet  := nil;
    if Model.Kind<>mkWeapon  then it.Weapon  := nil;

    it.inProcess  := false;
    it.Center.S   := S;
    it.Center.P   := CenterSector(S^);
    Trace(it.Center, ToPoint(0,0,1000));   
    Trace(it.Center, ToPoint(0,0,-Model.HeadR));

    it.Model := Model;

    it.CPoints    := Model.CPoints;
    it.ItemPoints := Alloc(it.CPoints * SizeOf(ItemPoint));
    it.CConvexes  := Model.CConvexes;
    it.Convexes   := Alloc(it.CConvexes*sizeof(Convex));

    SetID(it.Position);
    j := 0;

    for i := 0 to it.CConvexes-1 do with it.Convexes[i] do 
      Center := it.Center;

    it.Model.ItemProc(it^); // выставить координаты
    MovePoints(it^);        // передвинуть точки
    for i := 0 to it.CConvexes-1 do with it.Convexes[i] do begin
      Item    := it;
      FSector := nil;
      LSector := nil;
      inProcess := false;
      Mass    := Model.Mass;
      // а теперь надо как-то составить PTS из той хуйни, что в модели...
      Ptc := 0;
      while Model.Connections[j]>=-1 do begin
        Inc(Ptc);
        if Model.Connections[j]>=0 then begin
          Assert(Model.Connections[j]<it.CPoints);
          Pts[Ptc-1] := @it.ItemPoints [Model.Connections[j] ].cP
        end else
          Pts[Ptc-1] := nil;
        Inc(j);
      end;
      Inc(j);
      CreateSector(G, Ptc, Pts);
      
      for k := 0 to G.CFaces-1 do begin
        G.Faces[k].Texture := Model.Texture;
        G.Faces[k].Light := 2;
      end;
      Assert(it.Convexes[i].R < 10);
    end;

    RegroupItemTxr(it^);
    PutItemToSectors(it^);
  end;

end.
