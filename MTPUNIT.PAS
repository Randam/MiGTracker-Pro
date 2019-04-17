{$F+}

Unit MTPUNIT;

Interface

Uses GMUnit, Dos;

Type songTp = Record
       playing      : Boolean;
       filename     : String [12];
     End;

Var
     IntVec          : Procedure;
     f               : Text;
     regs            : Registers;
     equipment,
     resbasic        : Pointer;
     TmpCX,
     env,
     stackseg,
     stackptr,
     stacksegsave,
     stackptrsave    : Word;

     song            : SongTp;


Const
    TSR_ID    = $0013;

Procedure LoadSong (temp : String);
Procedure PlaySong;
Procedure StopSong;

Implementation

Var
     pattern      : Array [1..60 , 1..17 , 1..16] of Byte;
     position     : Array [1..200] of Byte;

     startvoice   : Array [1..15] of Byte;
     voice        : Array [1..15] of Byte;
     startvolume  : Array [1..16] of Byte;
     startmode    : Array [1..16] of Boolean;
     voicechange  : Array [1..21] of Byte;
     volume       : Array [1..16] of Byte;
     mode         : Array [1..15] of Boolean;
     notehis      : Array [1..15] of Byte;

     lastpos,
     looppos,
     startspeed   : Byte;
     speed        : Byte;
     songname     : String [70];
     endofpattern : Boolean;

     time         : LongInt;
     pos          : Integer;
     x, y         : Byte;
     s, t         : String;
     t1, t2, t3,
     t4           : Integer;
     playpos      : Byte;
     step,
     track,
     number       : Integer;
     plusvalue    : Integer;

Procedure LoadSong;
begin
  If song. playing = False then begin
    Assign (f, temp);
    Reset (f);
    song. filename:=Copy (temp, length (temp) - 11, 12);
    For t1:=1 to 60 do for t2:=1 to 17 do for t3:=1 to 16 do begin
      ReadLn (f, pattern [t1, t2, t3]);
    End;
    For t1:=1 to 200 do ReadLn (f, position [t1]);
    ReadLn (f, looppos);
    ReadLn (f, lastpos);
    ReadLn (f, startspeed);
    ReadLn (f, Songname);
    For t1:=1 to 16 do begin
      ReadLn (f, startvoice [t1]);
      ReadLn (f, t2);
      If t2 = 1 then startmode [t1]:=True else startmode [t1]:=False;
      ReadLn (f, startvolume [t1]);
    End;
    For t1:=1 to 20 do ReadLn (f, voicechange [t1]);
    If IOresult > 0 then begin
      Write ('failed!');
    End;
    Close (f);
  End;
End;

