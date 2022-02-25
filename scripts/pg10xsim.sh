#!/bin/bash
#
# Bluespec Simulation Driver
#
set -e

function usage 
{
    echo "Usage: $1 [-m <maxcycles>] [--model <pg101|pg103>] <elf_binaryfile>"
}

MAX_CYCLES=0
MODEL="pg101"
INPUT=""

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --max_cycles)
            MAX_CYCLES="$2"
            shift # past argument
            shift # past value
        --model)
            MODEL="$2"
            shift # past argument
            shift # past value
            ;;
        *)
            # If it's a directory, assume it's an include directory
            POSITIONAL+=("$1")
            shift # past argument
            ;;
  esac
done

if [ ${#POSITIONAL[@]} -eq 0 ]; then
    usage
    exit 1;
fi

INPUT="$POSITIONAL[0]"

PROGRAM_MEMORY_FILE="$INPUT" ./build/$MODEL/src/PG10x/Simulator/Simulator -m $MAX_CYCLES