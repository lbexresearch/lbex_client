#ifndef _LOGGER_H
#define _LOGGER_H

#include <time.h>
#include <sys/time.h>

struct timespec log_time;

#ifdef DEBUG
    #define _DEBUG(format, ...) \
    clock_gettime(CLOCK_REALTIME, &log_time); \
    fprintf (stdout, "%09i.%09i [DEBUG][%s] "format, (uint32_t) log_time.tv_sec, ( uint32_t )log_time.tv_nsec, __FUNCTION__, __VA_ARGS__)
#else
    #define _DEBUG(fmt, args...)
#endif

#define log_info(format, ...) \
    clock_gettime(CLOCK_REALTIME, &log_time) ; \
    fprintf (stdout, "%09i.%09i [INFO][%s] "format, (uint32_t) log_time.tv_sec, ( uint32_t )log_time.tv_nsec, __FUNCTION__, __VA_ARGS__)

#define log_err(format, ...) \
    clock_gettime(CLOCK_REALTIME, &log_time) ; \
    fprintf (stdout, "%09i.%09i [ERR][%s] "format, (uint32_t)log_time.tv_sec, ( uint32_t )log_time.tv_nsec, __FUNCTION__, __VA_ARGS__)

#endif
