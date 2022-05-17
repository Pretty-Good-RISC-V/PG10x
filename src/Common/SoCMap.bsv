import PGTypes::*;
import SoCAddressMap::*;

module mkSoCAddressMap(SoCAddressMap);
    TileId        _crossbarId = 15;

    FabricAddress _clintBase = 'h0020_0000;
    FabricAddress _clintSize = 'h0000_1000;     // 4K
    FabricAddress _clintEnd  = _clintBase + _clintSize;
    TileId        _clintId   = 3;

    FabricAddress _uart0Base = 'h0020_1000;
    FabricAddress _uart0Size = 'h0000_1000;     // 4K
    FabricAddress _uart0End  = _uart0Base + _uart0Size;
    Integer       _uart0Id   = 4;

    FabricAddress _rom0Base  = 'h0040_0000;
    FabricAddress _rom0Size  = 'h0800_0000;     // 128M
    FabricAddress _rom0End   = _rom0Base + _rom0Size;
    TileId        _rom0Id    = 5;

    FabricAddress _ram0Base  = 'h8000_0000;
    FabricAddress _ram0Size  = 'h4000_0000;     // 2G
`ifdef RV32
    FabricAddress _ram0End   = (_ram0Base - 1) + _ram0Size;
`elsif RV64
    FabricAddress _ram0End   = _ram0Base + _ram0Size;
`endif
    TileId        _ram0Id    = 6;

    method TileId crossbarId = _crossbarId;

    method FabricAddress clintBase = _clintBase;
    method FabricAddress clintSize = _clintSize;
    method FabricAddress clintEnd  = _clintEnd;
    method TileId clintId          = _clintId;

    method FabricAddress uart0Base = _uart0Base;
    method FabricAddress uart0Size = _uart0Size;
    method FabricAddress uart0End  = _uart0End;
    method Integer uart0Id         = _uart0Id;

    method FabricAddress rom0Base  = _rom0Base;
    method FabricAddress rom0Size  = _rom0Size;
    method FabricAddress rom0End   = _rom0End;
    method TileId rom0Id           = _rom0Id;

    method FabricAddress ram0Base  = _ram0Base;
    method FabricAddress ram0Size  = _ram0Size;
    method FabricAddress ram0End   = _ram0End;
    method TileId ram0Id           = _ram0Id;
endmodule
