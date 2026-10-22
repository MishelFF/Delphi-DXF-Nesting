unit NestGeom;

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections;

type
  TPointD = record
    X, Y: Double;
  end;

  TPolygon = TArray<TPointD>;

  TRectD = record
    LeftD, TopD, RightD, BottomD: Double;
    function Width: Double;
    function Height: Double;
  end;

function PointD(aX, aY: Double): TPointD; inline;
function PolygonArea(aPoly: TPolygon): Double;
function PolygonBounds(aPoly: TPolygon): TRectD;

function PolygonRotateNormalized(const aPoly: TPolygon; Rot90: Integer): TPolygon;
function PolygonTranslate(const aPoly: TPolygon; Dx, Dy: Double): TPolygon;
function BoxTranslate(const aRect: TRectD; Dx, Dy: Double): TRectD;

function PolygonsIntersection(const A: TPolygon; const ABox: TRectD; Ax, Ay: Double;
  const B: TPolygon; const BBox: TRectD; Gap: Double): Boolean;

implementation

const
  Eps = 1e-8;

function TRectD.Width: Double;
begin
  Result := RightD - LeftD;
end;

function TRectD.Height: Double;
begin
  Result := BottomD - TopD;
end;

function PointD(aX, aY: Double): TPointD;
begin
  Result.X := aX;
  Result.Y := aY;
end;


function PolygonArea(aPoly: TPolygon): Double;
var
  i, j, n: Integer;
begin
  Result := 0;
  n := Length(aPoly);
  if n < 3 then Exit;
  for i := 0 to n - 1 do begin
    j := (i + 1) mod n;
    Result := Result + aPoly[i].X * aPoly[j].Y - aPoly[j].X * aPoly[i].Y;
  end;
  Result := Result / 2;
end;

function PolygonBounds(aPoly: TPolygon): TRectD;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Length(aPoly) = 0 then Exit;
  Result.LeftD := aPoly[0].X; Result.RightD := aPoly[0].X;
  Result.TopD := aPoly[0].Y; Result.BottomD := aPoly[0].Y;
  for i := 1 to Length(aPoly)-1 do begin
    Result.LeftD := Min(Result.LeftD, aPoly[i].X);
    Result.RightD := Max(Result.RightD, aPoly[i].X);
    Result.TopD := Min(Result.TopD, aPoly[i].Y);
    Result.BottomD := Max(Result.BottomD, aPoly[i].Y);
  end;
end;

function PolygonRotateNormalized(const aPoly: TPolygon; Rot90: Integer): TPolygon;
var
  i: Integer;
  X, Y: Double;
  Bnd: TRectD;
begin
  SetLength(Result, Length(aPoly));
  for i := 0 to Length(aPoly)-1 do begin
    X := aPoly[i].X;
    Y := aPoly[i].Y;
    case Rot90 and 3 of
      0: Result[i] := PointD(X, Y);
      1: Result[i] := PointD(-Y, X);
      2: Result[i] := PointD(-X, -Y);
      3: Result[i] := PointD(Y, -X);
    end;
  end;
  Bnd := PolygonBounds(Result);
  for i := 0 to Length(Result)-1 do begin
    Result[i].X := Result[i].X - Bnd.LeftD;
    Result[i].Y := Result[i].Y - Bnd.TopD;
  end;
end;

function PolygonTranslate(const aPoly: TPolygon; Dx, Dy: Double): TPolygon;
var
  i: Integer;
begin
  SetLength(Result, Length(aPoly));
  for i := 0 to Length(aPoly)-1 do begin
    Result[i].X := aPoly[i].X + Dx;
    Result[i].Y := aPoly[i].Y + Dy;
  end;
end;

function BoxTranslate(const aRect: TRectD; Dx, Dy: Double): TRectD;
begin
  Result.LeftD := aRect.LeftD + Dx;
  Result.RightD := aRect.RightD + Dx;
  Result.TopD := aRect.TopD + Dy;
  Result.BottomD := aRect.BottomD + Dy;
end;

// Polygon Intersection
function Orient(Ax, Ay, Bx, By, Px, Py: Double): Double; inline;
begin
  Result := (Bx - Ax) * (Py - Ay) - (By - Ay) * (Px - Ax);
end;

// Cross segments
function SegCross(Ax, Ay, Bx, By, Cx, Cy, Dx, Dy: Double): Boolean;
var
  D1, D2, D3, D4: Double;
begin
  D1 := Orient(Cx, Cy, Dx, Dy, Ax, Ay);
  D2 := Orient(Cx, Cy, Dx, Dy, Bx, By);
  D3 := Orient(Ax, Ay, Bx, By, Cx, Cy);
  D4 := Orient(Ax, Ay, Bx, By, Dx, Dy);
  Result := (((D1 > Eps) and (D2 < -Eps)) or ((D1 < -Eps) and (D2 > Eps))) and
            (((D3 > Eps) and (D4 < -Eps)) or ((D3 < -Eps) and (D4 > Eps)));
end;

function PtSegDist(Px, Py, Ax, Ay, Bx, By: Double): Double;
var
  Vx, Vy, L2, T: Double;
