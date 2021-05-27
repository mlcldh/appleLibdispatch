/*
 * Copyright (c) 2011-2013 Apple Inc. All rights reserved.
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

/*
 * IMPORTANT: This header file describes INTERNAL interfaces to libdispatch
 * which are subject to change in future releases of Mac OS X. Any applications
 * relying on these interfaces WILL break.
 */

#ifndef __DISPATCH_SHIMS_HW_CONFIG__
#define __DISPATCH_SHIMS_HW_CONFIG__

#ifdef __SIZEOF_POINTER__
#define DISPATCH_SIZEOF_PTR __SIZEOF_POINTER__
#elif defined(_WIN64)
#define DISPATCH_SIZEOF_PTR 8
#elif defined(_WIN32)
#define DISPATCH_SIZEOF_PTR 4
#elif defined(_MSC_VER)
#error "could not determine pointer size as a constant int for MSVC"
#elif defined(__LP64__) || defined(__LLP64__)
#define DISPATCH_SIZEOF_PTR 8
#elif defined(__ILP32__)
#define DISPATCH_SIZEOF_PTR 4
#else
#error "could not determine pointer size as a constant int"
#endif // __SIZEOF_POINTER__

#define DISPATCH_CACHELINE_SIZE 64u
#define ROUND_UP_TO_CACHELINE_SIZE(x) \
		(((x) + (DISPATCH_CACHELINE_SIZE - 1u)) & \
		~(DISPATCH_CACHELINE_SIZE - 1u))
#define DISPATCH_CACHELINE_ALIGN \
		__attribute__((__aligned__(DISPATCH_CACHELINE_SIZE)))

#if !TARGET_OS_WIN32

typedef enum {
	_dispatch_hw_config_logical_cpus,
	_dispatch_hw_config_physical_cpus,
	_dispatch_hw_config_active_cpus,
} _dispatch_hw_config_t;

#if !defined(DISPATCH_HAVE_HW_CONFIG_COMMPAGE) && \
		defined(_COMM_PAGE_LOGICAL_CPUS) && \
		defined(_COMM_PAGE_PHYSICAL_CPUS) && defined(_COMM_PAGE_ACTIVE_CPUS)
#define DISPATCH_HAVE_HW_CONFIG_COMMPAGE 1
#endif

#if DISPATCH_HAVE_HW_CONFIG_COMMPAGE

DISPATCH_ALWAYS_INLINE
static inline uint32_t
_dispatch_hw_get_config(_dispatch_hw_config_t c)
{
	uintptr_t p;
	switch (c) {
	case _dispatch_hw_config_logical_cpus:
		p =  _COMM_PAGE_LOGICAL_CPUS; break;
	case _dispatch_hw_config_physical_cpus:
		p = _COMM_PAGE_PHYSICAL_CPUS; break;
	case _dispatch_hw_config_active_cpus:
		p = _COMM_PAGE_ACTIVE_CPUS; break;
	}
	return *(uint8_t*)p;
}

#define dispatch_hw_config(c) \
		_dispatch_hw_get_config(_dispatch_hw_config_##c)

#define DISPATCH_HW_CONFIG()
#define _dispatch_hw_config_init()

#else // DISPATCH_HAVE_HW_CONFIG_COMMPAGE

extern struct _dispatch_hw_configs_s {
	uint32_t logical_cpus;
	uint32_t physical_cpus;
	uint32_t active_cpus;
} _dispatch_hw_config;

#define DISPATCH_HW_CONFIG() struct _dispatch_hw_configs_s _dispatch_hw_config
#define dispatch_hw_config(c) (_dispatch_hw_config.c)

DISPATCH_ALWAYS_INLINE
static inline uint32_t
_dispatch_hw_get_config(_dispatch_hw_config_t c)
{
	uint32_t val = 1;
#if defined(__linux__) && HAVE_SYSCONF
	switch (c) {
	case _dispatch_hw_config_logical_cpus:
	case _dispatch_hw_config_physical_cpus:
		return (uint32_t)sysconf(_SC_NPROCESSORS_CONF);
	case _dispatch_hw_config_active_cpus:
		{
#ifdef __USE_GNU
			// Prefer pthread_getaffinity_np because it considers
			// scheduler cpu affinity.  This matters if the program
			// is restricted to a subset of the online cpus (eg via numactl).
			cpu_set_t cpuset;
			if (pthread_getaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset) == 0)
				return (uint32_t)CPU_COUNT(&cpuset);
#endif
			return (uint32_t)sysconf(_SC_NPROCESSORS_ONLN);
		}
	}
#else
	const char *name = NULL;
	int r;
#if defined(__APPLE__)
	switch (c) {
	case _dispatch_hw_config_logical_cpus:
		name = "hw.logicalcpu_max"; break;
	case _dispatch_hw_config_physical_cpus:
		name = "hw.physicalcpu_max"; break;
	case _dispatch_hw_config_active_cpus:
		name = "hw.activecpu"; break;
	}
#elif defined(__FreeBSD__)
	 (void)c; name = "kern.smp.cpus";
#endif
	if (name) {
		size_t valsz = sizeof(val);
		r = sysctlbyname(name, &val, &valsz, NULL, 0);
		(void)dispatch_assume_zero(r);
		dispatch_assert(valsz == sizeof(uint32_t));
	} else {
#if HAVE_SYSCONF && defined(_SC_NPROCESSORS_ONLN)
		r = (int)sysconf(_SC_NPROCESSORS_ONLN);
		if (r > 0) val = (uint32_t)r;
#endif
	}
#endif
	return val;
}

#define dispatch_hw_config_init(c) \
		_dispatch_hw_get_config(_dispatch_hw_config_##c)

static inline void
_dispatch_hw_config_init(void)
{
	dispatch_hw_config(logical_cpus) = dispatch_hw_config_init(logical_cpus);
	dispatch_hw_config(physical_cpus) = dispatch_hw_config_init(physical_cpus);
	dispatch_hw_config(active_cpus) = dispatch_hw_config_init(active_cpus);
}

#undef dispatch_hw_config_init

#endif // DISPATCH_HAVE_HW_CONFIG_COMMPAGE

#else // TARGET_OS_WIN32

static inline long
_dispatch_count_bits(unsigned long value)
{
	long bits = 0;
	while (value) {
		bits += (value & 1);
		value = value >> 1;
	}
	return bits;
}

static inline uint32_t
_dispatch_get_ncpus(void)
{
	uint32_t val;
	DWORD_PTR procmask, sysmask;
	if (GetProcessAffinityMask(GetCurrentProcess(), &procmask, &sysmask)) {
		val = _dispatch_count_bits(procmask);
	} else {
		val = 1;
	}
	return val;
}
#endif // TARGET_OS_WIN32

#endif /* __DISPATCH_SHIMS_HW_CONFIG__ */
