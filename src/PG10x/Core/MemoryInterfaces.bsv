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

typedef TileLinkChannelARequest#(1, XLEN, 32) InstructionMemoryRequest;
typedef TileLinkChannelDResponse#(1, 1, 32) InstructionMemoryResponse;

typedef TileLinkChannelARequest#(1, XLEN, XLEN) DataMemoryRequest;
typedef TileLinkChannelDResponse#(1, 1, XLEN) DataMemoryResponse;

typedef Server#(InstructionMemoryRequest, InstructionMemoryResponse) InstructionMemoryServer;
typedef Server#(DataMemoryRequest, DataMemoryResponse) DataMemoryServer;
