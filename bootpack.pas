unit bootpack;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.Types,
  files;

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
  TBOOTINFO = record
    cyls, leds, vmode, reserve: Int8;
    scrnx, scrny: Int16;
    vram: TBytes;
  end;

  TTimer = class
  private
    timeout: integer;
    data: integer;
    procedure settime(priority: integer);
  public
    constructor Create(data0: integer);
  end;

  TSS32 = record
    backlink, esp0, ss0, esp1, ss1, esp2, ss2, cr3: integer;
    eip, esp: Pointer;
    eflags, eax, ecx, edx, ebx, ebp, esi, edi: integer;
    es, cs, ss, ds, fs, gs: integer;
    ldtr, iomap: integer;
  end;

  TTask = class
  private
    sel, flags: integer;
    priority, level: integer;
    tss: TSS32;
    lv_change: Boolean;
  public
    constructor Create;
    procedure run(level, priority: integer);
  end;

  TIdle = class(TTask)
  public
    constructor Create;
  end;

  TFifo = class
  private
    buf: array of UInt32;
    p, q, size, space, flags: integer;
    task: TTask;
  public
    constructor Create(size: integer);
    destructor Destroy; override;
    function Put(data: integer): Boolean;
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
  public
    procedure wait_KBC_sendready;
    procedure inthandler21(var esp: integer); virtual; abstract;
  end;

  TKeyboard = class(TDevice)
  private
    keydata: integer;
    procedure make_table(const keys1, keys2: array of const);
  public
    keytable0, keytable1: array [$00 .. $80] of Byte;
    constructor Create(fifo: TFifo; data0: integer);
    procedure inthandler21(var esp: integer); override;
  end;

  TMOUSE_DEC = record
    buf: array [0 .. 2] of Byte;
    phase: Byte;
    x, y, btn: UInt32;
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

  TTaskCtl = class(TList)
    now: integer;
  end;

  TCtl = class
  private const
    MAX_TASKLEVELS = 10;
    MAX_TIMER = 500;
    procedure taskswitchsub;

  var
    list: TList;
    buf: array [0 .. MAX_TASKLEVELS - 1] of TTask;
    task: array [0 .. MAX_TASKLEVELS] of TTaskCtl;
    count: integer;
    next: integer;
    top: integer;
    now_lv: integer;
    ts: integer;
    mt_timer: TTimer;
    procedure inthandler20(var esp: integer);
  public
    fifo: TFifo;
    constructor Create(fifo: TFifo);
    destructor Destroy; override;
    function run(level, priority: integer): TTask;
    procedure remove(task: TTask);
    procedure sleep(task: TTask);
    function now: TTask;
    procedure taskswitch;
    function settime(data: integer; timeout: integer): TTimer;
  end;

  TMemtest = class
  private
    function memtest_sub(start, endpos: Cardinal): Cardinal;
  public
    function memtest(start, endpos: Cardinal): Cardinal;
  end;

  TFREEINFO = record
    addr, size: UInt32;
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
    function total(mem: TMEMMAN): UInt32;
    function alloc(mem: TMEMMAN; size: UInt32): UInt32;
    function memfree(mem: TMEMMAN; addr, size: Cardinal): integer;
  end;

  TDesk = class
  public
    constructor Create;
  end;

  TPic = class
  public
    constructor Create;
    procedure inthandler27(var esp: integer);
  end;

  TRefresh = procedure(Sender: TObject) of object;

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
    cursor_c: integer;
    cursor_x: integer;
    bxsize, bysize, vx0, vy0, col_inv, flags: integer;
    visible: Boolean;
    hankaku: TResourceStream;
    clip: TRect;
    OnRefresh: TRefresh;
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
  private
    ctl: TCtl;
    info: array of TFileInfo;
    procedure newline;
    procedure putchar(ch: Char; move: integer);
    procedure putstr0(str: string);
    procedure putstrl(str: string; length: integer);
  public
    fifo: TFifo;
    cursor_y: integer;
    files: TFiles;
    constructor Create(xsize, ysize: integer; title: string; act: integer);
    destructor Destroy; override;
    procedure cmd_ls;
    procedure cmd_type(param: string);
    procedure cmd_mem;
    procedure cmd_cls;
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
    procedure updown(sheet: TSheet; height: integer);
    procedure refresh(bx0, by0, bx1, by1: integer); overload;
    procedure refresh(Sender: TObject); overload;
    procedure slide(sheet: TSheet; x, y: integer);
    procedure delete(index: integer);
    procedure add(sheet: TSheet);
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
  ADR_IDT = $0026F800;
  LIMIT_IDT = $000007FF;
  ADR_GDT = $00270000;
  LIMIT_GDT = $0000FFFF;
  ADR_BOTPAK = $00280000;
  LIMIT_BOTPAK = $0007FFFF;
  AR_DATA32_RW = $4092;
  AR_CODE32_ER = $409A;
  AR_TSS32 = $0089;
  AR_INTGATE32 = $008E;
  ADR_DISKIMG = 0;

