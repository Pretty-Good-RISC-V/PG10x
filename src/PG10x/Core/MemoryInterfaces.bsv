import PGTypes::*;
import TileLink::*;

import ClientServer::*;
import GetPut::*;

export TileLink::*, 
       ClientServer::*,
       GetPut::*,
       TileLinkLiteWord32Request,
       TileLinkLiteWord32Response,
       TileLinkLiteWord32Client,
       TileLinkLiteWord32Server,
       TileLinkLiteWordRequest,
       TileLinkLiteWordResponse,
       TileLinkLiteWordClient,
       TileLinkLiteWordServer;

//
// TilelLink 32 bit data request/response (Instruction Memory)
//
typedef TileLinkChannelARequest#(TLog#(4), 1, XLEN, 4) TileLinkLiteWord32Request;
typedef TileLinkChannelDResponse#(TLog#(4), 1, 1, 4) TileLinkLiteWord32Response;

typedef Client#(TileLinkLiteWord32Request, TileLinkLiteWord32Response) TileLinkLiteWord32Client;
typedef Server#(TileLinkLiteWord32Request, TileLinkLiteWord32Response) TileLinkLiteWord32Server;

//
// TileLink Word (32/64/128 bit) request/response (Data Memory)
//
typedef TileLinkChannelARequest#(TLog#(TDiv#(XLEN, 8)), 1, XLEN, TDiv#(XLEN, 8)) TileLinkLiteWordRequest;
typedef TileLinkChannelDResponse#(TLog#(TDiv#(XLEN, 8)), 1, 1, TDiv#(XLEN, 8)) TileLinkLiteWordResponse;

typedef Client#(TileLinkLiteWordRequest, TileLinkLiteWordResponse) TileLinkLiteWordClient;
typedef Server#(TileLinkLiteWordRequest, TileLinkLiteWordResponse) TileLinkLiteWordServer;
