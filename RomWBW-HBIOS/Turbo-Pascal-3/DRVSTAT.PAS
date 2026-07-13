program DrvStat;
type
  Registers = record
      AX, BX, CX, DX, BP, SI, DI, DS, ES, Flags: Integer;
        end;
        var
          Regs: Registers;
            Drive: Integer;
              DpbAddr, AlvAddr: Integer;
                Dsm, BlkSize, FreeBlocks, TotalBlocks: Integer;
                  I, ByteIdx, BitIdx: Integer;
                    AlvByte: Byte;
                      TotalSize, FreeSize, UsedSize: Real;
                      begin
                        WriteLn;
                          { Perfectly aligned column headers }
                            WriteLn('Drv  HBIOS Target       Total Space   Used Space   Free Space');
                              WriteLn('---  ----------------   -----------   ----------   ----------');

  for Drive := 0 to 15 do
    begin
        if Drive < 14 then
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

        { Print target field with absolute character spacing layout }
                if Drive = 0 then Write('SD0:0 (Boot)      ')
                        else if Drive = 1 then Write('MD0:0    (RAM)    ')
                                else if Drive = 2 then Write('MD1:0    (ROM)    ')
                                        else if Drive >= 10 then Write('SD0:', Drive - 2, '            ')
                                                else Write('SD0:', Drive - 2, '             ');

        { Print metric data columns using right-aligned spacing layout (Value:Width:Precision) }
                WriteLn(TotalSize:7:0, ' KB ', UsedSize:12:0, ' KB ', FreeSize:12:0, ' KB');
                      end;
                          end;
                            end;
                            end.