implementation

uses asmhead, func;

const
  PIT_CTRL = $0043;
  PIT_CNT0 = $0040;

  { TTimer }

constructor TTimer.Create(data0: integer);
begin
  inherited Create;
  io_out8(PIT_CTRL, $34);
  io_out8(PIT_CNT0, $9C);
  io_out8(PIT_CNT0, $2E);
  data := data0;
  timeout := 0;
end;

procedure TTimer.settime(priority: integer);
begin
  Self.timeout := priority;
end;

{ TTask }

constructor TTask.Create;
begin
  inherited;
  priority := 2;
  flags := 1;
  with tss do
  begin
    ldtr := 0;
    iomap := $40000000;
    eflags := $00000202;
    eax := 0;
    ecx := 0;
    edx := 0;
    ebx := 0;
    ebp := 0;
    esi := 0;
    edi := 0;
    es := 0;
    cs := 0;
    ss := 0;
    ds := 0;
    fs := 0;
    gs := 0;
  end;
end;

procedure TTask.run(level, priority: integer);
begin
  if level < 0 then
    level := Self.level;
  if priority > 0 then
    Self.priority := priority;
  if (flags = 2) and (Self.level <> level) then
    flags := 1;
  if flags <> 2 then
  begin
    Self.level := level;
    lv_change := true;
  end
  else
    lv_change := false;
end;

{ TFifo }

destructor TFifo.Destroy;
begin
  Finalize(buf);
  inherited;
end;

function TFifo.Get: SmallInt;
begin
  if space = size then
  begin
    result := -1;
    Exit;
  end;
  result := buf[q];
  inc(q);
  if q = size then
    q := 0;
  inc(space);
end;

constructor TFifo.Create(size: integer);
begin
  inherited Create;
  SetLength(buf, size);
  size := size;
  space := size;
  flags := 0;
  p := 0;
  q := 0;
end;

function TFifo.Put(data: integer): Boolean;
begin
  if space = 0 then
  begin
    flags := FLAGSOVERRUN;
    result := false;
    Exit;
  end;
  buf[p] := data;
  inc(p);
  if p = size then
    p := 0;
  dec(space);
  if (task <> nil) and (task.flags <> 2) then
    task.run(-1, 0);
  result := true;
end;

function TFifo.Status: integer;
begin
  result := size - space;
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

function TMem.alloc(mem: TMEMMAN; size: UInt32): UInt32;
var
  i: integer;
  s: TFREEINFO;
begin
  result := 0;
  for i := 0 to mem.free.count - 1 do
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
  for i := 0 to mem.free.count - 1 do
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
    mem.maxfrees := mem.free.count;
    mem.free.Insert(i, s);
  end;
end;

function TMem.total(mem: TMEMMAN): UInt32;
var
  i: integer;
