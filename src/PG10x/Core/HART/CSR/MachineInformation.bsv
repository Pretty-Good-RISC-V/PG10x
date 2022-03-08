import PGTypes::*;

export MachineInformation(..), mkMachineInformationRegisters;

interface MachineInformation;
    method Word32 mvendorid;
    method Word marchid;
    method Word mimpid;
    method Word mhartid;
    method Word mconfigptr;
endinterface

module mkMachineInformationRegisters#(
    Word32 vendorID,
    Word architectureID,
    Word implementationID,
    Word hardwareThreadID,
    Word configurationPointer)
(MachineInformation);

    method Word32 mvendorid;
        return vendorID;
    endmethod
    
    method Word marchid;
        return architectureID;
    endmethod

    method Word mimpid;
        return implementationID;
    endmethod

    method Word mhartid;
        return hardwareThreadID;
    endmethod

    method Word mconfigptr;
        return configurationPointer;
    endmethod

endmodule