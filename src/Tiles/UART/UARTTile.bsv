import BaudGenerator::*;
import TileLink::*;
import UART::*;

import ClientServer::*;
import Clocks::*;
import Connectable::*;
import Counter::*;
import FIFO::*;
import GetPut::*;
import Memory::*;

interface UARTTile#(numeric type tileSourceIDBits, numeric type tileSinkIDBits, numeric type wordBits);
    interface TileLinkLiteWordServer#(tileSourceIDBits, tileSinkIDBits, wordBits) tilelinkServer;

    (* always_ready, always_enabled *)
    interface Get#(Bit#(1)) get_tx;

    (* always_ready, always_enabled *)
    interface Put#(Bit#(1)) put_rx;
endinterface

(* gate_input_clocks = "uartClock" *)
module mkUARTTile#(
    Integer tileId,
    Clock uartClock, 
    Reset uartReset,
    numeric tileIDBits, numeric wordBits
)(UARTTile#(tileIDBits, tileIDBits, wordBits));
    UART uart <- mkUART(clocked_by uartClock, reset_by uartReset);

    // TileLink queues
    FIFO#(TileLinkLiteWordRequest#(tileIDBits, wordBits)) tilelinkRequestQueue <- mkFIFO;
    FIFO#(TileLinkLiteWordResponse#(tileIDBits, tileIDBits, wordBits)) tilelinkResponseQueue <- mkFIFO;

    // UART queues (clock crossing)
    SyncFIFOIfc#(MemoryRequest#(4, 8)) uartRequests <- mkSyncFIFOFromCC(16, uartClock);
    SyncFIFOIfc#(MemoryResponse#(8)) uartResponses <- mkSyncFIFOToCC(16, uartClock, uartReset);

    mkConnection(uart.memoryServer, toGPClient(uartRequests, uartResponses));

    rule handleTileLinkRequests;
        let tlRequest <- pop(tilelinkRequestQueue);

        if (tlRequest.a_corrupt) begin
            tilelinkResponseQueue.enq(TileLinkLiteWordResponse{
                d_opcode: d_ACCESS_ACK,
                d_param: 0,
                d_sink: tlRequest.a_source,
                d_corrupt: True,
                d_size: 0,
                d_data: ?,
                d_denied: False,
                d_source: fromInteger(tileId)
            });
        end else if (tlRequest.a_size != 0) begin
            tilelinkResponseQueue.enq(TileLinkLiteWordResponse{
                d_opcode: d_ACCESS_ACK,
                d_param: 0,
                d_sink: tlRequest.a_source,
                d_corrupt: False,
                d_size: 0,
                d_data: ?,
                d_denied: True,
                d_source: fromInteger(tileId)
            });
        end else begin
            uartRequests.enq(MemoryRequest {
                write: (tlRequest.a_opcode == a_GET ? False : True),
                byteen: 1,  // single byte
                address: tlRequest.a_address[3:0],
                data: tlRequest.a_data[7:0]          
            });
        end
    endrule

    rule handleTileLinkResponses;
        let memResponse <- pop(uartResponses);
    endrule

    interface TileLinkLiteWordServer tilelinkServer = toGPServer(tilelinkRequestQueue, tilelinkResponseQueue);

    interface Get get_tx = uart.get_tx;
    interface Put put_rx = uart.put_rx;
endmodule
