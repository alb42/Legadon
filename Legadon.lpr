program Legadon;

uses
  SysUtils,
  MUIClass.Base,
  mainwinunit, waitunit;

const
  VERSION = '$VER: Legadon 0.2 (23.10.2024)';

begin
  TMainWindow.Create;
  WaitWindow := TWaitWindow.Create;

  MUIApp.Author := 'Marcus "ALB42" Sackrow';
  MUIApp.Description := 'ePub Reader for Amiga';
  MUIApp.Version := Copy(VERSION, 7);
  MUIApp.Title := 'Legadon';
  MUIApp.Base := 'LEGADON';

  MUIApp.Run;

end.

