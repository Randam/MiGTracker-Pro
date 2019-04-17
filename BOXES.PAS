
Unit Boxes;

Interface

Uses
  Crt, Crt2, U_Txt;  { in SWAG .. set CRT.SWG }

Procedure SingleFrame (X1, Y1, X2, Y2, At : Byte);
Procedure DoubleFrame (X1, Y1, X2, Y2, At : Byte);
Procedure FramedBox (X1, Y1, X2, Y2, At : Byte; Single : Boolean);
Procedure SpecialFrame (X1, Y1, X2, Y2, At : Byte; Title : String);
Procedure SpecialBox (X1, Y1, X2, Y2, At : Byte; Title : String);
Procedure Box (X1, Y1, X2, Y2 : Byte; C : Char; var At : Byte);

type
  colors = record
    fg : byte;
    bg : byte;
    bc : byte;
    ac : byte
  end;

var
  c : colors;

Implementation

Procedure SingleFrame (X1, Y1, X2, Y2, At : Byte);
Var
  A : Byte;
Begin
  at:=16 * c. bg + c. fg;
  CursorOff;
  FWrite (X1, Y1, #218, At);
  FWrite (X1, Y2, #192, At);
  FWrite (X2, Y1, #191, At);
  FWrite (X2, Y2, #217, At);
  For A := (X1 + 1) To (X2 - 1) Do
    Begin
      FWrite (A, Y1, #196, At);
      FWrite (A, Y2, #196, At);
    End;
  For A := (Y1 + 1) To (Y2 - 1) Do
    Begin
      FWrite (X1, A, #179, At);
      FWrite (X2, A, #179, At);
    End;
  GotoXY (x1 + 1, y1 + 1);
End;

Procedure Box (X1, Y1, X2, Y2 : Byte; C : Char; var At : Byte);
Var
  A, B : Byte;
Begin
  CursorOff;
  For A := Y1 To Y2 Do Begin
      For B := X1 To X2 Do FWrite (B, A, C, at);
  End;
  GotoXY (x1 + 1, y1 + 1);
End;

Procedure DoubleFrame (X1, Y1, X2, Y2, At : Byte);
Var
  A : Byte;
Begin
  at:=16 * c. bg + c. fg;
  CursorOff;
  FWrite (X1, Y1, #201, At);
  FWrite (X1, Y2, #200, At);
  FWrite (X2, Y1, #187, At);
  FWrite (X2, Y2, #188, At);
  For A := (X1 + 1) To (X2 - 1) Do
    Begin
      FWrite (A, Y1, #205, At);
      FWrite (A, Y2, #205, At);
    End;
  For A := (Y1 + 1) To (Y2 - 1) Do
    Begin
      FWrite (X1, A, #186, At);
      FWrite (X2, A, #186, At);
    End;
End;

Procedure FramedBox (X1, Y1, X2, Y2, At : Byte; Single : Boolean);
Begin
  at:=16 * c. bg + c. fg;
  CursorOff;
  Box (X1 - 1, Y1, X2 + 1, Y2, #32, At);
  If Single Then
    SingleFrame (X1, Y1, X2, Y2, At)
  Else
    DoubleFrame (X1, Y1, X2, Y2, At);
  GotoXY (x1 + 1, y1 + 1);
End;

Procedure SpecialFrame (X1, Y1, X2, Y2, At : Byte; Title : String);
Var
  A : Byte;
Begin
  at:=16 * c. bg + c. fg;
  CursorOff;
  FWrite (X1, Y1, #201, At);
  FWrite (X1, Y2, #200, At);
  FWrite (X2, Y1, #187, At);
  FWrite (X2, Y2, #188, At);
  For A := (X1 + 1) To (X2 - 1) Do
    FWrite (A, Y2, #205, At);
  For A := (Y1 + 1) To (Y2 - 1) Do
    Begin
      FWrite (X1, A, #186, At);
      FWrite (X2, A, #186, At);
    End;
  FWrite (X1 + 1, Y1, #181, At);
  FWrite (X2 - 1, Y1, #198, At);
  For A := (X1 + 2) To (X2 - 2) Do
    FWrite (A, Y1, #32, 16 * c. bc + c. fg);
  FWrite ((X2 - X1 - Length(Title)) div 2 + X1, Y1, Title, 16 * c. bc + c. fg);
  GotoXY (x1 + 1, y1 + 1);
End;

Procedure SpecialBox (X1, Y1, X2, Y2, At : Byte; Title : String);
Begin
  at:=16 * c. bg + c. fg;
  CursorOff;
  Box (X1 - 1, Y1, X2 + 1, Y2, #32, At);
  SpecialFrame (X1, Y1, X2, Y2, At, Title);
  GotoXY (x1 + 1, y1 + 1);
End;

End.

