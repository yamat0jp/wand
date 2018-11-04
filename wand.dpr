program wand;

{$R *.dres}

uses
  System.SysUtils,
  System.Classes,
  bootpack in 'bootpack.pas',
  asmhead in 'asmhead.pas',
  func in 'func.pas';

const
  MEMMAN_ADDR = $003C0000;

var
  binfo: ^TBOOTINFO = Pointer(ADR_BOOTINFO);
  mouse: TMouse;
  ctl: TCtl;
  keyboard: TKeyboard;
  key_to: integer;
  i: SmallInt;
  memtest: TMemtest;
  memtotal: Cardinal;
  memman: ^TMEMMAN = Pointer(MEMMAN_ADDR);
  mem: TMem;
  sheet: TShtCtl;
  mo, win, cons: TSheet;
  s: string;
  fifo: TFifo;
  mx, my: integer;

begin
  {
    TAsmhead.Init;
    TAsmhead.Boot;
  }
  fifo := TFifo.Create(128);
  keyboard := TKeyboard.Create(fifo, 216);
  key_to := 0;
  mouse := TMouse.Create(fifo, 512);
  ctl := TCtl.Create(fifo);
  sheet := TShtCtl.Create(binfo^.scrnx, binfo^.scrny);
  mo := TCursor.Create(16, 16, 99);
  win := TWindow.Create(160, 68, 'Window', 0);
  cons := TConsole.Create(160, 100, 'Console', 1);
  try
    sheet.add(mo);
    sheet.add(win);
    sheet.add(cons);
    memtest := TMemtest.Create;
    memtotal := memtest.memtest($00400000, $BFFFFFFF);
    {
      mem:=TMem.Create;
      mem.Init(memman);
      mem.memfree(memman,$00001000,$0009e000);
      mem.memfree(memman,$00400000,memtotal-$00400000);
      mem.Free;
    }
    memtest.Free;
    sheet.slide(mo, 10, 10);
    sheet.slide(win, 80, 72);
    sheet.screen.putfonts8_asc_sht(0, 28, 'Welcom to');
    sheet.screen.putfonts8_asc_sht(0, 44, 'Haribote-XE');
    mx := (sheet.screen.bxsize - 16) div 2;
    my := (sheet.screen.bysize - 28 - 16) div 2;
    sheet.slide(mo, mx, my);
    sheet.slide(win, 80, 72);
    sheet.updown(mo, 1);
    sheet.updown(win, 2);
    // sprintf
    sheet.screen.putfonts8_asc_sht(0, 32, s);
    sheet.refresh(0, 0, 80, 16);
    while True do
    begin
      io_cli;
      if fifo.Status = 0 then
        io_stihlt
      else
      begin
        i := fifo.Get;
        io_sti;
        if (i >= 256) and (i <= 511) then
        begin
          if i >= $54 + 256 then
            if (keyboard.keytable0[i - 256] <> 0) and (win.cursor_x < 144) then
            begin
              s[1] := Char(keyboard.keytable0[i - 256]);
              win.putfonts8_asc_sht(win.cursor_x, 28, s);
              inc(win.cursor_x, 8);
            end;
          if (i <= 256 + $0E) and (win.cursor_x > 8) then
          begin
            win.putfonts8_asc_sht(win.cursor_x, 28, ' ');
            dec(win.cursor_x, 8);
          end;
          if i = 256 + $0F then
          begin
            if key_to = 0 then
            begin
              key_to := 1;
              sheet.updown(win, 0);
              sheet.updown(cons, 1);
            end
            else
            begin
              key_to := 0;
              sheet.updown(win, 1);
              sheet.updown(cons, 0);
            end;
          end;
          win.clip:=Rect(0,0,win.bxsize,21);
          cons.clip:=Rect(0,0,cons.bxsize,21);
          sheet.refresh(win);
          sheet.refresh(cons);
          case i of
            256 + $2A:
              key_shift := key_shift or 1;
            256 + $36:
              key_shift := key_shift and 1;
            256 + $AA:
              ;
            256 + $B6:
              ;
            256 + $3A:
              begin
                key_leds = key_leds * key_leds * key_leds * key_leds;
                fifo.Put(KEYCMD_LED);
                fifo.Put(key_leds);
              end;
            256 + $45:
              begin
                key_leds := key_leds * key_leds;
                fifo.Put(KEYCMD_LED);
                fifo.Put(key_leds);
              end;
            256 + $46:
              begin
                fifo.Put(KEYCMD_LED);
                fifo.Put(key_leds);
              end;
            256 + $FA:
              keycmd_wait := -1;
            256 + $FE:
              begin
                keyboard.wait_KBC_sendready;
                io_out8(TKeyboard.PORT_KEYDAT, keycmd_wait);
              end;
          end;
          win.boxfill8(win.cursor_c, win.cursor_x, 28, win.cursor_x + 8, 44);
        end
        else if (i >= 512) and (i <= 711) then
        begin
          if mouse.decode(i) <> 0 then
          begin
            // sprontf
            if (mouse.dec.btn and $01) <> 0 then
              s[1] := 'L';
            if (mouse.dec.btn and $02) <> 0 then
              s[3] := 'R';
            if (mouse.dec.btn and $03) <> 0 then
              s[2] := 'C';
            sheet.screen.boxfill8(COL8_008484, 32, 16, 32 + 15 * 8 - 1, 31);
            sheet.screen.putfonts8_asc_sht(32, 16, s);
            sheet.refresh(32, 16, 32 + 15 * 8, 32);
            inc(mx, mouse.dec.x);
            inc(my, mouse.dec.y);
            if mx < 0 then
              mx := 0;
            if my < 0 then
              my := 0;
            if mx > sheet.screen.bxsize - 1 then
              mx := sheet.screen.bxsize - 1;
            if my > sheet.screen.bysize - 1 then
              my := sheet.screen.bysize - 1;
            // sprintf
            sheet.screen.boxfill8(COL8_008484, 0, 0, 78, 15);
            sheet.screen.putfonts8_asc_sht(0, 0, s);
            sheet.refresh(0, 0, 80, 16);
            sheet.slide(mo, mx, my);
          end;
          if fifo.Status <> 0 then
          begin
            i := fifo.Get;
            io_sti;
            sheet.screen.putfonts8_asc_sht(0, 64, '10sec');
            sheet.refresh(0, 64, 56, 80);
          end;
          sheet.refresh(0, 0, 80, 16);
        end;
      end;
    end;
  finally
    fifo.Free;
    sheet.Free;
    win.Free;
    mo.Free;
    keyboard.Free;
    mouse.Free;
  end;

end.
