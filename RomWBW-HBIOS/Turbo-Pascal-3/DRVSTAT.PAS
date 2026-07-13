program DrvStat;

const
  { Update 1: these three constants replace what used to be hardcoded
    Drive=0/1/2 checks buried in the print logic below. Edit these three
    to match YOUR system's "Configuring Drives..." boot banner -- this
    part still isn't auto-detected (no verified way to query the real
    HBIOS unit name string back from the drive), so it remains a manual
    one-time edit rather than something that adapts itself. }
  BOOT_DRIVE = 0;   { drive index (0=A:, 1=B:, ...) that boots as SD0:0 (Boot) }
  RAM_DRIVE  = 1;   { drive index that maps to MD0:0 (RAM)                    }
  ROM_DRIVE  = 2;   { drive index that maps to MD1:0 (ROM)                    }

  { This offset assumes exactly 2 non-SD drives (RAM+ROM) come before the
    SD-backed drives start at slice 0 -- true on this machine's layout,
    but edit if yours differs (e.g. only 1 non-SD drive, or 3). }
  SD_SLICE_OFFSET = 2;

  { Update 2: reverted the Update-1 attempt at dynamic drive detection.
    Checking BdosHL(14, Drive)'s return value doesn't work as a safety
    check -- BDOS's OWN error handler for Select Disk fires immediately
    on an invalid drive (printing "Bdos Err On x: Select" and aborting),
    before this program ever gets control back to check anything. This
    was confirmed on real hardware: it crashed at drive O:, recoverable
    only via Ctrl-C.

    Honestly, I don't fully understand the exact BDOS/CBIOS interaction
    here well enough to trust a clever workaround -- there's probably a
    genuinely safe way to detect this, but I don't know it for certain,
    so rather than guess again on real hardware, this just goes back to
    a manual, known-safe cutoff. Edit this constant to match how many
    drives YOUR system actually has configured (count the letters in
    your own "Configuring Drives..." boot banner). }
  MAX_CONFIGURED_DRIVE = 13;   { 0-indexed: 13 = N: is the last real drive on this machine }

type
  Registers = record
    AX, BX, CX, DX, BP, SI, DI, DS, ES, Flags: Integer;
  end;
  { Explicit string size required for TP3 (Error 8 otherwise) }
  TLabelStr = string[20];

var
  Regs: Registers;
  Drive: Integer;
  DpbAddr, AlvAddr: Integer;
  Dsm, BlkSize, FreeBlocks, TotalBlocks: Integer;
  I, ByteIdx, BitIdx: Integer;
  AlvByte: Byte;
  TotalSize, FreeSize, UsedSize: Real;
  TargetStr: TLabelStr;
  SliceStr: string[4];

{ Update 3: replaces the old hand-counted-trailing-spaces approach, which
  had an off-by-SD_SLICE_OFFSET bug -- the branch checked "Drive >= 10"
  (the drive LETTER position) when it should have checked whether the
  computed slice number itself was double-digit, so K:/L: (single-digit
  slices 8/9) got the padding meant for double-digit slices and landed
  one character short. Padding to a fixed width in one place, after the
  fact, avoids this whole category of bug regardless of how many digits
  any part of the label has. }
procedure PadRight(var S: TLabelStr; Width: Integer);
begin
  while Length(S) < Width do S := S + ' ';
end;

begin
  WriteLn;
  { Perfectly aligned column headers }
  WriteLn('Drv  HBIOS Target       Total Space   Used Space   Free Space');
  WriteLn('---  ----------------   -----------   ----------   ----------');

  for Drive := 0 to 15 do
  begin
    if Drive <= MAX_CONFIGURED_DRIVE then
    begin
      Bdos(14, Drive);
      DpbAddr := BdosHL(31, 0);
      AlvAddr := BdosHL(27, 0);

      if (DpbAddr <> 0) and (AlvAddr <> 0) and (DpbAddr <> $FFFF) then
      begin
        { Pull structural properties out of the DPB block }
        BlkSize := (Mem[DpbAddr + 3] + 1) * 128;
        Dsm := (Mem[DpbAddr + 6] SHL 8) or Mem[DpbAddr + 5];
        TotalBlocks := Dsm + 1;

        { Loop through Allocation Vector map to find zero-bits (unallocated space) }
        FreeBlocks := 0;
        for I := 0 to (Dsm div 8) do
        begin
          AlvByte := Mem[AlvAddr + I];
          for BitIdx := 0 to 7 do
          begin
            if ((AlvByte SHL BitIdx) and $80) = 0 then
              FreeBlocks := FreeBlocks + 1;
          end;
        end;

        { Safety ceiling check for trailing padding bits in the map byte }
        if FreeBlocks > TotalBlocks then FreeBlocks := TotalBlocks;

        { Calculate true floating-point capacity allocations via Reals }
        TotalSize := (TotalBlocks * 1.0 * BlkSize) / 1024.0;
        FreeSize  := (FreeBlocks  * 1.0 * BlkSize) / 1024.0;
        UsedSize  := TotalSize - FreeSize;

        { Print drive letter with consistent alignment }
        Write(' ', Chr(65 + Drive), ':  ');

        { Build target label, then pad to a fixed width -- see PadRight above }
        if Drive = BOOT_DRIVE then TargetStr := 'SD0:0    (Boot)'
        else if Drive = RAM_DRIVE then TargetStr := 'MD0:0    (RAM)'
        else if Drive = ROM_DRIVE then TargetStr := 'MD1:0    (ROM)'
        else
        begin
          Str(Drive - SD_SLICE_OFFSET, SliceStr);
          TargetStr := 'SD0:' + SliceStr;
        end;
        PadRight(TargetStr, 19);
        Write(TargetStr);

        { Print metric data columns using right-aligned spacing layout (Value:Width:Precision) }
        WriteLn(TotalSize:7:0, ' KB ', UsedSize:12:0, ' KB ', FreeSize:12:0, ' KB');
      end;
    end;
  end;
end.
