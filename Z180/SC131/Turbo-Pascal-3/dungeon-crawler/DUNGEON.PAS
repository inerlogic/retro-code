program Dungeon;

const
  MAP_SIZE = 18; 
  X_OFFSET = 2;
  Y_OFFSET = 2;

type
  { Locked: Explicit string sizes prevent Error 8 }
  TString    = string[35];
  TMapArray  = array[1..MAP_SIZE, 1..MAP_SIZE] of Char;
  TBoolMap   = array[1..MAP_SIZE, 1..MAP_SIZE] of Boolean;
  
  TScoreRecord = record
    Name  : string[10];
    Value : Integer;
  end;
  TScoreTable = array[1..5] of TScoreRecord;
  TScoreFile  = file of TScoreRecord;

var
  Map: TMapArray;
  Revealed: TBoolMap; 
  PlayerX, PlayerY: Integer;
  PrevPlayerX, PrevPlayerY: Integer;
  HP, Coins, FloorLevel: Integer;
  RandSeed: Integer;
  Ch: Char;
  GameOver: Boolean;
  
  HighScores: TScoreTable;
  ScoreFile: TScoreFile;

procedure AnsiCmd(Cmd: TString);
begin
  Write(Chr(27), '[', Cmd);
end;

function GetRndRange(MaxVal: Integer): Integer;
begin
  if (RandSeed and 1) <> 0 then
    RandSeed := (RandSeed shr 1) xor $A1A1
  else
    RandSeed := RandSeed shr 1;
  GetRndRange := (Abs(RandSeed) mod MaxVal) + 1;
end;

procedure DrawTile(X, Y: Integer);
begin
  GotoXY(X_OFFSET + (X * 2), Y_OFFSET + Y);
  
  if not Revealed[X, Y] then
  begin
    AnsiCmd('0m');
    Write('  ');
  end
  else
  begin
    case Map[X, Y] of
      '#': begin AnsiCmd('40;37m'); Write('##'); end;
      '.': begin AnsiCmd('0m');     Write('..'); end;
      '@': begin AnsiCmd('1;33m');  Write(' @'); end;
      '$': begin AnsiCmd('1;32m');  Write('$$'); end;
      'C': begin AnsiCmd('1;35m');  Write('[?]');end;
      'M': begin AnsiCmd('1;31m');  Write('%%'); end;
      '>': begin AnsiCmd('1;36m');  Write('><'); end;
    end;
  end;
  AnsiCmd('0m');
end;

procedure RenderSidebar;
begin
  GotoXY(X_OFFSET + 40, Y_OFFSET + 1);  Write('=== CP/M PROCEDURAL DUNGEON ==='); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 3);  Write('FLOOR LAYER : ', FloorLevel); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 5);  Write('HERO HEALTH : ', HP, ' / 10 HP'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 6);  Write('GOLD COINS  : ', Coins, ' c'); ClrEol;
  
  GotoXY(X_OFFSET + 40, Y_OFFSET + 9);  Write('TACTICAL NAVIGATION:'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 11); Write('  W : Move North    S : Move South'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 12); Write('  A : Move West     D : Move East'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 14); Write('  Q : Retire / Abandon Run'); ClrEol;
  
  GotoXY(X_OFFSET + 40, Y_OFFSET + 16); Write('LEGEND:'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 17); Write('  @  Hero      ## Wall      .. Floor'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 18); Write('  $$ Coin      [?] Chest    %% Monster'); ClrEol;
  
  GotoXY(X_OFFSET + 40, Y_OFFSET + 20); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 21); ClrEol;
end;

function MonstersCleared: Boolean;
var
  X, Y: Integer;
  FoundAny: Boolean;
begin
  FoundAny := False;
  for Y := 2 to MAP_SIZE - 1 do
    for X := 2 to MAP_SIZE - 1 do
      if Map[X, Y] = 'M' then FoundAny := True;
  MonstersCleared := not FoundAny;
end;

