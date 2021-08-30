unit Hud;

interface
uses
  Windows, Messages, Bitmaps, EngineTypes;

  procedure ShowHUD (var B: Bitmap; const M : Monster);

implementation

  uses
    Generator, Level, SaveLoad, Monsters;

  procedure ShowHUD (var B: Bitmap; const M : Monster);
  var
    j, i,x,y : integer;
    tmp  : string [31];
    S    : string [31];
    cl,clw,clf,clh,clp : Color;
    Line : PAColor;

    hx,hy : array [0..LabSize] of integer;
    sz : TSize;

  const
    H: HFONT = 0;
  begin
    if H=0 then begin
      H := CreateFont(-B.sizeY div 20, 0, 0, 0,
        0, 0, 0, 0, RUSSIAN_CHARSET, OUT_DEFAULT_PRECIS,
        CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE,
        'Lucida Console');
    end;
    cl := NearestColor(round(255*(1-M.LastDamage)),0,0);
    for j := 0 to B.sizeY div 4 - 1 do begin
      Line := PAColor(@B.Pixels[B.Stride*j]);
      for i := 0 to B.sizeX-1 do Line[i] := cl;
    end;
    SetBkMode(B.DC,TRANSPARENT);

    if Live(L.Boss^) then begin

      if M.Health>80 then
        SetTextColor(B.DC, $00FF00)
      else if M.Health>30 then
        SetTextColor(B.DC, $00FFFF)
      else
        SetTextColor(B.DC, $0000FF);

      SelectObject(B.DC, H);

      Str(M.Health:3:0, tmp);
      S := 'Здоровья: ' + tmp;
      TextOut(B.DC, B.sizeX div 20, B.sizeY * 33 div 40, PAnsiChar(@S[1]), Length(S));

      Str(M.Armor:3:0, tmp);
      S := 'Брони   : ' + tmp;
      TextOut(B.DC, B.sizeX div 20, B.sizeY * 35 div 40, PAnsiChar(@S[1]), Length(S));

      for i := 1 to 3 do if M.Weapons[i].IsWeapon then begin
        if M.CurrentWeapon=i then SetTextColor(B.DC, $0000FF) else SetTextColor(B.DC, $777777);
        S := M.Weapons[i].Item.Model.Name;
        TextOut(B.DC, B.sizeX*6 div 9, B.sizeY*(15+i)div 20, PAnsiChar(@S[1]), Length(S));
      end;

      Str((M.Legs.S.ID shr 16 - 3):2, tmp);
      S := 'Уровень ' + tmp;
      TextOut(B.DC, B.sizeX*4 div 10, B.sizeY * 30 div 40, PAnsiChar(@S[1]), Length(S));

      for i := 0 to LabSize do begin
        hx[i] := B.SizeX    div 2  +(i*2-LabSize)*B.sizeY div (LabSize*10);
        hy[i] := B.SizeY*4  div 40 +(i*2-LabSize)*B.sizeY div (LabSize*10);
      end;

      clw := NearestColor(64,32,0);
      clf := NearestColor(128,255,0);
      clh := NearestColor(64,128,0);
      clp := NearestColor(255,255,255);

      for y := 0 to LabSize-1 do begin
        for x := 0 to LabSize-1 do begin
          if (x=M.Legs.S.ID shr 8 and $FF) and (y=M.Legs.S.ID and $FF) then
            cl := clp
          else if cp[M.Legs.S.ID shr 16, x,y] > 0 then
            cl := clw
          else if cp[M.Legs.S.ID shr 16, x,y] <= -$20000 then
            cl := clh
          else
            cl := clf;
          for j := hy[y] to hy[y+1]-1 do begin
            Line := PAColor(@B.Pixels[B.Stride*j]);
            for i := hx[x] to hx[x+1]-1 do
              Line[i] := cl;
          end;
        end;
      end;
    end else begin
      SetTextColor(B.DC, $00FF00);
      S := 'П О Б Е Д А ! ! !';     
      GetTextExtentPoint32(B.DC, PAnsiChar(@S[1]), Length(S), sz);
      TextOut(B.DC, B.sizeX div 2 - sz.cx div 2, B.sizeY * 34 div 40, PAnsiChar(@S[1]), Length(S));

    end;

    SetTextColor(B.DC, $0000FF);
    if LastSave>0 then begin
      S := 'Сохранено';
      TextOut(B.DC, 0, B.sizeY div 20, PAnsiChar(@S[1]), Length(S));
    end else if LastLoad>0 then begin
      S := 'Загружено';
      TextOut(B.DC, 0, B.sizeY div 20, PAnsiChar(@S[1]), Length(S));
    end;

  end;

end.
