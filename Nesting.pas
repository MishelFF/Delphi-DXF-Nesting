unit Nesting;


interface

uses
  System.SysUtils, System.Classes, System.Math, System.Diagnostics,
  System.Generics.Collections, System.Generics.Defaults, NestGeom;

type
  TNestSettings = record
    SheetWidth, SheetHeight: Double;
    Margin: Double;         // отступ от края листа
    ItemGap: Double;            // минимальный зазор между деталями
    FiniteGridStep: Double;       // шаг сетки позиций
    AllowRotation: Boolean; // разрешить повороты
  end;

  TNestItem = class
  private
    FVariants: array[0..3] of TPolygon;
    FBoxes: array[0..3] of TRectD;
    FArea: Double;
  public
    Name: string;
    Outline: TPolygon;
    function Variant(Rot: Integer): TPolygon;//повернутый контур
    function Box(Rot: Integer): TRectD;//повернутые границы
    property Area: Double read FArea;
    procedure Prepare;
  end;

  TNestPlacement = record
    PartIndex: Integer;
    Rot90: Integer;
    OffsetX, OffsetY: Double;
    Outline: TPolygon;
    Box: TRectD;
  end;

  TNestSheet = class
  public
    Placements: TList<TNestPlacement>;
    PlacedArea: Double;
    constructor Create;
    destructor Destroy; override;
    procedure Add(const APlacement: TNestPlacement; AArea: Double);
  end;

  TNestResult = class
  public
    AlgorithmName: string;
    SheetArea: Double;
    ElapsedMs: Int64;
    Sheets: TObjectList<TNestSheet>;
    Unplaced: TList<Integer>;
    constructor Create;
    destructor Destroy; override;
    function Utilization: Double;
  end;


  TNestProgressEvent = procedure(Done, Total: Integer; var Cancel: Boolean) of object;

  TNestingAlgorithm = class abstract
  protected
    FParts: TObjectList<TNestItem>;
    FSettings: TNestSettings;
    procedure DoNest(AResult: TNestResult); virtual; abstract;
    function Rotations: Integer;
    function MakePlacement(PartIdx, Rot: Integer; X, Y: Double): TNestPlacement;
    function ReportProgress(Done, Total: Integer): Boolean;
  public
    OnProgress: TNestProgressEvent;
    class function AlgorithmName: string; virtual; abstract;
    function Nest(AParts: TObjectList<TNestItem>; const ASettings: TNestSettings): TNestResult;
  end;

  TNestingAlgorithmClass = class of TNestingAlgorithm;

function DefaultNestSettings: TNestSettings;
procedure RegisterNestingAlgorithm(AClass: TNestingAlgorithmClass);
function NestingAlgorithmNames: TArray<string>;
function CreateNestingAlgorithm(const AName: string): TNestingAlgorithm;
procedure ParseDXF(aFileName:String;aParts: TObjectList<TNestItem>);

implementation

var
  GRegistry: TDictionary<string, TNestingAlgorithmClass>;

procedure ParseDXF(aFileName:String;aParts: TObjectList<TNestItem>);
var
  FPos,FCode:Integer;
  FEof:Boolean;
  FSection,FValue:String;
  FLines : TStringList;
  FFS: TFormatSettings;
procedure NextLine;
begin
  if FPos + 1 >= FLines.Count then begin
    FEof := True;
    FCode := -1;
    FValue := '';
    Exit;
  end;
  FCode := StrToIntDef(Trim(FLines[FPos]), -1);
  FValue := Trim(FLines[FPos + 1]);
  Inc(FPos, 2);
end;
procedure ParseLwPolyline;
var
  wItem: TNestItem;
  Idx: Integer;
  wX:double;
begin
  wItem := TNestItem.Create;
  Idx := -1;
  NextLine;
  while (not FEof) and (FCode <> 0) do begin
    case FCode of
      8:  wItem.Name := FValue;
      10: wX := StrToFloatDef(FValue, 0, FFS);
      20: begin
            Idx:=Length(wItem.Outline);
            SetLength(wItem.Outline,Idx+1);
            wItem.Outline[Idx]:=PointD(wX,StrToFloatDef(FValue, 0, FFS));
          end;
    end;
    NextLine;
  end;
  if Length(wItem.Outline)>3 then begin
    wItem.prepare;
    aParts.Add(wItem);
  end
  else wItem.Free;
