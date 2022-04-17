import RVCommon::*;
import Memory::*;
import TileLink::*;

import GetPut::*;

typedef Bit#(XLEN) Word;
typedef Bit#(32) Word32;
typedef Bit#(64) Word64;
typedef Bit#(128) Word128;

typedef Bit#(XLEN) UnsignedInt;
typedef Int#(XLEN) SignedInt;

typedef Word ProgramCounter;
typedef Word VirtualAddress;

typedef Bit#(4) TileId;
typedef Word FabricAddress;

typedef TileLinkLiteWordRequest#(SizeOf#(TileId), XLEN) StdTileLinkRequest;
typedef TileLinkLiteWordResponse#(SizeOf#(TileId), SizeOf#(TileId), XLEN) StdTileLinkResponse;

typedef TileLinkLiteWordClient#(SizeOf#(TileId), SizeOf#(TileId), XLEN) StdTileLinkClient;
typedef TileLinkLiteWordServer#(SizeOf#(TileId), SizeOf#(TileId), XLEN) StdTileLinkServer;

typedef TLog#(TDiv#(n,8)) DataSz#(numeric type n);

// A Rust inspired Result type.
typedef union tagged {
    success_type Success;
    error_type Error;
} Result#(type success_type, type error_type);

function Bool isSuccess(Result#(success_type, error_type) result);
    if (result matches tagged Success .*) begin
        return True;
    end else begin
        return False;
    end
endfunction

function ActionValue#(t) pop(ifc f) provisos (ToGet#(ifc, t));
   return toGet(f).get;
endfunction

function ActionValue#(Bit #(32)) getCurrentCycle;
    actionvalue
	    Bit#(32) t <- $stime;
	    return t / 10;
    endactionvalue
endfunction

export Memory::*, RVCommon::*, PGTypes::*;
