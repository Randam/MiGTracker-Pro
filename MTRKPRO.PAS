{$I- $R- $G+}
Program MiGTrackerPro;   {v1.4}

Uses DSP,
     Crt,
     U_txt,
     GMUnit,
     Dos,
     ExtDos,
     ModeX,
     UnitPcx,
     JerVGA,
     Boxes,
     Crt2;

Type
     blockTp    = Record
       sx, sy, sp : Byte;
       ex, ey, ep : Byte;
       inside     : Boolean;
     End;

Const
     note         : Array [1..12] of String [3] = ('C ', 'C#' , 'D ', 'D#', 'E ', 'F ', 'F#', 'G ', 'G#', 'A ', 'A#', 'B ');
     KeyB         : String [12] = 'ZSXDCVGBHNJM';

Var
     pattern      : Array [1..60 , 1..17 , 1..16] of Byte;
     position     : Array [1..200] of Byte;
     channel      : Array [1..15] of Boolean;

     startvoice   : Array [1..16] of Byte;
     startvolume  : Array [1..16] of Byte;
     startmode    : Array [1..16] of Boolean;
     voicechange  : Array [1..21] of Byte;

     channelvoice : Array [1..16] of Byte;
     voicename    : Array [1..128] of String [20];
     volume       : Array [1..17] of Byte;
     mode         : Array [1..15] of Boolean;
     playchannel  : Array [1..17] of Boolean;

     filename     : Array [0..212] of String [13];
     fileID       : Array [0..212] of Byte;
     maxfiles     : Integer;
     MigDir       : String;
     TempDir      : String;

     block        : BlockTp;
     lastpos,
     looppos,
     startspeed   : Byte;
     speed        : Byte;
     songname     : String [70];
     endofpattern : Boolean;

     option       : Array [1..10] of String [30];
     poort        : Word;
     notehis      : Array [1..17] of Byte;
     time         : LongInt;
     equtime      : LongInt;
     equ          : Array [1..17] of Byte;
     equnr        : Byte;
     pos          : Integer;
     x, y         : Byte;
     s, t         : String;
     f            : Text;
     t1, t2, t3,
     t4           : Integer;
     ch           : Char;
     octaaf,
     noot,
     history,
     drumhis      : Byte;
     csVoice,
     caVoice      : Integer;
     playpos      : Byte;
     tracking     : Boolean;
     audition     : Byte;
     settingscan  : Boolean;
     x1, x2,
     y1, y2       : Integer;
     patternnr    : Byte;
     step,
     track,
     number       : Integer;
     plusvalue    : Integer;
     fl                 : file;
     st                 : Word;
     freq               : Word;
     h : Record
       signature        : Array [1..19] of Char;
       Terminator       : Byte;
       data_start       : Word;
       version          : Integer;
       id               : Integer;
     End;
     d : Record
       id               : Byte;
       len              : Array [1..3] of Byte;
       sr               : Byte;
       pack             : Byte
     End;
     niceeffect         : boolean;

procedure clearscreen;
var t1, t2 : byte;
begin
  gotoxy (1, 1);
  for t1:=1 to 23 do
    for t2:=1 to 80 do
    write (' ')
end;

Procedure ShowEqu;
Begin
  If LongInt (Ptr ($40, $6C)^) > equtime then begin
    equtime:=LongInt (Ptr ($40, $6C)^);
    For t1:=1 to 17 do begin
      GotoXY (t1 * 2 + 43, 22);
      Write (Char (equnr + equ [t1]));
      If equ [t1] > 0 then Dec (equ [t1]);
    End;
  End;
End;

Procedure ShowScreen (filename : String);
Var color : Byte;
Begin
  color:=16 * c. bg + c. fg;
  CursorOff;
  GotoXY (1, 1);
  Assign (f, filename);
  Reset (f);
  For t1:=1 to 23 do begin
    ReadLn (f, s);
    For t2:=1 to Length (s) do begin
      If (copy (s, t2, 1) = '<') and (t1 < 18) then color:=16 * c. bg + c. ac;
      If copy (s, t2 - 1, 1) = '>' then color:=16 * c. bg + c. fg;;
      If copy (s, t2, 1) <> #32 then FWrite (t2, t1, copy (s, t2, 1), color);
    End;
  End;
  FWrite (30, 1, ' MiGTracker Pro v1.3 ', 16 * c. bc + c. fg);
  Close (f);
  If filename = 'MAIN.SCR' then begin
    For t1:=1 to 15 do begin
      GotoXY (t1 * 4, 4);
      If not playchannel [t1] then Write ('OFF') else Write ('C' + ShowByte (t1, 2));
    End;
    GotoXY (64, 4);
    If not playchannel [16] then Write ('OF') else Write ('D1');
    GotoXY (67, 4);
    If not playchannel [17] then Write ('OF') else Write ('D2');
    For t1:=1 to 17 do begin
      GotoXY (t1 * 2 + 43, 22);
      Write (Char (equnr + equ [t1]));
    End;
  End;
  TextBackground (c. bg);
  if upcase (filename [1]) = 'M' then
    showequ
End;

procedure show_song_variables (w1, w2, w3, w4, w5 : Byte);
begin
  cursoroff;
  GotoXY (2, 4);
  if niceeffect then
    write ('û')
  else
    write (' ');
  GotoXY (13, 2); Write (songname);
  For t1:=1 to 66 - Length (songname) do Write (' ');
  GotoXY (77, 5); Write (ShowByte (w1, 2));
  GotoXY (76, 8); Write (ShowByte (w2, 3));
  GotoXY (76, 11); Write (ShowByte (w3, 3));
  GotoXY (76, 14); If w4 > 0 then Write (ShowByte (w4, 3)) else Write (' No');
  GotoXY (77, 17); Write (ShowByte (w5, 2));
  GotoXY (18, 22);
  Case audition of
    0 : Write ('Off ');
    1 : Write ('Mono');
    2 : Write ('Poly');
  End;
  GotoXY (39, 22);
  If settingscan then Write ('On ') else Write ('Off');
end;

