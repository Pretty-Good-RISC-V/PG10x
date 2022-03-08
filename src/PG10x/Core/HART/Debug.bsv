import PGTypes::*;

interface Debug;
    method Word readGPR(RVGPRIndex idx);
    method Action writeGPR(RVGPRIndex idx, Word newValue);

    method Maybe#(Word) readCSR(RVCSRIndex idx);
    method Action writeCSR(RVCSRIndex idx, Word newValue);

    method Action halt();
    method Action resume();
    method Action step();
endinterface
