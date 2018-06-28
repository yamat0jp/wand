unit bootpack;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.Types;

type
  TBOOTINFO = record
    cyls, legs, vmode, reserve: Int8;
    scrnx, scrny: Int16;
    vram: TBytes;
  end;

  TPallet = class
  private
    // function hankaku: TBytes; external 'hankaku.bin';
  public
    procedure Init;
    procedure setp(start, endpos: integer; rgb: TBytes);
    procedure putfont8(vram: TBytes; xsize, x, y: integer; c: Int8;
      font: TBytes);
    procedure putfonts8_asc(vram: TBytes; xsize, x, y: integer; c: Int8;
      s: string);
    procedure mouse_cursor8(mouse: TBytes; bc: Int8);
  end;

  TScreen = class
  public
    procedure Init(vram: TBytes; x, y: integer);
    procedure boxfill8(vram: TBytes; xsize: integer; c: UInt8;
      x0, y0, x1, y1: integer);
  end;

  TFIFO8 = record
    buf: TBytes;
    p, q, size, free, flags: integer;
  end;

  TFifo = class
  public
    procedure Init(var fifo: TFIFO8; size: integer; buf: TBytes);
    function Put(var fifo: TFIFO8; data: Byte): integer;
    function Get(var fifo: TFIFO8): SmallInt;
    function Status(var fifo: TFIFO8): integer;
  end;

  TDevice = class
  const
    PORT_KEYDAT = $0060;
    PORT_KEYSTA = $0064;
    PORT_KEYCMD = $0064;
    KEYSTA_SEND_NOTREADY = $02;
    KEYCMD_WRITE_MODE = $60;
    KBC_MODE = $47;
  protected
    procedure wait_KBC_sendready;
  public
    fifo8: TFIFO8;
    fifo: TFifo;
    constructor Create;
    destructor Destroy; override;
    procedure Init; virtual; abstract;
    procedure inthandler21(var esp: integer); virtual; abstract;
  end;

  TKeyboard = class(TDevice)
  public
    procedure Init; override;
    procedure inthandler21(var esp: integer); override;
  end;

  TMOUSE_DEC = record
    buf: array [0 .. 2] of Byte;
    phase: Byte;
    x, y, btn: integer;
  end;

  TMouse = class(TDevice)
  const
    KEYCMD_SENDTO_MOUSE = $D4;
    MOUSECMD_ENABLE = $F4;
  public
    dec: TMOUSE_DEC;
    procedure Init; override;
    procedure enable_mouse;
    function decode(dat: UInt8): integer;
    procedure inthandler21(var esp: integer); override;
  end;

  TMemtest = class
  private
    function memtest_sub(start, endpos: Cardinal): Cardinal;
  public
    function memtest(start, endpos: Cardinal): Cardinal;
  end;

  TFREEINFO = record
    addr, size: Cardinal;
  end;

  TMEMMAN = class
  public
    frees, maxfrees, lostsize, losts: integer;
    free: TList<TFREEINFO>;
    constructor Create;
    destructor Destroy; override;
  end;

  TMem = class
  public
    procedure Init(mem: TMEMMAN);
    function total(mem: TMEMMAN): Cardinal;
    function alloc(mem: TMEMMAN; size: Cardinal): Cardinal;
    function memfree(mem: TMEMMAN; addr, size: Cardinal): integer;
  end;

  TSHEET = record
    buf: TBytes;
    bxsize, bysize, vx0, vy0, col_inv, flags: integer;
    visible: Boolean;
  end;

  TShtCtl = class
  public
    vram: TBytes;
    xsize, ysize: integer;
    sheets: TList<TSHEET>;
    constructor Create;
    destructor Destroy; override;
    procedure Init(mem: TMEMMAN; x, y: integer);
    function allock: integer;
    procedure setbuf(index: integer; buffer: TBytes;
      xsize, ysize, col_inv: integer);
    procedure updown(index, height: integer);
    procedure refresh(rect: TRect);
    procedure slide(index, x, y: integer);
    procedure delete(index: integer);
  end;

