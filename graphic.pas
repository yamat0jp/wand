unit graphic;

interface

uses System.Classes, System.SysUtils, System.Types;

const
  COL8_000000 = 0;
  COL8_FF0000 = 1;
  COL8_00FF00 = 2;
  COL8_FFFF00 = 3;
  COL8_0000FF = 4;
  COL8_FF00FF = 5;
  COL8_00FFFF = 6;
  COL8_FFFFFF = 7;
  COL8_C6C6C6 = 8;
  COL8_840000 = 9;
  COL8_008400 = 10;
  COL8_848400 = 11;
  COL8_000084 = 12;
  COL8_840084 = 13;
  COL8_008484 = 14;
  COL8_848484 = 15;

type
  TSheet = class
  private const
    table: array [0 .. 14, 0 .. 2] of Byte = (($00, $00, $00), ($FF, $00, $00),
      ($00, $FF, $00), ($FF, $FF, $00), ($00, $00, $FF), ($FF, $00, $FF),
      ($00, $FF, $FF), ($C6, $C6, $C6), ($84, $00, $00), ($00, $84, $00),
      ($84, $84, $00), ($00, $00, $84), ($84, $00, $84), ($00, $84, $84),
      ($84, $84, $84));

  var
    vram: TBytes;
    procedure putfont8(x, y: integer; c: Int8; font: PChar);
    procedure putfonts8_asc(x, y: integer; c: Int8; s: string);
  public
    bxsize, bysize, vx0, vy0, col_inv, flags: integer;
    visible: Boolean;
    hankaku: TResourceStream;
    refresh: Boolean;
    clip: TRect;
    constructor Create(x, y, act: integer);
    destructor Destroy; override;
    procedure boxfill8(c: UInt8; x0, y0, x1, y1: integer); overload;
    procedure boxfill8(c: UInt8; rect: TRect); overload;
    procedure setp(start, endpos: integer; rgb: TBytes);
    procedure putfonts8_asc_sht(x, y: integer; font: string;
      const back: integer = COL8_000000; const color: integer = COL8_FFFFFF);
  end;

  TCursor = class(TSheet)
  public
    constructor Create(x, y, act: integer);
  end;

  TScreen = class(TSheet)
  public
    constructor Create(x, y, act: integer);
  end;

  TWindow = class(TScreen)
  private
    procedure wintitl(title: string; act: integer);
  public
    constructor Create(xsize, ysize: integer; title: string; act: integer);
  end;

  TConsole = class(TWindow)
  public
  end;

  TShtCtl = class
  private const
    SHEET_USE = 1;
    procedure refreshmap(arect: TRect);
    procedure refreshsub(arect: TRect);
  public
    vram, map: TBytes;
    col_inv: integer;
    xsize, ysize: integer;
    top: integer;
    sheets: TList;
    screen: TScreen;
    constructor Create(x, y: integer);
    destructor Destroy; override;
    procedure setbuf(index: integer; buffer: TBytes;
      xsize, ysize, col_inv: integer);
    procedure updown(sheet: TSheet; height: integer);
    procedure refresh(bx0, by0, bx1, by1: integer);
    procedure slide(sheet: TSheet; x, y: integer);
    procedure delete(index: integer);
    procedure add(sheet: TSheet);
  end;

implementation

uses asmhead;

{ TShtCtl }

constructor TShtCtl.Create(x, y: integer);
begin
  sheets := TList.Create;
  SetLength(vram, x * y);
  SetLength(map, x * y);
  add(TScreen.Create(x, y, -1));
end;

procedure TShtCtl.delete(index: integer);
var
  s: TSheet;
begin
  s := sheets[index];
  s.Free;
  sheets.delete(index);
end;

destructor TShtCtl.Destroy;
begin
  screen.Free;
  sheets.Free;
  Finalize(vram);
  Finalize(map);
  inherited;
end;

procedure TShtCtl.add(sheet: TSheet);
begin
  sheets.add(sheet);
  sheet.flags := SHEET_USE;
end;

