unit epubunit;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Zipper, XMLRead, DOM, Math, crc;

type

  { TEPubMetaData }

  TEPubMetaData = class
    Creator, CreatorSort: string; // dc:
    Title: string;
    Language: string;
    Subjects: TStringList;
    Rights: string;  // dc.Rights
    PubDate: string;
    Source: string;

    constructor Create;
    destructor Destroy; override;
  end;

  TEpubItem = record
    ID: string;
    href: string;
    typ: string;
  end;

  TEPubTOCEntry = class
    Number: Integer;
    ID: String;
    Text: string;
    FileName: string;
    Link: string;
    StartAtPage: Integer;
  end;

  TUpdateEvent = procedure(Sender: TObject; Position: Integer) of object;

  { TEpub }

  TEpub = class
  private
    FOnUpdate: TUpdateEvent;
    FZip: TUnZipper;
    FCRC: LongWord;
    //
    FCoverImage: string; // Item name of the cover image file
    FRootName: string; // Filename of the root file in the Zip file
    FBaseDir: string; // Basedir for all files
    FTOCFile: string;
    FItemList: array of TEpubItem;
    FChunks: array of string;
    FPages: array of Integer;
    FText: TStringList;
    //
    FMetaData: TEPubMetaData;
    FToc: TList;
    MemStream: TMemoryStream;
    procedure CreateMemStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    procedure DoneMemStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
    function GetChapterName(Idx: Integer): string;
    function GetChapterNameByPage(PageIdx: Integer): string;
    function GetChapterStartPage(Idx: Integer): Integer;
    function GetNumChapter: Integer;
    function GetNumChunks: Integer;
    function GetNumPages: Integer;
    function GetPageText(Idx: Integer): string;
    function LoadMeta: Boolean;
    function LoadRootFile: Boolean;
    procedure LoadItems(ANode: TDOMNode);
    procedure LoadMetaData(ANode: TDOMNode);
    procedure LoadChunkInfo(ANode: TDOMNode);
    procedure LoadTOCFile;
    //
    function GetItembyID(AId: string): string;
    function GetTOC(Idx: Integer): TEPubTOCEntry;
    function GetTOCbyID(AFile, AID: string): TEPubTOCEntry;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function LoadFromFile(AFileName: string): Boolean;

    function SaveCover(AFilename: string): Boolean;

    function LoadPages: Integer;

    property MetaData: TEPubMetaData read FMetaData;

    property NumChunks: Integer read GetNumChunks;
    property NumChapter: Integer read GetNumChapter;
    property ChapterName[Idx: Integer]: string read GetChapterName;
    property ChapterNameByPage[PageIdx: Integer]: string read GetChapterNameByPage;
    property ChapterStartPage[Idx: Integer]: Integer read GetChapterStartPage;
    property NumPages: Integer read GetNumPages;
    property PageText[Idx: Integer]: string read GetPageText;
    property CRC: LongWord read FCRC;

    property OnUpdate: TUpdateEvent read FOnUpdate write FOnUpdate;
  end;

implementation

uses
  xmlhelper;

const
  MetaFilename = 'META-INF/container.xml';

{ TEPubMetaData }

constructor TEPubMetaData.Create;
begin
  Subjects := TStringList.Create;
end;

destructor TEPubMetaData.Destroy;
begin
  Subjects.Free;
  inherited Destroy;
end;

{ TEpub }

procedure TEpub.CreateMemStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
begin
  MemStream.Clear;
  AStream := MemStream;
end;

procedure TEpub.DoneMemStream(Sender: TObject; var AStream: TStream; AItem: TFullZipFileEntry);
begin
  AStream := nil;
end;

function TEpub.GetChapterName(Idx: Integer): string;
var
  Entry: TEPubTOCEntry;
begin
  Result := '';
  Entry := GetTOC(Idx);
  if Assigned(Entry) then
    Result := Entry.Text;
end;

function TEpub.GetChapterNameByPage(PageIdx: Integer): string;
var
  i, Num: Integer;
begin
  Result := '';
  for i := 0 to FToc.Count - 1 do
  begin
    Num := TEPubTOCEntry(FToc[i]).StartAtPage;
    //writeln(i, ' Num ', Num, ' ', TEPubTOCEntry(FToc[i]).Text);
    if Num <= PageIdx then
      Result := TEPubTOCEntry(FToc[i]).Text
    else
      Exit;
  end;
end;