const
  FLAGSOVERRUN = $0001;

  PIC0_ICW1 = $0020;
  PIC0_OCW2 = $0020;
  PIC0_IMR = $0021;
  PIC0_ICW2 = $0021;
  PIC0_ICW3 = $0021;
  PIC0_ICW4 = $0021;
  PIC1_ICW1 = $00A0;
  PIC1_OCW2 = $00A0;
  PIC1_IMR = $00A1;
  PIC1_ICW2 = $00A1;
  PIC1_ICW3 = $00A1;
  PIC1_ICW4 = $00A1;

  COL8_000000: Int8 = 0;
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

  ADR_BOOTINFO = $00000FF0;

implementation

{ TFIFO8 }

uses asmhead;

function TFifo.Get(var fifo: TFIFO8): SmallInt;
begin
  if fifo.free = fifo.size then
  begin
    result := -1;
    Exit;
  end;
  result := fifo.buf[fifo.q];
  inc(fifo.q);
  if fifo.q = fifo.size then
    fifo.q := 0;
  inc(fifo.free);
end;

procedure TFifo.Init(var fifo: TFIFO8; size: integer; buf: TBytes);
begin
  fifo.size := size;
  fifo.buf := buf;
  fifo.free := size;
  fifo.flags := 0;
  fifo.p := 0;
  fifo.q := 0;
end;

function TFifo.Put(var fifo: TFIFO8; data: Byte): integer;
begin
  if fifo.free = 0 then
  begin
    fifo.flags := FLAGSOVERRUN;
    result := -1;
    Exit;
  end;
  fifo.buf[fifo.p] := data;
  inc(fifo.p);
  if fifo.p = fifo.size then
    fifo.p := 0;
  dec(fifo.free);
  result := 0;
end;

function TFifo.Status(var fifo: TFIFO8): integer;
begin
  result := fifo.size - fifo.free;
end;

{ TMemtest }

function TMemtest.memtest(start, endpos: Cardinal): Cardinal;
const
  EFLAGS_AC_BIT = $00040000;
  CR0_CASH_DISABLE = $60000000;
var
  flag486: UInt8;
  eflg, cr0: UInt32;
begin
  flag486 := 0;
  eflg := io_load_eflags;
  eflg := eflg or EFLAGS_AC_BIT;
  io_store_eflags(eflg);
  eflg := io_load_eflags();
  if eflg and EFLAGS_AC_BIT <> 0 then
    flag486 := 1;
  eflg := eflg and EFLAGS_AC_BIT;
  io_store_eflags(eflg);
  if flag486 <> 0 then
  begin
    cr0 := load_cr0();
    cr0 := cr0 or CR0_CASH_DISABLE;
    store_cr0(cr0);
  end;
  result := memtest_sub(start, endpos);
  if flag486 <> 0 then
  begin
    cr0 := load_cr0();
    cr0 := cr0 and CR0_CASH_DISABLE;
    store_cr0(cr0);
  end;
end;

function TMemtest.memtest_sub(start, endpos: Cardinal): Cardinal;
const
  pat0 = $AA55AA55;
  pat1 = $55AA55AA;
var
  i, old: UInt32;
  p: ^UInt32;
label not_memory;
begin
  i := start;
  while i <= endpos do
  begin
    p := Pointer(i + $FFC);
    old := p^;
    p^ := pat0;
    p^ := p^ XOR $FFFFFFFF;
    if p^ <> pat1 then
    begin
    not_memory:
      p^ := old;
      break;
    end;
    p^ := p^ XOR $FFFFFFFF;
    if p^ <> pat0 then
      goto not_memory;
    p^ := old;
    inc(i, $1000);
  end;
  result := i;
end;

{ TMem }

function TMem.alloc(mem: TMEMMAN; size: Cardinal): Cardinal;
var
  i: integer;
  s: TFREEINFO;
