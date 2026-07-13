program Tetris;

const
  BOARD_WIDTH  = 10;
  BOARD_HEIGHT = 20;
  X_OFFSET     = 2;  
  Y_OFFSET     = 2;  

type
  TBoard  = array[1..BOARD_WIDTH, 1..BOARD_HEIGHT] of Integer;
  TPiece  = array[1..4, 1..4] of Integer;
  
  { Fixed for good: Explicit string sizes required for TP3 }
  TString = string[20]; 
  
  TScoreRecord = record
    Name  : string[10]; 
    Value : Integer;
  end;
  TScoreTable = array[1..5] of TScoreRecord;
  TScoreFile  = file of TScoreRecord;

var
  Board: TBoard;
  CurrentPiece: TPiece;
  PieceX, PieceY: Integer;
  PieceType: Integer;
  GameOver: Boolean;
  KeepPlaying: Boolean;
  Horizontal: Boolean;
  Score: Integer;
  LoopCount: Integer;
  Ch: Char;
  HighScores: TScoreTable;
  ScoreFile: TScoreFile;

procedure AnsiCmd(Cmd: TString);
begin
  Write(Chr(27), '[', Cmd);
end;

procedure ClearScreen;
begin
  ClrScr;
end;

procedure GetPiece(PType: Integer; var P: TPiece);
var
  X, Y, CharIdx: Integer;
  ShapeStr: string[16]; { Fixed local string size }
begin
  for Y := 1 to 4 do
    for X := 1 to 4 do P[X, Y] := 0;
  case PType of
    1: ShapeStr := '0000111100000000';
    2: ShapeStr := '0220022000000000';
    3: ShapeStr := '0300333000000000';
    4: ShapeStr := '0400040004400000';
    5: ShapeStr := '0050005005500000';
    6: ShapeStr := '0660660000000000';
    7: ShapeStr := '7700077000000000';
  else
    ShapeStr := '0000000000000000';
  end;
  CharIdx := 1;
  for Y := 1 to 4 do
    for X := 1 to 4 do
    begin
      if ShapeStr[CharIdx] <> '0' then
        P[X, Y] := Ord(ShapeStr[CharIdx]) - 48;
      CharIdx := CharIdx + 1;
    end;
end;

procedure ApplyColor(ID: Integer);
begin
  case ID of
    0: AnsiCmd('0m');      
    1: AnsiCmd('46;1m');   
    2: AnsiCmd('43;1m');   
    3: AnsiCmd('45;1m');   
    4: AnsiCmd('44;1m');   
    5: AnsiCmd('47;1m');   
    6: AnsiCmd('42;1m');   
    7: AnsiCmd('41;1m');   
    9: AnsiCmd('40;37m');  
  end;
end;

procedure DrawBlock(X, Y, ColorID: Integer);
begin
  GotoXY(X_OFFSET + (X * 2), Y_OFFSET + Y);
  ApplyColor(ColorID);
  if ColorID = 0 then Write('  ') else Write('[]');
  AnsiCmd('0m'); 
end;

procedure RedrawBoard;
var
  X, Y: Integer;
begin
  for Y := 0 to BOARD_HEIGHT do
  begin
    DrawBlock(0, Y, 9);
    DrawBlock(BOARD_WIDTH + 1, Y, 9);
  end;
  for X := 0 to BOARD_WIDTH + 1 do DrawBlock(X, BOARD_HEIGHT + 1, 9);

  for Y := 1 to BOARD_HEIGHT do
    for X := 1 to BOARD_WIDTH do DrawBlock(X, Y, Board[X, Y]);
    
  GotoXY(X_OFFSET + 28, Y_OFFSET + 1);  Write('SCORE: ', Score);
  GotoXY(X_OFFSET + 28, Y_OFFSET + 4);  Write('CONTROLS:');
  GotoXY(X_OFFSET + 28, Y_OFFSET + 6);  Write('A : Left   D : Right');
  GotoXY(X_OFFSET + 28, Y_OFFSET + 7);  Write('W : Rotate S : Drop');
  GotoXY(X_OFFSET + 28, Y_OFFSET + 9);  Write('Q : Quit Game');
end;

procedure DrawActivePiece(Clear: Boolean);
var
  X, Y: Integer;
