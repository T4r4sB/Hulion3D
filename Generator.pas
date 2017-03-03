unit Generator;
      
interface

uses
  Points;

  const LabSize=24;

  type
    PassMap = array [0..LabSize-1,0..LabSize-1] of integer;

  var
    cp : array [0..31] of PassMap;

  type DeltaArr = array [0..LabSize*2,0..LabSize*2] of float;

  procedure InitLab(var cp : PassMap; index : integer);
  procedure GenDeltas (const cp : PassMap; var D : DeltaArr; mode : integer);

  function IsLight(n : integer) : boolean;
  function Maxd (f : integer): integer;  
  procedure OutLabs;

implementation  

  function Maxd (f : integer): integer;
  begin
    case f div 4 of
        0 : result := 2;
        7 : result := LabSize * 4 div 9;
        6 : result := LabSize * 4 div 9;
        5 : result := LabSize * 6 div 9;
      else result := LabSize;
    end;
  end;

  function CanBeEmpty (f,x,y : integer): boolean;
  var
    d : integer;
  begin
    d := Maxd(f);
    result := false;
    case f mod 4 of
      0 : result := (x>=          1) and (x<=d      -2) and (y>=          1) and (y<=d      -2);
      1 : result := (x>=          1) and (x<=d      -2) and (y>=LabSize-d+1) and (y<=LabSize-2);
      2 : result := (x>=LabSize-d+1) and (x<=LabSize-2) and (y>=LabSize-d+1) and (y<=LabSize-2);
      3 : result := (x>=LabSize-d+1) and (x<=LabSize-2) and (y>=          1) and (y<=d      -2);
    end;
  end;
  
  function CanBeEmptyR (f,x,y : integer): boolean;
  var
    i,j : integer;
  begin
    for i := x-1 to x+1 do for j := y-1 to y+1 do
      if CanBeEmpty(f,i,j) then begin
        Result := True;
        Exit;
      end;
    Result := False;
  end;

  function GetD(l : integer): integer;
  begin
    Result := Maxd(l);
    if Result>Maxd(l+1) then Result :=Maxd(l+1);
    Result := 1 + round((0.5 + abs(sin(l*l))*0.5) * (Result-3));
  end;

  procedure InitLab(var cp : PassMap; index : integer);
  var
    i,j,k,m : integer;
    x,y : integer;
    lc : integer;
    c  : integer;
    bad : boolean;
    cl,cl2 : array [0..7] of integer;
  const
    dx : array [0..7] of integer = (0,1,1,1,0,-1,-1,-1);
    dy : array [0..7] of integer = (1,1,0,-1,-1,-1,0,1);

    function Good(x,y: integer) : boolean;
    begin
      Result := (x>=0) and (x<LabSize) and (y>=0) and (y<LabSize);
    end;

    function Inner(x,y: integer) : boolean;
    begin
      Result := (x>=1) and (x<LabSize-1) and (y>=1) and (y<LabSize-1);
    end;

    function Busy(x,y: integer) : boolean;
    begin
      Result := not Good(x,y) or (cp[x,y]>0);
    end;

    procedure FillC(x,y: integer; cl : integer);
    var
      i,j: integer;
    begin
      if Good(x,y) and (cp[x,y]>0) and (cp[x,y]<>cl) then begin
        cp[x,y] := cl;
        for i := x-1 to x+1 do for j := y-1 to y+1 do FillC(i,j,cl);
      end;
    end;

    procedure FillH(x,y: integer; cl : integer);
    begin
      if Good(x,y) and (cp[x,y]=-1) then begin
        cp[x,y] := cl;
        FillH(x-1,y,cl);   
        FillH(x,y-1,cl);
        FillH(x+1,y,cl);
        FillH(x,y+1,cl);
      end;
    end;

    function NearBubble (x,y : integer): boolean;   
    var
      i,j : integer;
    begin
      for i := x-1 to x+1 do
        for j := y-1 to y+1 do
          if Good(i,j) and (cp[i,j]=-1) then begin
            Result := True;
            Exit;
          end;
      Result := False;
    end;

    procedure CreateBubble(x,y:integer;ir,sr:integer);
    var
      i,j : integer;
    begin
      for i := x-(sr) div 2 to x+(sr) div 2 do
        for j := y-(sr) div 2 to y+(sr) div 2 do
          if  (sqr(i*2+1-x*2)+sqr(j*2+1-y*2)<=sqr(sr))
          and (sqr(i*2+1-x*2)+sqr(j*2+1-y*2)> sqr(ir))
          and Inner(i,j) and not NearBubble(i,j) and (cp[i,j]=0) then cp[i,j] := -2;

      for i := x-(sr) div 2 to x+(sr) div 2 do
        for j := y-(sr) div 2 to y+(sr) div 2 do
          if Inner(i,j) and (cp[i,j]=-2) then cp[i,j] := -1;             
    end;

  begin
    for i := 0 to LabSize-1 do for j := 0 to LabSize-1 do
      if CanBeEmpty(index,i,j) then
        cp[i,j] := 0
      else
        cp[i,j] := 1;
    lc := 1;

    if index>=4 then case index mod 4 of
      0 : begin if index>4 then cp[0, GetD(index-1)] := -1; cp[GetD(index), 0] := -1; end;
      1 : begin cp[GetD(index-1), LabSize-1] := -1; cp[0, LabSize-1-GetD(index)] := -1; end;
      2 : begin cp[LabSize-1, LabSize-1-GetD(index-1)] := -1; cp[LabSize-1-GetD(index), LabSize-1] := -1; end;
      3 : begin cp[LabSize-1-GetD(index-1), 0] := -1; if index<31 then cp[LabSize-1, GetD(index)] := -1; end;
    end;

    if index=16 then begin
      CreateBubble(LabSize-3,LabSize-3,0,6);
      CreateBubble(LabSize-3,LabSize-3,7,12);
      Assert(cp[LabSize-2,LabSize-2]<0);
    end;
    if index=20 then
      cp[1,1] := -1;

    if index in [10..14] then m := LabSize*LabSize div 128
    else if index<8  then m := LabSize*LabSize div 32            
    else if index<10 then m := LabSize*LabSize div 96
    else if index<28 then m := LabSize*LabSize div 128
    else m := LabSize*LabSize div 32;

    for k := 0 to m-1 do begin
      x := random(LabSize);
      y := random(LabSize);
      CreateBubble(x,y,0,2+random(4));
      if index in [8..9,15..31] then CreateBubble(x+(random(5)-1) div 2,y+(random(5)-1) div 2,3,9-random(4));
    end;

    if index in [4..7,10..14] then m := 3200
    else m := 170;

    for k := 0 to LabSize*LabSize*m div 100 -1 do begin
      x := Random(LabSize-2)+1;
      y := Random(LabSize-2)+1;
      if cp[x,y]=0 then begin
        for i := 0 to 7 do
          cl[i] := cp[x+dx[i],y+dy[i]];
                  
        bad := false;
        for i := 0 to 3 do begin
          if (cl[(i*2+1) and 7]>0) and ((cl[(i*2) and 7]<=0) and (cl[(i*2+2) and 7]<=0)) then bad := true;
        end;


        for i := 0 to 3 do
          if cl[i*2+1]<=0 then begin
            c := cl[(i*2+2) and 7];
            if c>0 then cl[i*2+1] := c;
            c := cl[(i*2+0) and 7];
            if c>0 then cl[i*2+1] := c;
          end;
        m := 0;
        for i := 0 to 7 do begin
          if (cl[i]>0) and (cl[(i+7)and 7]<=0) then begin
            cl2[m]:=cl[i];
            inc(m);
          end;
        end;
        for i := 0 to m-1 do begin
          for j := i+1 to m-1 do if cl2[i]=cl2[j] then begin
            bad := true;
            break;
          end;
        end;

        if not bad then begin
          if index in [0..3,9,10..14] then for i := 0 to 3 do begin
            if not Busy(x+dx[i*2],y+dy[i*2]) then begin
              j := 0;
              if Busy(x+2*dx[i*2],y+2*dy[i*2]) then inc(j);
              if Busy(x+dx[(i*2+7) and 7], y+dy[(i*2+7) and 7]) then inc(j);
              if Busy(x+dx[(i*2+1) and 7], y+dy[(i*2+1) and 7]) then inc(j);
              if (j>=2) then bad := true;
            end;
          end;

          if not bad then begin
            if m=0 then begin
              inc(lc);
              cp[x,y] := lc;
            end else begin
              cp[x,y] := cl2[0];   
              for i := 0 to m-1 do if cl2[i]=1 then cp[x,y] := cl2[i];
              for i := x-1 to x+1 do for j := y-1 to y+1 do fillc(i,j,cp[x,y]);
            end;
          end;
        end;    
      end;
    end;

    for i := 0 to LabSize-1 do for j := 0 to LabSize-1 do begin
      if cp[i,j]<=0 then cp[i,j] := 0          
      else if CanBeEmpty(index,i,j) then cp[i,j] := 1
      else if CanBeEmptyR(index,i,j) then cp[i,j] := 2
      else cp[i,j] := 3;
    end;

    for i := 0 to LabSize-2 do for j := 0 to LabSize-2 do begin
      if (cp[i,j]<=0) and (cp[i+1,j]<=0) and (cp[i,j+1]<=0) and (cp[i+1,j+1]<=0) then begin
        cp[i,j] := -1;
        cp[i+1,j] := -1;
        cp[i,j+1] := -1;
        cp[i+1,j+1] := -1;
      end;
    end;

    if index>=4 then begin
      for i := 0 to LabSize-2 do for j := 0 to LabSize-2 do begin
        c := random($10000);
        FillH(i,j,-(c and $7FFF)-1);
      end;
    end;

    for i := 0 to LabSize-1 do for j := 0 to LabSize-1 do begin
      if (cp[i,j]<0) and (cp[i,j]>-100) then cp[i,j] := 0;
    end;

    {
    for k := 0 to LabSize*LabSize div 4-1 do begin
      x := random(LabSize*2-1)-LabSize+1;
      y := Random(LabSize*2-1)-LabSize+1;
      if (cp[x,y]<=0) and (cp[x,y]>=-1) then begin
        i := random(4);
        case i of
          0 : if (x<LabSize-1) and (cp[x+1,y-1]>0) and (cp[x+1,y]>0) and (cp[x+1,y+1]>0) then cp[x+1,y] := 1;
          1 : if (y<LabSize-1) and (cp[x-1,y+1]>0) and (cp[x,y+1]>0) and (cp[x+1,y+1]>0) then cp[x,y+1] := 2;
          2 : if (x>1-LabSize) and (cp[x-1,y-1]>0) and (cp[x-1,y]>0) and (cp[x-1,y+1]>0) then cp[x-1,y] := 3;
          3 : if (y>1-LabSize) and (cp[x-1,y-1]>0) and (cp[x,y-1]>0) and (cp[x+1,y-1]>0) then cp[x,y-1] := 4;
        end;
      end;
    end;
    }
  end;
  
  function IsLight(n : integer) : boolean;
  begin
    Result := n<>0;
  end;
  
  procedure GenDeltas (const cp : PassMap; var D : DeltaArr; mode : integer);
  var
    i,j,k : integer;
    nd : DeltaArr;
    f : boolean;
    d1,d2 : float;
    maxd,mind : float;
    LS : integer;

    procedure cd (x,y: integer);
    begin
      if d1>d[x,y] then d1 := d[x,y];
      if d2<d[x,y] then d2 := d[x,y];
    end;

    procedure eq (x1,y1,x2,y2: integer);
    begin
      if d[x1,y1]<>d[x2,y2] then begin
        if (abs(x1*2-LS+1)+abs(y1*2-LS+1)>abs(x2*2-LS+1)+abs(y2*2-LS+1)) then begin
          nd[x1,y1] := d[x2,y2]
        end else
          nd[x1,y1] := d[x2,y2]*0.5+d[x1,y1]*0.5;
        nd[x2,y2] := nd[x1,y1];
        f := false;
      end;
    end;

  var
    Pr : array [0..LabSize,0..LabSize] of byte;
    v : single;
    c : integer;

    procedure Test(x,y,m : integer);

      procedure Go(cp1,cp2,cp3,cp4,cp5,cp6 : integer; nx,ny : integer);
      begin
        if (cp1<=0) and (cp2<=0) then Test(nx,ny,m)
        else if (cp1<=0) or (cp2<=0) then begin
          if ((cp3>0) and (cp4>0)) or ((cp5>0) and (cp6>0)) then
            Test(nx,ny,m);
        end;
      end;

    begin
      if pr[x,y]>=m then Exit;
      if (x<=0) or (y<=0) or (x>=LS) or (y>=LS) then exit;

      pr[x,y] := m;
      if m=1 then begin
        v := v + d[x,y];
        c := c + 1;
      end else
        nd[x,y] := v;

      if x>1 then
        Go(cp[x-1,y-1], cp[x-1,y], cp[x-2,y-1], cp[x-2,y], cp[x,y-1], cp[x,y], x-1, y)
      else                                                      
        Go(cp[x-1,y-1], cp[x-1,y], 1, 1, cp[x,y-1], cp[x,y], x-1, y);
      if y>1 then
        Go(cp[x-1,y-1], cp[x,y-1], cp[x-1,y-2], cp[x,y-2], cp[x-1,y], cp[x,y], x, y-1)
      else
        Go(cp[x-1,y-1], cp[x,y-1], 1, 1, cp[x-1,y], cp[x,y], x, y-1);
      if x<LabSize-1 then
        Go(cp[x,y-1], cp[x,y], cp[x+1,y-1], cp[x+1,y], cp[x-1,y-1], cp[x-1,y], x+1, y)
      else
        Go(cp[x,y-1], cp[x,y], 1, 1, cp[x-1,y-1], cp[x-1,y], x+1, y);
      if y<LabSize-1 then
        Go(cp[x-1,y], cp[x,y], cp[x-1,y+1], cp[x,y+1], cp[x-1,y-1], cp[x,y-1], x, y+1)
      else
        Go(cp[x-1,y], cp[x,y], 1, 1, cp[x-1,y-1], cp[x,y-1], x, y+1);
    end;

  begin
    if Mode=3 then LS := LabSize*2 else LS := LabSize;

    maxd := 0;
    mind := 0;
    for i := 1 to LS-1 do
      for j := 1 to LS-1 do begin
        if ((i=1) and (j=1)) or (maxd<d[i,j]) then maxd := d[i,j];
        if ((i=1) and (j=1)) or (mind>d[i,j]) then mind := d[i,j];
      end;
    nd := d;

    for k := 0 to LS-1 do begin
      f := true;
      if mode=2 then begin
        FillChar(Pr, sizeof(Pr), 0);
        for i := 1 to LS-1 do for j := 1 to LS-1 do begin
          c := 0;
          v := 0;
          Test(i,j,1);
          if c>0 then begin
            v := v/c;
            Test(i,j,2);
          end;
        end;
        d := nd;
      end;
      for i := 1 to LS-1 do begin
        for j := 1 to LS-1 do begin
          d1 := maxd;
          d2 := mind;

          if (mode=3) or (cp[i-1,j-1]<=0) or (cp[i-1,j]<=0) then cd(i-1,j);
          if (mode=3) or (cp[i-1,j-1]<=0) or (cp[i,j-1]<=0) then cd(i,j-1);
          if (mode=3) or (cp[i  ,j-1]<=0) or (cp[i  ,j]<=0) then cd(i+1,j);
          if (mode=3) or (cp[i-1,j  ]<=0) or (cp[i,j  ]<=0) then cd(i,j+1);
          if d1<=d2 then begin
            if (d[i,j]>d1+1) or (d[i,j]<d2-1) then f := false;
            if d1<=d2-1.6 then nd[i,j] := d[i,j]*0.5 + (d1+d2)*0.25
            else if d[i,j]>d1+0.8 then nd[i,j] := d[i,j]*0.5 + (d1+0.8)*0.5
            else if d[i,j]<d2-0.8 then nd[i,j] := d[i,j]*0.5 + (d2-0.8)*0.5
            else nd[i,j] := d[i,j];
          end else nd[i,j] := d[i,j];
        end;
      end;
      if mode=1 then begin
        for i := 1 to LS-1 do begin
          for j := 1 to LS-1 do begin
            if (cp[i-1,j-1]>0) or (cp[i,j-1]>0) or (cp[i-1,j]>0) or (cp[i,j]>0) then nd[i,j] := 0;
          end;
        end;
      end;

      d := nd;
      if f then break;
    end;

    if mode<>3 then for k := 0 to LS-1 do begin
      for i := 1 to LS-1 do for j := 1 to LS-1 do begin
        if  (cp[i-1,j-1]>0)
        and (cp[i  ,j-1]>0)
        and (cp[i-1,j  ]>0)
        and (cp[i  ,j  ]>0) then begin
          nd[i,j] := d[i,j]*0.5 + d[i-1,j]*0.125 + d[i,j-1]*0.125 + d[i+1,j]*0.125 + d[i,j+1]*0.125;
        end;
      end;
      d := nd;
    end;       
  end;

  procedure OutLab(var f : text; const cp : PassMap);
  var
    i,j:integer;
  begin
    for i := 0 to LabSize-1 do begin
      for j := 0 to LabSize-1 do begin
        if cp[i,j] <= -$20000 then write(f,'v')
        else if cp[i,j] <= -$10000 then write (f,'.')
        else if cp[i,j] <= 0 then write(f, ' ')
        else Write(f, 'M');
      end;
      WriteLn(f);
    end;
    WriteLn(f);
  end;

  procedure OutLabs;
  var
    i : integer;
    f : text;
  begin
  
    Assign(f, 'lab.txt');
    Rewrite(f);
    if IOResult=0 then begin
      for i := 4 to 31 do begin
        WriteLn(f, 'Level ', i-3);
        OutLab(f, cp[i]);
      end;
      Close(f);
    end;
  end;

end.
