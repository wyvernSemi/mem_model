//=====================================================================
//
// mem_model.h                                       Date: 2021/08/01
//
// Copyright (c) 2021 Simon Southwell
//
//=====================================================================

#ifndef _MEM_MODEL_H_
#define _MEM_MODEL_H_

#include "string.h"
#include "veriuser.h"
#include "vpi_user.h"
#include "mem.h"

#define MEM_MODEL_TF_TBL_SIZE 2

#define MEM_MODEL_ADDR_ARG          1
#define MEM_MODEL_DATA_ARG          2
#define MEM_MODEL_BE_ARG            3

#define MEM_MODEL_DEFAULT_NODE      0

#ifndef MEM_MODEL_DEFAULT_ENDIAN
#define MEM_MODEL_DEFAULT_ENDIAN    0
#endif

# ifdef VPROC_VHDL

#define MEM_MODEL_TF_TBL

#define MEM_READ_PARAMS    int  address, int* data, int be
#define MEM_WRITE_PARAMS   int  address, int  data, int be

#define MEM_RTN_TYPE       void

# else

#define MEM_MODEL_TF_TBL \
    {usertask, 0, NULL, 0, MemRead,   NULL,  "$memread",   1}, \
    {usertask, 0, NULL, 0, MemWrite,  NULL,  "$memwrite",  1},

#define MEM_READ_PARAMS    void
#define MEM_WRITE_PARAMS   void

#define MEM_RTN_TYPE       int

# endif

extern MEM_RTN_TYPE MemRead     (MEM_READ_PARAMS);
extern MEM_RTN_TYPE MemWrite    (MEM_WRITE_PARAMS);

#endif
