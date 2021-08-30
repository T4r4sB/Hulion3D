unit Memory;

interface

  function Alloc(size: integer) : pointer;

  type MemoryState = pointer;

  procedure SaveState (var MS : MemoryState);
  procedure RestoreState (const MS : MemoryState);

  function GetPtr : pointer;
  procedure FreePtr (p : pointer);

  // открываю для сейвлода
  type
    PPoolItem = ^PoolItem;

    PoolItem = record
      case boolean of
      true : (
        Free : boolean;
        Ptr : PPoolItem; );
      false : (
        bytes : array [0..31] of byte );
    end;

  var
    Data   : array [0..$1ffffff] of char;
    Beg    : pointer = @Data[0];
    MaxMem : pointer = @Data[0];       

  const MaxPools = $80000;

  var
    PoolCount : integer;
    Pool : array [0..MaxPools-1] of PoolItem;
    Free : PPoolItem;

implementation

  function Alloc(size: integer) : pointer;
  begin
    if size>0 then begin
      Assert(PChar(Beg)+size-1 <= @Data[High(Data)], 'Memory overflow!');
      result := Beg;
      Inc(PChar(Beg), size);
      if (PChar(Beg)>PChar(MaxMem)) then MaxMem := Beg;
    end else result := nil;
  end;

  procedure SaveState (var MS : MemoryState);
  begin
    MS := Beg;
  end;

  procedure RestoreState (const MS : MemoryState);
  begin
    Beg := MS;
    Assert (cardinal(Beg)>=cardinal(@Data));
  end;

  function GetPtr : pointer;
  begin                           
    Assert(PoolCount+1<MaxPools, 'Memory overflow!');
    Assert(Free<>nil);
    Assert(Free.Free);
    Result := @Free.Ptr;
    Free.Free := False;
    Free := Free.Ptr;
    Inc(PoolCount);
  end;

  procedure FreePtr (p : pointer);
  var
    PI : PPoolItem;
  begin
    PI := PPoolItem( PChar(p)-(PChar(@Pool[0].Ptr)-PChar(@Pool[0])) );
    Assert(not PI.Free);
    PI.Free := True;
    PI.Ptr := Free;
    Free := Pi;
    Dec(PoolCount);
  end;

  procedure InitPools;
  var i : integer;
  begin
    PoolCount := 0;
    Free := @Pool[Low(Pool)];
    for i := Low(Pool) to High(Pool)-1 do begin
      Pool[i].Ptr  := @Pool[i+1];
      Pool[i].Free := True;
    end;
    Pool[High(Pool)].Ptr := nil;
  end;

initialization
  InitPools;

end.