function FloorFullySearched: Boolean;
var
  X, Y: Integer;
  UnsearchedFound: Boolean;
begin
  UnsearchedFound := False;
  for Y := 2 to MAP_SIZE - 1 do
    for X := 2 to MAP_SIZE - 1 do
    begin
      if (Map[X, Y] <> '#') and (not Revealed[X, Y]) then
        UnsearchedFound := True;
    end;
  FloorFullySearched := not UnsearchedFound;
end;

procedure IlluminateDungeon;
var
  X, Y: Integer;
begin
  for Y := 1 to MAP_SIZE do
    for X := 1 to MAP_SIZE do
    begin
      if not Revealed[X, Y] then
      begin
        Revealed[X, Y] := True;
        DrawTile(X, Y);
      end;
    end;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 20);
  Write('MAP FULLY REVEALED!'); ClrEol;
end;

procedure UpdateFogOfWar;
var
  NX, NY, TargetX, TargetY: Integer;
  Changed: Boolean;
begin
  Changed := False;
  for NY := -2 to 2 do
    for NX := -2 to 2 do
    begin
      TargetX := PlayerX + NX;
      TargetY := PlayerY + NY;
      if (TargetX >= 1) and (TargetX <= MAP_SIZE) and
         (TargetY >= 1) and (TargetY <= MAP_SIZE) then
      begin
        if not Revealed[TargetX, TargetY] then
        begin
          Revealed[TargetX, TargetY] := True;
          DrawTile(TargetX, TargetY);
          Changed := True;
        end;
      end;
    end;

  if Changed and FloorFullySearched then
    IlluminateDungeon;
end;

procedure RenderScreen;
var X, Y: Integer;
begin
  for Y := 1 to MAP_SIZE do
    for X := 1 to MAP_SIZE do DrawTile(X, Y);
  RenderSidebar;
end;

procedure GenerateDungeon;
var
  X, Y, Steps, MaxSteps, Dir, MinerX, MinerY: Integer;
begin
  for Y := 1 to MAP_SIZE do
    for X := 1 to MAP_SIZE do
    begin
      Map[X, Y] := '#';
      Revealed[X, Y] := False; 
    end;

  MinerX := MAP_SIZE div 2;
  MinerY := MAP_SIZE div 2;
  Map[MinerX, MinerY] := '.';
  
  Steps := 0;
  MaxSteps := 100; 
  while Steps < MaxSteps do
  begin
    Dir := GetRndRange(4);
    case Dir of
      1: if MinerY > 3 then MinerY := MinerY - 1;
      2: if MinerY < (MAP_SIZE - 2) then MinerY := MinerY + 1;
      3: if MinerX > 3 then MinerX := MinerX - 1;
      4: if MinerX < (MAP_SIZE - 2) then MinerX := MinerX + 1;
    end;
    
    if Map[MinerX, MinerY] = '#' then
    begin
      Map[MinerX, MinerY] := '.';
      Steps := Steps + 1;
    end;
  end;

  for X := 1 to MAP_SIZE do
  begin
    Map[X, 1] := '#'; Map[X, MAP_SIZE] := '#';
    Map[1, X] := '#'; Map[MAP_SIZE, X] := '#';
    Revealed[X, 1] := True; Revealed[X, MAP_SIZE] := True;
    Revealed[1, X] := True; Revealed[MAP_SIZE, X] := True;
  end;

  PlayerX := MAP_SIZE div 2;
  PlayerY := MAP_SIZE div 2;
  Map[PlayerX, PlayerY] := '@';

  Steps := 0;
  while Steps < 5 do
  begin
    X := GetRndRange(MAP_SIZE - 4) + 2;
    Y := GetRndRange(MAP_SIZE - 4) + 2;
    if Map[X, Y] = '.' then
    begin
      Map[X, Y] := '$';
      Steps := Steps + 1;
    end;
  end;
  
  Steps := 0;
  while Steps < 2 do
  begin
    X := GetRndRange(MAP_SIZE - 4) + 2;
    Y := GetRndRange(MAP_SIZE - 4) + 2;
    if Map[X, Y] = '.' then
    begin
      Map[X, Y] := 'C';
      Steps := Steps + 1;
    end;
  end;

  Steps := 0;
  while Steps < 3 do
  begin
    X := GetRndRange(MAP_SIZE - 4) + 2;
    Y := GetRndRange(MAP_SIZE - 4) + 2;
    if Map[X, Y] = '.' then
    begin
      Map[X, Y] := 'M';
      Steps := Steps + 1;
    end;
  end;
  
  Steps := 0;
  while Steps < 1 do
  begin
    X := GetRndRange(MAP_SIZE - 4) + 2;
    Y := GetRndRange(MAP_SIZE - 4) + 2;
    if Map[X, Y] = '.' then
    begin
      Map[X, Y] := '>'; 
      Steps := Steps + 1;
    end;
  end;
