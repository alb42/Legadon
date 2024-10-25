unit mainwinunit;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math,
  muihelper, mui, intuition, agraphics, Inifiles,
  MUIClass.Window, MUIClass.Group, MUIClass.Base, MUIClass.Menu,
  MUIClass.Dialog, MUIClass.List, MUIClass.Image, MUIClass.Area,
  MUIClass.DrawPanel, MUIClass.StringGrid, MUIClass.Datatypes,
  epubunit;

type

  { TMainWindow }

  TMainWindow = class(TMUIWindow)
  private
    FIni: TIniFile;
    LastDir: string;
    ChapterList: TMUIStringGrid;
    MainGrp: TMUIGroup;
    PageLabel: TMUIText;
    DP: TMUIDrawPanel;
    DB: TDrawBuffer;
    FPageIdx: Integer;
    ePub: TEPub;
    ListView: TMUIListView;
    ContinueClickButton: TMUIButton;
    procedure ChapterListClick(Sender: TObject);
    procedure ContinueClick(Sender: TObject);
    procedure DrawImage(Sender: TObject; Rp: PRastPort; DrawRect: TRect);
    procedure HomeClick(Sender: TObject);
    procedure LoadFileMenu(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure PrevClick(Sender: TObject);
    procedure QuitMenu(Sender: TObject);
    procedure ShowEvent(Sender: TObject);
    procedure StartReadingClick(Sender: TObject);
    procedure UpdateWaitBar(Sender: TObject; Position: Integer);
  private
    procedure CheckIfLoaded;
    procedure OpenFile(AFileName: string);
    procedure LoadPage(AIdx: Integer);

    procedure LoadCover;
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

uses
  waitunit;

{ TMainWindow }

procedure TMainWindow.UpdateWaitBar(Sender: TObject; Position: Integer);
begin
  UpdateWait(Position);
end;

procedure TMainWindow.LoadFileMenu(Sender: TObject);
begin
  with TFileDialog.Create do
  begin
    Directory := LastDir;
    Pattern := '#?.epub';
    if Execute then
    begin
      OpenFile(FileName);
      LastDir := ExtractFileDir(FileName);
    end;
    Free;
  end;
end;

procedure TMainWindow.ContinueClick(Sender: TObject);
begin
  CheckIfLoaded;
  LoadPage(FPageIdx);
end;

procedure TMainWindow.ChapterListClick(Sender: TObject);
begin
  //
  if Assigned(ePub) and InRange(ChapterList.Row, 0, ePub.NumChapter - 1) then
  begin
    CheckIfLoaded;
    LoadPage(ePub.ChapterStartPage[ChapterList.Row]);
  end;
end;

procedure TMainWindow.DrawImage(Sender: TObject; Rp: PRastPort; DrawRect: TRect);
var
  w, h, l, t: LongInt;
  Aspect: Single;
begin
  SetRast(RP, 2);
  if Assigned(DB) and (DB.Width > 0) and (DB.Height > 0) then
  begin
    Aspect := DB.Height / DB.Width;
    if Aspect = 0 then
      Aspect := 1;
    w := DrawRect.Width;
    h := Round(w * Aspect);
    l := 0;
    t := 0;
    if h > DrawRect.Height then
    begin
      h := DrawRect.Height;
      w := Round(h / Aspect);
      l := (DrawRect.Width - w) div 2;
    end
    else
      t := (DrawRect.Height - h) div 2;
    DB.StretchDrawToRastPort(DrawRect.Left + l, DrawRect.Top + t, w, h, RP);
  end;
end;

procedure TMainWindow.HomeClick(Sender: TObject);
begin
  MainGrp.ActivePage := 0;
  ContinueClickButton.Disabled := FPageIdx = 0;
  if Assigned(ePub) then
    FIni.WriteInteger('Files', IntToHex(epub.CRC), FPageIdx);
end;

procedure TMainWindow.NextClick(Sender: TObject);
begin
  if Assigned(ePub) then
    LoadPage(FPageIdx + 1);
end;

procedure TMainWindow.PrevClick(Sender: TObject);
begin
  if Assigned(ePub) then
    LoadPage(FPageIdx - 1);
end;

procedure TMainWindow.QuitMenu(Sender: TObject);
begin
  Self.Close;
end;

procedure TMainWindow.ShowEvent(Sender: TObject);
var
  i: Integer;
  s: String;
begin
  if ParamCount > 0 then
  begin
    for i := 1 to ParamCount do
    begin
      s := ParamStr(i);
      if Lowercase(ExtractFileExt(s)) = '.epub' then
      begin
        OpenFile(s);
        Exit;
      end;
    end;
  end;
end;

procedure TMainWindow.StartReadingClick(Sender: TObject);
begin
  CheckIfLoaded;
  LoadPage(0);
end;

procedure TMainWindow.CheckIfLoaded;
begin

  if ePub.NumPages = 0 then
  begin
    OpenWait(epub.NumChunks);
    ePub.OnUpdate := @UpdateWaitBar;
    Self.Sleep := True;
    try
      ePub.LoadPages;
    finally
      Self.Sleep := False;
      CloseWait;
    end;
  end;

end;

procedure TMainWindow.OpenFile(AFileName: string);
var
  BookName: String;
  i: Integer;
begin
  FreeAndNil(DB);
  FreeAndNil(ePub);
  MainGrp.ActivePage := 0;
  Title := 'Legadon Loading...';
  ScreenTitle := 'Loading ' + ExtractFileName(AFileName);
  //
  ePub := TEpub.Create;
  ChapterList.NumColumns := 2;
  if not ePub.LoadFromFile(AFileName) then
  begin
    ChapterList.NumRows := 0;
    PageLabel.Contents := '';
    TMUIFloatText(ListView.List).Text := '';
    Title := 'Legadon' ;
    ScreenTitle := 'Error Loading ' + ExtractFileName(AFileName);
    Beep;
    Exit;
  end;
  ChapterList.ShowLines := True;
  ChapterList.Quiet := True;
  ChapterList.NumRows := ePub.NumChapter;
  for i := 0 to ePub.NumChapter  - 1 do
  begin
    ChapterList.Cells[0, i] := IntToStr(i + 1);
    ChapterList.Cells[1, i] := Utf8ToAnsi(ePub.ChapterName[i]);
  end;
  ChapterList.Quiet := False;
  LoadCover();
  BookName := Utf8ToAnsi(ePub.MetaData.Creator) + '"' + Utf8ToAnsi(ePub.MetaData.Title) + '"';
  FPageIdx := FIni.ReadInteger('Files', IntToHex(epub.CRC), 0);

  ContinueClickButton.Disabled := FPageIdx = 0;

  {Title := 'Legadon Loading Pages';
  ScreenTitle := 'Loading...' + BookName;
  ePub.LoadPages;}
  Title := 'Legadon ' + BookName;
  ScreenTitle := BookName;
  //LoadPage(0);
  //
end;

function MyTextConvert(Src: RawByteString): string; inline;
{var
  p: SizeInt;
  i: Integer;
begin

  p := Pos(' he asked', Src);
  if P > 0 then
  begin
    P := P - 3;
    for i := 0 to 10 do
    begin
      write(IntToHex(Byte(Src[P + i]), 2), ' ');
    end;
    writeln();
  end;}
begin
  Src := StringReplace(Src, #226#128#156, '"', [rfReplaceAll]);
  Src := StringReplace(Src, #226#128#157, '"', [rfReplaceAll]);
  Src := StringReplace(Src, #226#128#158, '"', [rfReplaceAll]);
  Src := StringReplace(Src, #226#128#152, '''', [rfReplaceAll]);
  Src := StringReplace(Src, #226#128#153, '''', [rfReplaceAll]);
  Src := StringReplace(Src, #226#128#148, '-', [rfReplaceAll]);

  Result := Utf8ToAnsi(Src);
end;

procedure TMainWindow.LoadPage(AIdx: Integer);
begin
  if Assigned(ePub) then
  begin
    FPageIdx := EnsureRange(AIdx, 0, epub.NumPages - 1);
    TMUIFloatText(ListView.List).Text := MyTextConvert(epub.PageText[FPageIdx]);
    PageLabel.Contents := IntToStr(FPageIdx + 1) + '/' + IntToStr(ePub.NumPages) + ' - ' + MyTextConvert(ePub.ChapterNameByPage[FPageIdx]);
    if MainGrp.ActivePage <> 1 then
      MainGrp.ActivePage := 1;
    FIni.WriteInteger('Files', IntToHex(epub.CRC), FPageIdx);
  end
  else
  begin
    TMUIFloatText(ListView.List).Text := '';
    PageLabel.Contents := '';
  end;
end;

procedure TMainWindow.LoadCover;
var
  Count: Integer;
  CoverFile: String;
  DT: TPictureDataType;
begin
  //
  if not Assigned(ePub) then
    Exit;

  Count := 0;
  repeat
    Inc(Count);
    CoverFile := 't:cover_' + IntToStr(Count);
  until not FileExists(CoverFile);

  if ePub.SaveCover(CoverFile) then
  begin
    DT := TPictureDataType.Create;
    if DT.LoadFile(CoverFile) then
    begin
      DB := TDrawBuffer.Create(DT.ImageSize.X, DT.ImageSize.Y, Self.Screen^.BitMap.Depth, @(Self.Screen^.BitMap));
      BltBitMapRastPort(DT.Bitmap, 0, 0, DB.RP, 0, 0, DB.Width, DB.Height, $00c0);
    end;
    DT.Free;
    DeleteFile(CoverFile);
    DP.RedrawObject;
  end;
end;

constructor TMainWindow.Create;
var
  Menu: TMUIMenu;
  MI: TMUIMenuItem;
  Grp, Grp2, Page1, Page2: TMUIGroup;
  PrevButton, NextButton, HomeButton: TMUIImage;
begin
  inherited Create;

  FIni := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  FIni.CacheUpdates := True;
  //
  LastDir := 'PROGDIR:';
  //
  ePub := nil;
  DB := nil;
  //
  Title := 'Legadon';
  ScreenTitle := 'Legadon';
  ID := MAKE_ID('L','M','W','I');
  //
  MainGrp := TMUIGroup.Create;
  MainGrp.PageMode := True;
  MAinGrp.Parent := Self;
  //
  Page1 := TMUIGroup.Create;
  Page1.Horiz := False;
  Page1.Frame := MUIV_Frame_None;
  Page1.Parent := MainGrp;
  //
  Page2 := TMUIGroup.Create;
  Page2.Horiz := False;
  Page2.Frame := MUIV_Frame_None;
  Page2.Parent := MainGrp;
  //
  MainGrp.ActivePage := 0;

  // ################## Menu
  Menustrip := TMUIMenustrip.Create;
  Menu := TMUIMenu.Create;
  Menu.Title := 'File';
  Menustrip.AddChild(Menu);

  MI := TMUIMenuItem.Create;
  MI.Title := 'Load...';
  MI.ShortCut := 'L';
  MI.OnTrigger  := @LoadFileMenu;
  Menu.AddChild(MI);

  MI := TMUIMenuItem.Create;
  MI.Title := 'Quit';
  MI.ShortCut := 'Q';
  MI.OnTrigger   := @QuitMenu;
  Menu.AddChild(MI);


  // ################ Chapter Page

  Grp := TMUIGroup.Create;
  Grp.Frame := MUIV_Frame_None;
  Grp.Horiz := True;
  Grp.Parent := Page1;

  DP := TMUIDrawPanel.Create;
  DP.MinWidth := 160;
  DP.MinHeight := 160;
  DP.DefWidth := 120;
  DP.DefHeight := 200;
  DP.OnDrawObject  := @DrawImage;
  DP.Parent := Grp;
  ChapterList := TMUIStringGrid.Create;
  ChapterList.Frame := MUIV_Frame_None;
  ChapterList.OnDoubleClick  := @ChapterListClick;
  ChapterList.Parent := Grp;

  Grp := TMUIGroup.Create;
  Grp.Frame := MUIV_Frame_None;
  Grp.Horiz := True;
  Grp.Parent := Page1;

  TMUIRectangle.Create.Parent := Grp;
  with TMUIButton.Create('Start Reading') do
  begin
    OnClick  := @StartReadingClick;
    Parent := Grp;
  end;
  ContinueClickButton := TMUIButton.Create('Continue Reading');
  with ContinueClickButton do
  begin
    Disabled := True;
    OnClick  := @ContinueClick;
    Parent := Grp;
  end;
  TMUIRectangle.Create.Parent := Grp;

  // ########### Read Page
  ListView := TMUIListView.Create;
  ListView.List := TMUIFloatText.Create;
  ListView.Parent := Page2;

  Grp := TMUIGroup.Create;
  Grp.Frame := MUIV_Frame_None;
  Grp.Horiz := True;
  Grp.Parent := Page2;

  Grp2 := TMUIGroup.Create;
  Grp2.Frame := MUIV_Frame_None;
  Grp2.Horiz := True;
  Grp2.Parent := Grp;

  HomeButton := TMUIImage.Create;
  HomeButton.Frame := MUIV_Frame_Button;
  HomeButton.InputMode := MUIV_InputMode_RelVerify;
  HomeButton.Spec.SetStdPattern(MUII_TapeStop);
  HomeButton.OnClick   := @HomeClick;
  HomeButton.Parent := Grp2;

  PrevButton := TMUIImage.Create;
  PrevButton.Frame := MUIV_Frame_Button;
  PrevButton.InputMode := MUIV_InputMode_RelVerify;
  PrevButton.Spec.SetStdPattern(MUII_TapePlayBack);
  PrevButton.OnClick  := @PrevClick;
  PrevButton.Parent := Grp2;

  NextButton := TMUIImage.Create;
  NextButton.Frame := MUIV_Frame_Button;
  NextButton.InputMode := MUIV_InputMode_RelVerify;
  NextButton.Spec.SetStdPattern(MUII_TapePlay);
  NextButton.OnClick  := @NextClick;
  NextButton.Parent := Grp2;

  PageLabel := TMUIText.Create;
  PageLabel.Frame := MUIV_Frame_None;
  PageLabel.Parent := Grp2;
  //
  TMUIRectangle.Create.Parent := Grp;
  //
  OnShow  := @ShowEvent;
end;

destructor TMainWindow.Destroy;
begin
  FIni.UpdateFile;
  FIni.Free;
  FreeAndNil(ePub);
  FreeAndNil(DB);
  inherited Destroy;
end;

end.