procedure init_nice_effect;
begin
  for t1:=5 to 20 do
  begin
    gotoxy (4, t1);
    for t2:=1 to 65 do
      write (#32)
  end;
end;

procedure show_nice_effect (w1, w2, w3, w4, w5 : Byte);
var
  npos  : integer;
  nchar : byte;
begin
  show_song_variables (w1, w2, w3, w4, w5);
  window (4, 5, 68, 21);
  s:='                                                                 ';
  textcolor (14);
  for t2:=1 to 16 do
  begin
    for t1:=1 to 17 do
    begin
      if (notehis [t1] < 96) and (notehis [t1] > 13) and (equ [t1] > 0) then
      begin
        npos:=round ((notehis [t1] - 13) / 83 * 64);
        delete (s, npos, 1);
        nchar:=175 + equ [t1] div 2 + 1;
        if nchar > 178 then
        nchar:=219;
        insert (Char (nchar), s, npos)
      end
    end;
    gotoxy (1, t2);
    write (s);
  end;
  textcolor (c. fg);
  window (1, 1, 80, 25)
end;

Procedure ShowPattern (w1, w2, w3, w4, w5 : Byte);
Begin
  show_song_variables (w1, w2, w3, w4, w5);
  x1:=0; x2:=0; y1:=0; y2:=0;
  If (w1 >= block. sp) and (w1 <= block. ep) then begin
    y1:=1;
    y2:=16;
    If w1 = block. sp then y1:=block. sy;
    If w1 = block. ep then y2:=block. ey;
    x1:=block. sx;
    x2:=block. ex;
  End;
  For t2:=1 to 16 do begin
    For t1:=1 to 15 do begin
      If t2 = playpos then TextBackground (c. bc) else TextBackground (c. bg);
      If playpos = 0 then If (t1 >= x1) and (t1 <= x2) and (t2 >= y1) and (t2 <= y2) then
        TextBackground (c. bc) else TextBackground (c. bg);
      If channel [t1] = true then begin
        t3:=pattern [w1, t1, t2];
        GotoXY (t1 * 4, t2 + 4);
        If (t3 > 0) and (t3 < 96) then begin
          noot:=(t3 mod 12) + 1;
          t4:=Trunc (t3 / 12) + 1;
          Write (note [noot]);
          Write (t4);
        End else if t3 = 96 then begin
          Write ('OFF');
        End else if t3 = 0 then begin
          Write (' - ')
        End else if (t3 > 96) and (t3 < 161) then begin
          Write ('V');
          Write (HexB (t3 - 97));
        End else if (t3 > 160) and (t3 < 171) then begin
          Write ('M ');
          Write (t3 - 161);
        End else if (t3 > 170) and (t3 < 181) then begin
          Write ('R ');
          Write (t3 - 171);
        End else if (t3 > 180) and (t3 < 191) then begin
          Write ('S ');
          Write (t3 - 181);
        End else if (t3 = 191) then begin
          Write ('///')
        End else if (t3 > 191) and (t3 < 209) then begin
          Write ('T-');
          Write (Copy (HexB (t3 - 192), 2, 1));
        End else if (t3 > 208) and (t3 < 225) then begin
          Write ('T+');
          Write (Copy (HexB (t3 - 209), 2, 1));
        End else if (t3 > 224) and (t3 < 246) then begin
          Write ('I');
          Write (ShowByte (t3 - 225, 2));
        End else Write (' - ');
        Write ('³');
      End;
    End;
    For t1:=0 to 1 do begin
      If (playpos = 0) and (t1 + 16 >= x1) and (t1 + 16 <= x2) and (t2 >= y1) and (t2 <= y2) then begin
        TextBackground (c. bc)
      End else If playpos = 0 then begin
        TextBackground (c. bg);
      End;
      GotoXY (63 + t1 * 3, t2 + 4);
      Write ('³');
      If pattern [w1, 16 + t1, t2] < 96 then begin
        Write (HexB (pattern [w1, 16 + t1, t2]));
      End else begin
        Write ('V');
        Write (Copy (HexB (pattern [w1, 16 + t1, t2] - 96), 2, 1));
      End;
    End;
  End;
  TextBackground (c. bg);
End;

Procedure ScanSettings;
Begin
  For track:=1 to position [pos] - 1 do
  begin
    For step:=1 to 16 do for t1:=16 to 17 do begin
      t2:=pattern [track, t1, step];
      If (t2 > 95) and (t2 < 112) then volume [16]:=t2 - 96;
    End;

    { 15 Music Tracks }
    For step:=1 to 16 do for t1:=1 to 15 do begin
      If playchannel [t1] then begin
        t2:=pattern [track, t1, step];
        If (t2 > 96) and (t2 < 161) then volume [t1]:=t2 - 97;
        If (t2 > 160) and (t2 < 171) then begin
          If t1 < 10 then SetModulation (t1 - 1, (t2 - 161) * 14) else SetModulation (t1, (t2 - 161) * 14);
        End;
        If (t2 > 170) and (t2 < 181) then begin
          If t1 < 10 then SetChorus (t1 - 1, (t2 - 171) * 14) else SetChorus (t1, (t2 - 171) * 14);
        End;
        If (t2 > 224) and (t2 < 246) then begin
          If t1 < 10 then SetInstrument (t1 - 1, voicechange [t2 - 225] - 1)
          else SetInstrument (t1, voicechange [t2 - 225] - 1);
        End;
        If (t2 > 180) and (t2 < 191) then
        begin
          speed:=t2 - 181;
        End;
      End;
    End;
  End;
  step:=1;
End;

Procedure PlayNextStep (track, step : Byte);
Begin
  If ch = #9 then begin
    if equnr = 131 then equnr:=139 else equnr:=131;
    ch:=#255;
  End;
  { 2 Drum Tracks }
  for t1:=16 to 17 do
  begin
    t2:=pattern [track, t1, step];
    if (t2 > 95) and (t2 < 112) then
      volume [16]:=t2 - 96
  end;
  For t1:=16 to 17 do begin
    t2:=pattern [track, t1, step];
    If (t2 > 0) and (t2 < 96) and playchannel [t1] then begin
      SetNoteOff (9, notehis [t1], 127);
      SetNoteOn (9, t2, volume [16] * 8);
      notehis [t1]:=t2;
      equ [t1]:=7;
    End;
  End;
  { 15 Music Tracks }
  endofpattern:=False;
  For t1:=1 to 15 do begin
    If playchannel [t1] then begin
      t2:=pattern [track, t1, step];
      If (t2 > 180) and (t2 < 191) then speed:=t2 - 181;
      If pattern [track, t1, step + 1] = 191 then endofpattern:=True;
    End;
  End;
  For t1:=1 to 15 do begin
    If playchannel [t1] then begin
      t2:=pattern [track, t1, step];
      If (t2 > 96) and (t2 < 161) then volume [t1]:=t2 - 97;
      If (t2 > 160) and (t2 < 171) then begin
        If t1 < 10 then SetModulation (t1 - 1, (t2 - 161) * 14) else SetModulation (t1, (t2 - 161) * 14);
      End;
      If (t2 > 170) and (t2 < 181) then begin
        If t1 < 10 then SetChorus (t1 - 1, (t2 - 171) * 14) else SetChorus (t1, (t2 - 171) * 14);
      End;
      If (t2 > 224) and (t2 < 246) then begin
        If t1 < 10 then SetInstrument (t1 - 1, voicechange [t2 - 225] - 1) else SetInstrument (t1, voicechange [t2 - 225] - 1);
      End;
      If (t2 > 0) and (t2 < 97) then begin
        If t1 < 10 then begin
          SetNoteOff (t1 - 1, notehis [t1], 127);
          If (mode [t1] = False) and (pattern [track, t1, step] = 96) then SilenceChannel (t1 - 1);
          If pattern [track, t1, step] < 96 then begin
            SetModulation (t1 - 1, 0);
            SetNoteOn (t1 - 1, pattern [track, t1, step] + 12 + plusvalue, volume [t1] * 2);
            notehis [t1]:=pattern [track, t1, step] + 12 + plusvalue;
            equ [t1]:=7;
          End;
        End else begin
          If (mode [t1] = True) or (pattern [track, t1, step] = 96) then SetNoteOff (t1, notehis [t1], 127);
          If (mode [t1] = False) and (pattern [track, t1, step] = 96) then SilenceChannel (t1);
          If pattern [track, t1, step] < 96 then begin
            SetModulation (t1, 0);
            SetNoteOn (t1, pattern [track, t1, step] + 12 + plusvalue, volume [t1] * 2);
            equ [t1]:=7;
            notehis [t1]:=pattern [track, t1, step] + 12 + plusvalue;
          End;
        End;
      End;
    End;
  End;
  For t1:=1 to 15 do begin
    If playchannel [t1] then begin
      t2:=pattern [track, t1, step];
      If (t2 > 191) and (t2 < 209) then plusvalue:=0 - (t2 - 192);
      If (t2 > 208) and (t2 < 225) then plusvalue:=t2 - 209;
    End;
  End;
End;

Procedure TrackPosition (p : Byte);
Begin
  t2:=6;
  CursorOff;
  GotoXY (30, 13);
  TextBackground (c. bc);
  Write     ('         ');
  TextBackground (c. bg);
  For t1:=p - 7 to p + 6 do begin
    If (t1 > 0) and (t1 < 201) then begin
      If t2 = 13 then TextBackground (c. bc) else TextBackground (c. bg);
      GotoXY (30, t2);
      Write (t1); Write (' ');
      GotoXY (35, t2);
      Write ('-'); Write (' ');
      GotoXY (38, t2);
      Write (position [t1]); Write (' ');
    End else begin
      GotoXY (30, t2);
      TextBackground (c. bg);
      Write ('          ');
    End;
    Inc (t2);
  End;
  If playpos = 0 then CursorOn;
  GotoXY (38, 13);
End;

Procedure PlaySong (stepmode : Boolean);
Begin
  plusvalue:=0;
  equtime:=LongInt (Ptr ($40, $6C)^);
  speed:=startspeed;
  ResetGM;
  SilenceAll;
  CursorOff;
  For t1:=1 to 15 do begin
    If t1 < 10 then SetInstrument (t1 - 1, startvoice [t1] - 1) else SetInstrument (t1, startvoice [t1] - 1);
    volume [t1]:=startvolume [t1];
    mode [t1]:=startmode [t1];
  End;
  volume [16]:=15;
  number:=pos; { position }
  If stepmode then step:=y else step:=1;
  time:=LongInt (Ptr ($40, $6C)^);
  if not niceeffect then
    showpattern (position [number], number, lastpos, looppos, speed);
  If settingscan and (pos > 1) then ScanSettings;
  If stepmode then step:=y else step:=1;
  Repeat
    playpos:=step;
    If tracking then TrackPosition (number);
    Repeat
      ShowEqu;
      if niceeffect then
        show_nice_effect (position [number], number, lastpos, looppos, speed)
    Until (time + (10 - speed) <= LongInt (Ptr ($40, $6C)^));
    if not niceeffect then
      showpattern (position [number], number, lastpos, looppos, speed);
    track:=position [number];
    PlayNextStep (track, step);
    if keypressed then
      ch:=readkey;
    if (ch = #22) then
    begin
      if niceeffect then
        niceeffect:=false
      else
        niceeffect:=true;
      show_song_variables (patternnr, pos, lastpos, looppos, startspeed);
      ch:=#255
    end;
    step:=step + 1;
    if endofpattern or (step > 16) then
    begin
      step:=1;
      number:=number + 1;
      if (number > lastpos) and (looppos > 0) then
        number:=looppos;
    end;
    time:=Longint (Ptr ($40, $6c)^);
  Until (number > lastpos) or (ch = #27) or (ch = #0);
  If keypressed then ch:=Readkey;
  ch:=#0;
  SilenceAll;
  playpos:=0;
  For t1:=1 to 17 do begin
    GotoXY (t1 * 2 + 43, 22);
    equ [t1]:=0;
    Write (Char (equnr + equ [t1]));
  End;
End;

Procedure PlayPattern;
Begin
  plusvalue:=0;
  speed:=startspeed;
  equtime:=LongInt (Ptr ($40, $6C)^);
  SilenceAll;
  ResetGM;
  CursorOff;
  For t1:=1 to 15 do begin
    If t1 < 10 then SetInstrument (t1 - 1, startvoice [t1] - 1) else SetInstrument (t1, startvoice [t1] - 1);
    volume [t1]:=startvolume [t1];
    mode [t1]:=startmode [t1];
  End;
  volume [16]:=15;
  number:=pos;
  step:=1;
  time:=LongInt (Ptr ($40, $6C)^);
  If settingscan and (pos > 1) then ScanSettings;
  Repeat
    playpos:=step;
    ShowPattern (patternnr, number, lastpos, looppos, speed);
    If tracking = True then TrackPosition (number);
    PlayNextStep (patternnr, step);
    Repeat
      ShowEqu;
    Until (time + (10 - speed) <= LongInt (Ptr ($40, $6C)^));
    If Keypressed then ch:=Readkey;
    step:=step + 1;
    time:=Longint (Ptr ($40, $6c)^);
  Until (step > 16) or (endofpattern) or (ch = #27) or (ch = #0);
  If keypressed then ch:=Readkey;
  ch:=#0;
  SilenceAll;
  playpos:=0;
  For t1:=1 to 17 do begin
    GotoXY (t1 * 2 + 43, 22);
    equ [t1]:=0;
    Write (Char (equnr + equ [t1]));
  End;
End;

Procedure SetNoteAudition;
Begin
  CursorOff;
  TextColor (c. ac);
  Repeat
    GotoXY (18, 22);
    Case audition of
      0 : Write ('Off ');
      1 : Write ('Mono');
      2 : Write ('Poly');
    End;
    ch:=Readkey;
    If ch = #0 then begin
      ch:=Readkey;
      If ((ch = #72) or (ch = #77)) then begin
        Inc (audition);
        If audition > 2 then audition:=0;
      End;
      If ((ch = #80) or (ch = #75)) then begin
        Dec (audition);
        If audition = 255 then audition:=2;
      End;
    End;
  Until (ch = #27) or (ch = #13) or (ch = #1);
  ch:=#255;
  TextColor (c .fg);
  GotoXY (18, 22);
  Case audition of
    0 : Write ('Off ');
    1 : Write ('Mono');
    2 : Write ('Poly');
  End;
End;

Procedure SetLooppos;
Begin
  CursorOff;
  TextColor (c. ac);
  Repeat
    GotoXY (76, 14); If looppos = 0 then Write (' No') else Write (ShowByte (looppos, 3));
    ch:=Readkey;
    If (ch = #0) then begin
      ch:=Readkey;
      If ((ch = #72) or (ch = #77)) and (looppos < 200) then Inc (looppos);
      If ((ch = #80) or (ch = #75)) and (looppos > 000) then Dec (looppos);
    End;
  Until (ch = #27) or (ch = #13) or (ch = #19);
  ch:=#255;
  TextColor (c. fg);
  GotoXY (76, 14); If looppos = 0 then Write (' No') else Write (ShowByte (looppos, 3));
End;

Procedure SetLastPos;
Begin
  CursorOff;
  TextColor (c. ac);
  Repeat
    GotoXY (76, 11); Write (ShowByte (lastpos, 3));
    ch:=Readkey;
    If (ch = #0) then begin
      ch:=Readkey;
      If ((ch = #72) or (ch = #77)) and (lastpos < 200) then Inc (lastpos);
      If ((ch = #80) or (ch = #75)) and (lastpos > 001) then Dec (lastpos);
    End;
  Until (ch = #27) or (ch = #13) or (ch = #19);
  ch:=#255;
  TextColor (c. fg);
  GotoXY (76, 11); Write (ShowByte (lastpos, 3));
End;

Procedure SetStartSpeed;
Begin
  CursorOff;
  TextColor (c. ac);
  Repeat
    GotoXY (77, 17); Write (HexB (startspeed));
    ch:=Readkey;
    If (ch = #0) then begin
      ch:=Readkey;
      If ((ch = #72) or (ch = #77)) and (startspeed < 9) then Inc (startspeed);
      If ((ch = #80) or (ch = #75)) and (startspeed > 1) then Dec (startspeed);
    End;
  Until (ch = #27) or (ch = #13) or (ch = #19);
  ch:=#255;
  TextColor (c. fg);
  GotoXY (77, 17); Write (HexB (startspeed));
End;

Procedure SetSongName;
Begin
  LineCursor;
  CursorOn;
  TextBackGround (c. bc);
  GotoXY (13, 2); Write ('                                                                 ');
  GotoXY (13, 2);
  ReadLn (s);
  TextBackground (c. bg);
  GotoXY (13, 2); Write ('                                                                 ');
  If s <> '' then songname:=copy (s, 1, 63);
  GotoXY (13, 2); Write (songname);
  CursorOff;
End;

Procedure CheckChangeValues;
Begin
  If ch = #9 then begin
    If equnr = 131 then equnr:=139 else equnr:=131;
    For t1:=1 to 17 do begin
      GotoXY (t1 * 2 + 43, 22);
      equ [t1]:=0;
      Write (Char (equnr + equ [t1]));
    End;
  End;
  If ch = #20 then begin
    GotoXY (39, 22);
    If settingscan then settingscan:=False else settingscan:=True;
    If settingscan then Write ('On ') else Write ('Off');
  End;
  If ch = #01 then SetNoteAudition;
  If ch = #12 then SetLoopPos;
  If ch = #16 then SetLastPos;
  If ch = #19 then SetStartSpeed;
  If ch = #14 then SetSongName;
  If ch = #26 then If playchannel [x] then playchannel [x]:=False else playchannel [x]:=True;
End;

Procedure PatternPositionEditor;
Begin
  tracking:=true;
  niceeffect:=false;
  SpecialBox (20, 5, 50, 20, 15, ' Pattern / Position Editor');
  Repeat
    patternnr:=position [pos];
    For t1:=5 to 12 do channel [t1]:=False;
    ShowPattern (patternnr, pos, lastpos, looppos, startspeed);
    For t1:=5 to 12 do channel [t1]:=True;
    TrackPosition (pos);
    ch:=Readkey;
    CheckChangeValues;
    If (ch = '+') and (pos < 200) then Inc (pos);
    If (ch = '-') and (pos > 001) then Dec (pos);
    If ch = #0 then begin
      ch:=Readkey;
      If (ch = #82) then begin
        For t1:=200 downto pos + 1 do begin
          position [t1]:=position [t1 - 1];
        End;
        position [pos]:=1;
      End;
      If (ch = #83) then begin
        For t1:=pos to 200 do begin
          position [t1]:=position [t1 + 1];
        End;
        position [200]:=1;
      End;
      If (ch = #63) then begin
        For t1:=5 to 12 do channel [t1]:=False;
        PlaySong (False);
        For t1:=5 to 12 do channel [t1]:=True;
      End;
      If (ch = #64) then begin
        For t1:=5 to 12 do channel [t1]:=False;
        PlayPattern;
        For t1:=5 to 12 do channel [t1]:=True;
      End;
      If (ch = #80) and (pos < 200) then Inc (pos);
      If (ch = #72) and (pos > 001) then Dec (pos);
      If (ch = #81) and (pos < 200) then begin
        Inc (pos, 6);
        If pos > 200 then pos:=200;
      End;
      If (ch = #73) and (pos > 001) then begin
        Dec (pos, 6);
        If pos < 001 then pos:=001;
      End;
    End;
    If ((ch >= '0') and (ch <= '9')) then begin
      TextBackground (c. bc);
      Write (ch);
      s:=ch;
      Repeat ch:=Readkey; Until (ch = #27) or (ch = #13) or ((ch >= '0') and (ch <= '9'));
      If ((ch >= '0') and (ch <= '9')) then begin
        Write (ch);
        s:=s + ch;
      End;
      If ch <> #27 then position [pos]:=Val2 (s);
      If position [pos] > 60 then position [pos]:=60;
      If position [pos] < 01 then position [pos]:=01;
      Inc (pos);
      If pos > 200 then pos:=200;
      TextBackground (c. bg);
    End;
  Until (ch = #27) or (ch = #59);
  ShowScreen ('MAIN.SCR');
  ch:=#0;
  tracking:=False;
End;

Procedure SelectVoices;
Begin
  SilenceAll;
  ResetGM;
  SpecialBox (8, 4, 62, 21, 15, 'Select Instruments');
  Write ('ÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÂÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
  t2:=6;
  For t1:=caVoice - 7 to caVoice + 7 do begin
    GotoXY (41, t2);
    If (t1 > 0) and (t1 < 129) then begin
      Write (voicename [t1]);
      GotoXY (59, t2);
      For t4:=1 to 20 do if voicechange [t4] = t1 then begin
        GotoXY (59, t2);
        Write (ShowByte (t4, 2));
      End;
    End;
    Inc (t2);
  End;
  Repeat
    For t1:=2 to 15 do channel [t1]:=False;
    ShowPattern (position [pos], pos, lastpos, looppos, startspeed);
    For t1:=2 to 15 do channel [t1]:=True;
    For t1:=1 to 15 do begin
      GotoXY (09, t1 + 5);
      Write (ShowByte (t1, 2)); Write ('³ ');
      s:='                    ';
      If t1 <> csVoice then begin
        Write (voicename [startvoice [t1]] +
        Copy (s, 1, 20 - Length (voicename [startvoice [t1]])));
      End;
      GotoXY (34, t1 + 5);
      Write ('³'); Write (HexB (startvolume [t1]));
      Write ('³');
      If startmode [t1] = True then Write ('M') else Write ('P');
      Write ('³');
    End;
    GotoXY (13, csVoice + 5);
    TextBackground (c. bc);
    Write (voicename [startvoice [csVoice]] + Copy (s, 1, 20 - Length (voicename [startvoice [csVoice]])));
    TextBackground (c. bg);
    ch:=Readkey;
    CheckChangeValues;
    If ch = #32 then if startmode [csVoice] = True then startmode [csVoice]:=False else startmode [csVoice]:=True;
    For t1:=1 to 12 do begin
      s:=Copy (KeyB, t1, 1);
      If Upcase (ch) = s then begin
        SilenceChannel (0);
        SetInstrument (0, startvoice [csVoice] - 1);
        SetNoteOn (0, t1 + (octaaf * 12) - 1, 127);
      End;
    End;
    If (ch = '/') and (octaaf > 1) then Dec (Octaaf);
    If (ch = '*') and (octaaf < 7) then Inc (Octaaf);
    If ch = #0 then begin
      ch:=Readkey;
      If (ch = #73) and (startvolume [csVoice] < 63) then Inc (startvolume [csVoice]);
      If (ch = #81) and (startvolume [csVoice] > 00) then Dec (startvolume [csVoice]);
      If (ch = #72) and (csVoice > 1) then Dec (csVoice);
      If (ch = #80) and (csVoice < 15) then Inc (csVoice);
      If ch = #66 then SilenceAll;
    End;
    If (ch = #13) or (ch = #77) then begin
      Repeat
        t2:=6;
        For t1:=caVoice - 7 to caVoice + 7 do begin
          GotoXY (41, t2);
          s:='                     ';
          If t1 <> caVoice then begin
            If (t1 > 0) and (t1 < 129) then begin
              Write (voicename [t1] + Copy (s, 1, 21 - Length (voicename [t1])));
              For t4:=1 to 20 do if voicechange [t4] = t1 then begin
                GotoXY (59, t2);
                Write (ShowByte (t4, 2));
              End;
            End else begin
              GotoXY (41, t2);
              Write (s);
            End;
          End;
          Inc (t2);
        End;
        GotoXY (41, 13);
        TextBackground (c. bc);
        Write (Voicename [caVoice] + Copy (s, 1, 20 - Length (voicename [caVoice])));
        For t4:=1 to 20 do if voicechange [t4] = caVoice then begin
          GotoXY (59, 13);
          Write (ShowByte (t4, 2));
         End;
        TextBackground (c. bg);
        For t1:=2 to 15 do channel [t1]:=False;
        ShowPattern (position [pos], pos, lastpos, looppos, startspeed);
        For t1:=2 to 15 do channel [t1]:=True;
        ch:=Readkey;
        If (ch = '/') and (octaaf > 1) then Dec (Octaaf);
        If (ch = '*') and (octaaf < 7) then Inc (Octaaf);
        For t1:=1 to 12 do begin
          s:=Copy (KeyB, t1, 1);
          If Upcase (ch) = s then begin
            SilenceChannel (0);
            SetInstrument (0, caVoice - 1);
            SetNoteOn (0, t1 + (octaaf * 12) - 1, 127);
          End;
        End;
        If ch = #0 then begin
          ch:=Readkey;
          If ch = #66 then SilenceAll;
          If (ch = #72) and (caVoice > 1) then Dec (caVoice);
          If (ch = #80) and (caVoice < 128) then Inc (caVoice);
          If (ch = #73) then begin
            Dec (caVoice, 7);
            If caVoice < 1 then caVoice:=1;
          End;
          If (ch = #81) then begin
            Inc (caVoice, 7);
            If caVoice > 128 then caVoice:=128;
          End;
        End;
        If ch = #13 then startvoice [csVoice]:=caVoice;
        If ch = #32 then begin
          t3:=0;
          Repeat
            Inc (t3);
          Until (voicechange [t3] = caVoice) or (t3 > 20);
          If t3 < 21 then begin
            voicechange [t3]:=0;
          End else begin
            t3:=0;
            Repeat
              Inc (t3);
              If voicechange [t3] = 0 then begin
                voicechange [t3]:=caVoice;
                t3:=21;
              End;
            Until (t3 > 20);
          End;
        End;
        CheckChangeValues;
      Until (ch = #13) or (ch = #27) or (ch = #60) or (ch = #75);
      SilenceAll;
      GotoXY (41, 13);
      s:='                    ';
      Write (Voicename [caVoice] + Copy (s, 1, 20 - Length (voicename [caVoice])));
      For t4:=1 to 20 do if voicechange [t4] = caVoice then begin
        GotoXY (59, 13);
        Write (ShowByte (t4, 2));
      End;
    End;
  Until (ch = #27) or (ch = #60);
  SilenceAll;
  ch:=#0;
  ShowScreen ('MAIN.SCR');
End;

Procedure PlayNoteAudition;
Begin
  If history < 96 then begin
    SilenceAll;
    Case audition of
      1 : Begin
        For t1:=0 to 95 do SetNoteOff (0, t1, 127);
        SetInstrument (0, 0);
        SetNoteOn (0, history + 12, 127);
      End;
      2 : Begin
        For t1:=0 to 95 do SetNoteOff (0, t1, 127);
        SetInstrument (0, startvoice [x] - 1);
        SetNoteOn (0, history + 12, 127);
      End;
    End;
  End;
End;

Procedure FindFile;
Var
  DirInfo       : SearchRec;
  a             : Integer;
  Attr          : Word;

Begin
  For a:=0 to 212 do begin
    filename [a]:='';
    fileID [a]:=0;
  End;
  a:=1;
  FindFirst ('*.MTP', Anyfile, DirInfo);
  While DosError = 0 do
  begin
    filename [a]:=copy (DirInfo.Name, 1, length (DirInfo.Name));
    fileID [a]:=Anyfile;
    Inc (a);
    FindNext (DirInfo);
  End;
  FindFirst ('*.*', Directory, DirInfo);
  While DosError = 0 do
  begin
    Assign (f, DirInfo.Name);
    GetFAttr (f, Attr);
    If (Attr and Directory) <> 0 then begin
      filename [a]:=copy (DirInfo.Name, 1, length (DirInfo.Name));
      fileID [a]:=Directory;
      Inc (a);
    End;
    FindNext (DirInfo);
  End;
  For t1:=1 to 26 do begin
    s:=Chr (t1 + 64) + ':\';
    If ExistDir (s) then begin
      filename [a]:='[' + Chr (t1 + 64) + ':]';
      fileID [a]:=$81;
      a:=a + 1
    End;
  End;
  maxfiles:=a - 1;
End;

Procedure DiskError;
Begin
  FramedBox (24, 10, 50, 12, 15, True);
  Write (' Error reading drive');
  Sound (500); Delay (50); NoSound;
  chDir (MiGDir);
  ch:=Readkey;
  GotoXY (24, 10); Write ('                           ');
  GotoXY (24, 11); Write ('                           ');
  GotoXY (24, 12); Write ('                           ');
End;

Procedure ClearSong;
Begin
  For t1:=1 to 17 do playchannel [t1]:=True;
  For t1:=1 to 60 do position [t1]:=t1;
  For t1:=61 to 200 do position [t1]:=1;
  For t1:=1 to 20 do voicechange [t1]:=0;
  voicechange [1]:=1;
  pos:=1;
  For t1:=1 to 60 do for t2:=1 to 17 do for t3:=1 to 16 do begin
    pattern [t1, t2, t3]:=0;
  End;
  startspeed:=8;
  looppos:=0;
  lastpos:=60;
  songname:='MiGTracker Pro v1.3 (c) 1997/1998 MiG';
  For t1:=1 to 15 do begin
    channel [t1]:=True;
    startvoice [t1]:=1;
    startvolume [t1]:=63;
    startmode [t1]:=True;
  End;
  patternnr:=1;
End;

Procedure StoreData (temp : String);
Begin
  Assign (f, temp);
  ReWrite (f);
  For t1:=1 to 60 do for t2:=1 to 17 do for t3:=1 to 16 do begin
    WriteLn (f, pattern [t1, t2, t3]);
  End;
  For t1:=1 to 200 do WriteLn (f, position [t1]);
  WriteLn (f, looppos);
  WriteLn (f, lastpos);
  WriteLn (f, startspeed);
  WriteLn (f, Songname);
  For t1:=1 to 16 do begin
    WriteLn (f, startvoice [t1]);
    If startmode [t1] then t2:=1 else t2:=0;
    WriteLn (f, t2);
    WriteLn (f, startvolume [t1]);
  End;
  For t1:=1 to 20 do WriteLn (f, voicechange [t1]);
  Close (f);
  ch:=#27;
End;

Procedure ReStoreData (temp : String);
Begin
  ClearSong;
  Assign (f, temp);
  Reset (f);
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
    For t1:=2 to 20 do voicechange [t1]:=0;
    voicechange [1]:=1;
  End;
  Close (f);
  ch:=#27;
End;

Procedure SaveSong;
Var select : Integer;
Begin
  ChDir (TempDir);
  CursorOff;
  SpecialBox (16, 4, 54, 21, 15, 'Save Song');
  select:=1;
  Repeat
    FindFile;
    Repeat
      t1:=5;
      For t2:=select - 8 to select + 7 do begin
        GotoXY (25, t1);
        If t1 = 13 then TextBackground (c. bc) else TextBackground (c. bg);
        If t2 > 0 then begin
          Write (filename [t2]);
          For t4:=1 to 15 - Length (filename [t2]) do begin
            Write (' ');
          End;
        End else Begin
             Write ('                      ');
        End;
        If t2 > 0 then begin
          Case fileID [t2] of
            Directory : Write    ('<DIR>  ');
            Anyfile   : Write ('[Song] ');
            $81       : Write ('<Drive>');
            else        Write ('       ');
          End;
        End;
        Inc (t1);
      End;
      ch:=Readkey;
      CheckChangeValues;
      For t1:=3 to 13 do channel [t1]:=False;
      ShowPattern (position [pos], pos, lastpos, looppos, startspeed);
      For t1:=3 to 13 do channel [t1]:=True;
      If ch = #0 then begin
        ch:=Readkey;
        If (ch = #80) and (fileID [select + 1] > 0) then Inc (select);
        If (ch = #72) and (fileID [select - 1] > 0) then Dec (select);
        If (ch = #81) then for t1:=1 to 6 do if fileID [select + 1] > 0 then Inc (select);
        If (ch = #73) then for t1:=1 to 6 do if fileID [select - 1] > 0 then Dec (select);
      End;
      If (ch = #13) and (fileID [select] = $81) then begin
        Repeat
          s:=copy (filename [select], 2, 2) + '\';
          ChDir (s);
	  If IOresult > 0 then DiskError
        Until (IOResult = 0) or (ch = #27);
        If ch <> #27 then begin
          tempdir:=s;
          Findfile;
          select:=1;
        End else ChDir (TempDir);
        ch:=#255;
      End else If (ch = #13) and (fileID [select] = Anyfile) then begin
        s:=filename [select];
        FramedBox (20, 10, 50, 12, 15, True);
        Write (' Overwrite ' + s + ' ? Y/N');
        Repeat
          ch:=Upcase (Readkey);
        Until (ch = #27) or (ch = 'N') or (ch = 'Y');
        If ch = 'Y' then begin
          StoreData (s);
          ch:=#27;
        End else begin
          GotoXY (20, 10); Write ('                               ');
          GotoXY (20, 11); Write ('                               ');
          GotoXY (20, 12); Write ('                               ');
          ch:=#255;
        End;
      End else If (ch = #13) and (fileID [select] = Directory) then begin
        GetDir (0, tempdir);
        If (length (tempdir) > 4) then Chdir (filename [select]) else begin
          If filename [select] <> '..' then Chdir (filename [select]);
        End;
        select:=1;
      End;
      If ch = #32 then begin
        Repeat
          FramedBox (20, 10, 50, 13, 15, False);
          Write (' Enter name (empty=abort)');
          GotoXY (22, 12); Write ('>         .MTP');
          GotoXY (23, 12);
          CursorOn;
          s:='';
          ReadLn (s);
          If s <> '' then begin
            CursorOff;
            Assign (f, s + '.MTP');
            Rewrite (f);
            WriteLn (f, 'MiGTracker Pro');
            Close (f);
            If IOresult > 0 then ch:=#255;
          End;
        Until ch = #32;
        If s <> '' then StoreData (s + '.MTP');
        ch:=#27;
      End;
    Until (ch = #27) or (ch = #62) or (ch = #13);
  Until (ch = #255) or (ch = #27) or (ch = #62);
  GetDir (0, tempdir);
  ChDir (MiGDir);
  ShowScreen ('MAIN.SCR');
  If ch = #0 then ch:=Readkey;
  ch:=#255;
End;

Procedure LoadSong;
Var select : Integer;
Begin
  ChDir (TempDir);
  CursorOff;
  SpecialBox (16, 4, 54, 21, 15, 'Load Song');
  select:=1;
  Repeat
    FindFile;
    Repeat
      t1:=5;
      For t2:=select - 8 to select + 7 do begin
        GotoXY (25, t1);
        If t1 = 13 then TextBackground (c. bc) else TextBackground (c. bg);
        If t2 > 0 then begin
          Write (filename [t2]);
          For t4:=1 to 15 - Length (filename [t2]) do begin
            Write (' ');
          End;
        End else Begin
             Write ('                      ');
        End;
        If t2 > 0 then begin
          Case fileID [t2] of
            Directory : Write    ('<DIR>  ');
            Anyfile   : Write ('[Song] ');
            $81       : Write ('<Drive>');
            else        Write ('       ');
          End;
        End;
        Inc (t1);
      End;
      ch:=Readkey;
      CheckChangeValues;
      For t1:=3 to 13 do channel [t1]:=False;
      ShowPattern (position [pos], pos, lastpos, looppos, startspeed);
      For t1:=3 to 13 do channel [t1]:=True;
      If ch = #0 then begin
        ch:=Readkey;
        If (ch = #80) and (fileID [select + 1] > 0) then Inc (select);
        If (ch = #72) and (fileID [select - 1] > 0) then Dec (select);
        If (ch = #81) then for t1:=1 to 6 do if fileID [select + 1] > 0 then Inc (select);
        If (ch = #73) then for t1:=1 to 6 do if fileID [select - 1] > 0 then Dec (select);
      End;
      If (ch = #13) and (fileID [select] = $81) then begin
        Repeat
          s:=copy (filename [select], 2, 2) + '\';
          ChDir (s);
	  If IOresult > 0 then DiskError;
        Until (IOResult = 0) or (ch = #27);
        If ch <> #27 then begin
          tempdir:=s;
          Findfile;
          select:=1;
        End else ChDir (TempDir);
        ch:=#255;
      End else If (ch = #13) and (fileID [select] = Anyfile) then begin
        s:=filename [select];
        ReStoreData (s);
        patternnr:=position [pos];
        ch:=#27;
      End else If (ch = #13) and (fileID [select] = Directory) then begin
        GetDir (0, tempdir);
        If (length (tempdir) > 4) then Chdir (filename [select]) else begin
          If filename [select] <> '..' then Chdir (filename [select]);
        End;
        select:=1;
      End;
    Until (ch = #27) or (ch = #61) or (ch = #13);
  Until (ch = #255) or (ch = #27) or (ch = #61);
  GetDir (0, tempdir);
  ChDir (MiGDir);
  ShowScreen ('MAIN.SCR');
  If ch = #0 then ch:=Readkey;
  ch:=#255;
End;

Procedure Sleep (k : Word);
Begin
  If not keypressed then begin
    For k:=1 to k do begin
      WaitForRetrace;
    End;
  End;
End;

procedure IntroScreen;
Var pl : Array [0..255 , 1..3] of Byte;
    r, g, b : Byte;
begin
  write ('Loading...');
  setmode (MODE200, 0, 0);
  showpage (1);
  usepage (0);
  Load_PCX (0, 0, 319, 199, 'introscr');
  for t1:=0 to 255 do
    getpal (t1, pl [t1, 1], pl [t1, 2], pl [t1, 3]);
  for t1:=0 to 255 do
    setpal (t1, 0, 0, 0);
  showpage (0);
  for t1:=255 downto 1 do
  begin
    setPal (t1, pl [t1, 1], pl [t1, 2], pl [t1, 3]);
    delay (1)
  end;
  t1:=0;
  while (t1 < 400) and not keypressed do
  begin
    inc (t1);
    waitforretrace;
  end;
  if t1 > 200 then
  begin
    for t2:=1 to 63 do
    begin
      for t1:=1 to 255 do
      begin
        setpal (t1, pl [t1, 1], pl [t1, 2], pl [t1, 3]);
        for t3:=1 to 3 do
        begin
          inc (pl [t1, t3]);
          if pl [t1, t3] > 63 then
            pl [t1, t3]:=63;
        end
      end;
      if not keypressed then
        waitforretrace;
    end;
    for t1:=63 downto 1 do
    begin
      for t2:=1 to 255 do
        setpal (t2, t1, t1, t1);
      sleep (1)
    end
  end;
  settextmode;
end;

Begin
  IntroScreen;
  dmastop;
  if keypressed then
    ch:=readkey;
  equnr:=139;
  { schermkleuren }
  assign (f, 'mtrkpro.cfg');
  reset (f);
    read (f, s);
    read (f, c. bg);
    read (f, c. fg);
    read (f, c. bc);
    read (f, c. ac);
  close (f);
  TextColor (c. fg);
  TextBackground (c. bg);
  Cursor ($0D, $0E);
  EquFont;
  GetDir (0, MiGDir);
  ResetGm;
  niceeffect:=false;
  octaaf:=4;
  csVoice:=1;
  caVoice:=1;
  Assign (f, 'GMLIST.TXT');
  Reset (f);
  For t1:=1 to 128 do ReadLn (f, voicename [t1]);
  Close (f);
  clearscreen;
  audition:=2;
  settingscan:=True;
  ClearSong;
  clearscreen;
  ShowScreen ('MAIN.SCR');
  x:=1;
  y:=1;
  Repeat
    TextBackground (c. bg);
    block. inside:=False;
    ShowPattern (patternnr, pos, lastpos, looppos, startspeed);
    For t1:=1 to 15 do begin
      GotoXY (t1 * 4, 4);
      If not playchannel [t1] then Write ('OFF') else Write ('C' + ShowByte (t1, 2));
    End;
    GotoXY (64, 4);
    If not playchannel [16] then Write ('OF') else Write ('D1');
    GotoXY (67, 4);
    If not playchannel [17] then Write ('OF') else Write ('D2');
    CursorOn;
    x1:=0; x2:=0; y1:=0; y2:=0;
    If (patternnr >= block. sp) and (patternnr <= block. ep) then begin
      y1:=1;
      y2:=16;
      If patternnr = block. sp then y1:=block. sy;
      If patternnr = block. ep then y2:=block. ey;
      x1:=block. sx;
      x2:=block. ex;
    End;
    If (x >= x1) and (x <= x2) and (y >= y1) and (y <= y2)
    and (patternnr >= block. sp) and (patternnr <= block. ep) then begin
      TextBackground (c. bc);
      block. inside:=True;
    End;
    If x < 16 then GotoXY (x * 4, y + 4) else GotoXY (61 + (x - 15) * 3 + 1, y + 4);
    ch:=Readkey;
    if (ch = #22) then
    begin
      if niceeffect then
        niceeffect:=false
      else
        niceeffect:=true;
      show_song_variables (patternnr, pos, lastpos, looppos, startspeed)
    end;
    if (ch = #42) then
    begin
      if c. bg = 1 then
      begin
        c. bg:=00;
        c. fg:=15;
        c. ac:=14;
        c. bc:=01;
      end
      else
      begin
        c. bg:=01;
        c. fg:=15;
        c. ac:=14;
        c. bc:=04;
      end;
      assign (f, 'mtrkpro.cfg');
      rewrite (f);
        writeln (f, 'MiGTracker Configuration File');
        writeln (f, c. bg);
        writeln (f, c. fg);
        writeln (f, c. bc);
        writeln (f, c. ac);
      close (f);
      textbackground (c. bg);
      textcolor (c. fg);
      clearscreen;
      showscreen ('main.scr')
    end;
    If (ch = #3) then begin
      Assign (f, 'BUFFER.TMP');
      ReWrite (f);
      WriteLn (f, block. ex - block. sx + 1);
      For t1:=block. sp to block. ep do begin
        y1:=1;
        y2:=16;
        x1:=block. sx;
        x2:=block. ex;
        If t1 = block. sp then y1:=block. sy;
        If t1 = block. ep then y2:=block. ey;
        For t2:=y1 to y2 do begin
          For t3:=x1 to x2 do begin
            WriteLn (f, pattern [t1, t3, t2]);
          End;
          If (t1 = block. ep) and (t2 = block. ey) and (t3 = block. ex) then WriteLn (f, 255) else WriteLn (f, 254);
        End;
      End;
      Close (f);
      Assign (f, 'BUFFER.TMP');
      Reset (f);
      ReadLn (f, t3);
      y2:=patternnr;
      x1:=x;
      y1:=y;
      Repeat
        t1:=1;
        For t1:=1 to t3 do ReadLn (f, pattern [y2, (x1 - 1) + t1, y1]);
        Inc (y1);
        If y1 > 16 then begin
          y1:=1;
          y2:=y2 + 1;
        End;
        ReadLn (f, t2);
      Until (t2 = 255) or (IOresult <> 0) or (y2 > 60);
      Close (f);
      ch:=#255;
    End;
    If ch = #2 then with block do begin
      sx:=x;
      sy:=y;
      sp:=patternnr;
    End;
    If ch = #5 then with block do begin
      ex:=x;
      ey:=y;
      ep:=patternnr;
    End;
    If x > 15 then begin
      If ch = #13 then begin
        pattern [patternnr, x, y]:=drumhis;
        If (drumhis < 97) and (audition > 0) then SetNoteOn (9, drumhis, 127);
        y:=y + 1;
        IF y > 16 then y:=1;
      End;
      If (Upcase (ch) = 'V') then begin
        GotoXY (61 + (x - 15) * 3,  y + 4); Write ('V');
        Repeat
          ch:=Upcase (Readkey);
        Until (ch = #27) or ((ch >= '0') and (ch <= '9')) or ((ch >= 'A') and (ch <= 'F'));
        If ch <> #27 then begin
          s:='0' + ch;
          Write (ch);
          pattern [patternnr, x, y]:=HexCode (s) + 96;
          drumhis:=HexCode (s) + 96;
          Inc (y);
          If y > 16 then y:=1;
        End;
        ch:=#255;
      End;
      If ((ch >= '0') and (ch <= '9')) or ((Upcase (ch) >= 'A') and (Upcase (ch) <= 'F')) then begin
        ch:=Upcase (ch);
        GotoXY (61 + (x - 15) * 3,  y + 4); Write ('0' + ch);
        s:=ch;
        Repeat
          ch:=Upcase (Readkey);
        Until (ch = #27) or (ch = #13) or ((ch >= '0') and (ch <= '9')) or ((ch >= 'A') and (ch <= 'F'));
        If ch <> #27 then begin
          If ch = #13 then begin
            s:='0' + s;
            pattern [patternnr, x, y]:=HexCode (s);
            drumhis:=HexCode (s);
            If audition > 0 then SetNoteOn (9, HexCode (s), 127);
          End else begin
            s:=s + ch;
            t1:=HexCode (s);
            If t1 > 96 then t1:=96;
            pattern [patternnr, x, y]:=t1;
            drumhis:=t1;
            If audition > 0 then SetNoteOn (9, HexCode (s), 127)
          End;
          Inc (y);
          If y > 16 then y:=1;
        End;
        ch:=#255;
      End;
    End;
    If x < 16 then begin
      ch:=Upcase (ch);
      If ch = #13 then begin
        pattern [patternnr, x, y]:=history;
        PlayNoteAudition;
        Inc (y);
        If y > 16 then y:=1;
      End;
      If ch = 'O' then begin
        pattern [patternnr, x, y]:=96;
        Inc (y);
        If y > 16 then y:=16;
        history:=96;
      End;
      If (ch > #64) and (ch < #72) then begin
        t1:=Ord (ch);
        Write (ch);
        s:=ch;
        Repeat
          ch:=Readkey;
        Until (ch = #27) or ((ch > #48) and (ch < #57)) or ((ch = #35) and (s <> 'E') and (s <> 'B'));
        If (ch <> #27) then begin
          If ch = #35 then begin
            Write (ch);
            s:=s + ch;
            Repeat
              ch:=Readkey;
            Until (ch = #27) or ((ch > #48) and (ch < #57));
            If ch <> #27 then begin
              Write (ch);
              s:=s + ch;
            End;
          End else begin
            Write (' ' + ch);
            s:=s + ' ' + ch;
          End;
        End;
        If ch <> #27 then begin
          t2:=0;
          For t1:=1 to 12 do If Copy (s, 1, 2) = note [t1] then t2:=t1 - 1;
          pattern [patternnr, x, y]:=(Val2 (Copy (s, 3, 1)) - 1) * 12 + t2;
          history:=pattern [patternnr, x, y];
          Inc (y);
          PlayNoteAudition;
          If y > 16 then y:=1;
        End;
        ch:=#255;
      End;
    End;
    CheckChangeValues;
    If (ch = '+') and (pos < 200) then begin
      Inc (pos);
      patternnr:=position [pos];
    End;
    If (ch = '-') and (pos > 001) then begin
      Dec (pos);
      patternnr:=position [pos];
    End;
    If (Upcase (ch) = 'M') then begin
      Write ('M ');
      Repeat
        ch:=Readkey
      Until (ch = #27) or ((ch >= '0') and (ch <= '9'));
      If ch <> #27 then begin
        Write (ch);
        pattern [patternnr, x, y]:=161 + Val2 (ch);
        history:=161 + Val2 (ch);
        Inc (y);
        If y > 16 then y:=1;
      End;
      ch:=#255;
    End;
    If (ch = ',') or (ch = '.') or (ch = '<') or (ch = '>') then begin
      If block. inside then begin
        For t1:=block. sp to block. ep do begin
          y1:=1;
          y2:=16;
          x1:=block. sx;
          x2:=block. ex;
          If t1 = block. sp then y1:=block. sy;
          If t1 = block. ep then y2:=block. ey;
          For t2:=y1 to y2 do for t3:=x1 to x2 do begin
            Case ch of
              ',' : t4:=-1;
              '.' : t4:=1;
              '<' : t4:=-12;
              '>' : t4:=12;
            End;
            number:=pattern [t1, t3, t2];
            If (number < 96) and (number > 0) then begin
              number:=number + t4;
              If number > 96 then number:=96;
            End;
            pattern [t1, t3, t2]:=number;
          End;
        End;
        ch:=#255;
      End;
    End;
    If (Upcase (ch) = 'R') then begin
      Write ('R ');
      Repeat
        ch:=Readkey
      Until (ch = #27) or ((ch >= '0') and (ch <= '9'));
      If ch <> #27 then begin
        Write (ch);
        pattern [patternnr, x, y]:=171 + Val2 (ch);
        history:=171 + Val2 (ch);
        Inc (y);
        If y > 16 then y:=1;
      End;
      ch:=#255;
    End;
    If (Upcase (ch) = 'S') then begin
      Write ('S ');
      Repeat
        ch:=Readkey
      Until (ch = #27) or ((ch >= '0') and (ch <= '9'));
      If ch <> #27 then begin
        Write (ch);
        pattern [patternnr, x, y]:=181 + Val2 (ch);
        history:=181 + Val2 (ch);
        Inc (y);
        If y > 16 then y:=1;
      End;
      ch:=#255;
    End;
    If (Upcase (ch) = 'T') then begin
      Write ('T');
      Repeat ch:=Readkey Until (ch = '+') or (ch = '-') or (ch = #27);
      If ch <> #27 then begin
        Write (ch);
        s:=ch;
        Repeat
          ch:=Upcase (Readkey);
        Until (ch = #27) or ((ch >= '0') and (ch <= '9')) or ((ch >= 'A') and (ch <= 'F'));
        If ch <> #27 then begin
          Write (ch);
          If s = '-' then begin
            pattern [patternnr, x, y]:=192 + HexCode ('0'+ ch);
            history:=192 + HexCode ('0' + ch);
          End else begin
            pattern [patternnr, x, y]:=209 + HexCode ('0' + ch);
            history:=209 + HexCode ('0' + ch);
          End;
          Inc (y);
          If y > 16 then y:=1;
        End;
        ch:=#255;
      End;
    End;
    If ch = '/' then begin
      If ch = '/' then pattern [patternnr, x, y]:=191;
      history:=191;
      Inc (y);
      If y > 16 then y:=1;
    End;
    If (Upcase (ch) = 'V') then begin
      Write ('V');
      Repeat
        ch:=Readkey
      Until (ch = #27) or ((ch >= '0') and (ch <= '3'));
      s:=ch;
      Write (ch);
      If ch <> #27 then begin
        Repeat
          ch:=Upcase (Readkey);
        Until (ch = #27) or ((ch >= '0') and (ch <= '9')) or ((ch >= 'A') and (ch <= 'F'));
        Write (ch);
        s:=s + ch;
        If ch <> #27 then begin
          t1:=HexCode (s) + 97;
          pattern [patternnr, x, y]:=t1;
          history:=t1;
          Inc (y);
          If y > 16 then y:=1;
        End;
      End;
      ch:=#255;
    End;
    If (Upcase (ch) = 'I') then begin
      Write ('I');
      Repeat
        ch:=Readkey
      Until (ch = #27) or ((ch >= '0') and (ch <= '3'));
      s:=ch;
      Write (ch);
      If ch <> #27 then begin
        Repeat
          ch:=Upcase (Readkey);
        Until (ch = #27) or ((ch >= '0') and (ch <= '9'));
        Write (ch);
        s:=s + ch;
        If ch <> #27 then begin
          t1:=Val2 (s) + 225;
          If t1 > 245 then t1:=245;
          pattern [patternnr, x, y]:=t1;
          history:=t1;
          Inc (y);
          If y > 16 then y:=1;
        End;
      End;
      ch:=#255;
    End;
    If ch = #0 then begin
      ch:=Readkey;
      If ch = #16 then begin
        clearscreen;
        Halt;
      End;
      If (ch = #116) and (patternnr < 200) then Inc (patternnr);
      If (ch = #115) and (patternnr > 001) then Dec (patternnr);
      If ch = #77 then begin
        Inc (x);
        If x > 17 then x:=1;
      End;
      If (ch = #75) then begin
        Dec (x);
        If x < 1 then x:=17;
      End;
      If (ch = #80) then begin
        Inc (y);
        If y > 16 then y:=1;
      End;
      If (ch = #72) then begin
        Dec (y);
        If y < 1 then y:=16;
      End;
      If ch = #83 then begin
        If block. inside then begin
          TextBackground (c. bg);
          FramedBox (25, 10, 45, 12, 15, False);
          Write (' Delete block ? Y/N');
          Repeat
            ch:=Upcase (Readkey);
          Until (ch = #27) or (ch = 'N') or (ch = 'Y');
          If ch = 'Y' then begin
            For t1:=block. sp to block. ep do begin
              y1:=1;
              y2:=16;
              x1:=block. sx;
              x2:=block. ex;
              If t1 = block. sp then y1:=block. sy;
              If t1 = block. ep then y2:=block. ey;
              For t2:=y1 to y2 do for t3:=x1 to x2 do begin
                pattern [t1, t3, t2]:=0;
              End;
            End;
          End;
          ch:=#255;
        End else begin
          pattern [patternnr, x, y]:=0;
          Inc (y);
          If y > 16 then y:=1;
          history:=0;
        End;
      End;
      TextBackground (c. bg);
      If ch = #71 then begin x:=1; y:=1; end;
      If ch = #79 then begin x:=17; y:= 16; end;
      If ch = #59 then PatternPositionEditor;
      If ch = #60 then SelectVoices;
      If ch = #61 then LoadSong;
      If ch = #62 then SaveSong;
      If ch = #63 then PlaySong (False);
      If ch = #64 then PlayPattern;
      If ch = #65 then PlaySong (True);
      If ch = #66 then SilenceAll;
      If ch = #67 then begin
        TextBackground (c. bg);
        FramedBox (23, 10, 50, 12, 15, False);
        Write (' Clear entire song ? Y/N');
        Repeat
          ch:=Upcase (Readkey);
        Until (ch = #27) or (ch = 'N') or (ch = 'Y') or (ch = #67);
        If ch = 'Y' then ClearSong;
        ch:=#255;
      End;
      If ch = #68 then begin
        TextBackground (c. bg);
        clearscreen;
        ShowScreen ('HELP.SCR');
        ch:=Readkey; If ch = #0 then ch:=Readkey;
        clearscreen;
        ShowScreen ('MAIN.SCR');
        ch:=#255;
      End;
    End;
    If ch = #27 then begin
      Repeat
        Cursoroff;
        TextBackground (c. bg);
        ShowPattern (patternnr, pos, lastpos, looppos, startspeed);
        SpecialBox (8, 8, 41, 16, 15, ' Main Menu');
        option [1]:='File                       >';
        option [2]:='Options                    >';
        option [3]:='Pattern/position editor     ';
        option [4]:='Select instruments          ';
        option [5]:='Help                       >';
        option [6]:='';
        TextBackground (c. bg);
        t2:=1;
        Repeat
          t1:=1;
          Repeat
            GotoXY (10, t1 + 9);
            If t1 = t2 then TextBackground (c. bc) else TextBackground (c. bg);
            Write (option [t1]);
            Inc (t1);
          Until option [t1] = '';
          t4:=t1 - 1;
          ch:=Readkey;
          If ch = #0 then begin
            ch:=Readkey;
            If (ch = #80) and (t2 < t4) then Inc (t2);
            If (ch = #72) and (t2 > 01) then Dec (t2);
          End;
          If (ch = #13) or (ch = #77) then begin
            If t2 = 1 then begin
              { Submenu file}
              option [1]:='New               ';
              option [2]:='Load song         ';
              option [3]:='Save song         ';
              option [4]:='Quit              ';
              option [5]:='';
              SpecialBox (38, 9, 60, 15, 15, ' File Menu');
              t2:=1;
              Repeat
                t1:=1;
                Repeat
                  GotoXY (40, t1 + 10);
                  If t1 = t2 then TextBackground (c. bc) else TextBackground (c. bg);
                  Write (option [t1]);
                  Inc (t1);
                Until option [t1] = '';
                t4:=t1 - 1;
                ch:=Readkey;
                If ch = #0 then begin
                  ch:=Readkey;
                  If (ch = #80) and (t2 < t4) then Inc (t2);
                  If (ch = #72) and (t2 > 01) then Dec (t2);
                End;
                If (ch = #13) and (t2 = 1) then begin
                  TextBackground (c. bg);
                  FramedBox (23, 10, 50, 12, 15, False);
                  Write (' Clear entire song ? Y/N');
                  Repeat
                    ch:=Upcase (Readkey);
                  Until (ch = #27) or (ch = 'N') or (ch = 'Y') or (ch = #67);
                  If ch = 'Y' then ClearSong;
                  ch:=#27;
                End else if (ch = #13) and (t2 = 2) then begin
                  ShowPattern (patternnr, pos, lastpos, looppos, startspeed);
                  LoadSong;
                  ch:=#13;
                End else if (ch = #13) and (t2 = 3) then begin
                  ShowPattern (patternnr, pos, lastpos, looppos, startspeed);
                  SaveSong;
                  ch:=#13;
                End else if (ch = #13) and (t2 = 4) then begin
                  CursorOff;
                  TextBackground (c. bg);
                  FramedBox (20, 10, 50, 12, 15, False);
                  Write (' Quit MiGTracker Pro ? Y/N');
                  Repeat
                    ch:=Upcase (Readkey);
                  Until (ch = #27) or (ch = 'N') or (ch = 'Y');
                  If ch = 'Y' then begin
                    ResetGM;
                    clearscreen;
                    GotoXY (1, 1);
                    Write ('Thank you for using MiGTracker Pro...');
                    Halt;
                  End else if ch = 'N' then ch:=#27;
                End;
              Until (ch = #27) or (ch = #13);
              If ch = #27 then ch:=#255;
            End else if t2 = 2 then begin
              { Submenu playback options}
              option [1]:='Modify last position ';
              option [2]:='Modify loop position ';
              option [3]:='Modify speed         ';
              option [4]:='Settingscan on/off   ';
              option [5]:='Modify noteaudition  ';
              option [6]:='Enter Songname       ';
              option [7]:='';
              SpecialBox (38, 10, 63, 18, 15, ' Playback Options');
              t2:=1;
              Repeat
                t1:=1;
                Repeat
                  GotoXY (40, t1 + 11);
                  If t1 = t2 then TextBackground (c. bc) else TextBackground (c. bg);
                  Write (option [t1]);
                  Inc (t1);
                Until option [t1] = '';
                t4:=t1 - 1;
                ch:=Readkey;
                If ch = #0 then begin
                  ch:=Readkey;
                  If (ch = #80) and (t2 < t4) then Inc (t2);
                  If (ch = #72) and (t2 > 01) then Dec (t2);
                End;
                If (ch = #13) and (t2 = 1) then SetLastPos
                Else if (ch = #13) and (t2 = 2) then SetLoopPos
                Else if (ch = #13) and (t2 = 3) then SetStartSpeed
                Else if (ch = #13) and (t2 = 4) then begin
                  GotoXY (39, 22);
                  If settingscan then settingscan:=False else settingscan:=True;
                  If settingscan then Write ('On ') else Write ('Off');
                End else if (ch = #13) and (t2 = 5) then SetNoteAudition
                Else if (ch = #13) and (t2 = 6) then begin
                  CursorOn;
                  SetSongname;
                  CursorOff;
                End;
              Until (ch = #27);
              If ch = #27 then ch:=#255;
            End else if t2 = 3 then begin
              ShowPattern (patternnr, pos, lastpos, looppos, startspeed);
              PatternpositionEditor;
              ch:=#13;
            End else if t2 = 4 then begin
              ShowPattern (patternnr, pos, lastpos, looppos, startspeed);
              SelectVoices;
              ch:=#13;
            End else if t2 = 5 then begin
              { Submenu help}
              option [1]:='Help screen      ';
              option [2]:='About            ';
              option [3]:='';
              SpecialBox (38, 9, 63, 13, 15, ' Help Menu');
              t2:=1;
              Repeat
                t1:=1;
                Repeat
                  GotoXY (40, t1 + 10);
                  If t1 = t2 then TextBackground (c. bc) else TextBackground (c. bg);
                  Write (option [t1]);
                  Inc (t1);
                Until option [t1] = '';
                t4:=t1 - 1;
                ch:=Readkey;
                If ch = #0 then begin
                  ch:=Readkey;
                  If (ch = #80) and (t2 < t4) then Inc (t2);
                  If (ch = #72) and (t2 > 01) then Dec (t2);
                End;
                If (ch = #13) and (t2 = 1) then begin
                  TextBackground (c. bg);
                  clearscreen;
                  ShowScreen ('HELP.SCR');
                  ch:=Readkey; If ch = #0 then ch:=Readkey;
                  clearscreen;
                  ShowScreen ('MAIN.SCR');
                  ch:=#13;
                End else if (ch = #13) and (t2 = 2) then begin
                  SpecialBox (23, 11, 60, 17, 15, 'About');
                  FWrite (32, 13, 'MiGTracker Pro v1.3', 16 * c. bg + c. ac);
                  FWrite (32, 14, ' (c) 1997/1998 MiG ', 16 * c. bg + c. fg);
                  FWrite (26, 16, ' Code: Jer Der   Grafix: Tracer  ', 16 * c. bg + c. ac);
                  ch:=Readkey;
                End;
              Until (ch = #27) or (ch = #13);
              If ch = #27 then ch:=#255;
            End;
          End;
        Until (ch = #27) or (ch = #13) or (ch = #255);
      Until (ch = #27) or (ch = #13);
    End;
  Until ch > #255;
  ResetGM;
End.