unit Collisions;

interface

uses
  Points, EngineTypes;

  function Trace          (var P : SPoint; Delta : Point) : boolean;
  function TraceWithItems (var P : SPoint; Delta : Point; var CIS : integer; IP : PAPItem; NoCCheck : boolean) : boolean;
  function Visible (const P1,P2: SPoint): boolean;
  procedure PushConvex (var C: Convex);
  procedure GetSectors (var P : SPoint; R: float; Push : boolean; var CPS : integer; PP: PAPSector);      
  procedure Unprocess (CPS : integer; PP : PAPSector);

implementation

  uses
    Memory, Level, Geometry, Items, Sounds;

  type
    ABool  = array [0..MaxInt div sizeof(boolean)-1] of boolean;
    PABool = ^ABool;
    AFloat  = array [0..MaxInt div sizeof(float)-1] of float;
    PAFloat = ^AFloat;

  function DistancePS (const P: Point; const S: Sector) : float;
  var
    i  : integer;
    ad : float;
  begin
    result := 0;
    for i := 0 to S.CFaces-1 do begin
      ad := Dot(P, S.Faces[i].INorm) - S.Faces[i].INormC;
      if result<ad then result := ad;
    end;
  end;

  function SPointCorrect (const P: SPoint) : boolean;
  begin
    Result := DistancePS(P.P, P.S^)<=0;
  end;

  procedure DoCorrect (var P: SPoint);
  var
    i,j : integer;
    ad : float;
    NP : Point;
    correct : boolean;
  begin
    // это такой мега-костыль, потому что плавучка может такое выкинуть
    repeat
      correct := true;
      for i := 0 to P.S.CFaces-1 do begin
        j := 1;
        NP := P.P;
        repeat
          ad := Dot(NP, P.S.Faces[i].INorm) - P.S.Faces[i].INormC;
          if ad<=0 then
            break;
          correct := false;
          NP := Add(P.P, Scale(P.S.Faces[i].INorm,-ad*j));
          inc(j);
        until false;
        P.P := NP;
      end;
    until correct;
  end;

  function TraceWithItems (var P : SPoint; Delta : Point; var CIS : integer; IP : PAPItem; NoCCheck : boolean) : boolean;
  // ну чё, смертнички, попиздовали!
  var
    NewF : PFace;
    NewP : SPoint;
    OldP,InitP : Point;
    t1,t2 : float;

    function GetIntersectionFace (const S: Sector; const P,Delta: Point) : PFace;
    var
      i  : integer;
      MS : MemoryState;
      gf : PAFloat;
      d  : float;
      md : float;

      procedure Enlarge (var f : float; newf : float);
      begin
        if f<newf then f := newf;
      end;

    begin
      SaveState(MS);
      gf := Alloc(S.CFaces*sizeof(boolean));
      for i := 0 to S.CFaces-1 do gf[i] := 0;
      for i := 0 to S.CLines-1 do begin
        d := Volume(Sub(S.Lines[i].P1^, P), Sub(S.Lines[i].P2^, P), Delta);
        if      d>0 then Enlarge(gf[S.Lines[i].f1.Id], d)
        else if d<0 then Enlarge(gf[S.Lines[i].f2.Id],-d);
      end;
      Result := nil;
      md := -1;
      for i := 0 to S.CFaces-1 do begin
        if ((md<0) or (gf[i]<md)) and (Dot(Delta, S.Faces[i].INorm)>0) then begin
          Result := @S.Faces[i];
          md := gf[i];
        end;
      end;
      // по идее, md для нужной грани должно быть ваще строго ноль, но так как у нас тут блядская плавучка, то всякое бывает
      Assert(Result <> nil);
      RestoreState(MS);
    end;

    procedure AddItemsFromSector (const S : Sector);
    var
      PCS : PConvexInSector;
      Dst,Cr : Point;
      ok : boolean;
    begin
      if IP=nil then Exit;
      PCS := S.FConvex;
      while PCS<>nil do begin
        if PCS.Convex.CanCollide then begin
          if NoCCheck then
            ok := True
          else begin
            Dst := Sub(PCS.Convex.Center.P, NewP.P);
            if Dot(Delta, Dst)>0 then begin
              ok := Dot(Dst,Dst) < sqr(PCS.Convex.R);
            end else begin
              Dst := Sub(PCS.Convex.Center.P, InitP);
              if Dot(Delta,Dst)<0 then begin
                ok := Dot(Dst,Dst) < sqr(PCS.Convex.R);
              end else begin
                Cr := Cross(Delta,Dst);
                ok := Dot(Cr,Cr) <= sqr(PCS.Convex.R)*Dot(Delta,Delta);
              end;
            end;
          end;
          if ok and not PCS.Convex.Item.inProcess then begin
            Inc(CIS);
            IP[CIS-1] := PCS.Convex.Item;
            PCS.Convex.Item.inProcess := True;
          end;
        end;     
        PCS := PCS.NC;
      end;
    end;

  begin
    CIS := 0;
    Assert(SPointCorrect(P));
    NewP.P := Add(P.P, Delta);
    NewP.S := P.S;    
    InitP  := P.P;
    AddItemsFromSector(P.S^);
    while not SPointCorrect(NewP) do begin
      NewF := GetIntersectionFace(NewP.S^, P.P, Delta);
      if (not NewF.Penetrable) or (NewF.NextSector=nil) then begin
        Result := False;
        OldP := P.P;
        t1 := -(Dot(OldP  , newF.INorm)-newF.INormC);
        t2 := +(Dot(NewP.P, newF.INorm)-newF.INormC);
        if (t1>=0) and (t2>0) then begin
          P.P := Mid(OldP, t1, NewP.P, t2);
          Delta := Sub(P.P, InitP);
        end;
        P.S := NewP.S;
        DoCorrect(P);
        Assert(SPointCorrect(P));
        Exit;
      end;
      NewP.S := NewF.NextSector;
      AddItemsFromSector(NewP.S^);
    end;
    P := NewP;
    Assert(SPointCorrect(P));
    Result := True;
  end;

  function Trace (var P : SPoint; Delta : Point) : boolean;
  var
    CI : integer;
  begin
    Result := TraceWithItems(P, Delta, CI, nil, True);
  end;
  
  function Visible (const P1,P2: SPoint): boolean;
  var
    P : SPoint;
  begin
    Result := False;
    P := P1;
    if not Trace(P, Sub(P2.P, P1.P)) then Exit;
    if P.S<>P2.S then Exit;
    Result := True;
  end;

  procedure GetSectors (var P : SPoint; R: float; Push : boolean; var CPS : integer; PP: PAPSector);
    // это всего лишь коллизии, всего-то навсего, спокойствие, только спокойствие
    // людей буем делать из трёх сфер
    procedure TestAllFaces (var P: SPoint; S : PSector; R: float);
    var
      i,j    : integer;
      dr     : float;
      b      : boolean;
      P1, P2 : Point;
      crs    : PAPoint;
      d1, d2 : float;

      function SoftNorm (const P: Point; const N: Point): Point;
      var l : float;
      begin
        l := LengthP(P);
        if l=0 then result := N else result := Scale(P,1/l);
      end;

    begin
      // контроль, что мы тут были уже, парадигма в выставлении флагов и их возврате обратно
      if S.inProcess>0 then exit;
      Inc(CPS);
      PP[CPS-1] := S;
      S.inProcess := 1;
      // перебираем поверхности, если расстояние до неё меньше R,
      // то рекурсивно перебираем и для поверхностей того сектора, на которые она выходит
      for i := 0 to S.CFaces-1 do with S.Faces[i] do begin
        dr := R-(INormC-Dot(P.P, INorm));
        if dr>0 then begin
          // кажется, мы близки к этой грани. ну по крайней мере, мы точно близки к плоскости, что её содержит
          b := true;

          crs := Alloc(CPoints*sizeof(Point));
          for j := 0 to CPoints-1 do begin
            P1 := Sub(Points[j]^, P.P);
            P2 := Sub(Points[(j+1) mod CPoints]^, P.P);
            crs[j] := Cross(P1,P2);
          end;

          for j := 0 to CPoints-1 do begin
            if Dot(crs[j], INorm)>0 then begin  // Volume (P1-P,P2-P,INorm)
              b := false;    // мы находимся не напротив этой грани(
              break;
            end;
          end;
          if b then begin
            if Penetrable then TestAllFaces(P, NextSector, R)
            else if  Push then Trace(P, Scale(INorm, -dr));
          end else begin
            // может, есть близость с какой-то линией?
            for j := 0 to CPoints-1 do begin
              // оценить площадь треугольника, но это после обеда
            P1 := Sub(Points[j]^, P.P);
            P2 := Sub(Points[(j+1) mod CPoints]^, P.P);
              dr := R-(LengthP(crs[j])/LengthP(Sub(P1,P2)));
              if dr>0 then begin
                // мы близки к линии, но не факт, что близки к отрезку
                d1 := Dot (P1, Sub(P1,P2));
                d2 := Dot (P2, Sub(P2,P1));
                if (d1>=0) and (d2>=0) then begin
                  // близки к отрезку!
                  if Penetrable then TestAllFaces(P, NextSector, R)
                  else if  Push then Trace(P, Scale(SoftNorm(Mid(P1,d1,P2,d2), INorm), -dr));
                end else begin      
                  // близки к одной из точек?
                  if d1<0 then begin
                    dr := R-LengthP(P1);
                    if dr>0 then begin
                      if Penetrable then TestAllFaces(P, NextSector, R)
                      else if  Push then Trace(P, Scale(SoftNorm(P1, INorm), -dr));
                    end;
                  end else if d2<0 then begin
                    dr := R-LengthP(P2);
                    if dr>0 then begin
                      if Penetrable then TestAllFaces(P, NextSector, R)
                      else if  Push then Trace(P, Scale(SoftNorm(P2, INorm), -dr));
                    end;
                  end;
                end;
              end;
            end;
          end;
        end;
      end;
    end;
    // 9 ендов, идём на рекорд!

  begin
    CPS := 0;
    TestAllFaces(P, P.S, R);
  end;

  procedure Unprocess (CPS : integer; PP : PAPSector);
  var i: integer;
  begin
    for i := 0 to CPS-1 do PP[i].inProcess := 0;
  end;  

  procedure PushTwoConvexes (var S1,S2 : Convex);
  var
    DP : Point;
    dr,l,mr1,mr2 : float;

    procedure Get(var S1,S2 : Convex);
    begin
      if (S2.Item.Model.Kind=mkMonster) and (S2.Item.Model.Player) then begin
        if S1.Item.Model.ApplyItemProc(S2.Item.Monster, S1.Item) then begin
          S1.Item.Center.S := @Level.L.EmptyS;
          S1.Item.Center.P := CenterSector(S1.Item.Center.S^);
          UpdateItem(S1.Item^);
          
          SetChanel(2);
          SetStyle(120);
          SetVolume(127);
          Sound(60);
        end;
      end;
    end;

  begin
    DP := Sub(S1.Center.P, S2.Center.P);
    mr1 := S1.Mass/(S1.Mass+S2.Mass);
    mr2 := 1-mr1;
    l := Dot(DP,DP);
    if l<sqr(s1.R+s2.R) then begin
      if S1.Item.Model.Kind=mkBox then begin
        Get(S1,S2);
      end else if S2.Item.Model.Kind=mkBox then begin
        Get(S2,S1);
      end else begin
        DR := s1.R+s2.R-sqrt(l);
        // просто рсталкиваем
        // todo : для игрока и аптечки надо другое
        if l=0 then begin
          DP := ToPoint(1,0,0);
          l := 1;
        end else
          l := 1/l;
        Trace(S1.Center, Scale(DP, +DR*mr2*l));
        Trace(S2.Center, Scale(DP, -DR*mr1*l));
      end;
    end;
  end;
  
  procedure PushConvex (var C: Convex);
  var
    CPS : integer;
    PP  : PAPSector;
    CPC : integer;
    PC  : PAPConvex;
    CIS : PConvexInSector;
    i   : integer;

    MS  : MemoryState;

    procedure AddC(C : PConvex);
    begin
      Inc(CPC);
      PC[CPC-1] := C;
      PC[CPC-1].inProcess := True;
    end;

  begin
    SaveState(MS);
    PP := Alloc(CSectors*sizeof(PSector));
    GetSectors (C.Center, C.R, True, CPS, PP);
    if C.CanCollide then begin
      CPC := 0;
      PC := Alloc(CConvexes*sizeof(PConvex));

      for i := 0 to CPS-1 do begin
        CIS := PP[i].FConvex;
        while CIS<>nil do begin
          if (not CIS.Convex.inProcess) and (CIS.Convex.Item <> C.Item) and (CIS.Convex.CanCollide) then
            AddC(CIS.Convex);
          CIS := CIS.NC;
        end;
      end;
      // переебрать все итемы во всех этих комнатах и растолкать
      for i := 0 to CPC-1 do begin
        PushTwoConvexes(C, PC[i]^);
        PC[i].inProcess := False;
      end;
    end;
    Unprocess(CPS, PP);
    RestoreState(MS);
  end;

end.
