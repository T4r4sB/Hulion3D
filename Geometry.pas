unit Geometry;

interface

uses
  Bitmaps, Points, Textures, EngineTypes;
             
  procedure CreateSector (var S: Sector; PC : integer; const Pts  : array of PPoint); // указатели на точки; nil=конец грани
  procedure InitSectorNormals (var S: Sector);
  function CenterSector (const S: Sector): Point;

implementation

uses Memory;

  procedure InitSectorNormals (var S: Sector);
  var
    f : integer;
    i : integer;
  begin
    for f := 0 to S.CFaces-1 do with S.Faces[f] do begin
      INorm := ToPoint(0,0,0);
      Assert(CPoints>=3);
      for i := 2 to CPoints-1 do
        INorm := Add(INorm, Cross( Sub(Points[i]^,Points[0]^), Sub(Points[i-1]^,Points[0]^)));
      INorm := Scale(INorm, 1/LengthP(INorm));
      INormC := 0;
      for i := 0 to CPoints-1 do
        INormC := INormC + Dot(Points[i]^, INorm);
      INormC := INormC/CPoints;
    end;
  end;


  procedure CreateSector (var S: Sector; PC : integer; const Pts  : array of PPoint); // указатели на точки; nil=конец грани
  var
    i,l,f : integer;
    cpc : integer;

    procedure Connect(p1,p2 : PPoint);
    var
      i : integer;
    begin
      for i := 0 to l-1 do begin
        Assert( not ((S.Lines[i].p1 = p1) and (S.Lines[i].p2 = p2)) );
        if (S.Lines[i].p1 = p2) and (S.Lines[i].p2 = p1) then begin
          Assert(S.Lines[i].f2 = nil);
          S.Lines[i].f2 := @S.Faces[f];
          Exit;
        end;
      end;
      Inc(l);
      S.Lines[l-1].p1 := p1;
      S.Lines[l-1].p2 := p2;
      S.Lines[l-1].f1 := @S.Faces[f];
      S.Lines[l-1].f2 := nil;
    end;

    function NoNilLines : boolean;
    var i : integer;
    begin
      Result := true;
      for i := 0 to l-1 do
        if (S.Lines[i].f1=nil) or (S.Lines[i].f1=nil) then begin
          Result := false;
          exit;
        end;
    end;

  begin
    S.CFaces := 0;
    S.ID     := 0;
    S.inProcess := 0;
    S.CLines := 0;
    for i := 0 to PC-1 do begin
      if Pts[i]=nil then Inc(S.CFaces) else Inc(S.CLines);
    end;
    S.CLines := S.CLines div 2; // эн точек на грань - эн линий на грань - каждая линия к 2 граням
    S.Faces := Alloc(S.CFaces*sizeof(Face));
    S.FConvex := nil;
    S.LConvex := nil;
    S.Gravity := 0;
    S.Skybox  := False;
    for i := 0 to S.CFaces-1 do begin
      S.Faces[i].inProcess := false;
      S.Faces[i].Id := i;
      S.Faces[i].CPoints := 0;
      S.Faces[i].Points  := nil;
      S.Faces[i].NextSector := nil;
      S.Faces[i].INorm  := ToPoint(0,0,0);
      S.Faces[i].INormC := 0;
    end;
    S.Lines := Alloc(S.CLines*sizeof(Line));

    // определяем количества точек
    f := 0;
    for i := 0 to PC-1 do begin
      if Pts[i]<>nil then inc(S.Faces[f].CPoints)
      else Inc(f);
    end;
    for f := 0 to S.CFaces-1 do with S.Faces[f] do Points := Alloc(CPoints*sizeof(PPoint));

    // определяем масивы точек
    f := 0;
    cpc := 0;
    for i := 0 to PC-1 do begin
      if Pts[i]<>nil then begin
        S.Faces[f].Points[cpc] := Pts[i];
        Inc(cpc);
      end else begin
        Inc(f);
        cpc := 0;
      end;
    end;

    // соединяем точки линиями                         
    l := 0;
    for f := 0 to S.CFaces-1 do with S.Faces[f] do begin
      for i := 0 to CPoints-1 do
        Connect(Points[i], Points[(i+1) mod CPoints]);
    end;

    // проверяем, что круто соединились
    Assert(NoNilLines);
    Assert(f=S.CFaces);
    Assert(l=S.CLines);
    Assert((f>0) or (PC=0));
    // вычисляем нормали
    InitSectorNormals(S);
  end;

  function CenterSector (const S: Sector): Point;
  var
    i,j,c: integer;
  begin
    Result := ToPoint(0,0,0);
    c := 0;
    for i := 0 to S.CFaces-1 do begin
      for j := 0 to S.Faces[i].CPoints-1 do begin
        Result := Add(Result, S.Faces[i].Points[j]^);
        Inc(c);
      end;
    end;
    Result := Scale(Result, 1/c);
  end;

end.

