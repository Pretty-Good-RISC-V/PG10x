import PGTypes::*;
import ClientServer::*;

/*
    TileLink Operation Categories
        Accesses (A)  - read and/or write the data at the specified address
        Hints (H)     - are informational only and have no direct effects
        Transfers (T) - move permissions or cached copies of data through the network.

    TileLine Operations

    Operation       Type        TL-UL   TL-UH   TL-C    Purpose
    -----------------------------------------------------------
    Get             A           Y       Y       Y       Read from and address range
    Put             A           Y       Y       Y       Write to an address range
    Atomic          A                   Y       Y       Read-modify-write an address range
    Intent          H                   Y       Y       Advance notification of likely future operations
    Acquire         T                           Y       Cache a copy of an address range or increase permissions of that copy
    Release         T                           Y       Write-back a cached copy of an address range or relinquish permissions to a cached copy
*/

// ChannelAOpcodes - Requests (responses on Channel D)
typedef enum {
    A_PUT_FULL_DATA     = 3'h0, // Put      - Response: D_ACCESS_ACK
    A_PUT_PARTIAL_DATA  = 3'h1, // Put      - Response: D_ACCESS_ACK
    A_ARITHMETIC_DATA   = 3'h2, // Atomic   - Response: D_ACCESS_ACK_DATA
    A_LOGICAL_DATA      = 3'h3, // Atomic   - Response: D_ACCESS_ACK_DATA
    A_GET               = 3'h4, // Get      - Response: D_ACCESS_ACK_DATA
    A_INTENT            = 3'h5, // Intent   - Response: D_HINT_ACK
    A_ACQUIRE_BLOCK     = 3'h6, // Acquire  - Response: D_GRANT, D_GRANT_DATA
    A_ACQUIRE_PERM      = 3'h7  // Acquire  - Response: D_GRANT
} ChannelAOpcodes deriving(Bits, Eq, FShow);

// ChannelDOpcodes - Responses (resquests on Channel A)
typedef enum {
    D_ACCESS_ACK        = 3'h0, // Put
    D_ACCESS_ACK_DATA   = 3'h1, // Get or Atomic
    D_HINT_ACK          = 3'h2, // Intent
    D_GRANT             = 3'h4, // Acquire
    D_GRANT_DATA        = 3'h5, // Acquire
    D_RELEASE_ACK       = 3'h6  // Release
} ChannelDOpcodes deriving(Bits, Eq, FShow);

typedef struct {
    Bit#(3) a_opcode;
    Bit#(3) a_param;
    Bit#(z) a_size;             // z = number of bits required for transfer size
    Bit#(o) a_source;           // o = number of bits to identify source
    Bit#(a) a_address;          // a = number of address bits
    Bit#(w) a_mask;             // w = number of bytes in the mask
    Bit#(TMul#(w, 8)) a_data;
    Bool a_corrupt;       // The data in this beat is corrupt.

    // The below are part of the TileLink spec but are automatically provided by BlueSpec.
    // Bit#(1) a_valid
    // Bit#(1) a_ready
} TileLinkChannelARequest#(numeric type z, numeric type o, numeric type a, numeric type w) deriving(Bits, Eq, FShow);

typedef TileLinkChannelARequest#(1, 1, XLEN, 4) TileLinkChannelARequest32;

typedef struct {
    Bit#(3) d_opcode;
    Bit#(2) d_param;
    Bit#(z) d_size;             // z = number of bits required for transfer size
    Bit#(o) d_source;           // o = number of bits to identify source
    Bit#(i) d_sink;             // i = number of bits to identify sink
    Bool d_denied;
    Bit#(TMul#(w, 8)) d_data;
    Bool d_corrupt;

    // The below are part of the TileLink spec but are automatically provided by BlueSpec.
    // Bit#(1) d_valid
    // Bit#(1) d_ready
} TileLinkChannelDResponse#(numeric type z, numeric type o, numeric type i, numeric type w) deriving(Bits, Eq, FShow);

typedef TileLinkChannelDResponse#(1, 1, 1, 4) TileLinkChannelDResponse32;

typedef Client#(TileLinkChannelARequest32, TileLinkChannelDResponse32) TileLinkADClient32;
typedef Server#(TileLinkChannelARequest32, TileLinkChannelDResponse32) TileLinkADServer32;