end;

procedure ProcessMerchant;
var
  ShopCh: Char;
  Done: Boolean;
begin
  Done := False;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 9);  Write('*** TRAVELING MERCHANT SHOP ***'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 11); Write('POTION: Restores 2 HP (Cost: 10 c)'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 12); Write('Your Stash: ', Coins, ' c | Health: ', HP, '/10'); ClrEol;
  { Update 3: clear this line explicitly -- ResolveMonsterCombat writes its
    "[F] Fight (Roll 1-6 Die)" prompt here, and since ProcessMerchant is
    called right after combat with no ClrScr in between, that stale text
    was bleeding through onto the merchant screen. }
  GotoXY(X_OFFSET + 40, Y_OFFSET + 13); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 14); Write('  [Y] Buy Potion    [N] Leave Shop'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 16); Write('-------------------------------------'); ClrEol;

  while not Done do
  begin
    repeat until KeyPressed;
    Read(Kbd, ShopCh);
    ShopCh := UpCase(ShopCh);

    if ShopCh = 'N' then 
      Done := True
    else if ShopCh = 'Y' then
    begin
      if Coins < 10 then
      begin
        GotoXY(X_OFFSET + 40, Y_OFFSET + 18); Write('ERROR: Not enough coins!'); ClrEol;
      end
      else if HP >= 10 then
      begin
        GotoXY(X_OFFSET + 40, Y_OFFSET + 18); Write('ERROR: Health is already full!'); ClrEol;
      end
      else
      begin
        Coins := Coins - 10;
        HP := HP + 2;
        if HP > 10 then HP := 10;
        GotoXY(X_OFFSET + 40, Y_OFFSET + 12); 
        Write('Your Stash: ', Coins, ' c | Health: ', HP, '/10'); ClrEol;
        GotoXY(X_OFFSET + 40, Y_OFFSET + 18); 
        Write('Gulp! Bought an HP Potion!'); ClrEol;
      end;
    end;
  end;
end;

procedure ResolveMonsterCombat(TX, TY: Integer);
var
  MonsterTier, HeroRoll: Integer;
  CombatOver: Boolean;
  InputCh: Char;
