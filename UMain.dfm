object FMain: TFMain
  Left = 0
  Top = 0
  Caption = #1058#1077#1089#1090' '#1088#1072#1089#1082#1088#1086#1103
  ClientHeight = 667
  ClientWidth = 979
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object FBox: TPaintBox
    Left = 0
    Top = 73
    Width = 979
    Height = 594
    Align = alClient
    OnPaint = FBoxPaint
    ExplicitLeft = -8
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 979
    Height = 73
    Align = alTop
    TabOrder = 0
    object InfoLbl: TLabel
      Left = 8
      Top = 34
      Width = 79
      Height = 13
      Caption = #1042#1099#1073#1077#1088#1080#1090#1077' '#1092#1072#1081#1083
    end
    object FSheetLbl: TLabel
      Left = 568
      Top = 8
      Width = 83
      Height = 13
      Alignment = taCenter
      Caption = #1083#1080#1089#1090
    end
    object SheetLbl: TLabel
      Left = 8
      Top = 54
      Width = 3
      Height = 13
    end
    object Label1: TLabel
      Left = 240
      Top = 8
      Width = 38
      Height = 13
      Caption = #1096#1080#1088#1080#1085#1072
    end
    object Label2: TLabel
      Left = 319
      Top = 8
      Width = 37
      Height = 13
      Caption = #1074#1099#1089#1086#1090#1072
    end
    object ButtonOpen: TButton
      Left = 8
      Top = 3
      Width = 75
      Height = 25
      Caption = #1054#1090#1082#1088#1099#1090#1100
      TabOrder = 0
      OnClick = ButtonOpenClick
    end
    object ButtonRun: TButton
      Left = 456
      Top = 3
      Width = 75
      Height = 25
      Caption = #1056#1072#1089#1082#1088#1086#1080#1090#1100
      TabOrder = 1
      OnClick = ButtonRunClick
    end
    object FAlg: TComboBox
      Left = 89
      Top = 5
      Width = 145
      Height = 21
      TabOrder = 2
    end
    object ButtonPrev: TButton
      Left = 537
      Top = 3
      Width = 25
      Height = 25
      Caption = '-'
      TabOrder = 3
      OnClick = ButtonPrevClick
    end
    object ButtonNext: TButton
      Left = 657
      Top = 3
      Width = 25
      Height = 25
      Caption = '+'
      TabOrder = 4
      OnClick = ButtonNextClick
    end
    object RunProgressBar: TProgressBar
      Left = 696
      Top = 9
      Width = 218
      Height = 17
      TabOrder = 5
    end
    object EditWidth: TEdit
      Left = 284
      Top = 5
      Width = 33
      Height = 21
      TabOrder = 6
      Text = '2500'
    end
    object EditHeight: TEdit
      Left = 362
      Top = 5
      Width = 33
      Height = 21
      TabOrder = 7
      Text = '1830'
    end
  end
end
