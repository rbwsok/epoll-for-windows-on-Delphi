unit wepoll_once;

interface

uses Winapi.Windows;

var
  init__done: Boolean;
  init__once: INIT_ONCE; // INIT_ONCE_STATIC_INIT;

function init: Integer;

implementation

uses wepoll_ws, wepoll_reflock, wepoll;

function init__once_callback(once: PINIT_ONCE; parameter, context: Pointer): BOOL; stdcall;
begin
  // N.b. that initialization order matters here.
  if (ws_global_init < 0) or
//     (nt_global_init < 0) or
     (reflock_global_init < 0) or
     (epoll_global_init() < 0) then
    exit(FALSE);
  init__done := true;
  result := TRUE;
end;

function init: Integer;
begin
  if (not init__done) and (not InitOnceExecuteOnce(init__once, @init__once_callback, nil, nil)) then
    // `InitOnceExecuteOnce()` itself is infallible, and it doesn't set any
    // error code when the once-callback returns FALSE. We return -1 here to
    // indicate that global initialization failed; the failing init function is
    // resposible for setting `errno` and calling `SetLastError()`.
    exit(-1);
  result := 0;
end;


end.
