program wand;

uses
  System.SysUtils,
  bootpack in 'bootpack.pas',
  asmhead in 'asmhead.pas';

const
  MEMMAN_ADDR = $003C0000;

var
  binfo: ^TBOOTINFO = Pointer(ADR_BOOTINFO);
  screen: TScreen;
  keyboard: TKeyboard;
  keybuf: TBytes;
  i: SmallInt;
  memtest: TMemtest;
  memtotal: Cardinal;
  memman: ^TMEMMAN = Pointer(MEMMAN_ADDR);
  mem: TMem;
  sheet: TShtCtl;
  mouse, win, back: integer;

procedure window8(buf: array of Byte; xsize, ysize: integer; var title: string);
const
  closebtn: array [0 .. 14, 0 .. 15] of Char = (('0', '0', '0', '0', '0', '0',
    '0', '0', '0', '0', '0', '0', '0', '0', '0', '@'),
    ('0', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', '$',
    '@'), ('0', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q',
    '$', '@'), ('0', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q',
    'Q', '$', '@'), ('0', 'Q', 'Q', 'Q', '@', '@', 'Q', 'Q', 'Q', 'Q', '@', '@',
    'Q', 'Q', '$', '@'), ('0', 'Q', 'Q', 'Q', 'Q', '@', '@', 'Q', 'Q', '@', '@',
    'Q', 'Q', 'Q', '$', '@'), ('0', 'Q', 'Q', 'Q', 'Q', 'Q', '@', '@', '@', '@',
    'Q', 'Q', 'Q', 'Q', '$', '@'), ('0', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', '@', '@',
    'Q', 'Q', 'Q', 'Q', 'Q', '$', '@'), ('0', 'Q', 'Q', 'Q', 'Q', 'Q', '@', '@',
    '@', '@', 'Q', 'Q', 'Q', 'Q', '$', '@'), ('0', 'Q', 'Q', 'Q', 'Q', '@', '@',
    'Q', 'Q', '@', '@', 'Q', 'Q', 'Q', '$', '@'), ('0', 'Q', 'Q', 'Q', '@', '@',
    'Q', 'Q', 'Q', 'Q', '@', '@', 'Q', 'Q', '$', '@'),
    ('0', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', '$',
    '@'), ('0', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q', 'Q',
    '$', '@'), ('0', '$', '$', '$', '$', '$', '$', '$', '$', '$', '$', '$', '$',
    '$', '$', '@'), ('@', '@', '@', '@', '@', '@', '@', '@', '@', '@', '@', '@',
    '@', '@', '@', '@'));
begin

end;

begin
  screen:=TScreen.Create;
  screen.Init(binfo^.vram,binfo^.scrnx,binfo^.scrny);
  keyboard := TKeyboard.Create;
  SetLength(keybuf, 32);
  with keyboard do
  begin
    keyfifo.Init(fifo, 32, keybuf);
    while True do
    begin
      io_cli;
      if keyfifo.Status(fifo) = 0 then
        // ioshift()
      else
      begin
        i := keyfifo.Get(fifo);
        io_sti;
        // sprintf
        // boxfill8
        // putfonts8
      end;
    end;
  end;
  {
    memtest:=TMemtest.Create;
    memtotal:=memtest.memtest($00400000,$bfffffff);
    mem:=TMem.Create;
    mem.Init(memman);
    mem.memfree(memman,$00001000,$0009e000);
    mem.memfree(memman,$00400000,memtotal-$00400000);
    mem.Free;
    memtest.Free;
  }
  sheet := TShtCtl.Create;
  back := sheet.allock;
  mouse := sheet.allock;
  win := sheet.allock;
  sheet.slide(mouse, 10, 10);
  sheet.slide(win, 80, 72);
  sheet.Free;
  keyboard.Free;
  screen.Free;
end.
