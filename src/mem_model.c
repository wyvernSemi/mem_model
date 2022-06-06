//=====================================================================
//
// mem_model.c                                       Date: 2021/08/01
//
// Copyright (c) 2021 Simon Southwell
//
//=====================================================================


#include <stdio.h>
#include <errno.h>
#include <unistd.h>

#include "mem_model.h"

// PLI access function for $memread.
//   Argument 1 is word address
//   Argument 2 is 32 bit return data
MEM_RTN_TYPE MemRead (MEM_READ_PARAMS)
{
    uint32_t data_int, addr;
    
#if !defined(VPROC_VHDL) && !defined(SYSVLOG)
    uint32_t address, be;

    // Get address from $memread argument list
    address  = tf_getp(MEM_MODEL_ADDR_ARG);
    
    // Get byte enable fro $memread argument list
    be       = tf_getp(MEM_MODEL_BE_ARG);
#endif

    // Get data  from memory model
    if (be == 0x1 || be == 0x2 || be == 0x4 || be == 0x8)
    {
        // Ensure address is 32 bit aligned, then add bottom bits based on byte enables
        addr = (address & ~0x3UL) | ((be == 0x01) ? 0 : (be == 0x02) ? 1 : (be == 0x04) ? 2 : 3);
        
        // Get the byte from the memory model
        data_int = ReadRamByte(addr, MEM_MODEL_DEFAULT_NODE);
        
        // Place in the correct lane
        data_int <<= (addr & 0x3) * 8;
    }
    else if (be == 0x3 || be == 0xc)
    {
        // Ensure address is 32 bit aligned, then add bottom bits based on byte enables
        addr = (address & ~0x3UL) | ((be == 0x03) ? 0 : 2);
 
        // Get the half word from the model
        data_int = ReadRamHWord(addr, MEM_MODEL_DEFAULT_ENDIAN, MEM_MODEL_DEFAULT_NODE);
        
        // Place in the correct lane
        data_int <<= (addr & 0x3) * 8;
    }
    else
        data_int = ReadRamWord(address, MEM_MODEL_DEFAULT_ENDIAN, MEM_MODEL_DEFAULT_NODE);

#if defined(VPROC_VHDL) || defined(SYSVLOG)
    *data = data_int;
#else
    // Update data argument of $memread with returned read data
    tf_putp (MEM_MODEL_DATA_ARG, data_int);

    return 0;
#endif
}

// PLI access function for $memwrite.
//   Argument 1 is word address
//   Argument 2 is 32 bit data
MEM_RTN_TYPE MemWrite (MEM_WRITE_PARAMS)
{
    uint32_t addr;
    
#if !defined(VPROC_VHDL) && !defined(SYSVLOG)
    uint32_t address, data, be;
    
    // Get address from $memwrite argument list
    address = tf_getp(MEM_MODEL_ADDR_ARG);
    
    // Get write data from $memwrite argument list
    data    = tf_getp(MEM_MODEL_DATA_ARG);
    
     // Get byte enable fro $memwrite argument list
    be      = tf_getp(MEM_MODEL_BE_ARG);
#endif

    // Update data in memory model
    if (be == 0x1 || be == 0x2 || be == 0x4 || be == 0x8)
    {
        // Ensure address is 32 bit aligned, then add bottom bits based on byte enables
        addr = (address & ~0x3UL) | ((be == 0x01) ? 0 : (be == 0x02) ? 1 : (be == 0x04) ? 2 : 3);
        
        WriteRamByte(addr, data >> ((addr & 0x3)*8), MEM_MODEL_DEFAULT_NODE);
    }
    else if (be == 0x3 || be == 0xc)
    {
        // Ensure address is 32 bit aligned, then add bottom bits based on byte enables
        addr = (address & ~0x3UL) | ((be == 0x03) ? 0 : 2);
        
        uint32_t d = data >> ((addr & 0x3ULL)*8);
        
        WriteRamHWord(addr, d, MEM_MODEL_DEFAULT_ENDIAN, MEM_MODEL_DEFAULT_NODE);
    }
    else
    {
        WriteRamWord(address, data, MEM_MODEL_DEFAULT_ENDIAN, MEM_MODEL_DEFAULT_NODE);
    }

#if !defined(VPROC_VHDL) && !defined(SYSVLOG)
    return 0;
#endif
}
