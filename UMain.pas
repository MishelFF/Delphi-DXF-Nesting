unit UMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, Vcl.ExtCtrls,
   System.Math,System.Generics.Collections,NestGeom,NestAlgorithms,Nesting,
  Vcl.ComCtrls;

type
  TFMain = class(TForm)
    Panel1: TPanel;
    FBox: TPaintBox;
    InfoLbl: TLabel;
    ButtonOpen: TButton;
    ButtonRun: TButton;
    FSheetLbl: TLabel;
    FAlg: TComboBox;
    ButtonPrev: TButton;
    ButtonNext: TButton;
    RunProgressBar: TProgressBar;
    SheetLbl: TLabel;
    Label1: TLabel;
    EditWidth: TEdit;
    Label2: TLabel;
    EditHeight: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure FBoxPaint(Sender: TObject);
    procedure ButtonOpenClick(Sender: TObject);
    procedure ButtonRunClick(Sender: TObject);
    procedure ButtonPrevClick(Sender: TObject);
    procedure ButtonNextClick(Sender: TObject);
  private
    { Private declarations }
    FParts: TObjectList<TNestItem>;
    FResult: TNestResult;
    FSheetIdx: Integer;
    FSheetW, FSheetH: Double;
    IsRunning,NeedCancel:Boolean;
    procedure LoadFile(const aFileName: string);
    procedure ReportProgress(Done, Total: Integer; var Cancel: Boolean);
    procedure SheetInfo;
  public
    { Public declarations }
  end;

var
  FMain: TFMain;

implementation

{$R *.dfm}


procedure TFMain.FormCreate(Sender: TObject);
var
  Names: TArray<string>;
  Nm: string;
begin
  FParts := TObjectList<TNestItem>.Create(True);
  Names := NestingAlgorithmNames;
  TArray.Sort<string>(Names);
  for Nm in Names do
    FAlg.Items.Add(Nm);
  FAlg.ItemIndex := Max(0, FAlg.Items.IndexOf('Shelf (bounding boxes)'));
  IsRunning:=False;NeedCancel:=False;
end;

procedure TFMain.LoadFile(const aFileName: string);
begin
  ParseDXF(aFileName,FParts);
  FreeAndNil(FResult);
  FSheetIdx := 0;
  InfoLbl.Caption := Format('Загружено контуров: %d', [FParts.Count]);
  FSheetLbl.Caption := '';
  FBox.Invalidate;
end;

procedure TFMain.ButtonPrevClick(Sender: TObject);
begin
  if FSheetIdx > 0 then
  begin
    Dec(FSheetIdx);
    SheetInfo;
    FBox.Invalidate;
  end;
end;

procedure TFMain.ButtonNextClick(Sender: TObject);
begin
if (FResult <> nil) and (FSheetIdx < FResult.Sheets.Count - 1) then  begin
    Inc(FSheetIdx);
    SheetInfo;
    FBox.Invalidate;
  end;

end;
procedure TFMain.ReportProgress(Done, Total: Integer; var Cancel: Boolean);
begin
   RunProgressBar.Max:=Total;
   RunProgressBar.Position:=Done;
   Cancel:=NeedCancel;
   NeedCancel:=False;
   Application.ProcessMessages;
end;
procedure TFMain.ButtonRunClick(Sender: TObject);
var
  Settings: TNestSettings;
  Algorythm: TNestingAlgorithm;
  i, Placed: Integer;
begin
  if FParts.Count = 0 then  begin
    ShowMessage('Сначала откройте DXF с деталями');
    Exit;
  end;
  if IsRunning then begin
    ShowMessage('Расчет прерван');
    NeedCancel:=True;
    IsRunning:=False;
    ButtonRun.Caption:='Раскроить';
    exit;
  end;
  IsRunning:=True;
  NeedCancel:=False;
  ButtonRun.Caption:='Стоп';

  if FAlg.ItemIndex < 0 then Exit;

  Settings := DefaultNestSettings;
  with Settings do begin
    SheetWidth := StrToFloatDef(EditWidth.Text,2500);
    SheetHeight :=StrToFloatDef(EditHeight.Text,1830);
    Margin := 10;
    ItemGap := 5;
    FiniteGridStep := 20;
    AllowRotation := true;
    FSheetW := SheetWidth;
    FSheetH := SheetHeight;
  end;


  FreeAndNil(FResult);
  Algorythm := CreateNestingAlgorithm(FAlg.Text);
  Algorythm.OnProgress:=ReportProgress;
  try
    FResult := Algorythm.Nest(FParts, Settings);
  finally
    Algorythm.Free;
  end;

  Placed := 0;
  for i := 0 to FResult.Sheets.Count - 1 do Inc(Placed, FResult.Sheets[i].Placements.Count);
  FSheetIdx := 0;
  InfoLbl.Caption := Format('Листов: %d, размещено: %d, не размещено: %d, использование: %.1f%%, время: %d мс',
    [FResult.Sheets.Count, Placed, FResult.Unplaced.Count,FResult.Utilization * 100, FResult.ElapsedMs]);
  SheetInfo;
  FBox.Invalidate;
  ButtonRun.Caption:='Раскроить';
  IsRunning:=False;
end;

procedure TFMain.ButtonOpenClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := 'DXF (*.dxf)|*.dxf|Все файлы (*.*)|*.*';
    if Dlg.Execute then
      LoadFile(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TFMain.SheetInfo;
begin
  if (FResult = nil) or (FResult.Sheets.Count = 0) then
    FSheetLbl.Caption := ''
  else
    FSheetLbl.Caption := Format('Лист %d из %d', [FSheetIdx + 1, FResult.Sheets.Count]);
end;

const
  PartColors: array[0..7] of TColor =
    ($F5D5B8, $B8E0B8, $B8C8F5, $F5E6B0, $E0B8E0, $B0E6E6, $D8D8D8, $B8B8F0);

procedure TFMain.FBoxPaint(Sender: TObject);
const
  Pad = 10;
var
  i,j: Integer;
  Scale, Ox, Oy: Double;
  Sheet: TNestSheet;
  Pl: TNestPlacement;
  Pts: TArray<TPoint>;
begin
  with FBox.Canvas do begin
    Brush.Color := clWhite;
    FillRect(FBox.ClientRect);
    if (FResult = nil) or (FResult.Sheets.Count = 0) or (FSheetW <= 0) or (FSheetH <= 0) then Exit;
    if FSheetIdx >= FResult.Sheets.Count then FSheetIdx := FResult.Sheets.Count - 1;
    Sheet := FResult.Sheets[FSheetIdx];

    Scale := Min((FBox.Width - 2 * Pad) / FSheetW, (FBox.Height - 2 * Pad) / FSheetH);
    Ox := Pad;
    Oy := FBox.Height - Pad;

    // лист
    Pen.Color := clBlack;
    Pen.Width := 1;
    Brush.Color := $F4F4F4;
    Rectangle(Round(Ox), Round(Oy - FSheetH * Scale),Round(Ox + FSheetW * Scale) + 1, Round(Oy) + 1);

    // детали
    for Pl in Sheet.Placements do begin
      SetLength(Pts, Length(Pl.Outline));
      for i := 0 to Length(Pl.Outline)-1 do
        Pts[i] := Point(Round(Ox + Pl.Outline[I].X * Scale),Round(Oy - Pl.Outline[I].Y * Scale));
      Brush.Color := PartColors[Pl.PartIndex mod Length(PartColors)];
      Pen.Color := clBlack;
      Polygon(Pts);
    end;
  end;
end;

end.
