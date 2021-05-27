// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

/********************
NSBlock support

We allocate space and export a symbol to be used as the Class for the on-stack and malloc'ed copies until ObjC arrives on the scene.  These data areas are set up by Foundation to link in as real classes post facto.

We keep these in a separate file so that we can include the runtime code in test subprojects but not include the data so that compiled code that sees the data in libSystem doesn't get confused by a second copy.  Somehow these don't get unified in a common block.
**********************/
#define BLOCK_EXPORT __attribute__((visibility("default")))

BLOCK_EXPORT void * _NSConcreteStackBlock[32] = { 0 };
BLOCK_EXPORT void * _NSConcreteMallocBlock[32] = { 0 };
BLOCK_EXPORT void * _NSConcreteAutoBlock[32] = { 0 };
BLOCK_EXPORT void * _NSConcreteFinalizingBlock[32] = { 0 };
BLOCK_EXPORT void * _NSConcreteGlobalBlock[32] = { 0 };
BLOCK_EXPORT void * _NSConcreteWeakBlockVariable[32] = { 0 };
