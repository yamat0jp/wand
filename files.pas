unit files;

interface

uses System.SysUtils, System.Types;

type
  TFileInfo = record
    clustno: integer;
    name: string[8];
    ext: string[3];
    tpye: Byte;
    reserve: string[10];
    size: UInt32;
  end;

  TFiles = class
  private
    procedure readfat(img: TBytes);
  public
    fat: array of DWORD;
    constructor Create;
    destructor Destroy; override;
    procedure loadfile(clustno, size: integer; buf, img: TBytes);
    function search(name: string; info: array of TFileInfo;
      max: integer): integer;
  end;

implementation

{ TFiles }

uses bootpack;

constructor TFiles.Create;
begin
  inherited;
  //fat := Pointer(0);
  SetLength(fat, 4 * 2880);
  readfat(Pointer(ADR_DISKIMG + $00C200));
end;

destructor TFiles.Destroy;
begin
  Finalize(fat);
  inherited;
end;

procedure TFiles.loadfile(clustno, size: integer; buf, img: TBytes);
var
  i: integer;
begin
  while true do
  begin
    if size < 512 then
    begin
      for i := 0 to size do
        buf[i] := img[clustno * 512 + i];
      break;
    end;
    for i := 0 to 512 do
      buf[i] := img[clustno * 512 + i];
    dec(size, 512);
    inc(clustno, 512);
    clustno := fat[clustno];
  end;
end;

procedure TFiles.readfat(img: TBytes);
var
  i, j: integer;
begin
  j := 0;
  for i := 0 to 2880 do
  begin
    fat[i] := (img[j] or img[j + 1] shl 8) and $FFF;
    fat[i + 1] := (img[j + 1] shr 4 or img[j + 2] shl 4) and $FFF;
    inc(j);
  end;
end;

function TFiles.search(name: string; info: array of TFileInfo;
  max: integer): integer;
var
  i, j: integer;
  s: string;
label next;
begin
  s:='';
  j := 1;
  for i := 1 to Length(name) do
  begin
    if j > 12 then
    begin
      result := -1;
      Exit;
    end;
    if (name[i] = '.') and (j <= 8) then
    begin
      repeat
        s:=s+' ';
        inc(j);
      until j = 8;
    end
    else
    begin
      s := s + name[i];
      inc(j);
    end;
  end;
  s := UpperCase(s);
  result := -1;
  for i := 0 to max do
  begin
    if info[i].name = '' then
      break;
    if info[i].tpye and $18 = 0 then
    begin
      for j := 0 to 10 do
        if info[i].name <> s[j] then
          goto next;
      result := i;
      break;
    end;
  next:
  end;
end;

end.
