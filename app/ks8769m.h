/*******************************************************************************
* Copyright (C) 2016 Mike Ferrara (mikef@mrf.sonoma.ca.us), All rights reserved.
*
*
* Filename:     ks8769M.h
*
* Description: Keysight 8769M sp6t control.
*
*******************************************************************************/
//#define TRACE_PRINT 1

#ifndef _KS8769M_INCLUDED
#define _KS8769M_INCLUDED

#include "OSandPlatform.h"

#ifdef GLOBAL_KS8769M
#define KS8769MGLOBAL
#define KS8769MPRESET(A) = (A)
#else
#define KS8769MPRESET(A)
#ifdef __cplusplus
#define KS8769MGLOBAL extern "C"
#else
#define KS8769MGLOBAL extern
#endif	/*__cplusplus*/
#endif				/*GLOBAL_KS8769M */

// ----------------------------------------------------------------
// PRIVATE API AND SUBJECT TO CHANGE!
// ----------------------------------------------------------------

// ----------------------------------------------------------------
// PUBLIC API definition
// ----------------------------------------------------------------
KS8769MGLOBAL void set8769(sp8tSel_t sel);
#endif				//_KS8769M_INCLUDED
