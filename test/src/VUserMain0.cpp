/**************************************************************/
/* VUserMain0.cpp                            Date: 2021/08/02 */
/*                                                            */
/* Copyright (c) 2021 Simon Southwell. All rights reserved.   */
/*                                                            */
/**************************************************************/

#include <stdio.h>
#include <stdlib.h>

#include "VUserMain0.h"
#include "mem_vproc_api.h"

// I'm node 0
int node = 0;


// VUserMainX has no calling arguments. If you want runtime configuration,
// then you'll need to read in a configuration file.

extern "C" void VUserMain0()
{
    int error = 0;
    uint32_t rdval;

    const uint32_t addr1     = 0x00001000;
    const uint32_t addr2     = 0x20000000;
    const uint32_t testdata1 = 0x12345678;
    const uint32_t testdata2 = 0xcafef00d;
    const uint32_t testdata3 = 0x00001964;
    const uint32_t testdata4 = 0x000000aa;
    const uint32_t testdata5 = 0x000000ff;
    const uint32_t testdata6 = 0x00000055;
    const uint32_t testdata7 = 0x000000ee;
    
    VPrint("\n*****************************\n");
    VPrint(  "*   Wyvern Semiconductors   *\n");
    VPrint(  "* Virtual Processor (VProc) *\n");
    VPrint(  "*     Copyright (c) 2021    *\n");
    VPrint(  "*****************************\n\n");

    VTick(20, node);

    // Write a couple of data words to the memory model
    write_word(addr1, testdata1);
    write_word(addr2, testdata2);
    
    // Check word writes worked with a word read
    if((rdval = read_word(addr1)) != testdata1)
    {
        error |= 0x01;
        VPrint("**Error: bad read. Expected 0x%08x, got 0x%08x\n", testdata1, rdval);
    }
    else
    {
        VPrint("Read word 0x%08x\n", rdval);
    }
 
    // Check word writes worked with byte reads
    for (int idx = 0; idx < 4; idx++)
    {
        if ((rdval = read_byte(addr2+idx)) != ((testdata2 >> (idx*8)) & 0xff))
        {
            error |= 0x02;
            VPrint("**Error: bad read. Expected 0x%08x, got 0x%08x\n", ((testdata2 >> (idx*8)) & 0xff), rdval);
        }
        else
        {
            VPrint("Read byte 0x%02x\n", read_byte(addr2+idx));
        }
    }
    
    // Check word writes worked with half-word reads
    for (int idx = 0; idx < 4; idx+=2)
    {
        if ((rdval = read_hword(addr1+idx)) != ((testdata1 >> (idx*8)) & 0xffff))
        {
            error |= 0x04;
            VPrint("**Error: bad read. Expected 0x%08x, got 0x%08x\n", ((testdata1 >> (idx*8)) & 0xffff), rdval);
        }
        else
        {
            VPrint("Read byte 0x%02x\n", read_byte(addr2+idx));
        }
    }
    

    // Overwrite the top half of the memory location at addr1
    write_hword(addr1 + 2, testdata3);
    
    uint32_t newaddr1val = (testdata3 << 16) | (testdata1 & 0x0000ffff);

    if ((rdval = read_word(addr1)) != newaddr1val)
    {
        error = 0x08;
        VPrint("**Error: bad read. Expected 0x%08x, got 0x%08x\n", newaddr1val, rdval);
    }
    else
    {
        VPrint("Read word 0x%08x\n", read_word(addr1));
    }
    
    uint32_t newaddr2val = testdata2;

    // Overwrite memory bytes at addr2 and check
    write_byte(addr2 + 3, testdata4);
    newaddr2val = (testdata4 << 24) | (newaddr2val & 0x00ffffff);
    if ((rdval = read_word(addr2)) != newaddr2val)
    {
        error = 0x10;
        VPrint("**Error: bad read. Expected 0x%08x, got 0x%08x\n", newaddr2val, rdval);
    }
    else
    {
        VPrint("Read word 0x%08x\n", read_word(addr2));
    }

    write_byte(addr2 + 2, testdata5);
    newaddr2val = (testdata5 << 16) | (newaddr2val & 0xff00ffff);
    if ((rdval = read_word(addr2)) != newaddr2val)
    {
        error = 0x20;
        VPrint("**Error: bad read. Expected 0x%08x, got 0x%08x\n", newaddr2val, rdval);
    }
    else
    {
        VPrint("Read word 0x%08x\n", read_word(addr2));
    }

    write_byte(addr2 + 1, testdata6);
    newaddr2val = (testdata6 << 8) | (newaddr2val & 0xffff00ff);
    if ((rdval = read_word(addr2)) != newaddr2val)
    {
        error = 0x40;
        VPrint("**Error: bad read. Expected 0x%08x, got 0x%08x\n", newaddr2val, rdval);
    }
    else
    {
        VPrint("Read word 0x%08x\n", read_word(addr2));
    }

    write_byte(addr2 + 0, testdata7);
    newaddr2val = (testdata7 << 0) | (newaddr2val & 0xffffff00);
    if ((rdval = read_word(addr2)) != newaddr2val)
    {
        error = 0x80;
        VPrint("**Error: bad read. Expected 0x%08x, got 0x%08x\n", newaddr2val, rdval);
    }
    else
    {
        VPrint("Read word 0x%08x\n", read_word(addr2));
    }
    
    if (error)
    {
        VPrint("\n***FAIL***: exit code %d\n\n", error);
    }
    else
    {
        VPrint("\nPASS\n\n");
    }

    write_word(HALT_ADDR, 0);


    SLEEP_FOREVER;
}

