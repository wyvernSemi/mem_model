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
#ifndef SYSVLOG
#include "veriuser.h"
#include "vpi_user.h"
#else
#include "svdpi.h"
#endif
#include "mem.h"

#define MEM_MODEL_TF_TBL_SIZE 2

#define MEM_MODEL_ADDR_ARG          1
#define MEM_MODEL_DATA_ARG          2
#define MEM_MODEL_BE_ARG            3

#define MEM_MODEL_DEFAULT_NODE      0

#define MEM_MODEL_BE                0
#define MEM_MODEL_LE                1

#ifndef MEM_MODEL_DEFAULT_ENDIAN
#define MEM_MODEL_DEFAULT_ENDIAN    MEM_MODEL_BE
#endif

# if defined (VPROC_VHDL) || defined(SYSVLOG)

#define MEM_MODEL_TF_TBL

#define MEM_READ_PARAMS    const int  address,       int* data, const int be
#define MEM_WRITE_PARAMS   const int  address, const int  data, const int be

#define MEM_RTN_TYPE       void

# else
    
#  if !defined(VPROC_PLI_VPI)

#define MEM_MODEL_TF_TBL \
    {usertask, 0, NULL, 0, MemRead,   NULL,  "$memread",   1}, \
    {usertask, 0, NULL, 0, MemWrite,  NULL,  "$memwrite",  1},

#define MEM_READ_PARAMS    void
#define MEM_WRITE_PARAMS   void

#define MEM_RTN_TYPE       int

#  else

#define MEM_MODEL_VPI_TBL \
  {vpiSysTask, 0, "$memread",     MemRead,     0, 0, 0}, \
  {vpiSysTask, 0, "$memwrite",    MemWrite,    0, 0, 0}

#define MEM_MODEL_VPI_TBL_SIZE 2

#define MEM_READ_PARAMS   char* userdata
#define MEM_WRITE_PARAMS  char* userdata

#define MEM_RTN_TYPE int

#  endif

# endif

extern MEM_RTN_TYPE MemRead     (MEM_READ_PARAMS);
extern MEM_RTN_TYPE MemWrite    (MEM_WRITE_PARAMS);

#endif
