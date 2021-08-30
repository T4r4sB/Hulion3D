unit Config;

interface

{$IFOPT D+}
uses
  SysUtils;
{$ENDIF}

var
  sx   : integer = -1;
  sy   : integer = -1;
  flsc : integer = 1;
  revy : integer = 0;
  seed : integer = 15071987;
  sens : single  = 0.004;
  fovx : single  = -1;
  fovy : single  = 1;
  chgres : boolean = false;
  showfps : integer = 0;
  god : integer = 0;

  function SetResolution (x,y: integer; test : boolean): boolean; 
  procedure RestoreResolution;

implementation

uses
  Windows;

  function SetResolution (x,y: integer; test : boolean): boolean;
  var
    dm : TDevMode;
  begin
    FillChar(dm, sizeof(dm), 0);
    dm.dmSize := sizeof(dm);
    dm.dmPelsWidth  := x;
    dm.dmPelsHeight := y;
    dm.dmFields := DM_PELSWIDTH or DM_PELSHEIGHT;
    if Test then
      Result := ChangeDisplaySettings(dm, CDS_TEST)  = DISP_CHANGE_SUCCESSFUL
    else                                
      Result := ChangeDisplaySettings(dm, CDS_FULLSCREEN) = DISP_CHANGE_SUCCESSFUL;
  end;

  procedure RestoreResolution;
  begin
    ChangeDisplaySettings(PDevMode(nil)^, 0);
  end;

var
  F: text;
  ssx,ssy : integer;
  S : string;
  DC : HDC;
initialization

  Assign(F, 'config.txt');
  Reset(F);
  if IOResult=0 then begin
    while not EOF(F) do begin
      ReadLn(F,S);
      if S='sizeX' then ReadLn(F,sx)
      else if S='sizeY' then ReadLn(F,sy)
      else if S='fullScreen' then ReadLn(F,flsc)
      else if S='seed' then ReadLn(F,seed)
      else if S='sens' then ReadLn(F,sens)   
      else if S='revy' then ReadLn(F,revy)
      else if S='fovx' then ReadLn(F,fovx)
      else if S='fovy' then ReadLn(F,fovy)
      else if S='showfps' then ReadLn(F, showfps)
      else if S='god' then ReadLn(F, god);
    end;
    Close(F);
  end;
  
  DC := GetDC(0);
  ssx := GetDeviceCaps(DC, HORZRES);
  ssy := GetDeviceCaps(DC, VERTRES);
  ReleaseDC(0,DC);

  if sx<0 then sx:=ssx;
  if sy<0 then sy:=ssy;
  if (flsc=1) and not SetResolution(sx,sy,true) then flsc := 0;
                 
  if fovx<0 then begin
    if flsc=1 then fovx := fovy*ssx/(ssy*3/4) else fovx := fovy*sx/(sy*3/4);
  end;

  chgres := (flsc=1) and ((sx<>ssx) or (sy<>ssy));

  if chgres then SetResolution(sx,sy,false);

  RandSeed := seed;

finalization

  if chgres then RestoreResolution;

end.
