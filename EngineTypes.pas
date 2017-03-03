unit EngineTypes;

interface        

uses
  Points;

type
  PMonster        = ^Monster;
  PAPMonster      = ^APMonster;

  PItem           = ^Item;
  PAPItem         = ^APItem;

  PSPoint         = ^SPoint;
  PAPoint         = ^APoint;
  PPoint          = ^Point;
  PAPPoint        = ^APPoint;

  PSector         = ^Sector;     
  PAPSector       = ^APSector;

  PAFace          = ^AFace;
  PFace           = ^Face;
  PAPFace         = ^APFace;

  PConvexInSector = ^ConvexInSector;

  PConvex         = ^Convex;    
  PAConvex        = ^AConvex;
  PAPConvex       = ^APConvex;

  PAInt           = ^AInt;
  PTexture        = ^Texture;
  PItemPoint      = ^ItemPoint;
  PAItemPoint     = ^AItemPoint;
  PItemModel      = ^ItemModel;

  PBullet         = ^Bullet;
  PWeapon         = ^Weapon;

  AInt = array [0 .. MaxInt div sizeof(integer)-1] of integer;

  APoint = array [0 .. MaxInt div sizeof(Point)-1] of Point;
  APPoint = array [0 .. MaxInt div sizeof(PPoint)-1] of PPoint;

  RenderFunc = record
    vplt,vdx,vdy : float;
  end;

  RenderInfo = record
    w,tx,ty : RenderFunc;
    Txr : PTexture;
    Light : integer;
  end;

  Texture = record
    Pixels : PAInt;
    Dithering : boolean;
    maskx, masky : integer;
    shlx : integer;
  end;

  Face = record
    inProcess    : boolean; // для обходов полезно
    Id           : integer; // ид внутренний относительно сектора
    RI           : RenderInfo; // для отрисовки
    NextSector   : PSector;
    Penetrable   : boolean;
    INorm        : Point;  // нормаль
    INormC       : float;  // для <P,INorm-INormC> < 0
    CPoints      : integer;
    Points       : PAPPoint; // массив её вершин, да-да, от него не уйти!
    Texture      : PTexture;
    Light        : integer;
    VTx, VTy     : Point;    // информация для текстурирования, задаёт функцию R3->R2 для текстурных координат
    VTxc, VTyc   : float;
  end;

  AFace = array [0 .. MaxInt div sizeof(Face)-1] of Face;
  APFace = array [0 .. MaxInt div sizeof(PFace)-1] of PFace;

  Line = record
    p1,p2: PPoint;   // точки общие
    f1,f2 : PFace;   // грани общие
  end;

  ALine = array [0 .. MaxInt div sizeof(Line)-1] of Line;
  PALine = ^ALine;

  Sector = record
    inProcess : integer; // для обходов полезно
    ID        : integer; 
    FConvex, LConvex : PConvexInSector;
    CFaces  : integer;
    Faces   : PAFace; // грани принадлежат лишь ему лично
    CLines  : integer;
    Lines   : PALine; // линии принадлежал лишь ему лично
    Gravity : float; // боковых гравитаций не будет, ибо монстры все выстроены по вертикали
    Skybox  : boolean;
  end;           

  APSector = array [0 .. MaxInt div sizeof(PSector)-1] of PSector;
  
  SPoint = record
    S : PSector;
    P : Point;
  end;

  ConvexInSector = record
    NC,PC,NS,PS : PConvexInSector;
    Convex : PConvex;
    Sector : PSector;
  end;

  Convex = record     
    inProcess : boolean;

    FSector,LSector : PConvexInSector;  // в каких комнатах сидит
    Item            : PItem;
    CanCollide      : boolean; // годится ли для коллиий
    Mass            : float;   // только для коллидеров
    Center          : SPoint;  // центр для отрисовки, коллизий
    Shift           : Point;   // смещение от центра предмета
    R : float;     // радиус для коллизий
    G : Sector;    // геометрия
  end;
  
  AConvex = array [0..MaxInt div sizeof(Convex)-1] of Convex;
  APConvex = array [0 .. MaxInt div sizeof(PConvex)-1] of PConvex;
  
  Controls = record
    Forw,Back,StrL,StrR,Jump,Sit : boolean;
    Shot : boolean;
    WeaponNumber : integer;
    dax, daz : float;
  end;

  ItemPoint = record   
    cP : Point;
    iP : Point;
    tx, ty : float;
  end;

  AItemPoint = array [0..MaxInt div sizeof(ItemPoint)-1] of ItemPoint;

  ApplyItemProc = function (M : PMonster; It : PItem) : boolean;

  Item = record
    inProcess  : boolean;
    Center     : SPoint;
    Position   : Matrix;
    CConvexes  : integer;
    Convexes   : PAConvex;

    Monster    : PMonster;
    Bullet     : PBullet;
    Weapon     : PWeapon;
    // это для геометрии
    CPoints    : integer;
    ItemPoints : PAItemPoint;
    Model      : PItemModel;
  end;

  APItem = array [0..MaxInt div sizeof(PItem)-1] of PItem;

  Weapon = record
    IsWeapon   : boolean;
    Item       : Item;
    ReloadLeft : float;
  end;

  Monster = record
    Controls : Controls;
    CurrentWeapon  : integer;
    Head,Body,Legs : PSPoint;
    anglex, anglez : float;
    StepStage : float;
    Fr : float;
    DeltaPos : Point;
    Health,Armor : float;
    Item : Item;
    ProcessTime : float; // <0 не в процессе
    DeathStage  : float; // <=0 несдох
    LastDamage  : float;
    Weapons : array [0..9] of Weapon;
    PrevShot : boolean;
  end;

  APMonster = array [0..MaxInt div sizeof(PMonster)-1] of PMonster;

  Bullet = record
    Item     : Item;
    WPModel  : PItemModel;
    DeltaPos : Point;
    TripDist : float;
    Owner    : PMonster;
    Active   : boolean;
  end;

  ModelKind = (mkBox,mkMonster,mkBullet,mkWeapon);

  ItemProc = procedure (var it : Item);

  ItemModel = record
    Kind        : ModelKind;
    Name        : string;
    CPoints     : integer;
    CConvexes   : integer;
    Connections : PAInt;
    ItemProc    : ItemProc;
    Texture     : PTexture;
    // бля монстров
    Player      : boolean;
    Mass,HeadR,BodyR,LegsR,HB,MinBL,MaxBL,Speed,Spring,Lightness : float;
    InitialHealths : float;
    WeaponModels     : array [0..9] of PItemModel;
    DefaultHasWeapon : array [0..9] of boolean;
    // бля аптечек,патронов,брони 
    ApplyItemProc : ApplyItemProc;
    // бля оружия
    Instrument,Nota : byte;
    BulletSpeed,Range,Damage,BulletsPerShot,Dispersion,ReloadTime : float;
    BulletModel : PItemModel;
    Sabre : boolean;
  end;

implementation

end.
