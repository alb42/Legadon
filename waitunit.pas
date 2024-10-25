unit waitunit;

{$mode ObjFPC}{$H+}

interface

uses
  MUI, MAth,
  MUIClass.Window, MUIClass.Group, MUIClass.Area,
  Classes, SysUtils;

type
  { TWaitWindow }
  TWaitWindow = class(TMUIWindow)
  private
    PB: TMUIGauge;
    CloseAllowed: Boolean;
    procedure CloseReqEvent(Sender: TObject; var CloseAction: TCloseAction);
  public
    constructor Create; override;

  end;

var
  WaitWindow: TWaitWindow;


procedure OpenWait(MaxVal: Integer);
procedure CloseWait;
procedure UpdateWait(Position: Integer);

implementation

{ TWaitWindow }

procedure TWaitWindow.CloseReqEvent(Sender: TObject; var CloseAction: TCloseAction);
begin
  if CloseAllowed then
    CloseAction := caClose
  else
    CloseAction := caNone;
end;

constructor TWaitWindow.Create;
var
  Grp: TMUIGroup;
begin
  inherited Create;
  //
  CloseAllowed := False;
  //
  Self.Borderless := True;
  Self.CloseGadget := False;
  Self.SizeGadget := False;
  Self.DepthGadget := False;
  Self.DragBar := False;

  Grp := TMUIGroup.Create;
  With Grp do
  begin
    Horiz := False;
    Parent := Self;
  end;
  Width := 300;
  Horizontal := False;
  //
  with TMUIText.Create('   Loading...    ') do
  begin
    Frame := MUIV_Frame_None;
    Parent := Grp;
  end;

  PB := TMUIGauge.Create;
  PB.Horiz := True;
  PB.Parent := Grp;

  Self.OnCloseRequest  := @CloseReqEvent;
end;

procedure OpenWait(MaxVal: Integer);
begin
  WaitWindow.PB.Current := 0;
  WaitWindow.PB.Max := MaxVal;
  WaitWindow.CloseAllowed := False;
  WaitWindow.Show;
  WaitWindow.ToFront;
end;

procedure CloseWait;
begin
  WaitWindow.CloseAllowed := True;
  WaitWindow.Close;
end;

procedure UpdateWait(Position: Integer);
begin
  WaitWindow.PB.Current := EnsureRange(Position, 0, WaitWindow.PB.Max);
end;

end.

