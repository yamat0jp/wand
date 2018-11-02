program wand;

{$R *.dres}

uses
  System.SysUtils,
  System.Classes,
  bootpack in 'bootpack.pas',
  asmhead in 'asmhead.pas',
  graphic in 'graphic.pas';

const
  MEMMAN_ADDR = $003C0000;

var
  binfo: ^TBOOTINFO = Pointer(ADR_BOOTINFO);
  mouse: TMouse;
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
  sheet := TShtCtl.Create(binfo^.scrnx,binfo^.scrny);
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
      if fifo.Status + fifo.Status = 0 then
        io_stihlt
      else
      begin
        if fifo.Status <> 0 then
        begin
          i := fifo.Get;
          io_sti;
          // sprintf
          sheet.screen.boxfill8(COL8_008484, 0, 16, 15, 31);
          sheet.screen.putfonts8_asc_sht(0, 16, s);
          sheet.refresh(0, 16, 16, 32);
        end
        else if fifo.Status <> 0 then
        begin
          i := fifo.Get;
          io_sti;
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
            if mx > binfo^.scrnx - 1 then
              mx := binfo^.scrnx - 1;
            if my > binfo^.scrny - 1 then
              my := binfo^.scrny - 1;
            // sprintf
            sheet.screen.boxfill8(COL8_008484, 0, 0, 78, 15);
            sheet.screen.putfonts8_asc_sht(0, 0, s);
            sheet.refresh(0, 0, 80, 16);
            sheet.slide(mo, mx, my);
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