begin
  result := 0;
  for i := 0 to mem.free.Count - 1 do
    if mem.free[i].size >= size then
    begin
      s := mem.free[i];
      result := s.addr;
      inc(s.addr, size);
      dec(s.size, size);
      if s.size = 0 then
        mem.free.delete(i)
      else
        mem.free[i] := s;
      break;
    end;
end;

procedure TMem.Init(mem: TMEMMAN);
begin
  mem.free.Clear;
  mem.maxfrees := 0;
  mem.lostsize := 0;
  mem.losts := 0;
end;

function TMem.memfree(mem: TMEMMAN; addr, size: Cardinal): integer;
var
  i, j: integer;
  s: TFREEINFO;
begin
  j := 0;
  for i := 0 to mem.free.Count - 1 do
    if mem.free[i].addr > addr then
    begin
      j := i;
      break;
    end;
  if i > 0 then
    if mem.free[i - 1].addr + mem.free[i - 1].size = addr then
    begin
      s := mem.free[i - 1];
      inc(s.size, size);
      if addr + size = s.addr then
      begin
        inc(s.size, mem.free[i].size);
        mem.free.delete(i);
      end;
      mem.free[i - 1] := s;
      result := 0;
      Exit;
    end;
  if addr + size = mem.free[i].addr then
  begin
    s := mem.free[i];
    s.addr := addr;
    inc(s.size, size);
    mem.free[i] := s;
  end
  else
  begin
    s.addr := addr;
    s.size := size;
    mem.maxfrees := mem.free.Count;
    mem.free.Insert(i, s);
  end;
end;

function TMem.total(mem: TMEMMAN): Cardinal;
var
  i: integer;
begin
  result := 0;
  for i := 0 to mem.free.Count - 1 do
    inc(result, mem.free[i].size);
end;

{ TMEMMAN }

constructor TMEMMAN.Create;
begin
  inherited;
  free := TList<TFREEINFO>.Create;
end;

destructor TMEMMAN.Destroy;
begin
  free.free;
  inherited;
end;

{ TShtCtl }

constructor TShtCtl.Create;
begin
  sheets := TList<TSHEET>.Create;
end;

procedure TShtCtl.delete(index: integer);
begin
  sheets.delete(index);
end;

destructor TShtCtl.Destroy;
begin
  sheets.free;
  inherited;
end;

function TShtCtl.allock: integer;
const
  SHEET_USE = 1;
var
  s: TSHEET;
begin
  s.flags := SHEET_USE;
  s.visible := True;
  result := sheets.Add(s);
end;

procedure TShtCtl.Init(mem: TMEMMAN; x, y: integer);
begin
  xsize := x;
  ysize := y;
  sheets.Clear;
end;

procedure TShtCtl.refresh(rect: TRect);
var
  i: integer;
  x: integer;
  y: integer;
  vx, vy: integer;
  c: Byte;
  clip: TRect;
begin
  if rect.Left < 0 then
    rect.Left := 0;
  if rect.Right >= xsize then
    rect.Right := xsize;
  if rect.Top < 0 then
    rect.Top := 0;
  if rect.Bottom >= ysize then
    rect.Bottom := ysize;
  for i := 0 to sheets.Count - 1 do
    with sheets[i] do
    begin
      clip.Left := rect.Left - vx0;
      clip.Right := rect.Right - vx0;
      clip.Top := rect.Top - vy0;
      clip.Bottom := rect.Bottom - vy0;
      if clip.Left < 0 then
        clip.Left := 0;
      if clip.Right > bxsize then
        clip.Right := bxsize;
      if clip.Top < 0 then
        clip.Top := 0;
      if clip.Bottom > bysize then
        clip.Bottom := bysize;
      for y := clip.Top to clip.Bottom - 1 do
      begin
        vy := vy0 + y;
        for x := clip.Left to clip.Right - 1 do
        begin
          vx := vx0 + x;
          c := buf[y * bxsize + x];
          if c <> col_inv then
            vram[vy * xsize + vx] := c;
        end;
      end;
    end;