end;
begin
  aParts.Clear;
  FPos := 0;
  FEof := False;
  FSection := '';
  FLines := TStringList.Create;
  FLines.LoadFromFile(aFileName);
  FFS := TFormatSettings.Create;
  FFS.DecimalSeparator := '.';

  NextLine;
  while not FEof do begin
    if FCode <> 0 then NextLine
    else if SameText(FValue, 'SECTION') then begin
      NextLine;
      if (not FEof) and (FCode = 2) then FSection := UpperCase(FValue);
    end
    else if SameText(FValue, 'ENDSEC') then begin
      FSection := '';
      NextLine;
    end
    else if FSection = 'ENTITIES' then begin
      if SameText(FValue, 'LWPOLYLINE') then ParseLwPolyline
      else NextLine;
    end
    else NextLine;
  end;
end;

function DefaultNestSettings: TNestSettings;
begin
  Result.SheetWidth := 3000;
  Result.SheetHeight := 1500;
  Result.Margin := 10;
  Result.ItemGap := 5;
  Result.FiniteGridStep := 10;
  Result.AllowRotation := True;
end;


procedure TNestItem.Prepare;
var
  i: Integer;
begin
  FArea := Abs(PolygonArea(Outline));
  for i := 0 to 3 do
  begin
    FVariants[i] := PolygonRotateNormalized(Outline, i);
    FBoxes[i] := PolygonBounds(FVariants[i]);
  end;
end;

function TNestItem.Variant(Rot: Integer): TPolygon;
begin
  Result := FVariants[Rot and 3];
end;

function TNestItem.Box(Rot: Integer): TRectD;
begin
  Result := FBoxes[Rot and 3];
end;


constructor TNestSheet.Create;
begin
  inherited;
  Placements := TList<TNestPlacement>.Create;
end;

destructor TNestSheet.Destroy;
begin
  Placements.Free;
  inherited;
end;

procedure TNestSheet.Add(const APlacement: TNestPlacement; AArea: Double);
begin
  Placements.Add(APlacement);
  PlacedArea := PlacedArea + AArea;
end;


constructor TNestResult.Create;
begin
  inherited;
  Sheets := TObjectList<TNestSheet>.Create(True);
  Unplaced := TList<Integer>.Create;
end;

destructor TNestResult.Destroy;
begin
  Unplaced.Free;
  Sheets.Free;
  inherited;
end;

function TNestResult.Utilization: Double;
var
  S: TNestSheet;
  Total: Double;
begin
  if (Sheets.Count = 0) or (SheetArea <= 0) then Exit(0);
  Total := 0;
  for S in Sheets do
    Total := Total + S.PlacedArea;
  Result := Total / (Sheets.Count * SheetArea);
end;

function TNestingAlgorithm.Rotations: Integer;
begin
  if FSettings.AllowRotation then
    Result := 4
  else
    Result := 1;
end;

function TNestingAlgorithm.MakePlacement(PartIdx, Rot: Integer; X, Y: Double): TNestPlacement;
begin
  Result.PartIndex := PartIdx;
  Result.Rot90 := Rot;
  Result.OffsetX := X;
  Result.OffsetY := Y;
  Result.Outline := PolygonTranslate(FParts[PartIdx].Variant(Rot), X, Y);
  Result.Box := BoxTranslate(FParts[PartIdx].Box(Rot), X, Y);
end;

function TNestingAlgorithm.ReportProgress(Done, Total: Integer): Boolean;
var
  Cancel: Boolean;
begin
  Cancel := False;
  if Assigned(OnProgress) then OnProgress(Done, Total, Cancel);
  Result := not Cancel;
end;

function TNestingAlgorithm.Nest(AParts: TObjectList<TNestItem>;
  const ASettings: TNestSettings): TNestResult;
var
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  FParts := AParts;
  FSettings := ASettings;
  Result := TNestResult.Create;
  try
    Result.AlgorithmName := AlgorithmName;
    Result.SheetArea := ASettings.SheetWidth * ASettings.SheetHeight;
    DoNest(Result);
    Result.ElapsedMs := SW.ElapsedMilliseconds;
  except
    Result.Free;
    raise;
  end;
end;


procedure RegisterNestingAlgorithm(AClass: TNestingAlgorithmClass);
begin
  GRegistry.AddOrSetValue(AClass.AlgorithmName, AClass);
end;

function NestingAlgorithmNames: TArray<string>;
begin
  Result := GRegistry.Keys.ToArray;
end;

function CreateNestingAlgorithm(const AName: string): TNestingAlgorithm;
var
  C: TNestingAlgorithmClass;
begin
  if not GRegistry.TryGetValue(AName, C) then
    raise Exception.CreateFmt('Алгоритм раскроя "%s" не зарегистрирован', [AName]);
  Result := C.Create;
end;

initialization
  GRegistry := TDictionary<string, TNestingAlgorithmClass>.Create(TIStringComparer.Ordinal);

finalization
  GRegistry.Free;

end.
