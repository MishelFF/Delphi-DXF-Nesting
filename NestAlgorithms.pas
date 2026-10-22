unit NestAlgorithms;

{ 1. TShelfNesting      - по габаритам в строки (полки).
  2. TBottomLeftNesting - по контурам, влево вниз по сетке. }

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, System.Generics.Defaults,
  NestGeom, Nesting;

type
  TShelfNesting = class(TNestingAlgorithm)
  protected
    procedure DoNest(AResult: TNestResult); override;
  public
    class function AlgorithmName: string; override;
  end;

  TBottomLeftNesting = class(TNestingAlgorithm)
  private
    FFitState: TArray<ShortInt>;   // 0 - неизвестно, 1 - влезает на пустой лист, -1 - нет
    function FindPosition(ASheet: TNestSheet; PIdx: Integer;var BestRot: Integer; var BestX, BestY: Double): Boolean;
  protected
    procedure DoNest(AResult: TNestResult); override;
  public
    class function AlgorithmName: string; override;
  end;

implementation

const
  Eps = 1e-7;

type
  TShelf = record
    Y, H, X: Double;
  end;

  TShelfSheet = class
  public
    Sheet: TNestSheet;
    Shelves: TList<TShelf>;
    NextY: Double;
    constructor Create(ASheet: TNestSheet; AStartY: Double);
    destructor Destroy; override;
  end;

constructor TShelfSheet.Create(ASheet: TNestSheet; AStartY: Double);
begin
  inherited Create;
  Sheet := ASheet;
  NextY := AStartY;
  Shelves := TList<TShelf>.Create;
end;

destructor TShelfSheet.Destroy;
begin
  Shelves.Free;
  inherited;
end;

class function TShelfNesting.AlgorithmName: string;
begin
  Result := 'Shelf (bounding boxes)';
end;

procedure TShelfNesting.DoNest(AResult: TNestResult);
var
  Inst: TArray<Integer>;
  PartRot: TArray<Integer>;
  PartH: TArray<Double>;
  States: TObjectList<TShelfSheet>;
  UW, UH, Margin, Gap, W, H: Double;
  I,K, J, P, R, Rot, SI: Integer;
  Box: TRectD;
  St: TShelfSheet;
  Sh: TShelf;
  Placed: Boolean;

  procedure Put(S: TShelfSheet; PIdx, ARot: Integer; X, Y: Double);
  begin
    S.Sheet.Add(MakePlacement(PIdx, ARot, X, Y), FParts[PIdx].Area);
  end;

begin
  Margin := FSettings.Margin;
  Gap := FSettings.ItemGap;
  UW := FSettings.SheetWidth - 2 * Margin;
  UH := FSettings.SheetHeight - 2 * Margin;
  //распологаем горизонтально
  SetLength(PartRot, FParts.Count);
  SetLength(PartH, FParts.Count);
  for P := 0 to FParts.Count - 1 do begin
    PartRot[P] := -1;
    PartH[P] := 0;
    for R := 0 to Rotations - 1 do begin
      Box := FParts[P].Box(R);
      if (Box.Width <= UW + Eps) and (Box.Height <= UH + Eps) and
         ((PartRot[P] < 0) or (Box.Height < PartH[P] - Eps)) then begin
        PartRot[P] := R;
        PartH[P] := Box.Height;
      end;
    end;
  end;

  SetLength(Inst,FParts.Count);
  for I := 0 to Length(Inst)-1 do Inst[I]:=I;
  TArray.Sort<Integer>(Inst, TComparer<Integer>.Construct(
    function(const A, B: Integer): Integer
    begin
      Result := CompareValue(PartH[B], PartH[A]);
      if Result = 0 then
        Result := A - B;
    end));

  States := TObjectList<TShelfSheet>.Create(True);
  try
    for K := 0 to High(Inst) do
    begin
      P := Inst[K];
      Rot := PartRot[P];
      if Rot < 0 then
      begin
        AResult.Unplaced.Add(P);
        Continue;
      end;
      Box := FParts[P].Box(Rot);
      W := Box.Width;
      H := Box.Height;
      Placed := False;

      for SI := 0 to States.Count - 1 do
      begin
        St := States[SI];
        // 1) в существующие полки
        for J := 0 to St.Shelves.Count - 1 do
        begin
          Sh := St.Shelves[J];
          if (H <= Sh.H + Eps) and (Sh.X + W <= Margin + UW + Eps) then
          begin
            Put(St, P, Rot, Sh.X, Sh.Y);
            Sh.X := Sh.X + W + Gap;
            St.Shelves[J] := Sh;
            Placed := True;
            Break;
          end;
        end;
        // 2) новая полка на этом листе
        if (not Placed) and (St.NextY + H <= Margin + UH + Eps) then
        begin
          Sh.Y := St.NextY;
          Sh.H := H;
          Sh.X := Margin + W + Gap;
          St.Shelves.Add(Sh);
          Put(St, P, Rot, Margin, Sh.Y);
          St.NextY := St.NextY + H + Gap;
          Placed := True;
        end;
        if Placed then Break;
      end;

      // 3) новый лист
      if not Placed then
      begin
        St := TShelfSheet.Create(TNestSheet.Create, Margin);
        States.Add(St);
        AResult.Sheets.Add(St.Sheet);
        Sh.Y := St.NextY;
        Sh.H := H;
        Sh.X := Margin + W + Gap;
        St.Shelves.Add(Sh);
        Put(St, P, Rot, Margin, Sh.Y);
        St.NextY := St.NextY + H + Gap;
      end;

      if not ReportProgress(K + 1, Length(Inst)) then
      begin
        for J := K + 1 to High(Inst) do
          AResult.Unplaced.Add(Inst[J]);
        Break;
      end;
    end;
  finally
    States.Free;   // листы остаются у AResult
  end;