begin
  for Y := 1 to 4 do
    for X := 1 to 4 do
      if CurrentPiece[X, Y] <> 0 then
        if (PieceY + Y - 1 >= 1) and (PieceX + X - 1 <= BOARD_WIDTH) then
          if Clear then
            DrawBlock(PieceX + X - 1, PieceY + Y - 1, 0)
          else
            DrawBlock(PieceX + X - 1, PieceY + Y - 1, CurrentPiece[X, Y]);
end;

function CheckCollision(NewX, NewY: Integer; Piece: TPiece): Boolean;
var
  X, Y, BX, BY: Integer;
  Collision: Boolean;
begin
  Collision := False;
  for Y := 1 to 4 do
    for X := 1 to 4 do
      if Piece[X, Y] <> 0 then
      begin
        BX := NewX + X - 1;
        BY := NewY + Y - 1;
        if (BX < 1) or (BX > BOARD_WIDTH) or (BY > BOARD_HEIGHT) then
          Collision := True
        else if BY >= 1 then
          if Board[BX, BY] <> 0 then Collision := True;
      end;
  CheckCollision := Collision;
end;

procedure RotatePiece;
var
  Temp: TPiece;
  X, Y: Integer;
begin
  if PieceType = 2 then Exit;
  for Y := 1 to 4 do
    for X := 1 to 4 do Temp[X, Y] := 0;
    
  if PieceType = 1 then
  begin
    { Update 2: fixed I-piece rotate needing to be pressed twice.
      Horizontal reflects the piece's CURRENT orientation, so a
      rotate press must build the OPPOSITE shape, not rebuild the
      one it already has. }
    if Horizontal then
    begin
      Temp[2,1]:=1; Temp[2,2]:=1; Temp[2,3]:=1; Temp[2,4]:=1;
    end
    else
    begin
      Temp[1,2]:=1; Temp[2,2]:=1; Temp[3,2]:=1; Temp[4,2]:=1;
    end;
  end
  else
  begin
    for Y := 1 to 3 do
      for X := 1 to 3 do Temp[4 - Y, X] := CurrentPiece[X, Y];
  end;
  
  if not CheckCollision(PieceX, PieceY, Temp) then
  begin
    DrawActivePiece(True); 
    CurrentPiece := Temp; 
    if PieceType = 1 then Horizontal := not Horizontal; 
    DrawActivePiece(False);
  end;
end;

procedure SpawnPiece;
begin
  PieceType := Random(7) + 1;
  GetPiece(PieceType, CurrentPiece);
  PieceX := (BOARD_WIDTH div 2) - 1; PieceY := 1;
  Horizontal := True;
  if CheckCollision(PieceX, PieceY, CurrentPiece) then GameOver := True;
end;

procedure LockPiece;
var
  X, Y, BX, BY: Integer;
begin
  for Y := 1 to 4 do
    for X := 1 to 4 do
      if CurrentPiece[X, Y] <> 0 then
      begin
        BX := PieceX + X - 1; BY := PieceY + Y - 1;
        if (BX >= 1) and (BX <= BOARD_WIDTH) and (BY >= 1) and (BY <= BOARD_HEIGHT) then
          Board[BX, BY] := CurrentPiece[X, Y];
      end;
end;

procedure ClearLines;
var
  X, Y, TargetY, LinesCleared: Integer;
  Full: Boolean;
  TempBoard: TBoard;
begin
  LinesCleared := 0;
  TargetY := BOARD_HEIGHT;
  for Y := 1 to BOARD_HEIGHT do
    for X := 1 to BOARD_WIDTH do TempBoard[X, Y] := 0;
  for Y := BOARD_HEIGHT downto 1 do
  begin
    Full := True;
    for X := 1 to BOARD_WIDTH do if Board[X, Y] = 0 then Full := False;
    if Full then
      LinesCleared := LinesCleared + 1
    else
    begin
      for X := 1 to BOARD_WIDTH do TempBoard[X, TargetY] := Board[X, Y];
      TargetY := TargetY - 1;
    end;
  end;
  if LinesCleared > 0 then
  begin
    Board := TempBoard;
        { Scale down and subtract points instead of adding }
    case LinesCleared of
      1: Score := Score - 10; { Single }
      2: Score := Score - 30; { Double }
      3: Score := Score - 50; { Triple }
      4: Score := Score - 80; { TETRIS! }
    end;

    RedrawBoard;
  end;
