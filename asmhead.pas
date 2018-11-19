unit asmhead;

interface

type
  TAsmhead = class
  private
    procedure resb(count: integer); virtual;
    procedure align16; virtual;
    procedure Init;
    procedure Boot;
  public
    constructor Create;
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

procedure TAsmhead.resb(count: integer);
asm
  MOV   ECX,count
@start:
  DB    $00
  LOOP  @start
  RET
end;

procedure TAsmhead.align16;
asm
  MOV   EBX,ESP
  AND   EBX,$00000001
  MOV   EAX,Self
  MOV   EDX,[EAX]
  CALL  [EDX + VMTOFFSET TAsmhead.resb(EBX)]
  RET
end;

procedure TAsmhead.Boot;
const
  VBEMODE: UInt16 = $105;

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
    MOV   EBP,$00c200

    MOV   AX,$9000
    MOV   ES,AX
    MOV   DI,0
    INT   $10
    CMP   AX,$004f
    JNE   @scrn320

    MOV   AX,[ES:DI+4]
    CMP   AX,$0200
    JB    @scrn320

    MOV   CX,VBEMODE
    MOV   AX,$4f01
    INT   $10
    CMP   BYTE PTR [ES:DI+$1b],4
    JNE   @scrn320
    MOV   AX,[ES:DI+$00]
    AND   AX,$0080
    JZ    @scrn320

    MOV   BX,VBEMODE+$4000
    MOV   AX,$4f02
    INT   $10
    MOV   BYTE PTR [VMODE],8
    MOV   AX,[ES:DI+$12]
    MOV   [SCRNX],AX
    MOV   EAX,[ES:DI+$28]
    MOV   [VRAM],AX
    JMP   @keystatus

  @scrn320:
    MOV   AL,$13
    MOV   AH,$00
    INT   $10
    MOV   BYTE PTR [VMODE],8
    MOV   WORD PTR [SCRNX],320
    MOV   WORD PTR [SCRNY],200
    MOV   DWORD PTR [VRAM],$000a0000

  @keystatus:
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

    LGDT  [@GDTR0]
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
    MOV   EAX,2*8 SHL 1
    INC   EAX
    JMP   EAX

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
    LOOP  @memcpy
    RET

    MOV   EAX,Self
    MOV   EDX,[EAX]
    CALL  DWORD PTR [EDX + VMTOFFSET TAsmhead.align16]
  @GDT0:
    MOV   EAX,Self
    MOV   EDX,[EAX]
    CALL  DWORD PTR [EDX + VMTOFFSET TAsmhead.resb(8)]
    DW    $ffff,$0000,$9200,$00cf
    DW    $ffff,$0000,$9a28,$0047

    DW    0
  @GDTR0:
    DW    8*3-1
    DD    @GDT0

    MOV   EAX,Self
    MOV   EDX,[EAX]
    CALL  DWORD PTR [EDX + VMTOFFSET TAsmhead.align16]
  @bootpack:
end;

constructor TAsmhead.Create;
begin
  inherited;
  Init;
  Boot;
end;

procedure TAsmhead.Init;
const
  CYLS: UInt8 = 10;
  asm
    MOV   EBP,$007c00
    JMP   @entry
    DB    $90
    DB    'HARIBOTE'
    DW    512
    DB    1
    DW    1
    DB    2
    DW    224
    DW    2880
    DB    $f0
    DW    9
    DW    18
    DW    2
    DD    0
    DD    2880
    DB    0,0,$29
    DD    $ffffffff
    DB    'HARIBOTEOS '
    DB    'FAT12   '
    MOV   EAX,Self
    MOV   EDX,[EAX]
    CALL  DWORD PTR [EDX + VMTOFFSET TAsmhead.resb(18)]
  @entry:
    MOV   AX,0
    MOV   SS,AX
    MOV   SP,$7c00
    MOV   DS,AX

    MOV   AX,$0820
    MOV   ES,AX
    MOV   CH,0
    MOV   DH,0
    MOV   CL,2
  @readloop:
    MOV   SI,0
  @retry:
    MOV   AH,$02
    MOV   AL,1
    MOV   BX,0
    MOV   DL,$00
    INT   $13
    JNC   @next
    ADD   SI,1
    CMP   SI,5
    JAE   @error
    MOV   AH,$00
    MOV   DL,$00
    INT   $13
    JMP   @retry
  @next:
    MOV   AX,ES
    ADD   AX,$0020
    MOV   ES,AX
    ADD   CL,1
    CMP   CL,18
    JBE   @readloop
    MOV   CL,1
    ADD   DH,1
    CMP   DH,2
    JB    @readloop
    MOV   DH,0
    ADD   CH,1
    CMP   CH,CYLS
    JB    @readloop

    MOV   [$0ff0],CH
    MOV   EAX,$00c200
    JMP   EAX
  @error:
    MOV   SI,WORD PTR @msg
  @putloop:
    MOV   AL,[SI]
    ADD   SI,1
    CMP   AL,0
    JE    @fin
    MOV   AH,$0e
    MOV   BX,15
    INT   $10
    JMP   @putloop
  @fin:
    HLT
    JMP   @fin
  @msg:
    DB    $0a,$0a
    DB    'load error'
    DB    $0a
    DB    0
    MOV   EAX,$7dfe
    SUB   EAX,ESP
    MOV   EBX,EAX
    MOV   EAX,Self
    MOV   EDX,[EAX]
    CALL  DWORD PTR [EDX + VMTOFFSET TAsmhead.resb(EBX)]
    DB    $55,$AA
end;

end.