end;


class function TBottomLeftNesting.AlgorithmName: string;
begin
  Result := 'Bottom-Left (polygons)';
end;

function TBottomLeftNesting.FindPosition(ASheet: TNestSheet; PIdx: Integer;
  var BestRot: Integer; var BestX, BestY: Double): Boolean;
var
  R, I: Integer;
  Poly: TPolygon;
  Box: TRectD;
  Pl: TNestPlacement;
  MaxX, MaxY, X, Y, Step, Gap, Margin: Double;
  RotFound, Hit: Boolean;
begin
  Result := False;
  BestRot := 0;
  BestX := 0;
  BestY := 0;
  Step := Max(FSettings.FiniteGridStep, 0.1);
  Gap := FSettings.ItemGap;
  Margin := FSettings.Margin;

  for R := 0 to Rotations - 1 do begin
    Poly := FParts[PIdx].Variant(R);
    Box := FParts[PIdx].Box(R);
    MaxX := FSettings.SheetWidth - Margin - Box.Width;
    MaxY := FSettings.SheetHeight - Margin - Box.Height;
    if (MaxX < Margin - Eps) or (MaxY < Margin - Eps) then Continue;

    RotFound := False;
    Y := Margin;
    repeat
      if Result and (Y > BestY + Eps) then Break;
      X := Margin;
      repeat
        Hit := False;
        for I := 0 to ASheet.Placements.Count - 1 do begin
          Pl := ASheet.Placements[I];
          if PolygonsIntersection(Poly, Box, X, Y, Pl.Outline, Pl.Box, Gap) then begin
            Hit := True;
            Break;
          end;
        end;
        if not Hit then begin
          RotFound := True;
          Break;
        end;
        if X >= MaxX - Eps then Break;
        X := Min(X + Step, MaxX);
      until False;

      if RotFound then begin
        if (not Result) or (Y < BestY - Eps) or
           (SameValue(Y, BestY, Eps) and (X < BestX)) then begin
          Result := True;
          BestRot := R;
          BestX := X;
          BestY := Y;
        end;
        Break;
      end;
      if Y >= MaxY - Eps then Break;
      Y := Min(Y + Step, MaxY);
    until False;
  end;
end;

procedure TBottomLeftNesting.DoNest(AResult: TNestResult);
var
  Inst: TArray<Integer>;
  I,K, J, P, Rot: Integer;
  X, Y: Double;
  Sheet: TNestSheet;
  Placed: Boolean;
begin
  SetLength(FFitState, FParts.Count);

  SetLength(Inst,FParts.Count);
  for I := 0 to FParts.Count - 1 do Inst[I]:=I;
  TArray.Sort<Integer>(Inst, TComparer<Integer>.Construct(
    function(const A, B: Integer): Integer
    begin
      Result := CompareValue(FParts[B].Area, FParts[A].Area);
      if Result = 0 then Result := A - B;
    end));

  for K := 0 to Length(Inst)-1 do begin
    P := Inst[K];
    if FFitState[P] < 0 then begin
      AResult.Unplaced.Add(P);
      Continue;
    end;

    Placed := False;
    for Sheet in AResult.Sheets do
      if FindPosition(Sheet, P, Rot, X, Y) then begin
        Sheet.Add(MakePlacement(P, Rot, X, Y), FParts[P].Area);
        Placed := True;
        Break;
      end;

    if not Placed then begin
      Sheet := TNestSheet.Create;
      if FindPosition(Sheet, P, Rot, X, Y) then begin
        FFitState[P] := 1;
        AResult.Sheets.Add(Sheet);
        Sheet.Add(MakePlacement(P, Rot, X, Y), FParts[P].Area);
      end
      else begin
        FFitState[P] := -1;   // не влезает даже на пустой лист
        Sheet.Free;
        AResult.Unplaced.Add(P);
      end;
    end;

    if not ReportProgress(K + 1, Length(Inst)) then begin
      for J := K + 1 to Length(Inst)-1 do AResult.Unplaced.Add(Inst[J]);
      Break;
    end;
  end;
end;

initialization
  RegisterNestingAlgorithm(TShelfNesting);
  RegisterNestingAlgorithm(TBottomLeftNesting);

end.
