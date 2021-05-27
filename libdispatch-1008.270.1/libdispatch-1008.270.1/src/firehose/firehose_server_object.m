/*
 * Copyright (c) 2015 Apple Inc. All rights reserved.
 *
 * @APPLE_APACHE_LICENSE_HEADER_START@
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @APPLE_APACHE_LICENSE_HEADER_END@
 */

#include "internal.h"

#if !USE_OBJC || _OS_OBJECT_OBJC_ARC
#error the firehose server requires the objc-runtime, no ARC
#endif

@implementation OS_OBJECT_CLASS(firehose_client)
DISPATCH_UNAVAILABLE_INIT()
+ (void)load { }

- (void)_xref_dispose
{
	_firehose_client_xref_dispose((struct firehose_client_s *)self);
	[super _xref_dispose];
}

- (void)_dispose
{
	_firehose_client_dispose((struct firehose_client_s *)self);
	[super _dispose];
}

- (NSString *)debugDescription
{
	return nil;
}
@end
