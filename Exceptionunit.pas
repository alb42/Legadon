unit Exceptionunit;


interface
{$mode objfpc}
uses
  SysUtils, Classes, Exec, AmigaDOS;

type
  TDebugSymbol = record
    Name: string;
    Offset: LongWord;
  end;

  TDebugSegments = record
    Symbols: array of TDebugSymbol;
  end;

var
  CurrentSegment: Integer;
  DebugSegments: array of TDebugSegments;

var
  TrapCode: Integer;
  TrapAddress: Pointer;
  TrapSR: Word;

type
  AmigaException = class(Exception)
  end;

  TSegment = packed record
    seg_Next: BPTR;
    seg_UC: LongInt;
    seg_Seq: BPTR;
    seg_Name: array[0..3] of Char;
  end;
  PSegment = ^TSegment;

procedure LoadDebug(Filename: string);

implementation


procedure ParseSegList(SegList: Pointer; Address: Pointer; out SegIdx, SegOffset: LongInt);
var
  Base: PtrUInt;
  Len: LongWord;
  Seg, s1: PLongWord;
  Idx: Integer;
begin
  SegIdx := -1;
  //writeln('seglist at ', HexStr(SegList));
  Seg := SegList;
  Idx := 0;
  while Seg <> nil do
  begin
    //writeln(idx, '. $', HexStr(Seg), ' points to next ', HexStr(Pointer(Seg^)));
    Base := PtrUInt(Seg) + 4;
    s1 := Seg;
    Dec(S1);
    Len := S1^;
    //writeln('  length of segment: ', Len);
    if (PtrUInt(Address) >= Base) and (PtrUInt(Address) < Base + Len) then
    begin
      SegIdx := Idx;
      SegOffset := PtrUInt(Address) - PtrUInt(Base);
    end;
    Inc(Idx);
    Seg := Pointer(Seg^ shl 2);
  end;
end;


function FindSymbol1(Idx: Integer; Offset: Integer): string;
var
  SymbolIdx, SmallestDist, i, Dist: Integer;
begin
  Result := IntToStr(Offset);
  SymbolIdx := -1;
  SmallestDist := MaxInt;
  if (Idx >= 0) and (Idx < High(DebugSegments)) then
  begin
    for i := 0 to High(DebugSegments[Idx].Symbols) do
    begin
      Dist := Offset - DebugSegments[Idx].Symbols[i].Offset;
      if (Dist >= 0) and (Dist < SmallestDist) then
      begin
        SmallestDist := Dist;
        SymbolIdx := i;
        Result := DebugSegments[Idx].Symbols[SymbolIdx].Name + ' + ' + IntToStr(SmallestDist);
      end;
    end;
  end;
end;

function FindSymbol(Address: Pointer): string;
var
  p: PTask;
  cli: PCommandLineInterface;
  SegList: Pointer;
  SegOffset, SegIdx, Dist: LongInt;
  SymbolIdx, SmallestDist, i: Integer;
begin
  Result := '$' + HexStr(Address);
  //
  p := FindTask(nil);
  if (PProcess(P)^.pr_CLI <> 0) then
  begin
    writeln('ok');
    cli := Pointer(pProcess(P)^.pr_CLI shl 2);
    SegList := Pointer(cli^.cli_Module shl 2);
    ParseSegList(SegList, Address, SegIdx, SegOffset);
    writeln('SegIdx: ', SegIDx, ' ', segOffset, ' debugsegments: ', Length(DebugSegments), ' at ', HexStr(@DebugSegments));
    //
    if (SegIdx >= 0) and (SegIdx < High(DebugSegments)) then
    begin
      SymbolIdx := -1;
      SmallestDist := MaxInt;
      Result := IntToStr(SegOffset);
      for i := 0 to High(DebugSegments[SegIdx].Symbols) do
      begin
        Dist := SegOffset - DebugSegments[SegIdx].Symbols[i].Offset;
        if (Dist >= 0) and (Dist < SmallestDist) then
        begin
          SmallestDist := Dist;
          SymbolIdx := i;
          Result := DebugSegments[SegIdx].Symbols[SymbolIdx].Name + ' + ' + IntToStr(SmallestDist);
        end;
      end;
    end;
  end;
end;

function MyBackTrace(Addr: CodePointer): ShortString;
begin
  if Length(DebugSegments) = 0 then
    LoadDebug(ParamStr(0));
  Result := FindSymbol(Addr);
end;

procedure TrapAsException;
begin
  raise AmigaException.Create('Trap ' + IntToStr(TrapCode) + ' fired at ' + Trim(FindSymbol(TrapAddress)));
end;

procedure TrapHandler; assembler; nostackframe;
asm
  move.l (sp)+, TrapCode     // save TrapCode
  move.w (sp), TrapSR        // save broken SR
  move.l 2(sp), TrapAddress  // save broken Address

  move.l a0, -(sp)           // save a0
  lea TrapAsException, a0    // get my Trap Exception Handler
  move.l a0, 6(sp)           // set the Trap Exception handler (+6 becasue we saved a0 on the stack)
  move.l (sp)+, a0           // get a0 back
  rte                        // leave
end;


function ParseHunkHeader(F: BPTR): Boolean;
var
  StringLen, Dummy: LongWord;
  P: PAnsiChar;
