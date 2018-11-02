unit asmhead;

interface

type
  TAsmhead = class
  public
    class procedure Init;
    class procedure Boot;
  end;

procedure io_halt;
procedure io_cli;
procedure io_sti;
procedure io_stihlt;
function io_in8(port: integer): integer;
function io_in16(port: integer): integer;
function io_in32(port: integer): integer;
procedure io_out8(port, data: integer);
procedure io_out16(port, data: integer);
procedure io_out32(port, data: integer);
function io_load_eflags: integer;
procedure io_store_eflags(eflags: integer);
procedure load_gdtr(limit, addr: integer);
procedure load_idtr(limit, addr: integer);
function load_cr0: integer;
procedure store_cr0(cr0: integer);

implementation

procedure io_halt;
asm
  HLT;
  RET;
end;

procedure io_cli;
asm
  CLI;
  RET;
end;

procedure io_sti;
asm
  STI;
  RET;
end;

procedure io_stihlt;
asm
  STI;
  HLT;
  RET;
end;

function io_in8(port: integer): integer;
asm
  MOV   EDX,[ESP+4];
  MOV   EAX,0;
  IN    AL,DX;
  RET;
end;

function io_in16(port: integer): integer;
asm
  MOV   EDX,[ESP+4];
  MOV   EAX,0;
  IN    AX,DX;
  RET;
end;

function io_in32(port: integer): integer;
asm
  MOV   EDX,[ESP+4];
  IN    EAX,DX;
  RET;
end;

procedure io_out8(port, data: integer);
asm
  MOV   EDX,[ESP+4];
  MOV   AL,[ESP+8];
  OUT   DX,AL;
  RET;
end;

procedure io_out16(port, data: integer);
asm
  MOV   EDX,[ESP+4];
  MOV   EAX,[ESP+8];
  OUT   DX,AX;
  RET;
end;

procedure io_out32(port, data: integer);
asm
  MOV   EDX,[ESP+4];
  MOV   EAX,[ESP+8];
  OUT   DX,EAX;
  RET;
end;

function io_load_eflags: integer;
asm
  PUSHFD;
  POP   EAX;
  RET;
end;

procedure io_store_eflags(eflags: integer);
asm
  MOV   EAX,[ESP+4];
  PUSH  EAX;
  POPFD;
  RET;
end;

procedure load_gdtr(limit, addr: integer);
asm
  MOV   AX,[ESP+4];
  MOV   [ESP+6],AX;
  LGDT  [ESP+6];
  RET;
end;

procedure load_idtr(limit, addr: integer);
asm
  MOV   AX,[ESP+4];
  MOV   [ESP+6],AX;
  LIDT  [ESP+6];
  RET;
end;

function load_cr0: integer;
asm
  MOV   EAX,CR0
  RET;
end;

procedure store_cr0(cr0: integer);
asm
  MOV   EAX,[ESP+4];
  MOV   CR0,EAX;
  RET;
end;

{ TAsmhead }

class procedure TAsmhead.Boot;
const
  BOTPAK: UInt32 = $00280000;
  DSKCAC: UInt32 = $00100000;
  DSKCAC0: UInt32 = $00008000;

  CYLS: UInt16 = $0FF0;
  LEDS: UInt16 = $0FF1;
  VMODE: UInt16 = $0FF2;
  SCRNX: UInt16 = $0FF4;
  SCRNY: UInt16 = $0FF6;
  VRAM: UInt16 = $0FF8;
  asm
    // ORG

    MOV   AL,$13
    MOV   AH,$00
    INT   $10
    MOV   BYTE PTR [VMODE],8
    MOV   WORD PTR [SCRNX],320
    MOV   WORD PTR [SCRNY],200
    MOV   DWORD PTR [VRAM],$000a0000

    MOV   AH,$02
    INT   $16
    MOV   BYTE PTR [LEDS],AL

    MOV   AL,$ff
    OUT   $21,AL
    NOP
    OUT   $a1,AL

    CLI

    CALL  @waitkbdout

    MOV   AL,$d1
    OUT   $64,AL
    CALL  @waitkbdout
    MOV   AL,$df
    OUT   $60,AL
    CALL  @waitkbdout

    // LGDT
    MOV   EAX,CR0
    AND   EAX,$7FFFFFFF
    OR    EAX,$00000001
    MOV   CR0,EAX
    JMP   @pipelineflush

  @pipelineflush:
    MOV   AX,1*8
    MOV   DS,AX
    MOV   ES,AX
    MOV   FS,AX
    MOV   GS,AX
    MOV   SS,AX

    MOV   ESI,DWORD PTR @bootpack
    MOV   EDI,BOTPAK
    MOV   ECX,512*1024/4
    CALL  @memcpy

    MOV   ESI,$7C00
    MOV   EDI,DSKCAC
    MOV   ECX,512/4
    CALL  @memcpy

    MOV   ESI,DSKCAC0+512
    MOV   EDI,DSKCAC+512
    MOV   ECX,0
    MOV   CL,BYTE PTR [CYLS]
    IMUL  ECX,512*18*2/4
    SUB   ECX,512/4
    CALL  @memcpy

    MOV   EBX,BOTPAK
    MOV   ECX,[EBX+16]
    ADD   ECX,3
    SHR   ECX,2
    JZ    @skip
    MOV   ESI,[EBX+20]
    ADD   ESI,EBX
    MOV   EDI,[EBX+12]
    CALL  @memcpy

  @skip:
    MOV   ESP,[EBX+12]
    // JMP   DWORD PTR 2*8:$0000001b

  @waitkbdout:
    IN    AL,$64
    AND   AL,$02
    JNZ   @waitkbdout
    RET
  @memcpy:
    MOV   EAX,[ESI]
    ADD   ESI,4
    MOV   EDI,[EAX]
    ADD   EDI,4
    SUB   ECX,1
    JNZ   @memcpy
    RET

    // ALIGNB
  @GDT0:
    // RESB
    DW    $ffff,$0000,$9200,$00cf
    DW    $ffff,$0000,$9a28,$0047

    DW    0
  @GDTR0:
    DW    8*3-1
    DD    @GDT0

    // ALIGNB
  @bootpack:
end;

class procedure TAsmhead.Init;
const
  CYLS: UInt32 = 10;
  asm

end;

end.