function TEpub.GetChapterStartPage(Idx: Integer): Integer;
begin
  Result := -1;
  if InRange(Idx, 0, FToc.Count - 1) then
    Result := TEPubTOCEntry(FToc[Idx]).StartAtPage;
end;

function TEpub.GetNumChapter: Integer;
begin
  Result := FToc.Count;
end;

function TEpub.GetNumChunks: Integer;
begin
  Result := Length(FChunks);
end;

function TEpub.GetNumPages: Integer;
begin
  Result := Length(FPages);
end;

function TEpub.GetPageText(Idx: Integer): string;
var
  StartIdx, EndIdx, i: Integer;
begin
  Result := '';
  if (Idx >= 0) and (Idx <= High(FPages)) then
  begin
    StartIdx := FPages[Idx];
    if (Idx + 1) <= High(FPages) then
      EndIdx := FPages[Idx + 1] - 1
    else
      EndIdx := FText.Count - 1;
    for i := StartIdx to EndIdx do
    begin
      Result := Result + FText[i] + #10;
    end;

  end;
end;

function TEpub.LoadMeta: Boolean;
var
  ADoc: TXMLDocument;
  RootFiles, RootFile: TDOMNode;
begin
  Result := False;
  FRootName := '';
  try
    XMLRead.ReadXMLFile(ADoc, MemStream);
    RootFiles := FindNode(ADoc.DocumentElement, 'rootfiles');
    RootFile := FindNode(RootFiles, 'rootfile');
    FRootName := GetStringAttribute(RootFile, 'full-path');
  finally
    Result := FRootName <> '';
    ADoc.Free;
  end;
end;

function TEpub.LoadRootFile: Boolean;
var
  ADoc: TXMLDocument;
begin
  Result := False;
  FRootName := '';
  try
    XMLRead.ReadXMLFile(ADoc, MemStream);
    //
    LoadItems(FindNode(ADoc.DocumentElement, 'manifest'));
    //
    LoadMetaData(FindNode(ADoc.DocumentElement, 'metadata'));
    //
    LoadChunkInfo(FindNode(ADoc.DocumentElement, 'spine'));
    //
    Result := True;
  finally
    ADoc.Free;
  end;
end;

procedure TEpub.LoadItems(ANode: TDOMNode);
var
  i: Integer;
  INode: TDOMNode;
begin
  if not Assigned(ANode) then
  begin
    SetLength(FItemList, 0);
    Exit;
  end;
  SetLength(FItemList, ANode.ChildNodes.Count);
  for i := 0 to ANode.ChildNodes.Count - 1 do
  begin
    INode := ANode.ChildNodes[i];
    FItemList[i].ID := GetStringAttribute(INode, 'id');
    FItemList[i].href := GetStringAttribute(INode, 'href');
    FItemList[i].typ := GetStringAttribute(INode, 'media-type');
  end;
end;

procedure TEpub.LoadMetaData(ANode: TDOMNode);
var
  i: Integer;
  MNode: TDOMNode;
begin
  if not Assigned(ANode) then
    Exit;
  for i := 0 to ANode.ChildNodes.Count - 1 do
  begin
    MNode := ANode.ChildNodes[i];
    if Assigned(MNode) then
    begin
      try
      case MNode.NodeName of
        'dc:rights': FMetaData.Rights := UTF8Encode(MNode.TextContent);
        'dc:creator':
          begin
            FMetaData.Creator := UTF8Encode(MNode.TextContent);
            FMetaData.CreatorSort := GetStringAttribute(MNode, 'opf:file-as', FMetaData.Creator);
          end;
        'dc:title': FMetaData.Title := UTF8Encode(MNode.TextContent);
        'dc:language': FMetaData.Language := UTF8Encode(MNode.TextContent);
        'dc:subject': FMetaData.Subjects.Add(UTF8Encode(MNode.TextContent));
        'dc:date':
          begin
            if GetStringAttribute(MNode, 'opf:event') = 'publication' then
              FMetaData.PubDate := UTF8Encode(MNode.TextContent);
          end;
        'dc:source': FMetaData.Source := UTF8Encode(MNode.TextContent);
        'meta':
          begin
            if GetStringAttribute(MNode, 'name') = 'cover' then
              FCoverImage := GetItembyID(GetStringAttribute(MNode, 'content'));
          end;
      end;
      except
      end;
    end;
  end;
end;

procedure TEpub.LoadChunkInfo(ANode: TDOMNode);
var
  i: Integer;
  ItemNodes: TDOMNodes;