begin
  writeln(CurrentSegment + 1, '. Hunk Header found');
  DOSRead(F, @StringLen, SizeOf(StringLen));
  while StringLen > 0 do
  begin
    P := AllocMem(StringLen * 4);
    DOSRead(F, @P, StringLen * 4);
    FreeMem(P);
    DOSRead(F, @StringLen, SizeOf(StringLen));
  end;
  DOSRead(F, @Stringlen, SizeOf(Stringlen)); // Tabsize
  DOSRead(F, @Dummy, SizeOf(Dummy)); // First
  DOSRead(F, @Dummy, SizeOf(Dummy)); // Last
  while StringLen > 0 do
  begin
    DOSRead(F, @Dummy, SizeOf(Dummy));
    StringLen := StringLen - 1;
  end;
  Result := True;
end;

function parseCodeData(F: BPTR): Boolean;
var
  Size: LongWord;
begin
  writeln(CurrentSegment + 1, '. Code/Data Hunk');
  DOSRead(F, @Size, SizeOf(Size));
  //writeln('  Size: ', Size * 4);
  DOSSeek(F, Size * 4, OFFSET_CURRENT);
  Result := True;
end;

function parseReloc32(F: BPTR): Boolean;
var
  Size: LongWord;
begin
  writeln(CurrentSegment + 1, '. Reloc32 Hunk');
  DOSRead(F, @Size, SizeOf(Size));
  while Size > 0 do
  begin
    DOSSeek(F, Size * 4, OFFSET_CURRENT);
    DOSRead(F, @Size, SizeOf(Size));
  end;
  Result := True;
end;

function ParseSymbol(F: BPTR): Boolean;
var
  StringLen, Offset: LongWord;
  Idx: Integer;
  PC: PChar;
begin
  writeln(CurrentSegment + 1, '. Symbol Hunk');
  Result := False;
  //writeln('  Offset: ', DOSSeek(F, 0, OFFSET_CURRENT));
  DOSRead(F, @StringLen, SizeOf(StringLen));
  Idx := High(DebugSegments[CurrentSegment].Symbols);
  while StringLen > 0 do
  begin
    if Idx >= Length(DebugSegments[CurrentSegment].Symbols) then
      Setlength(DebugSegments[CurrentSegment].Symbols, Idx + 100);
    //
    PC := AllocMem(StringLen * 4 + 1);
    DOSRead(F, PC, StringLen * 4);
    DebugSegments[CurrentSegment].Symbols[Idx].Name := PC;
    FreeMem(PC);
    DOSRead(F, @Offset, SizeOf(Offset));
    DebugSegments[CurrentSegment].Symbols[Idx].Offset := Offset;
    //
    Idx := Idx + 1;
    DOSRead(F, @StringLen, SizeOf(StringLen));
  end;
  SetLength(DebugSegments[CurrentSegment].Symbols, Idx);
  writeln('  found ', Idx, ' Symbols ', Length(DebugSegments), ' at ', HexStr(@DebugSegments));
  Result := True;
end;

procedure LoadDebug(Filename: string);
var
  F: BPTR;
  BlockID: LongWord;
  ok: Boolean;
begin
  F := DOSOpen(filename, MODE_OLDFILE);
  if F = 0 then
    Exit;
  SetLength(DebugSegments, 10);
  CurrentSegment := 0;

  DOSRead(F, @BlockID, SizeOf(BlockID));

  ok := (BlockID = 1011);

  while ok do
  begin
    BlockID := BlockID and $3FFFFFFF;
    //writeln('BlockID ', BlockID);
    case BlockID of
      0: ok := False;
      HUNK_END: Inc(CurrentSegment);
      HUNK_HEADER: ok := ParseHunkHeader(F);
      HUNK_CODE: ok := ParseCodeData(F);
      HUNK_DATA: ok := ParseCodeData(F);
      HUNK_BSS: DOSSeek(F, 4, OFFSET_CURRENT);
      HUNK_RELOC32: ok := ParseReloc32(f);
      HUNK_SYMBOL: ok := ParseSymbol(f);

      else
        writeln('unknown blockid ', Blockid);
        ok := False;
    end;
    if DOSRead(F, @BlockID, SizeOf(BlockID)) = 0 then
    begin
      //writeln('end of file');
      Break;
    end;

  end;
  DOSClose(F);
end;

//########### Init Trap Handler
procedure InitTrapHandler;
var
  P: PTask;
begin
  P := FindTask(nil);
  P^.tc_TrapCode := @TrapHandler;
end;


procedure MakeATrap; assembler; nostackframe;
asm
  fmove #10, fp0
  fmove #0, fp1
  fdiv fp0, fp1
  trap #6
  //trap #7
end;

procedure TestTrap;
var
  t: Single;
  i: Integer;
begin
  writeln('######### Start of Procedure ', HexStr(@MakeATrap));
  //try
    //t := 1;
    //for i := 0 to 10 do
    //  writeln('test division by zero ', t/(5-i));
    MakeATrap;
  //except
  //  on e: Exception do
  //  begin
  //    writeln('Exception called "', e.Message ,'" in ', e.UnitName)
  //  end;
  //end;
  writeln('######## End of program');
  //MakeATrap;
end;

procedure Test2;
begin
  TestTrap;
end;

procedure Test1;
begin
  test2;
end;

initialization
  BackTraceStrFunc := @MyBackTrace;
  LoadDebug(ParamStr(0));
  //InitTrapHandler;
  //Test1;
  //writeln('enter');
  //readln;
end.