begin
  Vx := Bx - Ax;
  Vy := By - Ay;
  L2 := Vx * Vx + Vy * Vy;
  if L2 < 1e-18 then
    T := 0
  else
    T := ((Px - Ax) * Vx + (Py - Ay) * Vy) / L2;
  if T < 0 then T := 0 else if T > 1 then T := 1;
  Result := Sqrt(Sqr(Px - (Ax + T * Vx)) + Sqr(Py - (Ay + T * Vy)));
end;

function SegSegDist(Ax, Ay, Bx, By, Cx, Cy, Dx, Dy: Double): Double;
begin
  if SegCross(Ax, Ay, Bx, By, Cx, Cy, Dx, Dy) then
    Exit(0);
  Result := Min(Min(PtSegDist(Ax, Ay, Cx, Cy, Dx, Dy), PtSegDist(Bx, By, Cx, Cy, Dx, Dy)),
                Min(PtSegDist(Cx, Cy, Ax, Ay, Bx, By), PtSegDist(Dx, Dy, Ax, Ay, Bx, By)));
end;

function PointInPoly(Px, Py: Double; const P: TPolygon; Dx, Dy: Double): Boolean;
var
  I, J: Integer;
  Xi, Yi, Xj, Yj: Double;
begin
  Result := False;
  J := High(P);
  for I := 0 to High(P) do
  begin
    Xi := P[I].X + Dx; Yi := P[I].Y + Dy;
    Xj := P[J].X + Dx; Yj := P[J].Y + Dy;
    if ((Yi > Py) <> (Yj > Py)) and (Px < (Xj - Xi) * (Py - Yi) / (Yj - Yi) + Xi) then
      Result := not Result;
    J := I;
  end;
end;


function InsideStrict(Px, Py: Double; const P: TPolygon; Dx, Dy: Double): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  if not PointInPoly(Px, Py, P, Dx, Dy) then Exit;
  J := High(P);
  for I := 0 to High(P) do
  begin
    if PtSegDist(Px, Py, P[J].X + Dx, P[J].Y + Dy, P[I].X + Dx, P[I].Y + Dy) < 1e-6 then
      Exit;
    J := I;
  end;
  Result := True;
end;

procedure Centroid(const P: TPolygon; Dx, Dy: Double; out Cx, Cy: Double);
var
  I, J: Integer;
  A, Cr: Double;
begin
  A := 0; Cx := 0; Cy := 0;
  for I := 0 to High(P) do
  begin
    J := (I + 1) mod Length(P);
    Cr := P[I].X * P[J].Y - P[J].X * P[I].Y;
    A := A + Cr;
    Cx := Cx + (P[I].X + P[J].X) * Cr;
    Cy := Cy + (P[I].Y + P[J].Y) * Cr;
  end;
  if Abs(A) < 1e-12 then
  begin
    Cx := P[0].X + Dx;
    Cy := P[0].Y + Dy;
  end
  else
  begin
    Cx := Cx / (3 * A) + Dx;
    Cy := Cy / (3 * A) + Dy;
  end;
end;

function PolygonsIntersection(const A: TPolygon; const ABox: TRectD; Ax, Ay: Double;
  const B: TPolygon; const BBox: TRectD; Gap: Double): Boolean;
var
  I, J, NA, NB: Integer;
  A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y, Cx, Cy: Double;
begin
  Result := False;
  NA := Length(A);
  NB := Length(B);
  if (NA < 3) or (NB < 3) then Exit;

  // не пересеклись габариты
  if (Ax + ABox.LeftD >= BBox.RightD + Gap - Eps) or
     (BBox.LeftD >= Ax + ABox.RightD + Gap - Eps) or
     (Ay + ABox.TopD >= BBox.BottomD + Gap - Eps) or
     (BBox.TopD >= Ay + ABox.BottomD + Gap - Eps) then
    Exit;

  // пересечение ребер
  for I := 0 to NA - 1 do
  begin
    A1x := A[I].X + Ax;            A1y := A[I].Y + Ay;
    A2x := A[(I + 1) mod NA].X + Ax; A2y := A[(I + 1) mod NA].Y + Ay;
    for J := 0 to NB - 1 do
    begin
      B1x := B[J].X;               B1y := B[J].Y;
      B2x := B[(J + 1) mod NB].X;  B2y := B[(J + 1) mod NB].Y;
      if (Max(A1x, A2x) + Gap <= Min(B1x, B2x)) or
         (Min(A1x, A2x) >= Max(B1x, B2x) + Gap) or
         (Max(A1y, A2y) + Gap <= Min(B1y, B2y)) or
         (Min(A1y, A2y) >= Max(B1y, B2y) + Gap) then
        Continue;
      if SegCross(A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y) then
        Exit(True);
      if (Gap > Eps) and
         (SegSegDist(A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y) < Gap - Eps) then
        Exit(True);
    end;
  end;

  // целиком внутри
  for I := 0 to NA - 1 do
    if InsideStrict(A[I].X + Ax, A[I].Y + Ay, B, 0, 0) then
      Exit(True);
  for J := 0 to NB - 1 do
    if InsideStrict(B[J].X, B[J].Y, A, Ax, Ay) then
      Exit(True);
  Centroid(A, Ax, Ay, Cx, Cy);
  if InsideStrict(Cx, Cy, B, 0, 0) then Exit(True);
  Centroid(B, 0, 0, Cx, Cy);
  if InsideStrict(Cx, Cy, A, Ax, Ay) then Exit(True);
end;



end.
