// winsock
unit wepoll_ws;

interface

uses Winapi.Windows, Winapi.Winsock2;

const
  SIO_BSP_HANDLE_POLL = $4800001D;
  SIO_BASE_HANDLE     = $48000022;

function ws_get_base_socket(socket: TSocket): TSocket;
function ws_global_init: Integer;

implementation

uses wepoll_err;

function ws_global_init: Integer;
var
  r: Integer;
  wsa_data: WSADATA;
begin
  r := WSAStartup(MAKEWORD(2, 2), wsa_data);
  if r <> 0 then
    result := return_set_error(-1, r)
  else
    result := 0;
end;

function ws__ioctl_get_bsp_socket(socket: TSocket; ioctl: DWORD): TSocket;
var
  bsp_socket: TSocket;
  bytes: DWORD;
begin
  if (WSAIoctl(socket,
               ioctl,
               nil,
               0,
               @bsp_socket,
               sizeof(bsp_socket),
               bytes,
               nil,
               nil) <> SOCKET_ERROR) then
    result := bsp_socket
  else
    result := INVALID_SOCKET;
end;

function ws_get_base_socket(socket: TSocket): TSocket;
var
  base_socket: TSocket;
  error: DWORD;
begin
  while true do
  begin
    base_socket := ws__ioctl_get_bsp_socket(socket, SIO_BASE_HANDLE);
    if base_socket <> INVALID_SOCKET then
      exit(base_socket);
    error := GetLastError();
    if error = WSAENOTSOCK then
    begin
      err_set_win_error(error);
      exit(INVALID_SOCKET);
    end;
    // Even though Microsoft documentation clearly states that LSPs should
    // never intercept the `SIO_BASE_HANDLE` ioctl [1], Komodia based LSPs do
    // so anyway, breaking it, with the apparent intention of preventing LSP
    // bypass [2]. Fortunately they don't handle `SIO_BSP_HANDLE_POLL`, which
    // will at least let us obtain the socket associated with the next winsock
    // protocol chain entry. If this succeeds, loop around and call
    // `SIO_BASE_HANDLE` again with the returned BSP socket, to make sure that
    // we unwrap all layers and retrieve the actual base socket.
    //  [1] https://docs.microsoft.com/en-us/windows/win32/winsock/winsock-ioctls
    //  [2] https://www.komodia.com/newwiki/index.php?title=Komodia%27s_Redirector_bug_fixes#Version_2.2.2.6
    base_socket := ws__ioctl_get_bsp_socket(socket, SIO_BSP_HANDLE_POLL);
    if (base_socket <> INVALID_SOCKET) and (base_socket <> socket) then
      socket := base_socket
    else
    begin
      err_set_win_error(error);
      exit(INVALID_SOCKET);
    end;
  end;
end;


end.