procedure TShtCtl.refresh(bx0, by0, bx1, by1: integer);
var
  i: integer;
  arect: TRect;
  s: TSheet;
begin
  arect := rect(bx0, by0, bx1, by1);
  if arect.Left < 0 then
    arect.Left := 0;
  if arect.Right >= xsize then
    arect.Right := xsize;
  if arect.top < 0 then
    arect.top := 0;
  if arect.Bottom >= ysize then
    arect.Bottom := ysize;
  for i := 0 to sheets.Count - 1 do
  begin
    s := TSheet(sheets[i]);
    arect.Left := arect.Left - s.vx0;
    arect.Right := arect.Right - s.vx0;
    arect.top := arect.top - s.vy0;
    arect.Bottom := arect.Bottom - s.vy0;
    if arect.Left < 0 then
      arect.Left := 0;
    if arect.Right > xsize then
      arect.Right := xsize;
    if arect.top < 0 then
      arect.top := 0;
    if arect.Bottom > ysize then
      arect.Bottom := ysize;
    refreshmap(arect);
    refreshsub(arect);
  end;
end;

procedure TShtCtl.refreshmap(arect: TRect);
var
  i: integer;
  s: TSheet;
  x: integer;
  y: integer;
  bx0, by0, bx1, by1, vx, vy: integer;
begin
  if arect.Left < 0 then
    arect.Left := 0;
  if arect.Right > xsize then
    arect.Right := xsize;
  if arect.top < 0 then
    arect.top := 0;
  if arect.Bottom > ysize then
    arect.Bottom := ysize;
  for i := top to sheets.Count - 1 do
  begin
    s := TSheet(sheets[i]);
    if arect.Left < s.vx0 then
      bx0 := 0
    else
      bx0 := arect.Left;
    if arect.Right > s.vx0 + s.bxsize then
      bx1 := s.bxsize
    else
      bx1 := arect.Right;
    if arect.top < s.vy0 then
      by0 := 0
    else
      by0 := arect.top;
    if arect.Bottom > s.bysize then
      by1 := s.bysize
    else
      by1 := arect.Bottom;
    for y := by0 to by1 do
    begin
      vy := s.vy0 + y;
      for x := bx0 to bx1 do
      begin
        vx := s.vx0 + x;
        if s.vram[y * s.bxsize + x] <> s.col_inv then
          vram[vy * xsize + vx] := s.col_inv;
      end;
    end;
  end;
end;

procedure TShtCtl.refreshsub(arect: TRect);
var
  x, y, vx, vy: integer;
  c: integer;
  s: TSheet;
begin
  c := -1;
  s := nil;
  for y := arect.top to arect.Bottom do
    for x := arect.Left to arect.Right do
    begin
      if c <> map[y * xsize + y] then
      begin
        c := map[y * xsize + x];
        s := sheets[c];
      end;
      vx := x - s.vx0;
      vy := y - s.vy0;
      vram[y * xsize + x] := s.vram[vy * s.bxsize + vx];
    end;
end;

procedure TShtCtl.setbuf(index: integer; buffer: TBytes;
  xsize, ysize, col_inv: integer);
begin
  sheets.add(TSheet.Create(xsize, ysize, col_inv));
end;

procedure TShtCtl.slide(sheet: TSheet; x, y: integer);
var
  i, j: integer;
begin
  i := sheet.vx0;
  j := sheet.vy0;
  sheet.vx0 := x;
  sheet.vy0 := y;
  if sheet.flags = SHEET_USE then
  begin
    refresh(i, j, i + sheet.bxsize, j + sheet.bysize);
    refresh(x, y, x + sheet.bxsize, y + sheet.bysize);
  end;
end;

procedure TShtCtl.updown(sheet: TSheet; height: integer);
var
  i, j: integer;
begin
  j := -1;
  for i := 0 to sheets.Count - 1 do
    if sheet = sheets[i] then
      j := i;
  if height >= sheets.Count then
    height := sheets.Count - 1;
  if height < -1 then
    height := -1;
  if (height >= 0) and (sheet.flags = SHEET_USE) then
    sheets.Move(j, height);
