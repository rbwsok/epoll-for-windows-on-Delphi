unit wepoll_err;

interface

uses Winapi.Windows, Winapi.Winsock2;

const
  // from errno.h (MSVC)
  EPERM           = 1;
  ENOENT          = 2;
  ESRCH           = 3;
  EINTR           = 4;
  EIO             = 5;
  ENXIO           = 6;
  E2BIG           = 7;
  ENOEXEC         = 8;
  EBADF           = 9;
  ECHILD          = 10;
  EAGAIN          = 11;
  ENOMEM          = 12;
  EACCES          = 13;
  EFAULT          = 14;
  EBUSY           = 16;
  EEXIST          = 17;
  EXDEV           = 18;
  ENODEV          = 19;
  ENOTDIR         = 20;
  EISDIR          = 21;
  ENFILE          = 23;
  EMFILE          = 24;
  ENOTTY          = 25;
  EFBIG           = 27;
  ENOSPC          = 28;
  ESPIPE          = 29;
  EROFS           = 30;
  EMLINK          = 31;
  EPIPE           = 32;
  EDOM            = 33;
  EDEADLK         = 36;
  ENAMETOOLONG    = 38;
  ENOLCK          = 39;
  ENOSYS          = 40;
  ENOTEMPTY       = 41;

  // Error codes used in the Secure CRT functions
  EINVAL          = 22;
  ERANGE          = 34;
  EILSEQ          = 42;
  STRUNCATE       = 80;

  // Support EDEADLOCK for compatibility with older Microsoft C versions
  EDEADLOCK       = EDEADLK;

  // POSIX Supplement
  EADDRINUSE      = 100;
  EADDRNOTAVAIL   = 101;
  EAFNOSUPPORT    = 102;
  EALREADY        = 103;
  EBADMSG         = 104;
  ECANCELED       = 105;
  ECONNABORTED    = 106;
  ECONNREFUSED    = 107;
  ECONNRESET      = 108;
  EDESTADDRREQ    = 109;
  EHOSTUNREACH    = 110;
  EIDRM           = 111;
  EINPROGRESS     = 112;
  EISCONN         = 113;
  ELOOP           = 114;
  EMSGSIZE        = 115;
  ENETDOWN        = 116;
  ENETRESET       = 117;
  ENETUNREACH     = 118;
  ENOBUFS         = 119;
  ENODATA         = 120;
  ENOLINK         = 121;
  ENOMSG          = 122;
  ENOPROTOOPT     = 123;
  ENOSR           = 124;
  ENOSTR          = 125;
  ENOTCONN        = 126;
  ENOTRECOVERABLE = 127;
  ENOTSOCK        = 128;
  ENOTSUP         = 129;
  EOPNOTSUPP      = 130;
  EOTHER          = 131;
  EOVERFLOW       = 132;
  EOWNERDEAD      = 133;
  EPROTO          = 134;
  EPROTONOSUPPORT = 135;
  EPROTOTYPE      = 136;
  ETIME           = 137;
  ETIMEDOUT       = 138;
  ETXTBSY         = 139;
  EWOULDBLOCK     = 140;

  ERROR_HOST_DOWN = 1256;
  ERROR_NOT_FOUND = 1168;

type
  ErrnoMapping = record
    LastError: DWORD;
    Errno: Integer;
  end;

  errno_t = Integer;