end;

procedure MovePiece(DX, DY: Integer);
begin
  if not CheckCollision(PieceX + DX, PieceY + DY, CurrentPiece) then
  begin
    DrawActivePiece(True); PieceX := PieceX + DX; PieceY := PieceY + DY; DrawActivePiece(False);
  end
  else if DY > 0 then
  begin
    LockPiece; ClearLines; SpawnPiece; RedrawBoard;
  end;
end;

procedure LoadScores;
var I: Integer;
begin
  Assign(ScoreFile, 'GOLF.DAT');
  {$I-} Reset(ScoreFile); {$I+}
  if IOResult = 0 then
  begin
    for I := 1 to 5 do Read(ScoreFile, HighScores[I]);
    Close(ScoreFile);
  end
    else
  begin
    HighScores[1].Name := 'PAJITNOV  '; HighScores[1].Value := 10000;
    HighScores[2].Name := 'Z180      '; HighScores[2].Value := 15000;
    HighScores[3].Name := 'CPM       '; HighScores[3].Value := 20000;
    HighScores[4].Name := 'PASCAL    '; HighScores[4].Value := 25000;
    HighScores[5].Name := 'ROOKIE    '; HighScores[5].Value := 30000;
  end;

end;

procedure PrintScoreboard;
var I: Integer;
begin
  WriteLn;
  WriteLn('   ====== LEADERBOARD ======');
  WriteLn;
  for I := 1 to 5 do
    WriteLn('     ', I, '. ', HighScores[I].Name, ' : ', HighScores[I].Value);
  WriteLn;
  WriteLn('   =========================');
  WriteLn;
end;

procedure ProcessEndGameScores;
var
  I, J: Integer;
  TempName: string[10]; { Fixed local string size }
  Temp: TScoreRecord;
begin
  LoadScores;
  ClearScreen;
  WriteLn('Game Over! Your Final Score: ', Score);

    { Golf Rules check: Lower final numbers beat the standing record }
  if Score < HighScores[5].Value then
  begin
    WriteLn;
    WriteLn('Congratulations! You broke into the Top 5!');
    { ... name capture blocks stay completely unchanged ... }
    
    { Flip the bubble sort comparison to sort from lowest to highest }
    for I := 1 to 4 do
      for J := I + 1 to 5 do
        if HighScores[J].Value < HighScores[I].Value then { <-- Flipped to < }
        begin
          Temp := HighScores[I]; HighScores[I] := HighScores[J]; HighScores[J] := Temp;
        end;

        
    Rewrite(ScoreFile);
    for I := 1 to 5 do Write(ScoreFile, HighScores[I]);
    Close(ScoreFile);
  end;
  PrintScoreboard;
end;

procedure Initialize;
var X, Y: Integer;
begin
  Score := 32767; { <-- Starts at the maximum theoretical limit }
  GameOver := False; LoopCount := 0;
  for Y := 1 to BOARD_HEIGHT do
    for X := 1 to BOARD_WIDTH do Board[X, Y] := 0;
  ClearScreen; RedrawBoard; SpawnPiece;
end;


begin
  Randomize;
  KeepPlaying := True;
  
  repeat
    Initialize;
    while not GameOver do
    begin
      if KeyPressed then
      begin
        Read(Kbd, Ch);
        case UpCase(Ch) of
          'A': MovePiece(-1, 0);
          'D': MovePiece(1, 0);
          'S': MovePiece(0, 1);
          'W': RotatePiece;
          'Q': GameOver := True;
        end;
      end;
      LoopCount := LoopCount + 1;
      if LoopCount >= 6000 then
      begin
        MovePiece(0, 1); LoopCount := 0;
      end;
    end;
    
    ProcessEndGameScores;
    
    Write('Would you like to play again? (Y/N): ');
    repeat
      if KeyPressed then
      begin
        Read(Kbd, Ch);
        Ch := UpCase(Ch);
      end;
    until (Ch = 'Y') or (Ch = 'N');
    WriteLn(Ch); 
    if Ch = 'N' then KeepPlaying := False;
  until not KeepPlaying;
  
  ClearScreen;
  WriteLn('Thanks for playing! Back to CP/M.');
end.
