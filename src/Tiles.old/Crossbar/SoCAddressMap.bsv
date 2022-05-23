import PGTypes::*;

interface SoCAddressMap;
    (* always_ready *) method TileId crossbarId;

    (* always_ready *) method FabricAddress clintBase;
    (* always_ready *) method FabricAddress clintSize;
    (* always_ready *) method FabricAddress clintEnd;
    (* always_ready *) method TileId clintId;

    (* always_ready *) method FabricAddress uart0Base;
    (* always_ready *) method FabricAddress uart0Size;
    (* always_ready *) method FabricAddress uart0End;
    (* always_ready *) method TileId uart0Id;

    (* always_ready *) method FabricAddress rom0Base;
    (* always_ready *) method FabricAddress rom0Size;
    (* always_ready *) method FabricAddress rom0End;
    (* always_ready *) method TileId rom0Id;

    (* always_ready *) method FabricAddress ram0Base;
    (* always_ready *) method FabricAddress ram0Size;
    (* always_ready *) method FabricAddress ram0End;
    (* always_ready *) method TileId ram0Id;
endinterface