const
  ERR__ERRNO_MAPPINGS: array [0..100] of ErrnoMapping = (
    (LastError: ERROR_ACCESS_DENIED;  Errno: EACCES),
    (LastError: ERROR_ALREADY_EXISTS;  Errno: EEXIST),
    (LastError: ERROR_BAD_COMMAND;  Errno: EACCES),
    (LastError: ERROR_BAD_EXE_FORMAT;  Errno: ENOEXEC),
    (LastError: ERROR_BAD_LENGTH;  Errno: EACCES),
    (LastError: ERROR_BAD_NETPATH;  Errno: ENOENT),
    (LastError: ERROR_BAD_NET_NAME;  Errno: ENOENT),
    (LastError: ERROR_BAD_NET_RESP;  Errno: ENETDOWN),
    (LastError: ERROR_BAD_PATHNAME;  Errno: ENOENT),
    (LastError: ERROR_BROKEN_PIPE;  Errno: EPIPE),
    (LastError: ERROR_CANNOT_MAKE;  Errno: EACCES),
    (LastError: ERROR_COMMITMENT_LIMIT;  Errno: ENOMEM),
    (LastError: ERROR_CONNECTION_ABORTED;  Errno: ECONNABORTED),
    (LastError: ERROR_CONNECTION_ACTIVE;  Errno: EISCONN),
    (LastError: ERROR_CONNECTION_REFUSED;  Errno: ECONNREFUSED),
    (LastError: ERROR_CRC;  Errno: EACCES),
    (LastError: ERROR_DIR_NOT_EMPTY;  Errno: ENOTEMPTY),
    (LastError: ERROR_DISK_FULL;  Errno: ENOSPC),
    (LastError: ERROR_DUP_NAME;  Errno: EADDRINUSE),
    (LastError: ERROR_FILENAME_EXCED_RANGE;  Errno: ENOENT),
    (LastError: ERROR_FILE_NOT_FOUND;  Errno: ENOENT),
    (LastError: ERROR_GEN_FAILURE;  Errno: EACCES),
    (LastError: ERROR_GRACEFUL_DISCONNECT;  Errno: EPIPE),
    (LastError: ERROR_HOST_DOWN;  Errno: EHOSTUNREACH),
    (LastError: ERROR_HOST_UNREACHABLE;  Errno: EHOSTUNREACH),
    (LastError: ERROR_INSUFFICIENT_BUFFER;  Errno: EFAULT),
    (LastError: ERROR_INVALID_ADDRESS;  Errno: EADDRNOTAVAIL),
    (LastError: ERROR_INVALID_FUNCTION;  Errno: EINVAL),
    (LastError: ERROR_INVALID_HANDLE;  Errno: EBADF),
    (LastError: ERROR_INVALID_NETNAME;  Errno: EADDRNOTAVAIL),
    (LastError: ERROR_INVALID_PARAMETER;  Errno: EINVAL),
    (LastError: ERROR_INVALID_USER_BUFFER;  Errno: EMSGSIZE),
    (LastError: ERROR_IO_PENDING;  Errno: EINPROGRESS),
    (LastError: ERROR_LOCK_VIOLATION;  Errno: EACCES),
    (LastError: ERROR_MORE_DATA;  Errno: EMSGSIZE),
    (LastError: ERROR_NETNAME_DELETED;  Errno: ECONNABORTED),
    (LastError: ERROR_NETWORK_ACCESS_DENIED;  Errno:  EACCES),
    (LastError: ERROR_NETWORK_BUSY;  Errno: ENETDOWN),
    (LastError: ERROR_NETWORK_UNREACHABLE;  Errno: ENETUNREACH),
    (LastError: ERROR_NOACCESS;  Errno: EFAULT),
    (LastError: ERROR_NONPAGED_SYSTEM_RESOURCES;  Errno: ENOMEM),
    (LastError: ERROR_NOT_ENOUGH_MEMORY;  Errno: ENOMEM),
    (LastError: ERROR_NOT_ENOUGH_QUOTA;  Errno: ENOMEM),
    (LastError: ERROR_NOT_FOUND;  Errno: ENOENT),
    (LastError: ERROR_NOT_LOCKED;  Errno: EACCES),
    (LastError: ERROR_NOT_READY;  Errno: EACCES),
    (LastError: ERROR_NOT_SAME_DEVICE;  Errno: EXDEV),
    (LastError: ERROR_NOT_SUPPORTED;  Errno: ENOTSUP),
    (LastError: ERROR_NO_MORE_FILES; Errno: ENOENT),
    (LastError: ERROR_NO_SYSTEM_RESOURCES;  Errno: ENOMEM),
    (LastError: ERROR_OPERATION_ABORTED;  Errno: EINTR),
    (LastError: ERROR_OUT_OF_PAPER;  Errno: EACCES),
    (LastError: ERROR_PAGED_SYSTEM_RESOURCES;  Errno: ENOMEM),
    (LastError: ERROR_PAGEFILE_QUOTA;  Errno: ENOMEM),
    (LastError: ERROR_PATH_NOT_FOUND;  Errno: ENOENT),
    (LastError: ERROR_PIPE_NOT_CONNECTED;  Errno: EPIPE),
    (LastError: ERROR_PORT_UNREACHABLE;  Errno: ECONNRESET),
    (LastError: ERROR_PROTOCOL_UNREACHABLE;  Errno: ENETUNREACH),
    (LastError: ERROR_REM_NOT_LIST;  Errno: ECONNREFUSED),
    (LastError: ERROR_REQUEST_ABORTED;  Errno: EINTR),
    (LastError: ERROR_REQ_NOT_ACCEP;  Errno: EWOULDBLOCK),
    (LastError: ERROR_SECTOR_NOT_FOUND;  Errno: EACCES),
    (LastError: ERROR_SEM_TIMEOUT;  Errno: ETIMEDOUT),
    (LastError: ERROR_SHARING_VIOLATION;  Errno: EACCES),
    (LastError: ERROR_TOO_MANY_NAMES;  Errno: ENOMEM),
    (LastError: ERROR_TOO_MANY_OPEN_FILES;  Errno: EMFILE),
    (LastError: ERROR_UNEXP_NET_ERR;  Errno: ECONNABORTED),
    (LastError: ERROR_WAIT_NO_CHILDREN;  Errno: ECHILD),
    (LastError: ERROR_WORKING_SET_QUOTA;  Errno: ENOMEM),
    (LastError: ERROR_WRITE_PROTECT;  Errno: EACCES),
    (LastError: ERROR_WRONG_DISK;  Errno: EACCES),
    (LastError: WSAEACCES;  Errno: EACCES),
    (LastError: WSAEADDRINUSE;  Errno: EADDRINUSE),
    (LastError: WSAEADDRNOTAVAIL;  Errno: EADDRNOTAVAIL),
    (LastError: WSAEAFNOSUPPORT;  Errno: EAFNOSUPPORT),
    (LastError: WSAECONNABORTED;  Errno: ECONNABORTED),
    (LastError: WSAECONNREFUSED;  Errno: ECONNREFUSED),
    (LastError: WSAECONNRESET;  Errno: ECONNRESET),
    (LastError: WSAEDISCON;  Errno: EPIPE),
    (LastError: WSAEFAULT;  Errno: EFAULT),
    (LastError: WSAEHOSTDOWN;  Errno: EHOSTUNREACH),
    (LastError: WSAEHOSTUNREACH;  Errno: EHOSTUNREACH),
    (LastError: WSAEINPROGRESS;  Errno: EBUSY),
    (LastError: WSAEINTR;  Errno: EINTR),
    (LastError: WSAEINVAL;  Errno: EINVAL),
    (LastError: WSAEISCONN;  Errno: EISCONN),
    (LastError: WSAEMSGSIZE;  Errno: EMSGSIZE),
    (LastError: WSAENETDOWN;  Errno: ENETDOWN),
    (LastError: WSAENETRESET;  Errno: EHOSTUNREACH),
    (LastError: WSAENETUNREACH;  Errno: ENETUNREACH),
    (LastError: WSAENOBUFS;  Errno: ENOMEM),
    (LastError: WSAENOTCONN;  Errno: ENOTCONN),
    (LastError: WSAENOTSOCK;  Errno: ENOTSOCK),
    (LastError: WSAEOPNOTSUPP;  Errno: EOPNOTSUPP),
    (LastError: WSAEPROCLIM;  Errno: ENOMEM),
    (LastError: WSAESHUTDOWN;  Errno: EPIPE),
    (LastError: WSAETIMEDOUT;  Errno: ETIMEDOUT),
    (LastError: WSAEWOULDBLOCK;  Errno: EWOULDBLOCK),
    (LastError: WSANOTINITIALISED;  Errno: ENETDOWN),
    (LastError: WSASYSNOTREADY;  Errno: ENETDOWN),
    (LastError: WSAVERNOTSUPPORTED;  Errno: ENOSYS)
  );

