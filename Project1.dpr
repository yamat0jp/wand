program Project1;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes;

var
  s: string;
  base: TMemoryStream;

begin
  try
    { TODO -oUser -cConsole メイン : ここにコードを記述してください }
    base := TMemoryStream.Create;
    try
      s:=ExtractFilePath(ParamStr(0));
      base.LoadFromFile(s+'wand.img');
      base.Position:=base.Size;
      while base.Position < 1440 * 1024 do
        base.WriteData(0);
      base.Position:=$0001FE;
      base.WriteData($FFFFF0AA55);
      base.Position:=$001400;
      base.WriteData($FFFFF0);
      base.SaveToFile(s+'test.img');
    finally
      base.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
