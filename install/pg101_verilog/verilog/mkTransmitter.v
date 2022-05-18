//
// Generated by Bluespec Compiler, version 2022.01 (build 066c7a87)
//
// On Sat Apr 23 11:03:21 PDT 2022
//
//
// Ports:
// Name                         I/O  size props
// RDY_putData_put                O     1
// RDY_putBaudX2Ticked_put        O     1
// get_tx_get                     O     1 reg
// RDY_get_tx_get                 O     1 const
// CLK                            I     1 clock
// CLK_GATE                       I     1
// RST_N                          I     1 reset
// putData_put                    I     8 reg
// putBaudX2Ticked_put            I     1 reg
// EN_putData_put                 I     1
// EN_putBaudX2Ticked_put         I     1
// EN_get_tx_get                  I     1 unused
//
// Combinational paths from inputs to outputs:
//   CLK_GATE -> RDY_putData_put
//   CLK_GATE -> RDY_putBaudX2Ticked_put
//
//

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

`ifdef BSV_POSITIVE_RESET
  `define BSV_RESET_VALUE 1'b1
  `define BSV_RESET_EDGE posedge
`else
  `define BSV_RESET_VALUE 1'b0
  `define BSV_RESET_EDGE negedge
`endif

module mkTransmitter(CLK,
		     CLK_GATE,
		     RST_N,

		     putData_put,
		     EN_putData_put,
		     RDY_putData_put,

		     putBaudX2Ticked_put,
		     EN_putBaudX2Ticked_put,
		     RDY_putBaudX2Ticked_put,

		     EN_get_tx_get,
		     get_tx_get,
		     RDY_get_tx_get);
  input  CLK;
  input  CLK_GATE;
  input  RST_N;

  // action method putData_put
  input  [7 : 0] putData_put;
  input  EN_putData_put;
  output RDY_putData_put;

  // action method putBaudX2Ticked_put
  input  putBaudX2Ticked_put;
  input  EN_putBaudX2Ticked_put;
  output RDY_putBaudX2Ticked_put;

  // actionvalue method get_tx_get
  input  EN_get_tx_get;
  output get_tx_get;
  output RDY_get_tx_get;

  // signals for module outputs
  wire RDY_get_tx_get, RDY_putBaudX2Ticked_put, RDY_putData_put, get_tx_get;

  // register txBaudX2Ticked
  reg txBaudX2Ticked;
  wire txBaudX2Ticked$D_IN, txBaudX2Ticked$EN;

  // register txBit
  reg [2 : 0] txBit;
  wire [2 : 0] txBit$D_IN;
  wire txBit$EN;

  // register txByte
  reg [7 : 0] txByte;
  wire [7 : 0] txByte$D_IN;
  wire txByte$EN;

  // register txLine
  reg txLine;
  wire txLine$D_IN, txLine$EN;

  // register txState
  reg [2 : 0] txState;
  wire [2 : 0] txState$D_IN;
  wire txState$EN;

  // ports of submodule transmitQueue
  wire [7 : 0] transmitQueue$D_IN, transmitQueue$D_OUT;
  wire transmitQueue$CLR,
       transmitQueue$DEQ,
       transmitQueue$EMPTY_N,
       transmitQueue$ENQ,
       transmitQueue$FULL_N;

  // ports of submodule txTick
  wire txTick$ADDA,
       txTick$ADDB,
       txTick$DATA_A,
       txTick$DATA_B,
       txTick$DATA_C,
       txTick$DATA_F,
       txTick$Q_OUT,
       txTick$SETC,
       txTick$SETF;

  // rule scheduling signals
  wire WILL_FIRE_RL_handleTransmitNonIDLE;

  // inputs to muxes for submodule ports
  reg [2 : 0] MUX_txState$write_1__VAL_1;
  wire MUX_txState$write_1__SEL_1, MUX_txState$write_1__SEL_2;

  // remaining internal signals
  wire [7 : 0] y__h754;
  wire [2 : 0] x__h958;
  wire NOT_txTick__read__1_2_AND_txState_EQ_1_3_OR_tx_ETC___d37;

  // action method putData_put
  assign RDY_putData_put = CLK_GATE && transmitQueue$FULL_N ;

  // action method putBaudX2Ticked_put
  assign RDY_putBaudX2Ticked_put = CLK_GATE ;

  // actionvalue method get_tx_get
  assign get_tx_get = txLine ;
  assign RDY_get_tx_get = 1'd1 ;

  // submodule transmitQueue
  SizedFIFO #(.p1width(32'd8),
	      .p2depth(32'd16),
	      .p3cntr_width(32'd4),
	      .guarded(1'd1)) transmitQueue(.RST(RST_N),
					    .CLK(CLK),
					    .D_IN(transmitQueue$D_IN),
					    .ENQ(transmitQueue$ENQ),
					    .DEQ(transmitQueue$DEQ),
					    .CLR(transmitQueue$CLR),
					    .D_OUT(transmitQueue$D_OUT),
					    .FULL_N(transmitQueue$FULL_N),
					    .EMPTY_N(transmitQueue$EMPTY_N));

  // submodule txTick
  Counter #(.width(32'd1), .init(1'd0)) txTick(.CLK(CLK),
					       .RST(RST_N),
					       .DATA_A(txTick$DATA_A),
					       .DATA_B(txTick$DATA_B),
					       .DATA_C(txTick$DATA_C),
					       .DATA_F(txTick$DATA_F),
					       .ADDA(txTick$ADDA),
					       .ADDB(txTick$ADDB),
					       .SETC(txTick$SETC),
					       .SETF(txTick$SETF),
					       .Q_OUT(txTick$Q_OUT));

  // rule RL_handleTransmitNonIDLE
  assign WILL_FIRE_RL_handleTransmitNonIDLE =
	     CLK_GATE && txState != 3'd0 && txBaudX2Ticked ;

  // inputs to muxes for submodule ports
  assign MUX_txState$write_1__SEL_1 =
	     WILL_FIRE_RL_handleTransmitNonIDLE &&
	     NOT_txTick__read__1_2_AND_txState_EQ_1_3_OR_tx_ETC___d37 ;
  assign MUX_txState$write_1__SEL_2 =
	     CLK_GATE && transmitQueue$EMPTY_N && txState == 3'd0 ;
  always@(txState)
  begin
    case (txState)
      3'd1: MUX_txState$write_1__VAL_1 = 3'd2;
      3'd2: MUX_txState$write_1__VAL_1 = 3'd3;
      3'd3: MUX_txState$write_1__VAL_1 = 3'd4;
      default: MUX_txState$write_1__VAL_1 = 3'd0;
    endcase
  end

  // register txBaudX2Ticked
  assign txBaudX2Ticked$D_IN = putBaudX2Ticked_put ;
  assign txBaudX2Ticked$EN = EN_putBaudX2Ticked_put ;

  // register txBit
  assign txBit$D_IN = (txState == 3'd1) ? 3'd0 : x__h958 ;
  assign txBit$EN =
	     WILL_FIRE_RL_handleTransmitNonIDLE && !txTick$Q_OUT &&
	     (txState == 3'd1 || txState == 3'd2 && txBit != 3'd7) ;

  // register txByte
  assign txByte$D_IN = transmitQueue$D_OUT ;
  assign txByte$EN = MUX_txState$write_1__SEL_2 ;

  // register txLine
  assign txLine$D_IN =
	     txState != 3'd1 &&
	     ((txState == 3'd2) ?
		(txByte & y__h754) != 8'd1 :
		txState != 3'd3) ;
  assign txLine$EN =
	     WILL_FIRE_RL_handleTransmitNonIDLE && !txTick$Q_OUT &&
	     (txState == 3'd1 || txState == 3'd2 || txState == 3'd3 ||
	      txState == 3'd4) ;

  // register txState
  assign txState$D_IN =
	     MUX_txState$write_1__SEL_1 ? MUX_txState$write_1__VAL_1 : 3'd1 ;
  assign txState$EN =
	     WILL_FIRE_RL_handleTransmitNonIDLE &&
	     NOT_txTick__read__1_2_AND_txState_EQ_1_3_OR_tx_ETC___d37 ||
	     CLK_GATE && transmitQueue$EMPTY_N && txState == 3'd0 ;

  // submodule transmitQueue
  assign transmitQueue$D_IN = putData_put ;
  assign transmitQueue$ENQ = EN_putData_put ;
  assign transmitQueue$DEQ = MUX_txState$write_1__SEL_2 ;
  assign transmitQueue$CLR = 1'b0 ;

  // submodule txTick
  assign txTick$DATA_A = 1'd1 ;
  assign txTick$DATA_B = 1'b0 ;
  assign txTick$DATA_C = 1'b0 ;
  assign txTick$DATA_F = 1'd0 ;
  assign txTick$ADDA = WILL_FIRE_RL_handleTransmitNonIDLE ;
  assign txTick$ADDB = 1'b0 ;
  assign txTick$SETC = 1'b0 ;
  assign txTick$SETF = MUX_txState$write_1__SEL_2 ;

  // remaining internal signals
  assign NOT_txTick__read__1_2_AND_txState_EQ_1_3_OR_tx_ETC___d37 =
	     !txTick$Q_OUT &&
	     (txState == 3'd1 || txState == 3'd2 && txBit == 3'd7 ||
	      txState == 3'd3 ||
	      txState == 3'd4) ;
  assign x__h958 = txBit + 3'd1 ;
  assign y__h754 = 8'd1 << txBit ;

  // handling of inlined registers

  always@(posedge CLK)
  begin
    if (RST_N == `BSV_RESET_VALUE)
      begin
        txBaudX2Ticked <= `BSV_ASSIGNMENT_DELAY 1'd0;
	txLine <= `BSV_ASSIGNMENT_DELAY 1'd1;
	txState <= `BSV_ASSIGNMENT_DELAY 3'd0;
      end
    else
      begin
        if (txBaudX2Ticked$EN)
	  txBaudX2Ticked <= `BSV_ASSIGNMENT_DELAY txBaudX2Ticked$D_IN;
	if (txLine$EN) txLine <= `BSV_ASSIGNMENT_DELAY txLine$D_IN;
	if (txState$EN) txState <= `BSV_ASSIGNMENT_DELAY txState$D_IN;
      end
    if (txBit$EN) txBit <= `BSV_ASSIGNMENT_DELAY txBit$D_IN;
    if (txByte$EN) txByte <= `BSV_ASSIGNMENT_DELAY txByte$D_IN;
  end

  // synopsys translate_off
  `ifdef BSV_NO_INITIAL_BLOCKS
  `else // not BSV_NO_INITIAL_BLOCKS
  initial
  begin
    txBaudX2Ticked = 1'h0;
    txBit = 3'h2;
    txByte = 8'hAA;
    txLine = 1'h0;
    txState = 3'h2;
  end
  `endif // BSV_NO_INITIAL_BLOCKS
  // synopsys translate_on
endmodule  // mkTransmitter