begin
  //
  ItemNodes := FindNodes(ANode, 'itemref');
  FTOCFile := GetItemByID(GetStringAttribute(ANode, 'toc'));
  SetLength(FChunks, Length(ItemNodes));
  for i := 0 to High(FChunks) do
    FChunks[i] := GetItembyID(GetStringAttribute(ItemNodes[i], 'idref'));
end;

function CompareTOCs(Item1, Item2: Pointer): Integer;
var
  I1, I2: TEPubTOCEntry;
begin
  I1 := TEPubTOCEntry(Item1);
  I2 := TEPubTOCEntry(Item2);
  //
  Result := I1.Number - I2.Number;
end;

procedure TEpub.LoadTOCFile;
var
  ADoc: TXMLDocument;
  MNode: TDOMNode;
  NavNodes: TDOMNodes;
  i: Integer;
  Entry: TEPubTOCEntry;
  s: String;
  p: SizeInt;
begin
  try
    XMLRead.ReadXMLFile(ADoc, MemStream);
    //
   //FTitle := FindNode(ADoc.DocumentElement, 'docTitle'));
   //
   MNode := FindNode(ADoc.DocumentElement, 'navMap');
   NavNodes := FindNodes(MNode, 'navPoint');
   for i := 0 to High(NavNodes) do
   begin
     Entry := TEPubTOCEntry.Create;
     Entry.ID := GetStringAttribute(NavNodes[i], 'id');
     //
     Entry.Text := '';
     MNode := FindNode(FindNode(NavNodes[i], 'navLabel'), 'text');
     if Assigned(MNode) then
       Entry.Text := UTF8Encode(MNode.TextContent);
     //
     Entry.Number := StrToIntDef(GetStringAttribute(NavNodes[i], 'playOrder'), -1);
     //
     s := GetStringAttribute(FindNode(NavNodes[i], 'content'), 'src');
     p := Pos('#', s);
     if p >= 1 then
     begin
       Entry.FileName := Copy(s, 1, p - 1);
       Entry.Link := Copy(s, p + 1, Length(s));
     end
     else
     begin
       Entry.FileName := s;
       Entry.Link := '';
     end;
     FToc.Add(Entry);
   end;
   // make sure they are sorted
   //FToc.Sort(@CompareTOCs);
  finally
    ADoc.Free;
  end;
end;

