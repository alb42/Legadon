unit xmlhelper;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DOM;

type
  TDOMNodes = array of TDOMNode;

function FindNode(ABaseNode: TDOMNode; ANodeName: string): TDOMNode;
function FindNodes(ABaseNode: TDOMNode; ANodeName: string): TDOMNodes;

function GetIntegerAttribute(ANode: TDOMNode; AttrName: string; Def: Integer = 0): Integer;
function GetStringAttribute(ANode: TDOMNode; AttrName: string; Def: string = ''): string;


implementation

function FindNode(ABaseNode: TDOMNode; ANodeName: string): TDOMNode;
var
  i: Integer;
  ANode: TDOMNode;
begin
  Result := nil;
  if not Assigned(ABaseNode) or not ABaseNode.HasChildNodes then
    Exit;
  for i := 0 to ABaseNode.ChildNodes.Count - 1 do
  begin
    ANode := ABaseNode.ChildNodes[i];
    if Assigned(ANode) and (string(ANode.NodeName) = ANodeName) then
    begin
      Result := ANode;
      Exit;
    end;
  end;
end;

function FindNodes(ABaseNode: TDOMNode; ANodeName: string): TDOMNodes;
var
  i, Idx: Integer;
  ANode: TDOMNode;
begin
  Result := [];
  if not Assigned(ABaseNode) or not ABaseNode.HasChildNodes then
    Exit;
  for i := 0 to ABaseNode.ChildNodes.Count - 1 do
  begin
    ANode := ABaseNode.ChildNodes[i];
    if Assigned(ANode) and (string(ANode.NodeName) = ANodeName) then
    begin
      Idx := Length(Result);
      SetLength(Result, Idx + 1);
      Result[Idx] := ANode;
    end;
  end;
end;

function GetStringAttribute(ANode: TDOMNode; AttrName: string; Def: string = ''): string;
var
  AttrNode: TDOMNode;
begin
  Result := Def;
  if not Assigned(ANode) then
    Exit;
  if ANode.HasAttributes then
  begin
    AttrNode := ANode.Attributes.GetNamedItem(DOMString(AttrName));
    if Assigned(AttrNode) then
      Result := UTF8Encode(AttrNode.NodeValue);
  end;
end;

function GetIntegerAttribute(ANode: TDOMNode; AttrName: string; Def: Integer = 0): Integer;
var
  s: string;
begin
  Result := Def;
  if not Assigned(ANode) then
    Exit;
  s := GetStringAttribute(ANode, AttrName);
  if s <> '' then
  begin
    Result := StrToIntDef(s, Def);
  end;
end;

end.

