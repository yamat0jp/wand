unit bootpack;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.Types,
  graphic;

type
  TBOOTINFO = record
    cyls, legs, vmode, reserve: Int8;
    scrnx, scrny: Int16;
    vram: TBytes;
  end;

  TFIFO8 = record
    buf: array of UInt32;
    p, q, size, free, flags: integer;
  end;

  TFifo = class
  private
    fifo: TFIFO8;
  public
    constructor Create(size: integer);
    destructor Destroy; override;
    function Put(data: Byte): integer;
    function Get: SmallInt;
    function Status: integer;
  end;

  TDevice = class
  const
    PORT_KEYDAT = $0060;
    PORT_KEYSTA = $0064;
    PORT_KEYCMD = $0064;
    KEYSTA_SEND_NOTREADY = $02;
    KEYCMD_WRITE_MODE = $60;
    KBC_MODE = $47;
  private
    fifo: TFifo;
    buf: array [0 .. 255] of Byte;
    procedure wait_KBC_sendready;
  public
    procedure inthandler21(var esp: integer); virtual; abstract;
  end;

  TKeyboard = class(TDevice)
  private
    keydata: integer;
  public
    constructor Create(fifo: TFifo; data0: integer);
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
  private
    mousedata: integer;
  public
    dec: TMOUSE_DEC;
    constructor Create(fifo: TFifo; data0: integer);
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

  ADR_BOOTINFO = $00000FF0;

implementation

{ TFIFO8 }

uses asmhead;

destructor TFifo.Destroy;
begin
  Finalize(fifo.buf);
  inherited;
end;

function TFifo.Get: SmallInt;
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

constructor TFifo.Create(size: integer);
begin
  inherited Create;
  SetLength(fifo.buf, size);
  fifo.size := size;
  fifo.free := size;
  fifo.flags := 0;
  fifo.p := 0;
  fifo.q := 0;
end;

function TFifo.Put(data: Byte): integer;
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

function TFifo.Status: integer;
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
  if (eflg and EFLAGS_AC_BIT) <> 0 then
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
      p^ := old;
      break;
    end;
    p^ := p^ XOR $FFFFFFFF;
    if p^ <> pat0 then
    begin
      p^ := old;
      break;
    end;
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

{ TMouse }

constructor TMouse.Create(fifo: TFifo; data0: integer);
begin
  inherited Create;
  mousedata := data0;
  Self.fifo := fifo;
  wait_KBC_sendready();
  io_out8(PORT_KEYCMD, KEYCMD_SENDTO_MOUSE);
  wait_KBC_sendready();
  io_out8(PORT_KEYDAT, MOUSECMD_ENABLE);
  dec.phase := 0;
end;

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

procedure TMouse.inthandler21(var esp: integer);
var
  i: integer;
begin
  io_out8(PIC1_OCW2, $64);
  io_out8(PIC0_OCW2, $62);
  i := io_in8(PORT_KEYDAT);
  fifo.Put(i + mousedata);
end;

{ TDevice }

procedure TDevice.wait_KBC_sendready;
begin
  while True do
    if io_in8(PORT_KEYSTA) and KEYSTA_SEND_NOTREADY = 0 then
      break;
end;

{ TKeyboard }

constructor TKeyboard.Create(fifo: TFifo; data0: integer);
begin
  inherited Create;
  Self.fifo := fifo;
  keydata := data0;
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
  fifo.Put(i + keydata);
end;

end.