Procedure PlayNextStep (track, step : Byte);
Begin
  { 2 Drum Tracks }
  For t1:=16 to 17 do begin
    t2:=pattern [track, t1, step];
    If (t2 > 0) and (t2 < 96) then SetNoteOn (9, t2, volume [16] * 8);

    If (t2 > 95) and (t2 < 112) then volume [16]:=t2 - 96;
  End;
  { 15 Music Tracks }
  endofpattern:=False;
  For t1:=1 to 15 do begin
    t2:=pattern [track, t1, step];
    If (t2 > 180) and (t2 < 191) then speed:=t2 - 181;
    If pattern [track, t1, step + 1] = 191 then endofpattern:=True;
  End;
  For t1:=1 to 15 do begin
    t2:=pattern [track, t1, step];
    If (t2 > 96) and (t2 < 161) then volume [t1]:=t2 - 97;
    If (t2 > 160) and (t2 < 171) then begin
      If t1 < 10 then SetModulation (t1 - 1, (t2 - 161) * 14) else SetModulation (t1, (t2 - 161) * 14);
    End;
    If (t2 > 170) and (t2 < 181) then begin
      If t1 < 10 then SetChorus (t1 - 1, (t2 - 171) * 14) else SetChorus (t1, (t2 - 171) * 14);
    End;
    If (t2 > 224) and (t2 < 246) then begin
      voice [t1]:=voicechange [t2 - 225];
      If t1 < 10 then SetInstrument (t1 - 1, voicechange [t2 - 225] - 1) else SetInstrument (t1, voicechange [t2 - 225] - 1);
    End;
    If (t2 > 0) and (t2 < 97) then begin
      If t1 < 10 then begin
        If (mode [t1] = True) or (pattern [track, t1, step] = 96) then SetNoteOff (t1 - 1, notehis [t1], 127);
        If (mode [t1] = False) and (pattern [track, t1, step] = 96) then SilenceChannel (t1 - 1);
        If pattern [track, t1, step] < 96 then begin
          SetModulation (t1 - 1, 0);
          SetNoteOn (t1 - 1, pattern [track, t1, step] + 12 + plusvalue, volume [t1] * 2);
          notehis [t1]:=pattern [track, t1, step] + 12 + plusvalue;
        End;
      End else begin
        If (mode [t1] = True) or (pattern [track, t1, step] = 96) then SetNoteOff (t1, notehis [t1], 127);
        If (mode [t1] = False) and (pattern [track, t1, step] = 96) then SilenceChannel (t1);
        If pattern [track, t1, step] < 96 then begin
          SetModulation (t1, 0);
          SetNoteOn (t1, pattern [track, t1, step] + 12 + plusvalue, volume [t1] * 2);
          notehis [t1]:=pattern [track, t1, step] + 12 + plusvalue;
        End;
      End;
    End;
  End;
  For t1:=1 to 15 do begin
    t2:=pattern [track, t1, step];
    If (t2 > 191) and (t2 < 209) then plusvalue:=0 - (t2 - 192);
    If (t2 > 208) and (t2 < 225) then plusvalue:=t2 - 209;
  End;
End;

Procedure Afspeler; Interrupt;
begin
  song. playing:=True;
  For t1:=1 to 15 do If t1 < 10 then SetInstrument (t1 - 1, voice [t1] - 1) else SetInstrument (t1, voice [t1] - 1);
  playpos:=step;
  If (time + (10 - speed) <= LongInt (Ptr ($40, $6C)^)) then begin
    track:=position [number];
    PlayNextStep (track, step);
    step:=step + 1;
    If endofpattern or (step > 16) then begin
      step:=1;
      number:=number + 1;
      If (number > lastpos) and (looppos > 0) then number:=looppos;
    End;
    time:=Longint (Ptr ($40, $6c)^);
    If (number > 200) then number:=1;
  End;
  Inline ($9C);
  IntVec;
End;

Procedure StopSong;
Begin
  If song. playing then begin
    Inline ($FA); { Disable interrupt}
    StackSegSave:=Sseg;
    StackPtrSave:=Sptr;
    Asm
      MOV SS, [StackSeg]
      MOV SP, [StackPtr]
    End;
    Inline ($FB); { Enable interrupt }
    Env:=memw [regs.ES:$2C];
    regs.AH:=$49;
    MsDos (regs);
    regs.ES:=Env;
    regs.AH:=$49;
    MsDos (regs);
    SetIntVec ($1C, @IntVec);
    SilenceAll;
    ResetGM;
    song. playing:=False;
  End;
End;

Procedure PlaySong;
Begin
  ResetGM;
  SilenceAll;
  For t1:=1 to 15 do begin
    If t1 < 10 then SetInstrument (t1 - 1, startvoice [t1] - 1) else SetInstrument (t1, startvoice [t1] - 1);
    voice [t1]:=startvoice [t1];
    volume [t1]:=startvolume [t1];
    mode [t1]:=startmode [t1];
  End;
  volume [16]:=15;
  plusvalue:=0;
  speed:=startspeed;
  number:=1; { Positie teller }
  step:=1; { Step teller }
  time:=LongInt (Ptr ($40, $6C)^);
  GetIntVec ($1C, @IntVec);
  SetIntVec ($1C, Addr (Afspeler));
  SwapVectors;
  StackSeg:=Sseg;
  StackPtr:=SPtr;
  regs.AH:=$34;
  MsDos (regs);
End;
{ H O O F D P R O G R A M M A }

Begin
End.









