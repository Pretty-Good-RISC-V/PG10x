`include "UART.bsvi"
import BaudGenerator::*;
import Transmitter::*;

import ClientServer::*;
import Connectable::*;
import FIFO::*;
import Memory::*;
import GetPut::*;

Integer clockRate = 12_000_000;
Integer baudRate  = 115_200;

interface UART;
    interface MemoryServer#(4, 8) memoryServer;
    interface Get#(Bit#(1)) get_tx;
    interface Put#(Bit#(1)) put_rx;
endinterface

(* synthesize *)
(* gate_input_clocks = "default_clock" *)
module mkUART(UART);
    BaudGenerator baudGenerator <- mkBaudGenerator(clockRate / baudRate);
    Transmitter transmitter <- mkTransmitter;

    mkConnection(baudGenerator.getBaudX2Ticked, transmitter.putBaudX2Ticked);

    Reg#(Bit#(1)) rx <- mkReg(1);

    // Request/Response queues
    FIFO#(MemoryRequest#(4, 8)) requests <- mkFIFO;
    FIFO#(MemoryResponse#(8)) responses <- mkFIFO;

    rule handleRequests;
        let request <- pop(requests);

        // Writes
        if (request.write) begin
            let address = request.address[3:0];
            let data = request.data[7:0];
            case(address)
                0: transmitter.putData.put(data);
            endcase
        end
    endrule

    rule clockTick;
        baudGenerator.clockTicked;
    endrule

    interface MemoryServer memoryServer = toGPServer(requests, responses);
    interface Get get_tx = transmitter.get_tx;
    interface Put put_rx = toPut(asIfc(rx));
endmodule