function TEpub.GetItembyID(AId: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0to High(FItemList) do
  begin
    if FItemList[i].ID = AID then
    begin
      Result := FItemList[i].href;
      Exit;
    end;
  end;
end;

function TEpub.GetTOC(Idx: Integer): TEPubTOCEntry;
begin
  Result := nil;
  if (Idx >= 0) and (Idx < FToc.Count) then
    Result := TEPubTOCEntry(FToc[Idx]);
end;

function TEpub.GetTOCbyID(AFile, AID: string): TEPubTOCEntry;
var
  i: Integer;
  Item: TEPubTOCEntry;
begin
  Result := nil;
  for i := 0 to FToc.Count - 1 do
  begin
    Item := TEPubTOCEntry(FToc[i]);
    if (Item.FileName = AFile) and (Item.Link = AID) then
    begin
      Result := Item;
      Exit;
    end;
  end;
end;

constructor TEpub.Create;
begin
  FZip := TUnZipper.Create;
  FZip.OnCreateStream  := @CreateMemStream;
  FZip.OnDoneStream   := @DoneMemStream;
  //
  MemStream := TMemoryStream.Create;
  FMetaData := TEPubMetaData.Create;
  FToc := TList.Create;
  FText := TStringList.Create;
end;

function CalcCRC(AStream: TStream): LongWord;
var
  Buffer: PByte;
  Len: Integer;
begin
  Len := AStream.Size;
  Buffer := AllocMem(Len);
  AStream.ReadBuffer(Buffer^, Len);
  Result := crc32(0, Buffer, Len);
  FreeMem(Buffer);
end;

destructor TEpub.Destroy;
var
  i: Integer;
begin
  FText.Free;
  FZip.Free;
  MemStream.Free;
  MetaData.Free;
  for i := 0 to FToc.Count - 1 do
    TObject(FToc[i]).Free;
  FToc.Free;
  inherited Destroy;
end;

function TEpub.LoadFromFile(AFileName: string): Boolean;
begin
  Result := False;
  //
  FZip.FileName := AFileName;
  FZip.Examine;

  FZip.UnZipFile(MetaFilename);
  if MemStream.Size = 0 then
    Exit;
  MemStream.Position := 0;
  if not LoadMeta then
    Exit;
  FBaseDir := ExtractFilePath(FRootName);
  //
  FZip.UnZipFile(FRootName);
  if MemStream.Size = 0 then
    Exit;
  MemStream.Position := 0;
  FCRC := CalcCRC(MemStream);
  MemStream.Position := 0;
  if not LoadRootFile then
    Exit;
  //
  if FTOCFile <> '' then
  begin
    FTOCFile := FBaseDir + FTOCFile;
    FZip.UnZipFile(FTOCFile);
    if MemStream.Size > 0 then
    begin
      MemStream.Position := 0;
      LoadTOCFile;
    end;
  end;

  Result := True;
end;

function TEpub.SaveCover(AFilename: string): Boolean;
begin
  Result := False;
  if FCoverImage = '' then
    Exit;
  MemStream.Clear;
  FZip.UnZipFile(FBaseDir + FCoverImage);
  if MemStream.Size > 0 then
  begin
    MemStream.Position := 0;
    MemStream.SaveToFile(AFilename);
    Result := FileExists(AFilename);
  end;
end;



function TEpub.LoadPages: Integer;
var
  NText: string;
  FPageIdx: Integer;
  NumLines: Integer;
  Chunk: Integer;

  procedure AddPageChange;
  begin
    FPages[FPageIdx] := FText.Count;
    Inc(FPageIdx);
    if FPageIdx > High(FPages) then
      SetLength(FPages, FPageIdx + 1001);
    NumLines := 0;
  end;

  procedure AddNText;
  var
    Chars: SizeInt;
  begin
    Chars := Length(NText);
    FText.Add(NText);
    NText := '';
    NumLines := NumLines + (Chars div 80)  + 1;
    if NumLines > 40 then
      AddPageChange;
  end;

  procedure ExamineNodes(ANode: TDomNode);
  var
    i: Integer;
    NNode, IDNode: TDOMNode;
    TOCEntry: TEPubTOCEntry;
  begin
    if not Assigned(ANode) then
      Exit;
    if not ANode.HasChildNodes then
      Exit;
    for i := 0 to ANode.ChildNodes.Count - 1 do
    begin
      NNode := ANode.ChildNodes[i];
      if NNode.HasAttributes then
      begin
        IDNode := NNode.Attributes.GetNamedItem('id');
        if Assigned(IDNode) then
        begin
          TOCEntry := GetTOCbyID(FChunks[Chunk], string(IDNode.NodeValue));
          if Assigned(TOCEntry) then
          begin
            TOCEntry.StartAtPage := FPageIdx;
            AddPageChange;
          end;
        end;
      end;
      case LowerCase(string(NNode.NodeName)) of
        '#text': NText := NText + UTF8Encode(NNode.TextContent);
        'br','hr': AddNText;
        'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6':
          begin
            ExamineNodes(NNode);
            AddNText;
          end
        else
          ExamineNodes(NNode);
      end;
    end;
  end;
var
  ADoc: TXMLDocument;
  BodyNode: TDOMNode;
  TOCEntry: TEPubTOCEntry;
begin
  SetLength(FPages, 1000);
  FPageIdx := 0;
  NumLines := 0;
  NText := '';
  Result := 0;
  ADoc := nil;
  try
    for Chunk := 0 to High(FChunks) do
    begin
      if Assigned(FOnUpdate) then
        FOnUpdate(Self, Chunk);
      MemStream.Clear;
      //writeln('read file');
      FZip.UnZipFile(FBaseDir + FChunks[Chunk]);
      if MemStream.Size > 0 then
      begin
        MemStream.Position := 0;
        ReadXMLFile(ADoc, MemStream);
        try
          BodyNode := ADoc.DocumentElement.FindNode('body');
          if not Assigned(BodyNode) then
            Exit;
          //
          TOCEntry := GetTOCbyID(FChunks[Chunk], '');
          if Assigned(TOCEntry) then
            TOCEntry.StartAtPage := FPageIdx;
          //
          try
            AddPageChange;
            ExamineNodes(Bodynode);
          except
            ;
          end;
        finally
          ADoc.Free;
        end;
      end;
    end;
  finally
    SetLength(FPages, FPageIdx);
    Result := FPageIdx;
  end;
end;

end.