end;

procedure TShtCtl.setbuf(index: integer; buffer: TBytes;
  xsize, ysize, col_inv: integer);
var
  s: TSHEET;
begin
  s.buf := buffer;
  s.bxsize := xsize;
  s.bysize := ysize;
  s.col_inv := col_inv;
  sheets[index] := s;
end;

procedure TShtCtl.slide(index, x, y: integer);
var
  i, j: integer;
  p: ^TSHEET;
begin
  p := TList(sheets)[index];
  with p^ do
  begin
    i := vx0;
    j := vy0;
    vx0 := x;
    vy0 := y;
    if visible = True then
    begin
      refresh(rect(i, j, i + bxsize, j + bysize));
      refresh(rect(x, y, x + bxsize, y + bysize));
    end;
  end;
end;

procedure TShtCtl.updown(index, height: integer);
var
  p: ^TSHEET;
begin
  if height >= sheets.Count then
    height := sheets.Count - 1;
  if height < -1 then
    height := -1;
  if height >= 0 then
  begin
    sheets.Move(index, height);
    if sheets[height].visible = false then
    begin
      p := TList(sheets)[height];
      p^.visible := True;
    end;
  end
  else
  begin
    p := TList(sheets)[index];
    p^.visible := false;
  end;
end;

{ TPallet }

procedure TPallet.Init;
const
  table: array [0 .. 14, 0 .. 2] of Byte = (($00, $00, $00), ($FF, $00, $00),
    ($00, $FF, $00), ($FF, $FF, $00), ($00, $00, $FF), ($FF, $00, $FF),
    ($00, $FF, $FF), ($C6, $C6, $C6), ($84, $00, $00), ($00, $84, $00),
    ($84, $84, $00), ($00, $00, $84), ($84, $00, $84), ($00, $84, $84),
    ($84, $84, $84));
begin
  setp(0, 15, @table);
end;

procedure TPallet.mouse_cursor8(mouse: TBytes; bc: Int8);
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
  x: integer;
  y: integer;
begin
  for y := 0 to 15 do
    for x := 0 to 15 do
      case cursor[y][x] of // x , y ?
        '*':
          mouse[y * 16 + x] := COL8_000000;
        '0':
          mouse[y * 16 + x] := COL8_FFFFFF;
        '.':
          mouse[y * 16 + x] := bc;
      end;
end;

procedure TPallet.putfont8(vram: TBytes; xsize, x, y: integer; c: Int8;
  font: TBytes);
var
  i: integer;
  p: TBytes;
  d: Byte;
begin
  for i := 0 to 16 do
  begin
    p := @vram[(y + i) * xsize + x];
    d := font[i];
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

procedure TPallet.putfonts8_asc(vram: TBytes; xsize, x, y: integer; c: Int8;
  s: string);
var
  hankaku: TMemoryStream;
  buf: TBytes;
  i: integer;
begin
  s:=LowerCase(s);
  hankaku := TMemoryStream.Create;
  try
    hankaku.LoadFromFile('hankaku.bin');
    SetLength(buf, 16);
    for i := 1 to Length(s) do
    begin
      hankaku.Write(buf, Ord(s[i]), 16);
      putfont8(vram, xsize, x, y, c, buf);
      inc(x, 8);
    end;
  finally
    Finalize(buf);
    hankaku.free;
  end;
end;

procedure TPallet.setp(start, endpos: integer; rgb: TBytes);
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

procedure TScreen.boxfill8(vram: TBytes; xsize: integer; c: UInt8;
  x0, y0, x1, y1: integer);
var
  y: integer;
  x: integer;
begin
  for y := y0 to y1 do
    for x := x0 to x1 do
      vram[y * xsize + x] := c;
end;

