Program Tryout;
Uses GmUnit, Crt;
Begin
  ResetGm;
  SetChorus (0, 0);
  SetNoteOn (0, 64, 127);
  Readkey;
  SetNoteOff (0, 64, 127);
  ResetGm;
End.