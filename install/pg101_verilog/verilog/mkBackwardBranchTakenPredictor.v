//
// Generated by Bluespec Compiler, version 2022.01 (build 066c7a87)
//
// On Sat Apr 23 11:03:22 PDT 2022
//
//
// Ports:
// Name                         I/O  size props
// predictNextProgramCounter      O    32
// RDY_predictNextProgramCounter  O     1 const
// CLK                            I     1 unused
// RST_N                          I     1 unused
// predictNextProgramCounter_currentProgramCounter  I    32
// predictNextProgramCounter_instruction  I    32
//
// Combinational paths from inputs to outputs:
//   (predictNextProgramCounter_currentProgramCounter,
//    predictNextProgramCounter_instruction) -> predictNextProgramCounter
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

module mkBackwardBranchTakenPredictor(CLK,
				      RST_N,

				      predictNextProgramCounter_currentProgramCounter,
				      predictNextProgramCounter_instruction,
				      predictNextProgramCounter,
				      RDY_predictNextProgramCounter);
  input  CLK;
  input  RST_N;

  // value method predictNextProgramCounter
  input  [31 : 0] predictNextProgramCounter_currentProgramCounter;
  input  [31 : 0] predictNextProgramCounter_instruction;
  output [31 : 0] predictNextProgramCounter;
  output RDY_predictNextProgramCounter;

  // signals for module outputs
  wire [31 : 0] predictNextProgramCounter;
  wire RDY_predictNextProgramCounter;

  // remaining internal signals
  wire [31 : 0] immediate__h78,
		predictedProgramCounter___1__h79,
		predictedProgramCounter__h22;
  wire [12 : 0] x__h90;

  // value method predictNextProgramCounter
  assign predictNextProgramCounter =
	     (predictNextProgramCounter_instruction[6:0] == 7'b1100011) ?
	       (predictNextProgramCounter_instruction[31] ?
		  predictedProgramCounter___1__h79 :
		  predictedProgramCounter__h22) :
	       predictedProgramCounter__h22 ;
  assign RDY_predictNextProgramCounter = 1'd1 ;

  // remaining internal signals
  assign immediate__h78 = { {19{x__h90[12]}}, x__h90 } ;
  assign predictedProgramCounter___1__h79 =
	     predictNextProgramCounter_currentProgramCounter +
	     immediate__h78 ;
  assign predictedProgramCounter__h22 =
	     predictNextProgramCounter_currentProgramCounter + 32'd4 ;
  assign x__h90 =
	     { predictNextProgramCounter_instruction[31],
	       predictNextProgramCounter_instruction[7],
	       predictNextProgramCounter_instruction[30:25],
	       predictNextProgramCounter_instruction[11:8],
	       1'b0 } ;
endmodule  // mkBackwardBranchTakenPredictor

