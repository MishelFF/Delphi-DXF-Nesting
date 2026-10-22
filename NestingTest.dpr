program NestingTest;

uses
  Vcl.Forms,
  UMain in 'UMain.pas' {FMain},
  NestGeom in 'NestGeom.pas',
  NestAlgorithms in 'NestAlgorithms.pas',
  Nesting in 'Nesting.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFMain, FMain);
  Application.Run;
end.