begin
  MonsterTier := GetRndRange(5);
  CombatOver := False;

  GotoXY(X_OFFSET + 40, Y_OFFSET + 9);  Write('BATTLE ENCOUNTER!'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 11); Write('Monster Tier Challenge: ', MonsterTier); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 12); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 13); Write('  [F] Fight (Roll 1-6 Die)'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 14); Write('  [R] Run Away (Retreat)'); ClrEol;
  GotoXY(X_OFFSET + 40, Y_OFFSET + 16); Write('-------------------------------------'); ClrEol;

  while not CombatOver do
  begin
    GotoXY(X_OFFSET + 40, Y_OFFSET + 5);  Write('HERO HEALTH : ', HP, ' / 10 HP'); ClrEol;
    GotoXY(X_OFFSET + 40, Y_OFFSET + 18); Write('Choose Battle Choice: '); ClrEol;

    repeat until KeyPressed;
    Read(Kbd, InputCh);
    InputCh := UpCase(InputCh);

    if InputCh = 'R' then
    begin
      Map[PlayerX, PlayerY] := '.';
      DrawTile(PlayerX, PlayerY);
      PlayerX := PrevPlayerX;
      PlayerY := PrevPlayerY;
      Map[PlayerX, PlayerY] := '@';
      DrawTile(PlayerX, PlayerY);
      CombatOver := True;
    end
    else if InputCh = 'F' then
    begin
      HeroRoll := GetRndRange(6);
      GotoXY(X_OFFSET + 40, Y_OFFSET + 18); Write('You rolled a: [ ', HeroRoll, ' ]'); ClrEol;

      if HeroRoll >= MonsterTier then
      begin
        Coins := Coins + 1;
        Map[TX, TY] := '.'; 
        DrawTile(TX, TY); 
        GotoXY(X_OFFSET + 40, Y_OFFSET + 20); Write('VICTORY! Monster Slain (+1 coin)'); ClrEol;
        Delay(1000);
        CombatOver := True;
      end
      else
      begin
        HP := HP - 1;
        GotoXY(X_OFFSET + 40, Y_OFFSET + 20); Write('DEFEAT! You take 1 point damage!'); ClrEol;
        Delay(1000);
        if HP <= 0 then
        begin
          GameOver := True;
          CombatOver := True;
        end;
      end;
    end;
  end;
  RenderSidebar;
end;

procedure MovePlayer(DX, DY: Integer);
var
  TargetX, TargetY: Integer;
begin
  TargetX := PlayerX + DX;
  TargetY := PlayerY + DY;

  if Map[TargetX, TargetY] <> '#' then
  begin
    PrevPlayerX := PlayerX;
    PrevPlayerY := PlayerY;

    { Intercept items and resolve their immediate actions }
    if Map[TargetX, TargetY] = '$' then
    begin
      Coins := Coins + 1;
      Map[TargetX, TargetY] := '.'; { Cleanly erase a COIN from memory since you collected it }
    end;
    
    if Map[TargetX, TargetY] = 'C' then
    begin
      HP := HP + 2;
      if HP > 10 then HP := 10;
      Map[TargetX, TargetY] := '.'; { Cleanly erase a CHEST from memory since it has been opened }
    end;

    if Map[TargetX, TargetY] = 'M' then
    begin
      Revealed[TargetX, TargetY] := True;
      DrawTile(TargetX, TargetY);
      ResolveMonsterCombat(TargetX, TargetY);
      if GameOver then Exit;
      if Map[TargetX, TargetY] = 'M' then Exit; 
    end;
    
    if Map[TargetX, TargetY] = '>' then
    begin
      if not MonstersCleared then
      begin
        GotoXY(X_OFFSET + 40, Y_OFFSET + 20);
        Write('ALL MONSTERS MUST BE DEFEATED!'); ClrEol;
        { Soft-Lock: No Exit here! Let the code proceed so you can walk onto it, }
        { but do NOT erase or clear the '>' symbol from memory! }
      end
      else
      begin
        ProcessMerchant; 
        FloorLevel := FloorLevel + 1;
        GenerateDungeon;
        ClrScr;
        RenderScreen;
        UpdateFogOfWar;
        Exit;
      end;
    end;

    { Core Fix: Remove the blind 'Map[PlayerX, PlayerY] := .' line! }
    { If the cell you are stepping off of is STILL marked as stairs, leave it alone! }
    if Map[PlayerX, PlayerY] = '@' then
      Map[PlayerX, PlayerY] := '.';

    { Render the tile you are vacating so it redraws its TRUE underlying symbol }
    DrawTile(PlayerX, PlayerY);

    { Advance your player hero position }
    PlayerX := TargetX;
    PlayerY := TargetY;
    
    { Store your symbol temporarily in a dedicated screen swap variable }
    { We do NOT write '@' to the permanent map array unless we leave a footprint, }
    { preserving special static structures underneath you! }
    GotoXY(X_OFFSET + (PlayerX * 2), Y_OFFSET + PlayerY);
    AnsiCmd('1;33m'); Write(' @'); AnsiCmd('0m');
    
    UpdateFogOfWar;
    
    { Force-draw your character space one final time to anchor visibility }
    GotoXY(X_OFFSET + (PlayerX * 2), Y_OFFSET + PlayerY);
    AnsiCmd('1;33m'); Write(' @'); AnsiCmd('0m');
    
    { Clear out alert lines if you step clean off a blocked staircase }
    if Map[PlayerX, PlayerY] = '.' then
    begin
      GotoXY(X_OFFSET + 40, Y_OFFSET + 20); 
      Write('                              '); ClrEol;
    end;
    
    GotoXY(X_OFFSET + 54, Y_OFFSET + 5); Write(HP, ' / 10 HP ');
    GotoXY(X_OFFSET + 54, Y_OFFSET + 6); Write(Coins, ' c  ');
  end;
