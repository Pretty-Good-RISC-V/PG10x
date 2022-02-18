import PGTypes::*;
import TileLink::*;

import ClientServer::*;
import GetPut::*;

export TileLink::*, 
       ClientServer::*,
       GetPut::*,
       InstructionMemoryRequest, 
       InstructionMemoryResponse, 
       DataMemoryRequest,
       DataMemoryResponse,
       InstructionMemoryServer,
       DataMemoryServer;

typedef TileLinkChannelARequest#(1, 1, XLEN, 4) InstructionMemoryRequest;
typedef TileLinkChannelDResponse#(1, 1, 1, 4) InstructionMemoryResponse;

typedef TileLinkChannelARequest#(1, 1, XLEN, TDiv#(XLEN, 8)) DataMemoryRequest;
typedef TileLinkChannelDResponse#(1, 1, 1, TDiv#(XLEN, 8)) DataMemoryResponse;

typedef Server#(InstructionMemoryRequest, InstructionMemoryResponse) InstructionMemoryServer;
typedef Server#(DataMemoryRequest, DataMemoryResponse) DataMemoryServer;
