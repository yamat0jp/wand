program wand;

{$R *.dres}

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
  s: string;
  buf_win, buf_back, buf_key, buf_mouse: TBytes;
  mx, my: integer;

procedure window8(buf: TBytes; xsize, ysize: integer; title: string);
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
  {
    TAsmhead.Init;
    TAsmhead.Boot;
  }
    screen:=TScreen.Create(binfo^.vram, binfo^.scrnx, binfo^.scrny);
    keyboard := TKeyboard.Create(32, buf_key);
    mousefifo := TMouse.Create(128, buf_mouse);
    font := TPallet.Create;
    sheet := TShtCtl.Create;
    try
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
    back := sheet.allock;
    mouse := sheet.allock;
    win := sheet.allock;
    sheet.slide(mouse, 10, 10);
    sheet.slide(win, 80, 72);
    SetLength(buf_win, 160 * 68);
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
    font.putfonts8_asc(binfo^.vram, binfo^.scrnx, 0, 32, COL8_FFFFFF, s);
    sheet.refresh(Rect(0, 0, 80, 16));
    while True do
    begin
      io_cli;
      if keyboard.Status + mousefifo.Status = 0 then
        io_stihlt
      else
      begin
        if keyboard.Status <> 0 then
        begin
          i := keyboard.Get;
          io_sti;
          // sprintf
          screen.boxfill8(buf_back, binfo^.scrnx, COL8_008484, 0, 16, 15, 31);
          font.putfonts8_asc(buf_back, binfo^.scrnx, 0, 16, COL8_FFFFFF, s);
          sheet.refresh(Rect(0, 16, 16, 32));
        end
        else if mousefifo.Status <> 0 then
        begin
          i := mousefifo.Get;
          io_sti;
          if mousefifo.decode(i) <> 0 then
          begin
            // sprontf
            if (mousefifo.dec.btn and $01) <> 0 then
              s[1] := 'L';
            if (mousefifo.dec.btn and $02) <> 0 then
              s[3] := 'R';
            if (mousefifo.dec.btn and $03) <> 0 then
              s[2] := 'C';
            screen.boxfill8(buf_back, binfo^.scrnx, COL8_008484, 32, 16,
              32 + 15 * 8 - 1, 31);
            font.putfonts8_asc(buf_back, binfo^.scrnx, 32, 16, COL8_FFFFFF, s);
            sheet.refresh(Rect(32, 16, 32 + 15 * 8, 32));
            inc(mx, mousefifo.dec.x);
            inc(my, mousefifo.dec.y);
            if mx < 0 then
              mx := 0;
            if my < 0 then
              my := 0;
            if mx > binfo^.scrnx - 1 then
              mx := binfo^.scrnx - 1;
            if my > binfo^.scrny - 1 then
              my := binfo^.scrny - 1;
            // sprintf
            screen.boxfill8(buf_back, binfo^.scrnx, COL8_008484, 0, 0, 78, 15);
            font.putfonts8_asc(buf_back, binfo^.scrnx, 0, 0, COL8_FFFFFF, s);
            sheet.refresh(Rect(0, 0, 80, 16));
            sheet.slide(mouse, mx, my);
          end;
          sheet.refresh(Rect(0, 0, 80, 16));
        end;
      end;
    end;
  finally
    font.Free;
    sheet.Free;
    keyboard.Free;
    mousefifo.Free;
    Finalize(buf_win);
    Finalize(buf_key);
    Finalize(buf_mouse);
    screen.Free;
  end;

end.