end;


procedure LoadScores;
var I: Integer;
begin
  Assign(ScoreFile, 'DUNGEON.DAT');
  {$I-} Reset(ScoreFile); {$I+}
  if IOResult = 0 then
  begin
    for I := 1 to 5 do Read(ScoreFile, HighScores[I]);
    Close(ScoreFile);
  end
  else
  begin
    { Fixed array indices mapped with clean internal spacing }
    HighScores[1].Name := 'KNIGHT    '; HighScores[1].Value := 50;
    HighScores[2].Name := 'ROGUE     '; HighScores[2].Value := 35;
    HighScores[3].Name := 'WIZARD    '; HighScores[3].Value := 20;
    HighScores[4].Name := 'PALADIN   '; HighScores[4].Value := 10;
    HighScores[5].Name := 'PEASANT   '; HighScores[5].Value := 2;
  end;
end;

procedure PrintScoreboard;
var I: Integer;
begin
  WriteLn;
  WriteLn('   ====== DUNGEON HALL OF FAME ======');
  WriteLn;
  for I := 1 to 5 do
    WriteLn('     ', I, '. ', HighScores[I].Name, ' : ', HighScores[I].Value, ' coins');
  WriteLn;
  WriteLn('   ==================================');
  WriteLn;
end;

procedure ProcessEndGameScores;
var
  I, J: Integer;
  TempName: string[10]; 
  Temp: TScoreRecord;
begin
  LoadScores;
  ClrScr;
  if HP <= 0 then
    WriteLn('You fell in battle on Floor ', FloorLevel, '...')
  else
    WriteLn('You successfully retired from your run!');
    
  WriteLn('Final Score: ', Coins, ' coins.');

  if Coins > HighScores[5].Value then
  begin
    WriteLn;
    WriteLn('A Legendary Loot Run! You ranked in the Top 5!');
    Write('Enter Name (max 10 chars): ');
    ReadLn(TempName);
    while Length(TempName) < 10 do TempName := TempName + ' ';
    
    HighScores[5].Name := Copy(TempName, 1, 10);
    HighScores[5].Value := Coins;
    
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

begin
  ClrScr;
  Randomize; 
  RandSeed := Trunc(Random * 32000); 
  
  HP := 10; Coins := 0; FloorLevel := 1;
  GameOver := False;

  GenerateDungeon;
  RenderScreen;
  UpdateFogOfWar; 

  while not GameOver do
  begin
    if KeyPressed then
    begin
      Read(Kbd, Ch);
      case UpCase(Ch) of
        'W': MovePlayer(0, -1);
        'S': MovePlayer(0, 1);
        'A': MovePlayer(-1, 0);
        'D': MovePlayer(1, 0);
        'Q': GameOver := True;
      end;
    end;
  end;

  ProcessEndGameScores;
end.