function return_map_error(value: Integer): Integer;
function return_set_error(value: Integer; error: DWORD): Integer;
procedure err_set_win_error(error: DWORD);
function err_check_handle(handle: THandle): Integer;

var
  errno: Integer;

implementation

function err__map_win_error_to_errno(error: DWORD): errno_t;
var
  it: ErrnoMapping;
begin
  for it in ERR__ERRNO_MAPPINGS do
  begin
    if it.LastError = error then
      exit(it.Errno);
  end;
  result := EINVAL;
end;

procedure err_map_win_error;
begin
  errno := err__map_win_error_to_errno(GetLastError());
end;

procedure err_set_win_error(error: DWORD);
begin
  SetLastError(error);
  errno := err__map_win_error_to_errno(error);
end;

function return_map_error(value: Integer): Integer;
begin
  err_map_win_error;
  result := value;
end;

function return_set_error(value: Integer; error: DWORD): Integer;
begin
  err_set_win_error(error);
  result := value;
end;

function err_check_handle(handle: THandle): Integer;
var
  flags: DWORD;
begin
  // GetHandleInformation() succeeds when passed INVALID_HANDLE_VALUE, so check
  // for this condition explicitly. */
  if handle = INVALID_HANDLE_VALUE then
    exit(return_set_error(-1, ERROR_INVALID_HANDLE));

  if not GetHandleInformation(handle, flags) then
    exit(return_map_error(-1));

  result := 0;
end;

end.
