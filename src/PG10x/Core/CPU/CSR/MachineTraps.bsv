import MachineStatus::*;
import MachineISA::*;
export MachineTrapSetup(..), MachineTraps(..), mkMachineTrapRegisters, MachineISA::*;

interface MachineTrapSetup;
    interface MachineISA machineISA;
    interface MachineStatus machineStatus;
endinterface

interface MachineTraps;
    interface MachineTrapSetup setup;
endinterface

(* synthesize *)
module mkMachineTrapRegisters(MachineTraps);
    MachineISA misa <- mkMachineISARegister;
    MachineStatus mstatus <- mkMachineStatusRegister;

    interface MachineTrapSetup setup;
        interface MachineISA machineISA = misa;
        interface MachineStatus machineStatus = mstatus;
    endinterface
endmodule