procedure TScreen.Init(vram: TBytes; x, y: integer);
begin
  boxfill8(vram, x, COL8_008484, 0, 0, x - 1, y - 29);
  boxfill8(vram, x, COL8_C6C6C6, 0, y - 28, x - 1, y - 28);
  boxfill8(vram, x, COL8_FFFFFF, 0, y - 27, x - 1, y - 27);
  boxfill8(vram, x, COL8_C6C6C6, 0, y - 26, x - 1, y - 1);

  boxfill8(vram, x, COL8_FFFFFF, 3, y - 24, 59, y - 24);
  boxfill8(vram, x, COL8_FFFFFF, 2, y - 24, 2, y - 4);
  boxfill8(vram, x, COL8_848484, 3, y - 4, 59, y - 4);
  boxfill8(vram, x, COL8_848484, 59, y - 23, 59, y - 5);
  boxfill8(vram, x, COL8_000000, 2, y - 3, 59, y - 3);
  boxfill8(vram, x, COL8_000000, 60, y - 24, 60, y - 3);

  boxfill8(vram, x, COL8_848484, x - 47, y - 24, x - 4, y - 24);
  boxfill8(vram, x, COL8_848484, x - 47, y - 23, x - 47, y - 4);
  boxfill8(vram, x, COL8_FFFFFF, x - 47, y - 3, x - 4, y - 3);
  boxfill8(vram, x, COL8_FFFFFF, x - 3, y - 24, x - 3, y - 3);
end;

{ TMouse }

function TMouse.decode(dat: UInt8): integer;
begin
  result := 0;
  case dec.phase of
    0:
      if dat = $FA then
        with dec do
          phase := 1;
    1:
      if (dat and $CB) = $08 then
        with dec do
        begin
          buf[0] := dat;
          phase := 2;
        end;
    2:
      with dec do
      begin
        buf[1] := dat;
        phase := 3;
      end;
    3:
      begin
        with dec do
        begin
          buf[2] := dat;
          phase := 1;
          btn := dec.buf[0] and $07;
          x := dec.buf[1];
          y := dec.buf[2];
          if (buf[0] and $10) <> 0 then
            x := x or $FFFFFF00;
          if (buf[0] and $20) <> 0 then
            y := y or $FFFFFF00;
          y := -y;
        end;
        result := 1;
      end;
  else
    result := -1;
  end;
end;

procedure TMouse.enable_mouse;
begin
  wait_KBC_sendready;
  io_out8(PORT_KEYCMD, KEYCMD_SENDTO_MOUSE);
  wait_KBC_sendready;
  io_out8(PORT_KEYDAT, MOUSECMD_ENABLE);
  dec.phase := 0;
end;

procedure TMouse.Init;
begin

end;

procedure TMouse.inthandler21(var esp: integer);
var
  i: integer;
begin
  io_out8(PIC1_OCW2, $64);
  io_out8(PIC0_OCW2, $62);
  i := io_in8(PORT_KEYDAT);
  fifo.Put(fifo8, i);
end;

{ TDevice }

constructor TDevice.Create;
begin
  inherited;
  fifo := TFifo.Create;
end;

destructor TDevice.Destroy;
begin
  fifo.free;
  inherited;
end;

procedure TDevice.wait_KBC_sendready;
begin
  while True do
    if io_in8(PORT_KEYSTA) and KEYSTA_SEND_NOTREADY = 0 then
      break;
end;

{ TKeyboard }

procedure TKeyboard.Init;
begin
  wait_KBC_sendready;
  io_out8(PORT_KEYCMD, KEYCMD_WRITE_MODE);
  wait_KBC_sendready;
  io_out8(PORT_KEYDAT, KBC_MODE)
end;

procedure TKeyboard.inthandler21(var esp: integer);
var
  i: UInt8;
begin
  io_out8(PIC0_OCW2, $61);
  i := io_in8(PORT_KEYDAT);
  fifo.Put(fifo8, i);
end;

end.
