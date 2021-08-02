/**************************************************************/
/* VUserMain0.h                              Date: 2021/08/01 */
/*                                                            */
/* Copyright (c) 2021 Simon Southwell. All rights reserved.   */
/*                                                            */
/**************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

extern "C" {
#include "VUser.h"
}

// Define a sleep forever macro
#define SLEEP_FOREVER {while(1)           VTick(0x7fffffff, node);}      

