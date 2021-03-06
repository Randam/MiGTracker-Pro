{
Here is the PASCAL version of a portion of the Assembler code I used in my
game to get General Midi sound.  I've compiled the program, and it works fine
on my GM device, MEGA-EM a TSR for the Gravis Ultrasound.

No checking is performed, make sure you have the correct hardware, but
it should run due to the timeout checking.

If you don't get sound, then it's probably because no instrument was
defined.  Send a program change midi sequence.

Feel free to toss this in SWAG.  Sound code is always requested,
and General Midi is so simple compared to everything else.
}
Program GMTest;
(*
Take from Colin Buckley's cheezy shareware game Tubes, written in BP.
The actual GM code is a converted assembler file, thus the obvious macro
like sequences, register passing, and semi-colon comments.  Sorry for any
typos/bugs introduced during the quick conversion.

This is completely public domain.  Which means no restrictions whatsoever.

{$DEFINE EducateTheMasses}
To the uninformed, you can not say something is public domain, then paste a
copyright on it and say it's required for you to be acknowledged or
get a post card or something.  You give up all rights when you give something
to the public domain.  What you want, is called freeware.
{$ENDIF}
*)
Uses Crt;

Const
  GMPort        = $331;
  Send          = $80;
  Receive       = $40;

{ AL:=Command; }
Procedure WriteGMCommand; Assembler;
ASM
    MOV   DX, GMPort                  {;DX:=GMStatusPort;                 }
    PUSH  AX                          {;Save AX                           }
    XOR   AX, AX                      {;AH:=TimeOutValue;                 }
@@WaitLoop:
    { ;Prevent Infinite Loop with Timeout }
    DEC   AH                          {; |If TimeOutCount=0 then          }
    JZ    @@TimeOut                   {;/   TimeOut;                      }
    {; Wait until GM is ready }
    IN    AL, DX                      {; |If Not Ready then               }
    AND   AL, Receive                 {; |  WaitLoop;                     }
    JNZ   @@WaitLoop                  {;/                                 }
@@TimeOut:
    POP   AX                          {;Restore AX                        }

    OUT   DX, AL                      {;Send Data                         }
End;

{ ; AL:=Data }
Procedure WriteGM; Assembler;
ASM
    MOV   DX, GMPort                  {;DX:=GMStatusPort;                 }
    PUSH  AX                          {;Save AX                           }
    XOR   AX, AX                      {;AH:=TimeOutValue;                 }
@@WaitLoop:
    { ; Prevent Infinite Loop with Timeout }
    DEC   AH                          {; |If TimeOutCount=0 then          }
    JZ    @@TimeOut                   {;/   TimeOut;                      }
    { ; Wait until GM is ready }
    IN    AL, DX                      {; |If Not Ready then               }
    AND   AL, Receive                 {; |  WaitLoop;                     }
    JNZ   @@WaitLoop                  {;/                                 }
@@TimeOut:
    POP   AX                          {;Restore AX                        }

    DEC   DX                          {;DX:=DataPort                     }
    OUT   DX, AL                      {;Send Data                        }
End;

{ AL ;Returns Data }
Function ReadGM:Byte; Assembler;
ASM
    MOV   DX, GMPort                  {;DX:=GMStatusPort;                 }
    PUSH  AX                          {;Save AX                           }
    XOR   AX, AX                      {;AH:=TimeOutValue;                 }
@@WaitLoop:
    { ; Prevent Infinite Loop with Timeout }
    DEC   AH                          {; |If TimeOutCount=0 then          }
    JZ    @@TimeOut                   {;/   TimeOut;                      }
    { ; Wait until GM is ready }
    IN    AL, DX                      {; |If Not Ready then               }
    AND   AL, Send                    {; |  WaitLoop;                     }
    JNZ   @@WaitLoop                  {;/                                 }
@@TimeOut:
    POP   AX                          {;Restore AX                        }

    DEC   DX                          {;DX:=DataPort                      }
    IN    AL, DX                      {;Receive Data                      }
End;

Procedure ResetGM; Assembler;
ASM
    { ;Reset GM }
    MOV   DX, GMPort
    MOV   AL, 0FFh
    OUT   DX, AL
    {; Get ACK }
    CALL  ReadGM
    {; UART Mode }
    MOV   AL, 03Fh
    CALL  WriteGMCommand
End;

Procedure SetNoteOn (Channel, Note, Volume : Byte); Assembler;
ASM
    MOV   AL,[Channel]
    ADD   AL, 90h
    Call  WriteGM
    MOV   AL, [Note]
    CALL  WriteGM
    MOV   AL, [Volume]
    CALL  WriteGM
End;

Procedure SetNoteOff(Channel,Note,Volume:Byte); Assembler;
ASM
    MOV   AL, [Channel]
    ADD   AL, 80h
    Call  WriteGM
    MOV   AL, [Note]
    CALL  WriteGM
    MOV   AL, [Volume]
    CALL  WriteGM
End;

Procedure SetInstrument (c, i : Byte);
Begin
  Inc (c, $C0);
  Asm
    MOV   AL, [c]
    CALL  WriteGM
    MOV   AL, [i]
    CALL  WriteGM
  End;
End;

Procedure SetModulation (c, m : Byte);
Begin
  Inc (c, $B0);
  Asm
    MOV   AL, [c]
    CALL  WriteGM
    MOV   AL, 1   { Modulation pedal }
    CALL  WriteGM
    MOV   AL, [m]
    CALL  WriteGM
  End;
End;

Procedure SetBreath (c, m : Byte);
Begin
  Inc (c, $B0);
  Asm
    MOV   AL, [c]
    CALL  WriteGM
    MOV   AL, 95
    CALL  WriteGM
    MOV   AL, 127
    CALL  WriteGM
    MOV   AL, [c]
    CALL  WriteGM
    MOV   AL, 93   { Breath control }
    CALL  WriteGM
    MOV   AL, [m]
    CALL  WriteGM
  End;
End;

Procedure ResetControllers (c : Byte);
Var t : Byte;
Begin
  SetModulation (c, 0);
  SetBreath (c, 0);
End;

Procedure WaitForKey;
Begin
  ASM
    XOR   AX,AX
    INT   16h
  End;
End;

Begin
  ResetGM;
  {ResetControllers (1);}
  SetInstrument (0, 70);
  SetInstrument (1, 1);
  {SetNoteOn (0, 64, 127);
  SetModulation (0, 127);}
  SetNoteOn (1, 71, 127);
  SetBreath (1, 127);
  WaitForKey;
  SetNoteOff(0,64,127);
  ResetGM;
End.

