# GCDWebServer, ported to GNUstep

This is ashalkhakov's fork of [GCDWebServer](https://github.com/swisspol/GCDWebServer),
which is archived upstream: its `gnustep` branch is release `3.5.4`
(`1c36bf07c848476111d523057a3a63b05328ce2a`) ported to GNUstep, and built as
a library for what builds on it (ODataKit's HTTPServerKit). License:
BSD-3-Clause, `LICENSE`, the upstream file, unchanged.

Only `GCDWebServer/Core`, `GCDWebServer/Requests` and `GCDWebServer/Responses`
are built. GCDWebDAVServer, GCDWebUploader, the apps, upstream's tests and its
Xcode project are left as upstream has them, unbuilt.

The port builds with ARC on macOS (Apple Foundation) and on GNUstep on Linux
and Windows (clang, libobjc2 with the gnustep-2.0 runtime, gnustep-base,
libdispatch; on Windows in MSYS2's CLANG64).

## Files

- `GCDWebServer/Core/`, `Requests/`, `Responses/`: upstream's sources with the
  changes below.
- `GCDWebServer/Core/GCDWebServerHTTPMessage.{h,m}`: new, replaces
  CFHTTPMessage (private).
- `GCDWebServer/Core/GCDWebServerPlatform.h` and
  `GCDWebServer/Platform/{POSIX,Windows}/`: new, what differs between POSIX
  and Windows (sockets, files) behind one set of names. The build's include
  path and source list choose the platform's `GCDWebServerPlatformTypes.h` and
  `GCDWebServerPlatform.m` (`GNUmakefile` by target OS, `Makefile.apple`
  POSIX), so the shared sources carry no `#if` for it.
- `GNUmakefile` (GNUstep) and `Makefile.apple` (macOS, iOS): the library,
  built, tested and installed the way gnustep-release-actions runs every
  repository: `make`, `make check`, `make install DESTDIR=...`. On GNUstep it
  installs `libGCDWebServer` and its headers in `GCDWebServer/`; on Apple,
  `GCDWebServer.xcframework` (a static library for macOS, iOS and the
  simulator, the headers in `GCDWebServer/`).
- `Tests/GNUstep/gws-smoke.m`: smoke test over plain sockets, through
  `GCDWebServerPlatform.h` (`make check`).
- `Tests/GNUstep/gws-cfcompare.m`: macOS only; compares the CFHTTPMessage
  replacement with CFNetwork (`make -f Makefile.apple check` runs it too).

## What the port changed

Upstream is archived, so there are no releases to take. This branch starts
from upstream's `3.5.4` (`1c36bf07`), so its history is the port:

    git diff 1c36bf07 -- GCDWebServer/Core GCDWebServer/Requests GCDWebServer/Responses

Changes are marked `ODataStore port` in comments, or sit in the guards named below.

## Changes

HTTP message parsing and serialisation:

- CFHTTPMessage replaced by `GCDWebServerHTTPMessage`: incremental request-head
  parser (request line, header fields, CRLFCRLF) and response-head writer.
- Header names keep their wire spelling; lookups are case-insensitive
  (`GCDWebServerHeaderDictionary`). CFHTTPMessage canonicalised the common
  names instead; upstream's `objectForKey:@"Content-Type"` lookups still work.
- Repeated request header fields are joined with ", ", as CFHTTPMessage did.
- Rejected with 400: bare CR or LF, obs-fold, whitespace before the colon,
  control characters in values, malformed request line, an undecodable
  request target, conflicting or non-numeric Content-Length, and
  Content-Length together with Transfer-Encoding. Transfer-Encoding other than
  `chunked` gets 501; an HTTP major version other than 1 gets 505. Upstream
  answered most of these with 500, or not at all.
- Status lines use the RFC 9110 reason phrases (CFHTTPMessage's table was
  older, e.g. 431 was "Bad Request"). CR/LF in response header values are
  replaced by spaces.
- The request URL is built as CFHTTPMessageCopyRequestURL() did: relative to
  `http://<Host>/` (or `fake://host/` without Host); characters not allowed
  in URLs are percent-escaped, existing escapes are kept.
- `CFURLCopyPath()` / `CFURLCopyQueryString()` became
  `GCDWebServerCopyURLPath()` / `GCDWebServerCopyURLQueryString()`, which split
  the URL's own string, so escapes, trailing slashes and `;params` survive as
  before. `/svc/Products(1)?$filter=Name%20eq%20'x'` gives path
  `/svc/Products(1)` and query `$filter=Name%20eq%20'x'` on both platforms.
- `GCDWebServerEscapeURLString()` / `GCDWebServerUnescapeURLString()` use
  Foundation; unescaping is strict (a bad escape or invalid UTF-8 gives nil)
  because GNUstep's `-stringByRemovingPercentEncoding` is lenient.

`Tests/GNUstep/gws-cfcompare.m` (`make -f Makefile.apple cfcompare`, macOS only) checks this against
CFHTTPMessage and CFURL for 17 request targets, with and without Host: method,
URL, path, query, header lookup and unescaping all match.

Platform:

- `TargetConditionals.h` only on Apple; elsewhere `TARGET_OS_IPHONE`,
  `TARGET_IPHONE_SIMULATOR` and `TARGET_OS_TV` are defined to 0.
- `CFUUID` → `NSUUID` (only in the compiled-out digest nonce).
- `CFSocketNativeHandle` → `GCDWebServerSocketHandle` (`int`; a `SOCKET` on
  Windows), valid when `GCDWebServerSocketIsValid()` says so, closed with
  `GCDWebServerSocketClose()`; socket errors from
  `GCDWebServerSocketLastError()`, errno values on both platforms (Winsock's
  are translated), so `NSPOSIXErrorDomain` errors and the no-IPv6 fallback
  mean the same.
- `sin_len`, `sin6_len`, `sa_len` only on Apple; elsewhere the length comes
  from the address family.
- `st_mtimespec` → `st_mtim` off Apple (File response Last-Modified and ETag).
- `SO_NOSIGPIPE` where it exists. Elsewhere `-startWithOptions:error:`
  sets SIGPIPE to SIG_IGN if it is still SIG_DFL: libdispatch does the writes,
  so `MSG_NOSIGNAL` is not an option. A handler the application installed is
  left alone. Windows has no SIGPIPE.
- Windows: Winsock is started once before the first socket; files (request
  and response bodies) are opened in binary mode with UTF-16 paths, since a
  text-mode file has its line ends rewritten; a file response's size,
  Last-Modified and ETag come from the file's attributes (no inode: size and
  modification time), and a reparse point (symbolic link, junction) is not
  served, as `lstat()` and `O_NOFOLLOW` refuse a link elsewhere. libdispatch
  reads and writes the sockets itself (`recv`/`send` on Windows).
- MIME types: UTType on Apple (deprecation warning silenced); elsewhere a small
  table (json, xml, txt, html, css, js, csv, png, jpg, gif, svg, ico, pdf, zip),
  `application/octet-stream` otherwise.
- Charset names: CFStringConvertIANACharSetNameToEncoding on Apple; elsewhere a
  table of the common IANA names, UTF-8 otherwise.
- Primary IP address (`serverURL` when not bound to localhost): SystemConfiguration
  on Apple; elsewhere the first interface that is up and not loopback
  (`GetAdaptersAddresses()` on Windows).
- The disconnect-coalescing timer is a dispatch source on the main queue
  instead of a CFRunLoopTimer (all platforms).
- `-runWithOptions:` and its helper use NSRunLoop instead of CFRunLoop off Apple.
- The typed `NSDictionary<NSString*, NSString*>*` for Basic auth accounts,
  which GNUstep's block signature for `-enumerateKeysAndObjectsUsingBlock:` needs.

Compiled out (`__GCDWEBSERVER_ENABLE_BONJOUR_NAT__`,
`__GCDWEBSERVER_ENABLE_DIGEST_AUTH__`, both 0 in `GCDWebServerPrivate.h`; the
code is kept only to keep this diff small):

- Bonjour (CFNetService) and NAT port mapping (dns_sd). The options are accepted
  and ignored; `bonjourName`, `bonjourType`, `bonjourServerURL` and
  `publicServerURL` return nil; the delegate callbacks never fire.
- Digest authentication (CommonCrypto MD5). Asking for it makes
  `-startWithOptions:error:` fail instead of running unauthenticated. Basic
  authentication still works.
- iOS background suspension stays under `TARGET_OS_IPHONE`, which is 0 on both
  supported platforms. iOS is not a target of the port.
- The `__GCDWEBSERVER_ENABLE_TESTING__` recording and replay code still uses
  CFHTTPMessage and builds on Apple only. It was never enabled here.

Logging:

- The built-in logger is the default on both platforms, at level Warning
  (upstream: Info, or Debug with `DEBUG`). It logs with NSLog, also when stderr
  is not a terminal (upstream logged only to a tty). `+setLogLevel:` and
  `+setBuiltInLogger:` work as before.

Added:

- `GCDWebServerOption_MaxHeadSize` (default 64 KiB): larger request heads get 431.
- `GCDWebServerOption_MaxBodySize` (default 64 MiB, 0 means no limit): a larger
  Content-Length gets 413 before the body is read (also before
  `100 Continue`); a chunked body gets 413 as soon as a chunk size goes over.
- `GCDWebServerOption_ReadTimeout` (default 60 s, 0 disables): the time from
  accept to the end of the request body. When it runs out the read side is
  shut down and the server answers 408.
- Chunked bodies: the chunk-size line is limited to 4 KiB and the trailer
  section to the head size limit.
- `GCDWebServerOption_KeepAliveTimeout` (default 0: off, as upstream) and
  `GCDWebServerOption_MaxRequestsPerConnection` (default 100, 0 means no
  limit): HTTP/1.1 persistent connections. After a response the connection
  waits this long for the next request (`-_finishOrKeepAlive:` resets the
  per-request state and reads the next head; its first bytes restart the
  read timeout), and one that receives nothing is closed without an answer.
  A connection is kept only when it is safe to: an HTTP/1.1 request without
  `Connection: close`, no chunked request body (reading one can run past
  it), nothing read past the request (a pipelined request closes it), and a
  response whose end the client can find (a length, chunks, or no body,
  for which `Content-Length: 0` is sent). Any other is closed as before,
  with `Connection: Close`.

Fixed along the way:

- A chunked body whose last chunk and trailer arrived in separate reads spun
  forever re-scanning the same bytes; now it waits for more data.
- A request body that could not be read completely (client gone, timeout,
  bad chunk) was still passed to the handler, truncated. Now the request is
  aborted with 400, 408 or 413.
- A request path that does not unescape (`/%FF`) got 500 and, in `DEBUG`
  builds, `abort()`. Now it gets 400.
- The socket is closed as soon as the last byte of the response is written
  (`-_finish`), rather than when the connection object is deallocated.
  `-close` and the delegate's disconnect bookkeeping run at the same point.
- Listening on every address (not bound to localhost) failed on Linux: the
  IPv6 wildcard socket also takes IPv4 there unless `IPV6_V6ONLY` is set,
  so binding it after the IPv4 one gave EADDRINUSE. The IPv6 socket is now
  IPv6 only. A host without IPv6 (EAFNOSUPPORT, EPROTONOSUPPORT,
  EADDRNOTAVAIL, as in many containers) is served over IPv4 alone instead
  of failing to start.

## libobjc2 and stack blocks

libobjc2's `objc_retain()` copies a stack block to the heap and returns the
copy (`retain()` in `arc.mm` calls `Block_copy` on any block); Apple's
runtime returns a stack block unchanged. LLVM's ARC optimiser treats
`objc_retain` as returning its argument, so at `-O1` and above (and
`gnustep-config --objc-flags` says `-O2`) the result goes unused: the retain
ARC makes of a block parameter creates a heap copy that nothing refers to,
the matching release goes to the stack block, which the runtime ignores,
and the copy leaks along with everything it captured. It shows whenever a
block literal is passed to a function or method that captures the
parameter in another block (a completion handler, `dispatch_async`). Seen
with clang 18.1.3 and libobjc2 v2.2-92-gaca3916 in the `ois-dev`
container; macOS is not affected. For GCDWebServer the leaked object was
the connection: its socket stayed open until the client hung up.

Workaround here: every method that takes a block and keeps or captures it
starts with `block = [block copy];`, so what it captures is already a heap
block, which is retained in place. The smoke test's `no-leaked-connections`
check counts live connection objects.

The fix belongs in libobjc2: `retain()` should return a stack block
unchanged and leave moving it to the heap to `objc_retainBlock()`. It is
`libobjc2/stack-block-retain` in gnustep-patches. Until the runtime carries it, application code built on
this toolchain that captures block parameters in other blocks leaks too.

## Behaviour that differs from upstream

- The header dictionary implements fast enumeration itself: gnustep-base
  leaves `-countByEnumeratingWithState:objects:count:` to `NSDictionary`'s
  subclasses, so `for (name in request.headers)` raised on GNUstep.
- Header dictionaries keep wire spelling instead of CFHTTPMessage's
  canonical names (lookups are case-insensitive, so upstream code is unaffected).
- `-[NSURL absoluteString]` of the request URL can differ between macOS and
  GNUstep for odd targets (`//`, `/a?`). Path and query, which the server uses,
  do not.
- Stricter parsing, the new limits and the status codes listed above.
- Keep-alive, when asked for (`GCDWebServerOption_KeepAliveTimeout`); off
  by default, closing every connection after one response, as upstream.
