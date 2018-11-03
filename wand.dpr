program wand;

{$R *.dres}

uses
  System.SysUtils,
  System.Classes,
  bootpack in 'bootpack.pas',
  asmhead in 'asmhead.pas',
  graphic in 'graphic.pas',
  contrl in 'contrl.pas',
  func in 'func.pas';

const
  MEMMAN_ADDR = $003C0000;

var
  binfo: ^TBOOTINFO = Pointer(ADR_BOOTINFO);
  mouse: TMouse;
  ctl: TCtl;
  keyboard: TKeyboard;
  i: SmallInt;
  memtest: TMemtest;
  memtotal: Cardinal;
  memman: ^TMEMMAN = Pointer(MEMMAN_ADDR);
  mem: TMem;
  sheet: TShtCtl;
  mo, win: TSheet;
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
  mouse := TMouse.Create(fifo, 512);
  ctl := TCtl.Create(fifo);
  sheet := TShtCtl.Create(binfo^.scrnx, binfo^.scrny);
  mo := TCursor.Create(16, 16, 99);
  win := TWindow.Create(160, 68, 'Window', -1);
  try
    sheet.add(mo);
    sheet.add(win);
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
          with keyboard do
          begin
            if i >= $54 + 256 then
              if (keytable0[i - 256] <> 0) and (cursor_x < 144) then
              begin
                s[1] := Char(keytable0[i - 256]);
                win.putfonts8_asc_sht(cursor_x, 28, s);
                inc(cursor_x, 8);
              end;
            if (i <= 256 + $0E) and (cursor_x > 8) then
            begin
              win.putfonts8_asc_sht(cursor_x, 28, ' ');
              dec(cursor_x, 8);
            end;
            win.boxfill8(cursor_c, cursor_x, 28, cursor_x + 8, 44);
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