begin
  result := 0;
  for i := 0 to mem.free.count - 1 do
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
  while true do
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
  io_out8(PORT_KEYDAT, KBC_MODE);
  make_table([0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '^',
    $08, 0, 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '@', '[', $0A, 0,
    'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', ':', 0, 0, ']', 'Z', 'X',
    'C', 'V', 'B', 'N', 'M', ',', '.', '/', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, '7', '8', '9', '-', '4', '5', '6', '+', '1', '2', '3',
    '0', '.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, $5C, 0, 0, 0, 0, 0, 0, 0, 0, 0, $5C, 0, 0],
    [0, 0, '!', $22, '#', '$', '%', '&', $27, '(', ')', '~', '=', '~', $08, 0,
    'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '`', '{', $0A, 0, 'A',
    'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', '+', '*', 0, 0, '}', 'Z', 'X', 'C',
    'V', 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, '7', '8', '9', '-', '4', '5', '6', '+', '1', '2', '3', '0',
    '.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, '_', 0, 0, 0, 0, 0, 0, 0, 0, 0, '|', 0, 0]);
end;

procedure TKeyboard.inthandler21(var esp: integer);
var
  i: UInt8;
begin
  io_out8(PIC0_OCW2, $61);
  i := io_in8(PORT_KEYDAT);
  fifo.Put(i + keydata);
end;

procedure TKeyboard.make_table(const keys1, keys2: array of const);
var
  i: integer;
begin
  for i := 0 to High(keys1) do
    keytable0[i] := keys1[i].VType;
  for i := 0 to High(keys2) do
    keytable1[i] := keys2[i].VType;
end;

procedure init_pit(timerctl: TCtl);
begin

end;

{ TCtl }

procedure TCtl.inthandler20(var esp: integer);
var
  i: integer;
  s: TTimer;
begin
  io_out8(PIC0_OCW2, $60);
  inc(count);
  ts := 0;
  if next > count then
    Exit;
  for i := 0 to list.count - 1 do
  begin
    s := list[i];
    if s.timeout > count then
    begin
      s.free;
      list.delete(i);
      break;
    end;
    if s <> mt_timer then
      fifo.Put(s.data)
    else
      ts := 1;
  end;
  next := TTimer(list[0]).timeout;
  if ts <> 0 then
    taskswitch;
end;

function TCtl.now: TTask;
begin
  result := task[now_lv].Items[top];
end;

procedure TCtl.remove(task: TTask);
var
  i: integer;
  j: integer;
  s: TTaskCtl;
begin
  for i := 0 to High(Self.task) do
  begin
    s := Self.task[i];
    for j := 0 to Self.task[i].count - 1 do
      if s[j] = task then
        s.delete(j);
  end;
  if s.now >= s.count then
    s.now := 0;
  task.flags := 1;
end;

function TCtl.run(level, priority: integer): TTask;
var
  i: integer;
begin
  result := nil;
  for i := 0 to High(buf) do
    if buf[i].flags = 1 then
    begin
      result := buf[i];
      break;
    end;
  if level >= 0 then
    result.level := level;
  if priority > 0 then
    result.priority := priority;
  result.flags := 2;
  task[result.level].add(result);
end;

constructor TCtl.Create(fifo: TFifo);
var
  i, j: integer;
  s, s0: TTask;
begin
  inherited Create;
  j := High(buf);
  for i := 0 to j - 1 do
    buf[i] := TTask.Create;
  buf[j] := TIdle.Create;
  s0 := buf[j];
  list := TList.Create;
  for i := 0 to High(task) do
    task[i] := TTaskCtl.Create;
  s := buf[0];
  s.flags := 2;
  s.priority := 2;
  s.level := 0;
  Self.fifo := fifo;
  fifo.task := s;
  task[s.level].add(s);
  s.tss.eip := s;
  taskswitchsub;
  load_tr(s.sel);
  mt_timer := settime(0, s.priority);
  s0.run(MAX_TASKLEVELS - 1, 1);
  task[s.level].add(s0);
end;

destructor TCtl.Destroy;
var
  i: integer;
  s: TObject;
begin
  for i := 0 to High(buf) do
    buf[i].free;
  for i := 0 to list.count - 1 do
  begin
    s := list[i];
    s.free;
  end;
  for i := 0 to High(task) do
    task[i].free;
  list.free;
  inherited;
end;

function TCtl.settime(data: integer; timeout: integer): TTimer;
var
  eflags: integer;
  s, timer: TTimer;
  i: integer;
begin
  if list.count < MAX_TIMER then
  begin
    eflags := io_load_eflags;
    io_cli;
    timer := TTimer.Create(data);
    timer.settime(timeout + count);
    result := timer;
    for i := 0 to list.count - 1 do
    begin
      s := TTimer(list[i]);
      if s.timeout >= timer.timeout then
      begin
        list.Insert(i, timer);
        next := s.timeout;
        io_store_eflags(eflags);
        Exit;
      end;
    end;
    list.add(timer);
    io_store_eflags(eflags);
  end
  else
    result := nil;
end;

procedure TCtl.sleep(task: TTask);
var
  s: TTask;
begin
  if task.flags = 2 then
  begin
    s := now;
    remove(task);
    if s = task then
    begin
      taskswitchsub;
      s := now;
      farjump(0, s.sel);
    end;
  end;
end;

procedure TCtl.taskswitch;
var
  i: integer;
  s: TTaskCtl;
  t1, t2: TTask;
  x: Boolean;
  j: integer;
begin
  x := false;
  for i := 0 to High(task) do
  begin
    s := task[i];
    for j := 0 to s.count - 1 do
    begin
      t1 := s[j];
      if t1.lv_change = true then
      begin
        t1.lv_change := false;
        t1.run(-1, 0);
        x := true;
      end;
    end;
  end;
  s := task[now_lv];
  t1 := s[s.now];
  s.now := s.now + 1;
  if s.now = s.count then
    s.now := 0;
  if x = true then
  begin
    taskswitchsub;
    s := task[now_lv];
  end;
  t2 := s[s.now];
  mt_timer.settime(t2.priority);
  if t1 <> t2 then
    farjump(0, TTask(task[top]).sel);
end;

procedure TCtl.taskswitchsub;
var
  i: integer;
begin
  for i := 0 to High(task) do
    if task[i].count > 0 then
      now_lv := i;
end;

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
  s.free;
  sheets.delete(index);
end;

destructor TShtCtl.Destroy;
begin
  screen.free;
  sheets.free;
  Finalize(vram);
  Finalize(map);
  inherited;
end;

procedure TShtCtl.add(sheet: TSheet);
begin
  sheets.add(sheet);
  sheet.OnRefresh := refresh;
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
  for i := 0 to sheets.count - 1 do
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

procedure TShtCtl.refresh(Sender: TObject);
var
  arect: TRect;
  obj: TSheet;
begin
  obj := Sender as TSheet;
  if Assigned(obj.OnRefresh) = false then
    Exit;
  arect := obj.clip;
  refresh(arect.Left + obj.vx0, arect.top + obj.vy0, arect.Right + obj.vx0,
    arect.Bottom + obj.vy0);
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
  for i := top to sheets.count - 1 do
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
  for i := 0 to sheets.count - 1 do
    if sheet = sheets[i] then
      j := i;
  if height >= sheets.count then
    height := sheets.count - 1;
  if height < -1 then
    height := -1;
  if (height >= 0) and (sheet.flags = SHEET_USE) then
    sheets.move(j, height);
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
  hankaku.free;
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
  for i := 1 to length(s) do
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
  OnRefresh(Self);
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
  tc, tbc: UInt8;
  i: Byte;
begin
  if act <> 0 then
  begin
    tc := COL8_FFFFFF;
    tbc := COL8_000084;
  end
  else
  begin
    tc := COL8_C6C6C6;
    tbc := COL8_848484;
  end;
  boxfill8(tbc, 3, 3, bxsize - 4, 20);
  putfonts8_asc(24, 4, tc, title);
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

{ TConsole }

procedure TConsole.cmd_type(param: string);
var
  buf: TBytes;
  i: integer;
begin
  i := files.search(Copy(param, 1, 5), info, 224);
  if i > -1 then
  begin
    GetMem(Pointer(buf), info[i].size);
    files.loadfile(info[i].clustno, info[i].size, buf,
      Pointer(ADR_DISKIMG + $003E00));
    putstrl(PChar(buf), info[i].size);
    FreeMem(Pointer(buf));
  end
  else
    putstr0('file not found.');
end;

procedure TConsole.cmd_cls;
begin

end;

constructor TConsole.Create(xsize, ysize: integer; title: string; act: integer);
var
  i: integer;
  s: TTask;
  cmd: string;
  str: AnsiString;
  j: integer;
begin
  inherited;
  s := ctl.now;
  fifo := TFifo.Create(128);
  fifo.task := s;
  files := TFiles.Create;
  cursor_x := 16;
  cursor_y := 28;
  cursor_c := COL8_000000;
  ctl.run(ctl.MAX_TASKLEVELS - 1, 1);
  s.tss.esp := vram;
  ctl := TCtl.Create(fifo);
  ctl.settime(0, 50);
  info := Pointer(ADR_DISKIMG + $002600);
  while true do
  begin
    io_cli;
    if fifo.Status = 0 then
    begin
      s := ctl.now;
      ctl.sleep(s);
      io_sti;
    end
    else
    begin
      i := fifo.Get;
      io_sti;
      if i <= 1 then
      begin
        if i <> 0 then
        begin
          ctl.settime(0, 50);
          cursor_c := COL8_FFFFFF;
        end
        else
        begin
          ctl.settime(1, 50);
          cursor_c := COL8_000000;
        end;
        boxfill8(cursor_c, cursor_x, 28, cursor_x + 7, 43);
        clip := rect(cursor_x, 28, cursor_x + 8, 44);
        OnRefresh(Self);
      end;
      case i of
        2:
          cursor_c := COL8_FFFFFF;
        3:
          begin
            boxfill8(COL8_000000, cursor_x, 28, cursor_x + 7, 43);
            cursor_c := -1;
          end;
      end;
      if (i >= 256) and (i <= 511) then
        if i = 8 + 256 then
        begin
          if cursor_x > 16 then
          begin
            putfonts8_asc(cursor_x, 28, 1, ' ');
            dec(cursor_x, 8);
          end;
        end
        else if i = 10 + 256 then
        begin
          putfonts8_asc_sht(cursor_x, cursor_y, ' ');
          newline;
          cmd := LowerCase(str);
          if cmd = 'mem' then
            cmd_mem
          else if cmd = 'cls' then
            cmd_cls
          else if cmd = 'ls' then
            cmd_ls
          else if cmd = 'type' then
            cmd_type(str)
          else if Length(cmd) <> 0 then;
        end
        else if cursor_x < 240 then
        begin
          cmd := LowerCase(str);
          cmd[1] := Char(i - 256);
          cmd[2] := Char(0);
          putfonts8_asc(cursor_x, 28, 1, cmd);
          inc(cursor_x, 8);
        end;
      if cursor_c >= 0 then
        boxfill8(cursor_c, cursor_x, 28, cursor_x + 7, 43);
      boxfill8(cursor_c, cursor_x, 28, cursor_x + 7, 43);
      OnRefresh(Self);
    end;
  end;
end;

destructor TConsole.Destroy;
begin
  fifo.free;
  files.free;
  ctl.free;
  inherited;
end;

procedure TConsole.cmd_ls;
var
  i: integer;
  str: string;
begin
  for i := 0 to 223 do
  begin
    case Byte(info[i].name[1]) of
      $00:
        break;
      $E5:
        if Byte(info[i].tpye) and $18 = 0 then
        begin
          str := info[i].name;
          str := str + info[i].ext;
          putfonts8_asc_sht(8, cursor_y, str);
          newline;
        end;
    end;
  end;
  newline;
end;

procedure TConsole.cmd_mem;
begin

end;

procedure TConsole.newline;
var
  i: integer;
  j: integer;
begin
  if cursor_y < 28 + 112 then
    inc(cursor_y, 15)
  else
  begin
    for i := 28 + 112 to 28 + 127 do
      for j := 8 to 8 + 239 do
        vram[j + i * bxsize] := vram[j + (i + 16) * bxsize];
    for i := 28 to 28 + 111 do
      for j := 8 to 8 + 239 do
        vram[j + i * bxsize] := COL8_000000;
    clip := rect(8, 28, 8 + 240, 128 + 28);
    OnRefresh(Self);
  end;
end;

procedure TConsole.putchar(ch: Char; move: integer);
begin
  if Byte(ch) = $09 then
    while true do
    begin
      putfonts8_asc(cursor_x, cursor_y, 1, ch);
      inc(cursor_x, 8);
      if cursor_x = 8 + 240 then
        newline
      else if cursor_x - 8 and $1F = 0 then
        break;
    end
  else if Byte(ch) = $0A then
    newline
  else if Byte(ch) = $0D then

  else
  begin
    putfonts8_asc(cursor_x, cursor_y, 1, ch);
    if move <> 0 then
    begin
      inc(cursor_x, 8);
      if cursor_x = 8 + 240 then
        newline;
    end;
  end;
end;

procedure TConsole.putstr0(str: string);
var
  i: integer;
begin
  for i := 1 to length(str) do
    putchar(str[i], 1);
end;

procedure TConsole.putstrl(str: string; length: integer);
var
  i: integer;
begin
  for i := 1 to length do
    putchar(str[i], 1);
end;

{ TIdle }

constructor TIdle.Create;
begin
  inherited;
  with tss do
  begin
    esp := Pointer(integer(Self) + SizeOf(TIdle));
    eip := Self;
    es := 1 * 8;
    cs := 2 * 8;
    ss := 1 * 8;
    ds := 1 * 8;
    fs := 1 * 8;
    gs := 1 * 8;
  end;
end;

{ TPic }

constructor TPic.Create;
begin
  io_out8(PIC0_IMR, $FF);
  io_out8(PIC1_IMR, $FF);

  io_out8(PIC0_ICW1, $11);
  io_out8(PIC0_ICW2, $20);
  io_out8(PIC0_ICW3, 1 shl 2);
  io_out8(PIC0_ICW4, $01);

  io_out8(PIC1_ICW1, $11);
  io_out8(PIC1_ICW2, $28);
  io_out8(PIC1_ICW3, 2);
  io_out8(PIC1_ICW4, $01);

  io_out8(PIC0_IMR, $FB);
  io_out8(PIC1_IMR, $FF);
end;

procedure TPic.inthandler27(var esp: integer);
begin
  io_out8(PIC0_OCW2, $67);
end;

{ TDesk }

constructor TDesk.Create;
begin

end;

end.
