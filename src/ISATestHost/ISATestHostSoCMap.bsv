import PGTypes::*;
import SoCAddressMap::*;

module mkISATestHostSoCMap(SoCAddressMap);
    TileId        _crossbarId = 15;

    FabricAddress _clintBase = 0;
    FabricAddress _clintSize = 0;
    FabricAddress _clintEnd  = 0;
    TileId        _clintId   = 3;

    FabricAddress _uart0Base = 0;
    FabricAddress _uart0Size = 0;
    FabricAddress _uart0End  = 0;
    TileId        _uart0Id   = 4;

    FabricAddress _rom0Base  = 0;
    FabricAddress _rom0Size  = 0;
    FabricAddress _rom0End   = 0;
    TileId        _rom0Id    = 0;

    FabricAddress _ram0Base  = 'h8000_0000;
    FabricAddress _ram0Size  = 'h4000_0000;     // 1G
    FabricAddress _ram0End   = _ram0Base + _ram0Size;
    TileId        _ram0Id    = 5;

    method TileId crossbarId = _crossbarId;

    method FabricAddress clintBase = _clintBase;
    method FabricAddress clintSize = _clintSize;
    method FabricAddress clintEnd  = _clintEnd;
    method TileId clintId          = _clintId;

    method FabricAddress uart0Base = _uart0Base;
    method FabricAddress uart0Size = _uart0Size;
    method FabricAddress uart0End  = _uart0End;
    method TileId uart0Id          = _uart0Id;

    method FabricAddress rom0Base  = _rom0Base;
    method FabricAddress rom0Size  = _rom0Size;
    method FabricAddress rom0End   = _rom0End;
    method TileId rom0Id           = _rom0Id;

    method FabricAddress ram0Base  = _ram0Base;
    method FabricAddress ram0Size  = _ram0Size;
    method FabricAddress ram0End   = _ram0End;
    method TileId ram0Id           = _ram0Id;
endmodule