end;

{ TPallet }

procedure TSheet.boxfill8(c: UInt8; x0, y0, x1, y1: integer);
begin
  clip := rect(x0, y0, x1, y1);
  boxfill8(c, clip);
end;

procedure TSheet.boxfill8(c: UInt8; rect: TRect);
var
  x: integer;
  y: integer;
begin
  for y := rect.top to rect.Bottom do
    for x := rect.Left to rect.Right do
      vram[y * bxsize + x] := c;
end;

constructor TSheet.Create(x, y, act: integer);
begin
  inherited Create;
  bxsize := x;
  SetLength(vram, x * y);
  setp(0, 15, TBytes(@table));
  hankaku := TResourceStream.Create(HInstance, 'hankaku', RT_RCDATA);
end;

destructor TSheet.Destroy;
begin
  hankaku.Free;
  Finalize(vram);
  inherited;
end;

procedure TSheet.putfont8(x, y: integer; c: Int8; font: PChar);
var
  i: integer;
  p: TBytes;
  d: Byte;
begin
  for i := 0 to 16 do
  begin
    p := TBytes(@vram[(y + i) * bxsize + x]);
    d := Byte(font[i]);
    if d and $80 <> 0 then
      p[0] := c;
    if d and $40 <> 0 then
      p[1] := c;
    if d and $20 <> 0 then
      p[2] := c;
    if d and $10 <> 0 then
      p[3] := c;
    if d and $08 <> 0 then
      p[4] := c;
    if d and $04 <> 0 then
      p[5] := c;
    if d and $02 <> 0 then
      p[6] := c;
    if d and $01 <> 0 then
      p[7] := c;
  end;
end;

procedure TSheet.putfonts8_asc(x, y: integer; c: Int8; s: string);
var
  i: integer;
  buf: array [0 .. 15] of Byte;
begin
  s := LowerCase(s);
  for i := 1 to Length(s) do
  begin
    hankaku.Write(TBytes(@buf), Ord(s[i]), 16);
    putfont8(x, y, c, PChar(@buf));
    inc(x, 8);
  end;
end;

procedure TSheet.putfonts8_asc_sht(x, y: integer; font: string;
  const back: integer = COL8_000000; const color: integer = COL8_FFFFFF);
begin
  clip := rect(x, y, x + bxsize * 8 - 1, y + 15);
  boxfill8(back, clip);
  putfonts8_asc(x, y, color, font);
  refresh := True;
end;

procedure TSheet.setp(start, endpos: integer; rgb: TBytes);
var
  eflags: integer;
  i, j: integer;
begin
  eflags := io_load_eflags;
  io_cli;
  io_out8($03C8, start);
  j := 0;
  for i := start to endpos - 1 do
  begin
    io_out8($03C9, rgb[j + 0] div 4);
    io_out8($03C9, rgb[j + 1] div 4);
    io_out8($03C9, rgb[j + 2] div 4);
    inc(j, 3);
  end;
  io_store_eflags(eflags);
end;

{ TScreen }

constructor TScreen.Create(x, y, act: integer);
begin
  inherited;
  boxfill8(COL8_008484, 0, 0, x - 1, y - 29);
  boxfill8(COL8_C6C6C6, 0, y - 28, x - 1, y - 28);
  boxfill8(COL8_FFFFFF, 0, y - 27, x - 1, y - 27);
  boxfill8(COL8_C6C6C6, 0, y - 26, x - 1, y - 1);

  boxfill8(COL8_FFFFFF, 3, y - 24, 59, y - 24);
  boxfill8(COL8_FFFFFF, 2, y - 24, 2, y - 4);
  boxfill8(COL8_848484, 3, y - 4, 59, y - 4);
  boxfill8(COL8_848484, 59, y - 23, 59, y - 5);
  boxfill8(COL8_000000, 2, y - 3, 59, y - 3);
  boxfill8(COL8_000000, 60, y - 24, 60, y - 3);

  boxfill8(COL8_848484, x - 47, y - 24, x - 4, y - 24);
  boxfill8(COL8_848484, x - 47, y - 23, x - 47, y - 4);
  boxfill8(COL8_FFFFFF, x - 47, y - 3, x - 4, y - 3);
  boxfill8(COL8_FFFFFF, x - 3, y - 24, x - 3, y - 3);
