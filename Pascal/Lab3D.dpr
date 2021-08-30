program Lab3D;
uses
  Windows,
  Messages,
  Bitmaps in 'Bitmaps.pas',
  Geometry in 'Geometry.pas',
  Memory in 'Memory.pas',
  Points in 'Points.pas',
  Level in 'Level.pas',
  Collisions in 'Collisions.pas',
  Monsters in 'Monsters.pas',
  Render in 'Render.pas',
  Fillrate in 'Fillrate.pas',
  Generator in 'Generator.pas',
  Config in 'Config.pas',
  Textures in 'Textures.pas',
  Items in 'Items.pas',
  Engine in 'Engine.pas',
  EngineTypes in 'EngineTypes.pas',
  ItemModels in 'ItemModels.pas',
  Bullets in 'Bullets.pas',
  Hud in 'Hud.pas',
  WeaponModels in 'WeaponModels.pas',
  SaveLoad in 'SaveLoad.pas',
  Sounds;

var
  WC : TWndClass;
  H  : HWND;
  M  : TMsg;
  B  : Bitmap;
  ws : cardinal;
  wasPhys : boolean = false;
  predT : cardinal = 0;
  procT : integer = 0;

  prFor   : boolean = false;
  prBack  : boolean = false;
  prLeft  : boolean = false;
  prRight : boolean = false;
  prJump  : boolean = false;
  prSit   : boolean = false;
  prShot  : boolean = false;
  prNumber : integer = 1;

  fps  : integer = 0;
  fpsc : integer = 0;

  WR,CR: TRect;

procedure Phys (dt: float);
var
  P: Windows.TPoint;
begin
  if GetFocus=H then begin

    GetCursorPos(P);
    ScreenToClient(H, P);

    L.Player.Controls.dax := - (p.Y - B.sizeY div 2)*sens/dt;
    L.Player.Controls.daz :=   (p.X - B.sizeX div 2)*sens/dt;

    if revy=1 then L.Player.Controls.dax := -L.Player.Controls.dax;

    P.X := B.sizeX div 2;
    P.Y := B.sizeY div 2;

    ClientToScreen(H, P);

    LastSave := LastSave - dt;
    LastLoad := LastLoad - dt;

    SetCursorPos(P.X, P.Y);

    L.Player.Controls.Forw := prFor;
    L.Player.Controls.Back := prBack;
    L.Player.Controls.StrL := prLeft;
    L.Player.Controls.StrR := prRight;
    L.Player.Controls.Sit  := prSit;
    L.Player.Controls.Jump := prJump;
    L.Player.Controls.Shot := prShot;
    L.Player.Controls.WeaponNumber := prNumber;
    prJump := False;

    EnginePhys(dt);
    wasPhys := true;
  end;
end;

procedure Draw;
var
  DC: HDC;
  st: string[15];

begin
  if not wasPhys then exit;

  //FillChar(B.Pixels^, B.sizeX*B.sizeY*sizeof(Color), 0);
  opID := 0;
  ShowLevel(B, L, fovx, fovy);
  ShowHUD(B, L.Player);

  if showfps>0 then begin
    SetTextColor(B.DC, $0000FF);
    Str(fps, st);
    TextOut(B.DC, 0, 0, PAnsiChar(@st[1]), Length(st));
  end;
  DC := GetDC(H);
  BitBlt(DC, 0, 0, B.sizeX, B.sizeY, B.DC, 0, 0, SRCCOPY);           
  ReleaseDC(H,DC);

  Inc(fpsc);
end;

procedure TimerProc;
var
  T, dT : cardinal;
const Delta = 15;
begin
  T := GetTickCount;
  dT := T-predT;
  if dT>100 then dT := 100;
  procT := procT + dT;
  while procT>0 do begin
    Phys(delta*0.001);
    procT := procT-delta;
  end;
  Draw;
  if T div 1000 <> predT div 1000 then begin
    fps  := fpsc;
    fpsc := 0;
  end;

  predT := T;
end;

function hex(x:integer):string;
var
  i : integer;
const
  hc : array [0..15] of char = '0123456789ABCDEF';
begin
  SetLength(Result,8);
  for i :=0 to 7 do Result[i+1] := hc[(x shr (i*4))and $F];
end;

function Main (H: HWND; M: UINT; W: WParam; L: LParam): longint; stdcall;
begin
  try
    Result := 0;
    case M of
      WM_KEYDOWN : if L and $40000000 = 0 then case LoWord(W) of
        integer('A'), VK_LEFT  : prLeft  := True;
        integer('D'), VK_RIGHT : prRight := True;
        integer('W'), VK_UP    : prFor   := True;
        integer('S'), VK_DOWN  : prBack  := True;
        VK_CONTROL             : prSit   := True;
        VK_SPACE               : prJump  := True;
        integer('0') .. integer ('9') : prNumber := LoWord(W)-integer('0');
      end;        
      WM_KEYUP : case LoWord(W) of
        integer('A'), VK_LEFT  : prLeft  := False;
        integer('D'), VK_RIGHT : prRight := False;
        integer('W'), VK_UP    : prFor   := False;
        integer('S'), VK_DOWN  : prBack  := False;
        VK_CONTROL             : prSit   := False;
        VK_SPACE               : prJump  := False;
        VK_ESCAPE              : SendMessage(H, WM_CLOSE, 0, 0);
        VK_F6 : QuickSave;
        VK_F9 : QuickLoad;
      end;
      WM_LBUTTONDOWN : prShot := True;   
      WM_LBUTTONUP   : prShot := False;
      WM_TIMER : TimerProc;
      WM_DESTROY : begin
        PostQuitMessage(0);
        Exit;
      end;
    end;
  except
    MessageBox(H, 'Error', 'Error', MB_ICONERROR);
  end;
  Result := DefWindowProc(H,M,W,L);
end;

begin
  InitSounds;
  try
    Set8087CW($1020);
    FillChar(WC, SizeOf(WC), 0);
    with WC do begin
      lpfnWndProc := @Main;
      hInstance := MainInstance;
      hCursor := LoadCursor(0, idc_Arrow);
      hbrBackground := Color_BtnFace + 1;
      lpszClassName := 'Lab3D';
    end;
    RegisterClass(WC);

    if config.flsc=1 then ws := WS_POPUP else ws := WS_OVERLAPPEDWINDOW and not WS_SIZEBOX and not WS_MAXIMIZEBOX;

    H := CreateWindow('Lab3D', 'Lab3D', ws,
      integer(CW_USEDEFAULT), integer(CW_USEDEFAULT), sx,sy,
      0, 0, MainInstance, nil);
    if flsc=0 then begin
      GetWindowRect(H, WR);
      GetClientRect(H, CR);
      MoveWindow(H, WR.Left, WR.Top, sx+(WR.Right-WR.Left)-(CR.Right-CR.Left), sy+(WR.Bottom-WR.Top)-(CR.Bottom-CR.Top), True);
    end;

    CreateBitmap(B, sx,sy);
    SetFogTable(0,0,0);
    InitLevel(L);
    SetTimer(H, 0, 1, nil);
    ShowCursor(False);
    ShowWindow(H, cmdShow);
    UpdateWindow(H);
    while GetMessage(M, 0, 0, 0) do begin
      TranslateMessage(M);
      DispatchMessage(M);
    end;
    DestroyBitmap(B);
  except
  end;
  CloseSounds;
end.
