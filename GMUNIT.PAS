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
Unit GMUnit;
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
Interface

Uses Crt, U_Txt, BBFont;

Const
  GMPort        = $331;
  Send          = $80;
  Receive       = $40;

Function HexCode (t : String) : Byte;
Procedure WriteGM;
Function ReadGM : Byte;
Procedure SetNoteOn (Channel, Note, Volume : Byte);
Procedure SetNoteOff (Channel, Note, Volume : Byte);
Procedure ResetGM;
Procedure SetInstrument (c, i : Byte);
Procedure SetModulation (c, m : Byte);
Procedure SetChorus (c, m : Byte);
Procedure ResetControllers (c : Byte);
Procedure WaitForKey;
Function HexB (B : Byte) : String;
Function Val2 (s : String) : Integer;
Function ShowByte (t, nr : Byte) : String;
Procedure SilenceChannel (c : Byte);
Procedure SilenceAll;
Procedure SetPal(Col,R,G,B : Byte);
Procedure GetPal(Col : Byte; Var R,G,B : Byte);
Procedure Equfont;

Implementation

procedure EquFont;
Var t1 : Integer;
const
  New : Array [1..16] of TCharShape = (
  ($00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF),
  ($00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF),
  ($00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF),
  ($00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
  ($00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
  ($00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
  ($00, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
  ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),
  ($00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF),
  ($00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $00, $FF),
  ($00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $00, $FF, $00, $FF),
  ($00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $00, $FF, $00, $FF, $00, $FF),
  ($00, $00, $00, $00, $00, $00, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF),
  ($00, $00, $00, $00, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF),
  ($00, $00, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF),
  ($00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF));
begin
  For t1:=1 to 16 do ReplaceChar(Chr (130 + t1), @New [t1]);
end;

Procedure SetPal(Col,R,G,B : Byte); assembler;
  { This sets the Red, Green and Blue values of a certain color }
asm
   mov    dx,3c8h
   mov    al,[col]
   out    dx,al
   inc    dx
   mov    al,[r]
   out    dx,al
   mov    al,[g]
   out    dx,al
   mov    al,[b]
   out    dx,al
end;

Procedure GetPal(Col : Byte; Var R,G,B : Byte);
  { This gets the Red, Green and Blue values of a certain color }
Var
   rr,gg,bb : Byte;
Begin
   asm
      mov    dx,3c7h
      mov    al,col
      out    dx,al

      add    dx,2

      in     al,dx
      mov    [rr],al
      in     al,dx
      mov    [gg],al
      in     al,dx
      mov    [bb],al
   end;
   r := rr;
   g := gg;
   b := bb;
end;

Procedure SilenceChannel (c : Byte);
Begin
  {ResetControllers (c);}
  c:=$B0 + c;
  Asm
    MOV   AL, [c]
    CALL  WriteGM
    MOV   AL, 123
    CALL  WriteGM
    MOV   AL, 0
    CALL  WriteGM
  End;
End;

Function HexCode (t : String) : Byte;
Var chr : String [1]; ch  : Char; t1  : Byte;
Begin
  chr:=Copy (t, 1, 1);
  ch:=chr [1];
  If (ch >= '0') and (ch <= '9') then t1:=16 * Val2 (ch);
  Case Upcase (ch) of
    'A' : t1:=160; 'B' : t1:=176; 'C' : t1:=192; 'D' : t1:=208; 'E' : t1:=224; 'F' : t1:=240;
  End;
  chr:=Copy (t, 2, 1);
  ch:=chr [1];
  If (ch >= '0') and (ch <= '9') then HexCode:=t1 + Val2 (ch);
  Case Upcase (ch) of
    'A' : Hexcode:=t1 + 10; 'B' : Hexcode:=t1 + 11; 'C' : Hexcode:=t1 + 12;
    'D' : Hexcode:=t1 + 13; 'E' : Hexcode:=t1 + 14; 'F' : Hexcode:=t1 + 15;
  End;
End;

Function Val2 (s : String) : Integer;
Var w1, w2 : Integer;
Begin
  Val (s, w1, w2);
  Val2:=w1;
End;

Function ShowByte (t, nr : Byte) : String;
Var s2 : String [3];
    t1 : Integer;
Begin
  Str (t, s2);
  for t1:=1 to 2 do If length (s2) < nr then s2:='0' + s2;
  ShowByte:=s2;
End;

Function Hexit (H : Byte) : Char;
(* convert a byte in the range 0..15 to hexadecimal '0'..'F' *)
Begin
  If H <= 9 then begin
    Hexit:= char(H + byte('0'))
  End else begin
    If H <= 15 then Hexit:= char(H + byte('A') - 10) else Hexit:= '?';
  End;
End;

Function HexB (B : Byte) : String;
(* convert a byte to hexadecimal *)
Var
  m,n : Byte;

Begin
  m:= B shr 4;
  n:= B and $0F;
  HexB:= Hexit(m) + Hexit(n);
End;

{AL = Command }
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

Procedure SilenceAll;
Var t : Byte;
Begin
  For t:=$B0 to $B0 + 15 do begin
    Asm
      MOV   AL, [t]
      CALL  WriteGM
      MOV   AL, 123   { Modulation pedal }
      CALL  WriteGM
      MOV   AL, 0
      CALL  WriteGM
    End;
    ResetControllers (t - $B0);
  End;
End;

Procedure SetChorus (c, m : Byte);
Begin
  Inc (c, $B0);
  Asm
    MOV   AL, [c]
    CALL  WriteGM
    MOV   AL, 10 {Panning!}
    CALL  WriteGM
    MOV   AL, [m]
    CALL  WriteGM
  End;
End;

Procedure ResetControllers (c : Byte);
Var t : Byte;
Begin
  SetModulation (c, 0);
  SetChorus (c, 63);
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
  Asm
    MOV   AL, $B0
    CALL  WriteGM
    MOV   AL, 126
    CALL  WriteGM
  End;
End.

