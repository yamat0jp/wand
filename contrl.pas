unit contrl;

interface

uses System.Classes, bootpack;

type
  TTimer = class
  private
    timeout: integer;
    data: integer;
    procedure settime(timeout: integer);
  public
    constructor Create(data0: integer);
  end;

  TSS32 = record
    backlink, esp0, ss0, esp1, ss1, esp2, ss2, cr3: integer;
    eip, eflags, eax, ecx, edx, ebx, esp, ebp, esi, edi: integer;
    es, cs, ss, ds, fs, gs: integer;
    ldtr, iomap: integer;
  end;

  TTask = class
  public
    sel, flags: integer;
    tss: TSS32;
    constructor Create;
  end;

  TCtl = class
  private
    list: TList;
    task: TList;
    count: integer;
    next: integer;
    top: integer;
    mt_timer: TTimer;
    ts: integer;
    procedure inthandler20(var esp: integer);
  public
    fifo: TFifo;
    constructor Create(fifo: TFifo);
    destructor Destroy; override;
    procedure run;
    procedure taskswitch;
    function settime(data: integer; timeout: integer): Boolean;
  end;

procedure init_pit(timerctl: TCtl);

implementation

uses asmhead, func;

const
  PIT_CTRL = $0043;
  PIT_CNT0 = $0040;
  MAX_TIMER = 500;

procedure init_pit(timerctl: TCtl);
begin

end;

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

procedure TTimer.settime(timeout: integer);
begin
  Self.timeout := timeout;
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
      s.Free;
      list.Delete(i);
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

procedure TCtl.run;
begin

end;

constructor TCtl.Create(fifo: TFifo);
begin
  inherited Create;
  list := TList.Create;
  task := TList.Create;
  Self.fifo := fifo;
  settime(2, 2);
  mt_timer := list[0];
end;

destructor TCtl.Destroy;
var
  i: integer;
  s: TObject;
begin
  for i := 0 to list.count - 1 do
  begin
    s := list[i];
    s.Free;
  end;
  for i := 0 to task.count - 1 do
  begin
    s := task[i];
    s.Free;
  end;
  list.Free;
  task.Free;
  inherited;
end;

function TCtl.settime(data: integer; timeout: integer): Boolean;
var
  eflags: integer;
  s, timer: TTimer;
  i: integer;
begin
  if list.count < MAX_TIMER then
  begin
    result:=true;
    eflags := io_load_eflags;
    io_cli;
    timer := TTimer.Create(data);
    timer.settime(timeout + count);
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
    list.Add(timer);
    io_store_eflags(eflags);
  end
  else
    result := false;
end;

procedure TCtl.taskswitch;
begin
  mt_timer.settime(2);
  if top >= 2 then
  begin
    inc(top);
    if top >= task.count then
      top := 0;
    farjump(0, TTask(task[top]).sel);
  end;
end;

{ TTask }

constructor TTask.Create;
var
  task_esp: integer;
begin
  with tss do
  begin
    ldtr := 0;
    iomap := $40000000;
    ldtr := 0;
    iomap := $40000000;
    set_segmdesc(gdt + 3, 103, Self, AR_TSS32);
    load_tr(3 * 8);
    task_esp := integer(Self);
    Pointer(eip) := @main;
    eflags := $00000202; // * IF = 1; */
    eax := 0;
    ecx := 0;
    edx := 0;
    ebx := 0;
    esp := task_esp;
    ebp := 0;
    esi := 0;
    edi := 0;
    es := 1 * 8;
    cs := 2 * 8;
    ss := 1 * 8;
    ds := 1 * 8;
    fs := 1 * 8;
    gs := 1 * 8;
  end;
  task_esp := sht_back - 4;
end;

end.
