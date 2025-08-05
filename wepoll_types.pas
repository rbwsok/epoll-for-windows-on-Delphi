unit wepoll_types;

interface

uses Winapi.Windows, Winapi.Winsock2;

const
  EPOLLIN      = 1 shl 0;
  EPOLLPRI     = 1 shl 1;
  EPOLLOUT     = 1 shl 2;
  EPOLLERR     = 1 shl 3;
  EPOLLHUP     = 1 shl 4;
  EPOLLRDNORM  = 1 shl 6;
  EPOLLRDBAND  = 1 shl 7;
  EPOLLWRNORM  = 1 shl 8;
  EPOLLWRBAND  = 1 shl 9;
  EPOLLMSG     = 1 shl 10;
  EPOLLRDHUP   = 1 shl 13;
  EPOLLONESHOT = 1 shl 31;

  EPOLL_CTL_ADD = 1;
  EPOLL_CTL_MOD = 2;
  EPOLL_CTL_DEL = 3;

  KEYEDEVENT_WAIT = $00000001;
  KEYEDEVENT_WAKE = $00000002;
  KEYEDEVENT_ALL_ACCESS = (STANDARD_RIGHTS_REQUIRED or KEYEDEVENT_WAIT or KEYEDEVENT_WAKE);

  STATUS_SUCCESS = NTSTATUS($00000000);
  STATUS_NOT_FOUND = NTSTATUS($C0000225);
  STATUS_CANCELLED = NTSTATUS($C0000120);
  STATUS_PENDING = NTSTATUS($00000103);

  FILE_SKIP_COMPLETION_PORT_ON_SUCCESS = 1;
  FILE_SKIP_SET_EVENT_ON_HANDLE = 2;

type
  epoll_data = record
    ptr: Pointer;
    fd: Integer;
    u32: Cardinal;
    u64: UInt64;
    sock: TSocket; // Windows specific
    hnd: THandle;  // Windows specific
  end;
  epoll_data_t = epoll_data;

  pepoll_event = ^epoll_event;
  epoll_event = record
    events: Cardinal;    // Epoll events and flags
    data: epoll_data_t;  // User data variable
  end;

  PLARGE_INTEGER = ^LARGE_INTEGER;

  _IO_STATUS_BLOCK = record
    Status: NTSTATUS;
    Information: ULONG_PTR;
  end;
  PIO_STATUS_BLOCK = ^_IO_STATUS_BLOCK;
  IO_STATUS_BLOCK = _IO_STATUS_BLOCK;

  _UNICODE_STRING = record
    Length: USHORT;
    MaximumLength: USHORT;
    Buffer: LPWSTR;
  end;
  UNICODE_STRING = _UNICODE_STRING;
  PUNICODE_STRING = ^_UNICODE_STRING;

  _OBJECT_ATTRIBUTES = record
    Length: ULONG;
    RootDirectory: THandle;
    ObjectName: PUNICODE_STRING;
    Attributes: ULONG;
    SecurityDescriptor: PVOID;
    SecurityQualityOfService: PVOID;
  end;
  OBJECT_ATTRIBUTES = _OBJECT_ATTRIBUTES;
  POBJECT_ATTRIBUTES = ^_OBJECT_ATTRIBUTES;

  PSRWLOCK = ^_RTL_SRWLOCK;

  PIO_APC_ROUTINE = procedure(ApcContext: PVOID; IoStatusBlock: PIO_STATUS_BLOCK; Reserved: ULONG); stdcall;

function SetFileCompletionNotificationModes(FileHandle: THandle; Flags: UCHAR): BOOL; stdcall; external 'kernel32.dll';

function NtCreateFile(FileHandle: PHANDLE; DesiredAccess: ACCESS_MASK; ObjectAttributes: POBJECT_ATTRIBUTES; IoStatusBlock: PIO_STATUS_BLOCK;
  AllocationSize: PLARGE_INTEGER; FileAttributes: ULONG; ShareAccess: ULONG; CreateDisposition: ULONG; CreateOptions: ULONG; EaBuffer: PVOID;
  EaLength: ULONG): NTSTATUS; stdcall; external 'ntdll.dll';

function RtlNtStatusToDosError(Status: NTSTATUS): ULONG; stdcall; external 'ntdll.dll'

function NtDeviceIoControlFile(FileHandle: THandle; Event: THandle; ApcRoutine: PIO_APC_ROUTINE; ApcContext: PVOID;IoStatusBlock: PIO_STATUS_BLOCK;
    IoControlCode: ULONG; InputBuffer: PVOID; InputBufferLength: ULONG; OutputBuffer: PVOID; OutputBufferLength: ULONG): NTSTATUS; stdcall; external 'ntdll.dll';

function NtCancelIoFileEx(FileHandle: THandle; IoRequestToCancel: PIO_STATUS_BLOCK; IoStatusBlock: PIO_STATUS_BLOCK): NTSTATUS; stdcall; external 'ntdll.dll';

function NtCreateKeyedEvent(KeyedEventHandle: PHandle; DesiredAccess: ACCESS_MASK; ObjectAttributes: POBJECT_ATTRIBUTES; Flags: ULONG): NTSTATUS; stdcall; external 'ntdll.dll';

function NtReleaseKeyedEvent(KeyedEventHandle: THandle; KeyValue: Pointer; Alertable: Boolean; Timeout: PLARGE_INTEGER): NTSTATUS; stdcall; external 'ntdll.dll';

function NtWaitForKeyedEvent(KeyedEventHandle: THandle; KeyValue: Pointer; Alertable: Boolean; Timeout: PLARGE_INTEGER): NTSTATUS; stdcall; external 'ntdll.dll';


implementation

end.