end;

{ TWindow }

constructor TWindow.Create(xsize, ysize: integer; title: string; act: integer);
begin
  inherited Create(xsize, ysize, act);
  putfonts8_asc(24, 4, COL8_FFFFFF, title);
  boxfill8(COL8_C6C6C6, 0, 0, xsize - 1, 0);
  boxfill8(COL8_FFFFFF, 1, 1, xsize - 2, 1);
  boxfill8(COL8_C6C6C6, 0, 0, 0, ysize - 1);
  boxfill8(COL8_FFFFFF, 1, 1, 1, ysize - 2);
  boxfill8(COL8_848484, xsize - 2, 1, xsize - 2, ysize - 2);
  boxfill8(COL8_000000, xsize - 1, 0, xsize - 1, ysize - 1);
  boxfill8(COL8_C6C6C6, 2, 2, xsize - 3, ysize - 3);
  boxfill8(COL8_000084, 3, 3, xsize - 4, 20);
  boxfill8(COL8_848484, 1, ysize - 2, xsize - 2, ysize - 2);
  boxfill8(COL8_000000, 0, ysize - 1, xsize - 1, ysize - 1);
  wintitl(title, act);
end;

procedure TWindow.wintitl(title: string; act: integer);
const
  closebtn: array [0 .. 14] of string[16] = ( //
    ('000000000000000@'), //
    ('0QQQQQQQQQQQQQ$@'), //
    ('0QQQQQQQQQQQQQ$@'), //
    ('0QQQQQQQQQQQQQ$@'), //
    ('0QQQ@@QQQQ@@QQ$@'), //
    ('0QQQQ@@QQ@@QQQ$@'), //
    ('0QQQQQ@@@@QQQQ$@'), //
    ('0QQQQQQ@@QQQQQ$@'), //
    ('0QQQQQ@@@@QQQQ$@'), //
    ('00QQQ@@QQ@@QQQ$@'), //
    ('0QQQ@@QQQQ@@QQ$@'), //
    ('0QQQQQQQQQQQQQ$@'), //
    ('0QQQQQQQQQQQQQ$@'), //
    ('0$$$$$$$$$$$$$$@'), //
    ('@@@@@@@@@@@@@@@@') //
    );
var
  y: integer;
  x: integer;
  c: AnsiChar;
  i: Byte;
begin
  for y := 0 to 14 do
    for x := 1 to 16 do
    begin
      c := closebtn[y][x];
      case c of
        '@':
          i := COL8_000000;
        '$':
          i := COL8_848484;
        '0':
          i := COL8_C6C6C6;
      else
        i := COL8_FFFFFF;
      end;
      vram[(5 + y) * bxsize + (bxsize - 21 + x)] := i;
    end;
end;

{ TCursor }

constructor TCursor.Create(x, y, act: integer);
const
  cursor: array [0 .. 15] of string[16] = ( //
    ('**************..'), //
    ('*00000000000*...'), //
    ('*0000000000*....'), //
    ('*000000000*.....'), //
    ('*00000000*......'), //
    ('*0000000*.......'), //
    ('*0000000*.......'), //
    ('*00000000*......'), //
    ('*0000**000*.....'), //
    ('*000*..*000*....'), //
    ('*00*....*000*...'), //
    ('*0*......*000*..'), //
    ('**........*000*.'), //
    ('*..........*000*'), //
    ('............*00*'), //
    ('.............***') //
    );
var
  i: integer;
  j: integer;
begin
  inherited;
  for j := 0 to y do
    for i := 0 to x do
      case cursor[j, i] of // x , y ?
        '*':
          vram[j * 16 + i] := COL8_000000;
        '0':
          vram[j * 16 + i] := COL8_FFFFFF;
        '.':
          vram[j * 16 + i] := act;
      end;
end;

end.
