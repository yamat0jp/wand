unit asmhead;

interface

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
  IN   EAX,DX;
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

end.
