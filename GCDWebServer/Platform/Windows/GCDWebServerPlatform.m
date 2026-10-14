/*
 ODataStore port: GCDWebServerPlatform.h on Windows: Winsock, its errors as
 errno values, binary-mode files with UTF-16 paths, and the primary address
 from the adapters' list. libdispatch reads and writes sockets itself
 (recv/send on a SOCKET it is given as the descriptor).
 */

#if !__has_feature(objc_arc)
#error GCDWebServer requires ARC
#endif

#import "GCDWebServerPrivate.h"

// iphlpapi.h reaches COM's headers (through ras.h), which use the macro
// interface that gnustep-base undefines for Objective-C's @interface: defined
// here as Windows' own headers define it, for them alone.
#define interface struct
#include <iphlpapi.h>
#undef interface

static void _StartWinsock(void* context) {
  WSADATA data;
  int result = WSAStartup(MAKEWORD(2, 2), &data);
  if (result != 0) {
    GWS_LOG_ERROR(@"Failed starting Winsock: %i", result);
  }
}

void GCDWebServerSocketsStart(void) {
  static dispatch_once_t once;
  dispatch_once_f(&once, NULL, _StartWinsock);
}

BOOL GCDWebServerSocketIsValid(GCDWebServerSocketHandle socket) {
  return socket != INVALID_SOCKET;
}

int GCDWebServerSocketClose(GCDWebServerSocketHandle socket) {
  return closesocket(socket) == 0 ? 0 : -1;
}

/* Winsock's errors as the errno values they stand for, so that what the
   sources compare with (EAFNOSUPPORT, EINTR) and NSPOSIXErrorDomain mean the
   same on both platforms. */
int GCDWebServerSocketLastError(void) {
  int error = WSAGetLastError();
  switch (error) {
    case WSAEINTR: return EINTR;
    case WSAEBADF: return EBADF;
    case WSAEACCES: return EACCES;
    case WSAEFAULT: return EFAULT;
    case WSAEINVAL: return EINVAL;
    case WSAEMFILE: return EMFILE;
    case WSAEWOULDBLOCK: return EWOULDBLOCK;
    case WSAEINPROGRESS: return EINPROGRESS;
    case WSAEALREADY: return EALREADY;
    case WSAENOTSOCK: return ENOTSOCK;
    case WSAEMSGSIZE: return EMSGSIZE;
    case WSAEPROTONOSUPPORT: return EPROTONOSUPPORT;
    case WSAEOPNOTSUPP: return EOPNOTSUPP;
    case WSAEAFNOSUPPORT: return EAFNOSUPPORT;
    case WSAEADDRINUSE: return EADDRINUSE;
    case WSAEADDRNOTAVAIL: return EADDRNOTAVAIL;
    case WSAENETDOWN: return ENETDOWN;
    case WSAENETUNREACH: return ENETUNREACH;
    case WSAECONNABORTED: return ECONNABORTED;
    case WSAECONNRESET: return ECONNRESET;
    case WSAENOBUFS: return ENOBUFS;
    case WSAENOTCONN: return ENOTCONN;
    case WSAETIMEDOUT: return ETIMEDOUT;
    case WSAECONNREFUSED: return ECONNREFUSED;
    case WSAEHOSTUNREACH: return EHOSTUNREACH;
    case 0: return errno;  // Not Winsock's: the C library's
    default: return error;
  }
}

NSString* GCDWebServerSocketErrorString(int error) {
  return [NSString stringWithUTF8String:strerror(error)];
}

void GCDWebServerSocketSetReceiveTimeout(GCDWebServerSocketHandle socket, int seconds) {
  DWORD milliseconds = (DWORD)seconds * 1000;  // Windows takes milliseconds, not a timeval
  setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, (const char*)&milliseconds, sizeof(milliseconds));
}

void GCDWebServerSocketNoBrokenPipeSignal(GCDWebServerSocketHandle socket) {
}

void GCDWebServerIgnoreBrokenPipe(void) {
  // Windows has no SIGPIPE: a send() to a closed socket fails with WSAECONNRESET.
}

int GCDWebServerOpenFile(NSString* path, int flags) {
  // _wopen: UTF-16, so any path opens; O_BINARY: a text-mode file would have its line ends rewritten.
  const wchar_t* wide = (const wchar_t*)[path cStringUsingEncoding:NSUnicodeStringEncoding];
  return wide ? _wopen(wide, flags | O_BINARY | O_NOINHERIT, _S_IREAD | _S_IWRITE) : -1;
}

BOOL GCDWebServerRegularFileInfo(NSString* path, unsigned long long* size, NSDate** modified, NSString** eTag) {
  WIN32_FILE_ATTRIBUTE_DATA data;
  const wchar_t* wide = (const wchar_t*)[path cStringUsingEncoding:NSUnicodeStringEncoding];
  if (!wide || !GetFileAttributesExW(wide, GetFileExInfoStandard, &data)) {
    return NO;
  }
  // A directory or a reparse point (a symbolic link or junction, not followed as lstat() does not) is not served.
  if (data.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DEVICE)) {
    return NO;
  }
  *size = ((unsigned long long)data.nFileSizeHigh << 32) | data.nFileSizeLow;
  // 100 ns intervals since 1601-01-01, which is 11644473600 seconds before the Unix epoch.
  unsigned long long ticks = ((unsigned long long)data.ftLastWriteTime.dwHighDateTime << 32) | data.ftLastWriteTime.dwLowDateTime;
  *modified = [NSDate dateWithTimeIntervalSince1970:((NSTimeInterval)ticks / 10000000.0 - 11644473600.0)];
  // No inode: the size and the time to the 100 ns tick tell one version of the file from another.
  *eTag = [NSString stringWithFormat:@"%llu/%llu", *size, ticks];
  return YES;
}

NSString* GCDWebServerGetPrimaryIPAddress(BOOL useIPv6) {
  NSString* address = nil;
  ULONG length = 16 * 1024;
  IP_ADAPTER_ADDRESSES* adapters = NULL;
  ULONG result = ERROR_BUFFER_OVERFLOW;
  for (int attempt = 0; (attempt < 3) && (result == ERROR_BUFFER_OVERFLOW); ++attempt) {
    free(adapters);
    adapters = malloc(length);
    if (adapters == NULL) {
      return nil;
    }
    result = GetAdaptersAddresses(useIPv6 ? AF_INET6 : AF_INET, GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER, NULL, adapters, &length);
  }
  if (result == NO_ERROR) {
    // The first adapter that is up and not loopback, as on Linux.
    for (IP_ADAPTER_ADDRESSES* adapter = adapters; adapter && !address; adapter = adapter->Next) {
      if ((adapter->OperStatus != IfOperStatusUp) || (adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK)) {
        continue;
      }
      for (IP_ADAPTER_UNICAST_ADDRESS* unicast = adapter->FirstUnicastAddress; unicast; unicast = unicast->Next) {
        address = GCDWebServerStringFromSockAddr(unicast->Address.lpSockaddr, NO);
        if (address) {
          break;
        }
      }
    }
  }
  free(adapters);
  return address;
}
