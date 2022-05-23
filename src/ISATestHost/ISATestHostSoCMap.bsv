import PGRV::*;
import AddressMap::*;

typedef FabricAddress#(XLEN) SocAddress;
typedef TileId#(4)           SocTileId;
typedef AddressMap#(4, XLEN) SocAddressMap;

module mkISATestHostSoCMap(SocAddressMap);
    SocTileId  _crossbarId = 15;

    SocAddress _clintBase = 0;
    SocAddress _clintSize = 0;
    SocAddress _clintEnd  = 0;
    SocTileId  _clintId   = 3;

    SocAddress _uart0Base = 0;
    SocAddress _uart0Size = 0;
    SocAddress _uart0End  = 0;
    SocTileId  _uart0Id   = 4;

    SocAddress _rom0Base  = 0;
    SocAddress _rom0Size  = 0;
    SocAddress _rom0End   = 0;
    SocTileId  _rom0Id    = 0;

    SocAddress _ram0Base  = 'h8000_0000;
    SocAddress _ram0Size  = 'h4000_0000;     // 1G
    SocAddress _ram0End   = _ram0Base + _ram0Size;
    SocTileId  _ram0Id    = 5;

    method SocTileId crossbarId = _crossbarId;

    method SocAddress clintBase = _clintBase;
    method SocAddress clintSize = _clintSize;
    method SocAddress clintEnd  = _clintEnd;
    method SocTileId  clintId   = _clintId;

    method SocAddress uart0Base = _uart0Base;
    method SocAddress uart0Size = _uart0Size;
    method SocAddress uart0End  = _uart0End;
    method SocTileId uart0Id    = _uart0Id;

    method SocAddress rom0Base  = _rom0Base;
    method SocAddress rom0Size  = _rom0Size;
    method SocAddress rom0End   = _rom0End;
    method SocTileId rom0Id     = _rom0Id;

    method SocAddress ram0Base  = _ram0Base;
    method SocAddress ram0Size  = _ram0Size;
    method SocAddress ram0End   = _ram0End;
    method SocTileId ram0Id     = _ram0Id;
endmodule
