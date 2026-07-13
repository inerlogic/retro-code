program Tetris84;

const
  BOARD_WIDTH  = 10;
  BOARD_HEIGHT = 20;
  X_OFFSET     = 2;
  Y_OFFSET     = 2;

type
  TBoard  = array[1..BOARD_WIDTH, 1..BOARD_HEIGHT] of Integer;
  TPiece  = array[1..4, 1..4] of Integer;

  { Explicit string sizes required for TP3 }
  TString = string[255];

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

procedure ClearScreen;
begin
  ClrScr;
end;

procedure GetPiece(PType: Integer; var P: TPiece);
var
  X, Y, CharIdx: Integer;
  ShapeStr: string[16]; { Explicitly sized to 16 characters }
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

procedure DrawBlock(X, Y, ColorID: Integer);
begin
  GotoXY(X_OFFSET + (X * 2), Y_OFFSET + Y);
  if ColorID = 0 then
    Write('  ')
  else
    Write('[]');
end;

procedure RedrawBoard;
var
  X, Y: Integer;
begin
  { Render the iconic 1984 wireframe walls }
  for Y := 0 to BOARD_HEIGHT do
  begin
    { Left Wall draws at Column 2 (occupies 2 and 3) }
    GotoXY(X_OFFSET, Y_OFFSET + Y); Write('<!');
    { Right Wall draws at Column 24 (occupies 24 and 25) }
    GotoXY(X_OFFSET + 2 + (BOARD_WIDTH * 2), Y_OFFSET + Y); Write('!>');
  end;

  { Render floor frame boundary (24 characters wide from Column 2 to 25) }
  GotoXY(X_OFFSET, Y_OFFSET + BOARD_HEIGHT + 1);
  Write('========================');

  { Draw current background matrix values }
  for Y := 1 to BOARD_HEIGHT do
    for X := 1 to BOARD_WIDTH do DrawBlock(X, Y, Board[X, Y]);

  { Balanced Sidebar Layout - Moved to Column 28 for safe margins }
  GotoXY(X_OFFSET + 28, Y_OFFSET + 2);  Write('SCORE: ', Score);
  GotoXY(X_OFFSET + 28, Y_OFFSET + 5);  Write('CONTROLS:');
  GotoXY(X_OFFSET + 28, Y_OFFSET + 7);  Write('  A : LEFT');
  GotoXY(X_OFFSET + 28, Y_OFFSET + 8);  Write('  D : RIGHT');
  GotoXY(X_OFFSET + 28, Y_OFFSET + 9);  Write('  W : ROTATE');
  GotoXY(X_OFFSET + 28, Y_OFFSET + 10); Write('  S : DROP');
  GotoXY(X_OFFSET + 28, Y_OFFSET + 12); Write('  Q : QUIT');
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
      Temp[2,1] := 1; Temp[2,2] := 1; Temp[2,3] := 1; Temp[2,4] := 1;
    end
    else
    begin
      Temp[1,2] := 1; Temp[2,2] := 1; Temp[3,2] := 1; Temp[4,2] := 1;
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
    case LinesCleared of
      1: Score := Score + 100;
      2: Score := Score + 300;
      3: Score := Score + 500;
      4: Score := Score + 800;
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
  Assign(ScoreFile, 'SOV1984.DAT');
  {$I-} Reset(ScoreFile); {$I+}
  if IOResult = 0 then
  begin
    for I := 1 to 5 do Read(ScoreFile, HighScores[I]);
    Close(ScoreFile);
  end
  else
  begin
    HighScores[1].Name := 'PAJITNOV  '; HighScores[1].Value := 2500;
    HighScores[2].Name := 'GERASIMOV '; HighScores[2].Value := 2000;
    HighScores[3].Name := 'Z180      '; HighScores[3].Value := 1500;
    HighScores[4].Name := 'CPM       '; HighScores[4].Value := 1000;
    HighScores[5].Name := 'PASCAL    '; HighScores[5].Value := 500;
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
  TempName: string[10]; 
  Temp: TScoreRecord;
begin
  LoadScores;
  ClearScreen;
  WriteLn('Game Over! Your Final Score: ', Score);

  if Score > HighScores[5].Value then
  begin
    WriteLn;
    WriteLn('Congratulations! You broke into the Top 5!');
    Write('Enter Name (max 10 chars): ');
    ReadLn(TempName);
    while Length(TempName) < 10 do TempName := TempName + ' ';

    HighScores[5].Name := Copy(TempName, 1, 10);
    HighScores[5].Value := Score;

    for I := 1 to 4 do
      for J := I + 1 to 5 do
        if HighScores[J].Value > HighScores[I].Value then
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
  Score := 0; GameOver := False; LoopCount := 0;
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
    
    Write('Play again? (Y/N): ');
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
