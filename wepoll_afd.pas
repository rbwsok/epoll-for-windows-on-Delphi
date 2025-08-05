unit wepoll_afd;

interface

uses Winapi.Windows, wepoll_types;

const
  afd_name: WideString = '\Device\Afd\Wepoll';

  AFD_POLL_RECEIVE           = $0001;
  AFD_POLL_RECEIVE_EXPEDITED = $0002;
  AFD_POLL_SEND              = $0004;
  AFD_POLL_DISCONNECT        = $0008;
  AFD_POLL_ABORT             = $0010;
  AFD_POLL_LOCAL_CLOSE       = $0020;
  AFD_POLL_ACCEPT            = $0080;
  AFD_POLL_CONNECT_FAIL      = $0100;

  IOCTL_AFD_POLL = $00012024;

type
  _AFD_POLL_HANDLE_INFO = record
    Handle: THandle;
    Events: ULONG;
    Status: NTSTATUS;
  end;
  AFD_POLL_HANDLE_INFO = _AFD_POLL_HANDLE_INFO;
  PAFD_POLL_HANDLE_INFO = ^AFD_POLL_HANDLE_INFO;

  _AFD_POLL_INFO = record
    Timeout: LARGE_INTEGER;
    NumberOfHandles: ULONG;
    Exclusive: ULONG;
    Handles: array [0..0] of AFD_POLL_HANDLE_INFO;
  end;
  AFD_POLL_INFO = _AFD_POLL_INFO;
  PAFD_POLL_INFO = ^_AFD_POLL_INFO;

function afd_create_device_handle(iocp_handle: THandle; afd_device_handle_out: PHandle): Integer;
function afd_cancel_poll(afd_device_handle: THandle; io_status_block: PIO_STATUS_BLOCK): Integer;
function afd_poll(afd_device_handle: THandle; poll_info: PAFD_POLL_INFO; io_status_block: PIO_STATUS_BLOCK): Integer;

implementation

uses wepoll_err;

function afd_create_device_handle(iocp_handle: THandle; afd_device_handle_out: PHandle): Integer;

  procedure RTL_CONSTANT_STRING(const s: WideString; var us: UNICODE_STRING);
  begin
    us.Length := Length(s) * sizeof(WideChar); //sizeof(s) - sizeof((s)[1]);
    us.MaximumLength := us.Length + 2;
    us.Buffer := PWideChar(s);
  end;

  procedure RTL_CONSTANT_OBJECT_ATTRIBUTES(ObjectName: PUNICODE_STRING; Attributes: ULONG; var oa: OBJECT_ATTRIBUTES);
  begin
    oa.Length := sizeof(OBJECT_ATTRIBUTES);
    oa.RootDirectory := 0;
    oa.ObjectName := ObjectName;
    oa.Attributes := Attributes;
    oa.SecurityDescriptor := nil;
    oa.SecurityQualityOfService := nil;
  end;

label error;
const
  FILE_OPEN = $00000001;
var
  afd_device_handle: THandle;
  iosb: IO_STATUS_BLOCK;
  status: NTSTATUS;
  afd__device_name: UNICODE_STRING;
  afd__device_attributes: OBJECT_ATTRIBUTES;
begin
  RTL_CONSTANT_STRING(afd_name, afd__device_name);
  RTL_CONSTANT_OBJECT_ATTRIBUTES(@afd__device_name, 0, afd__device_attributes);
  // By opening \Device\Afd without specifying any extended attributes, we'll
  // get a handle that lets us talk to the AFD driver, but that doesn't have an
  // associated endpoint (so it's not a socket).
  status := NtCreateFile(@afd_device_handle,
                        SYNCHRONIZE,
                        @afd__device_attributes,
                        @iosb,
                        nil,
                        0,
                        FILE_SHARE_READ or FILE_SHARE_WRITE,
                        FILE_OPEN,
                        0,
                        nil,
                        0);
  if status <> STATUS_SUCCESS then
    exit(return_set_error(-1, RtlNtStatusToDosError(status)));
  if CreateIoCompletionPort(afd_device_handle, iocp_handle, 0, 0) = 0 then
    goto error;
  if not SetFileCompletionNotificationModes(afd_device_handle, FILE_SKIP_SET_EVENT_ON_HANDLE) then
    goto error;

  afd_device_handle_out^ := afd_device_handle;
  exit(0);

error:
  CloseHandle(afd_device_handle);
  result := return_map_error(-1);
end;

function afd_poll(afd_device_handle: THandle; poll_info: PAFD_POLL_INFO; io_status_block: PIO_STATUS_BLOCK): Integer;
var
  status: NTSTATUS;
begin

  // Blocking operation is not supported.
  Assert(io_status_block <> nil);
  io_status_block.Status := STATUS_PENDING;
  status := NtDeviceIoControlFile(afd_device_handle,
                                 0,
                                 nil,
                                 io_status_block,
                                 io_status_block,
                                 IOCTL_AFD_POLL,
                                 poll_info,
                                 sizeof(AFD_POLL_INFO),
                                 poll_info,
                                 sizeof(AFD_POLL_INFO));
  if status = STATUS_SUCCESS then
    exit(0)
  else
  if status = STATUS_PENDING then
    result := return_set_error(-1, ERROR_IO_PENDING)
  else
    result := return_set_error(-1, RtlNtStatusToDosError(status));
end;

function afd_cancel_poll(afd_device_handle: THandle; io_status_block: PIO_STATUS_BLOCK): Integer;
var
  cancel_iosb: _IO_STATUS_BLOCK;
  cancel_status: NTSTATUS;
begin
  // If the poll operation has already completed or has been cancelled earlier,
  // there's nothing left for us to do.
  if io_status_block.Status <> STATUS_PENDING then
    exit(0);
  cancel_status := NtCancelIoFileEx(afd_device_handle, io_status_block, @cancel_iosb);
  // NtCancelIoFileEx() may return STATUS_NOT_FOUND if the operation completed
  // just before calling NtCancelIoFileEx(). This is not an error.
  if (cancel_status = STATUS_SUCCESS) or (cancel_status = STATUS_NOT_FOUND) then
    result := 0
  else
    result := return_set_error(-1, RtlNtStatusToDosError(cancel_status));
end;


end.
