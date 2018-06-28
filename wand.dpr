program wand;

uses
  System.SysUtils,
  System.Classes,
  bootpack in 'bootpack.pas',
  asmhead in 'asmhead.pas';

const
  MEMMAN_ADDR = $003C0000;

var
  binfo: ^TBOOTINFO = Pointer(ADR_BOOTINFO);
  screen: TScreen;
  font: TPallet;
  mousefifo: TMouse;
  keyboard: TKeyboard;
  i: SmallInt;
  memtest: TMemtest;
  memtotal: Cardinal;
  memman: ^TMEMMAN = Pointer(MEMMAN_ADDR);
  mem: TMem;
  sheet: TShtCtl;
  mouse, win, back: integer;
  s: string[40];
  buf_win, buf_back, keybuf, buf_mouse: TBytes;
  mx, my: integer;

procedure window8(buf: TBytes; xsize, ysize: integer; title: PAnsiChar);
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
  with screen do
  begin
    boxfill8(buf, xsize, COL8_C6C6C6, 0, 0, xsize - 1, 0);
    boxfill8(buf, xsize, COL8_FFFFFF, 1, 1, xsize - 2, 1);
    boxfill8(buf, xsize, COL8_C6C6C6, 0, 0, 0, ysize - 1);
    boxfill8(buf, xsize, COL8_FFFFFF, 1, 1, 1, ysize - 2);
    boxfill8(buf, xsize, COL8_848484, xsize - 2, 1, xsize - 2, ysize - 2);
    boxfill8(buf, xsize, COL8_000000, xsize - 1, 0, xsize - 1, ysize - 1);
    boxfill8(buf, xsize, COL8_C6C6C6, 2, 2, xsize - 3, ysize - 3);
    boxfill8(buf, xsize, COL8_000084, 3, 3, xsize - 4, 20);
    boxfill8(buf, xsize, COL8_848484, 1, ysize - 2, xsize - 2, ysize - 2);
    boxfill8(buf, xsize, COL8_000000, 0, ysize - 1, xsize - 1, ysize - 1);
  end;
  font.putfonts8_asc(buf, xsize, 24, 4, COL8_FFFFFF, title);
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
      buf[(5 + y) * xsize + (xsize - 21 + x)] := i;
    end;
end;

begin
  screen := TScreen.Create;
  screen.Init(binfo^.vram, binfo^.scrnx, binfo^.scrny);
  keyboard := TKeyboard.Create;
  mousefifo := TMouse.Create;
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
  font := TPallet.Create;
  sheet := TShtCtl.Create;
  back := sheet.allock;
  mouse := sheet.allock;
  win := sheet.allock;
  sheet.slide(mouse, 10, 10);
  sheet.slide(win, 80, 72);
  SetLength(buf_win, 160 * 68);
  SetLength(keybuf, 32);
  SetLength(buf_mouse, 128);
  sheet.setbuf(back, buf_back, binfo^.scrnx, binfo^.scrny, -1);
  sheet.setbuf(mouse, buf_mouse, 16, 16, 99);
  sheet.setbuf(win, buf_win, 160, 68, -1);
  font.mouse_cursor8(buf_mouse, 99);
  window8(buf_win, 160, 68, 'window');
  font.putfonts8_asc(buf_win, 160, 24, 28, COL8_000000, 'Welcom to');
  font.putfonts8_asc(buf_win, 160, 24, 44, COL8_000000, 'Haribote-XE');
  mx := (binfo^.scrnx - 16) div 2;
  my := (binfo^.scrny - 28 - 16) div 2;
  sheet.slide(mouse, mx, my);
  sheet.slide(win, 80, 72);
  sheet.updown(back, 0);
  sheet.updown(mouse, 1);
  sheet.updown(win, 2);
  // sprintf
  font.putfonts8_asc(binfo^.vram, 0, 32, COL8_FFFFFF, s);
  sheet.refresh(Rect(0, 0, 80, 16));
  mousefifo.Init(mousefifo.fifo8, 128, buf_mouse);
  keyboard.Init(keyboard.fifo8, 32, keybuf);
  while True do
  begin
    io_cli;
    if keyboard.fifo.Status(keyboard.fifo8) + mousefifo.fifo.Status
      (mousefifo.fifo8) = 0 then
      io_stihlt
    else
    begin
      if keyboard.fifo.Status(keyboard.fifo8) <> 0 then
      begin
        i := keyboard.fifo.Get(keyboard.fifo8);
        io_sti;
        // sprintf
        screen.boxfill8(buf_back, binfo^.scrnx, COL8_008484, 0, 16, 15, 31);
        font.putfonts8_asc(buf_back, binfo^.scrnx, 0, 16, COL8_FFFFFF, s);
        sheet.refresh(Rect(0, 16, 16, 32));
      end
      else if mousefifo.fifo.Status(mousefifo.fifo8) <> 0 then
      begin
        i := mousefifo.fifo.Get(mousefifo.fifo8);
        io_sti;
        sheet.refresh(Rect(0, 0, 80, 16));
      end;
    end;
  end;
  font.Free;
  sheet.Free;
  keyboard.Free;
  mousefifo.Free;
  Finalize(keybuf);
  screen.Free;

end.
