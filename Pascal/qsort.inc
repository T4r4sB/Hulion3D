procedure Sort(var A: array of T; L,R: integer);
var
  i,j: integer;
  x,y: T;
begin
  if L>=R then Exit;
  i := l;
  j := r;
  x := a[random(r-l+1)+l];
  repeat
    while LESS(a[i],x) do inc(i);
    while LESS(x,a[j]) do dec(j);
    if i<=j then begin
      y    := a[i];
      a[i] := a[j];
      a[j] := y;
      inc(i);
      dec(j);
    end;
  until i>=j;
  Sort(A,l,j);
  Sort(A,i,r);
end;