unit wepoll_port;

interface

uses Winapi.Windows, Winapi.Winsock2, System.Win.Crtl, wepoll_tree, wepoll_queue, wepoll_ts_tree, wepoll_types;

{$POINTERMATH ON}

type
  port_state = record
    iocp_handle: THandle;
    sock_tree: tree_t;
    sock_update_queue: queue_t;
    sock_deleted_queue: queue_t;
    poll_group_queue: queue_t;
    handle_tree_node: ts_tree_node_t;
    lock: _RTL_CRITICAL_SECTION;
    active_poll_count: size_t;
  end;
  port_state_t = port_state;
  pport_state_t = ^port_state_t;

const
  PORT__MAX_ON_STACK_COMPLETIONS = 256;

function port_get_iocp_handle(port_state: pport_state_t): THandle;
function port_get_poll_group_queue(port_state: pport_state_t): pqueue_t;
//function port_register_socket(port_state: pport_state_t; sock_state: psock_state_t; sock: TSocket): Integer;
function port_register_socket(port_state: pport_state_t; sock_state: Pointer; sock: TSocket): Integer;
//procedure port_cancel_socket_update(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_cancel_socket_update(port_state: pport_state_t; sock_state: Pointer);
//procedure port_unregister_socket(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_unregister_socket(port_state: pport_state_t; sock_state: Pointer);
//procedure port_remove_deleted_socket(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_remove_deleted_socket(port_state: pport_state_t; sock_state: Pointer);
//procedure port_add_deleted_socket(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_add_deleted_socket(port_state: pport_state_t; sock_state: Pointer);
//procedure port_request_socket_update(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_request_socket_update(port_state: pport_state_t; sock_state: Pointer);
function port_new(iocp_handle_out: PHandle): pport_state_t;
function port_state_to_handle_tree_node(port_state: pport_state_t): pts_tree_node_t;
function port_delete(port_state: pport_state_t): Integer;
function port_state_from_handle_tree_node(tree_node: pts_tree_node_t): pport_state_t;
function port_close(port_state: pport_state_t): Integer;
function port_ctl(port_state: pport_state_t; op: Integer; sock: TSocket; ev: pepoll_event): Integer;
function port_wait(port_state: pport_state_t; events: pepoll_event; maxevents: Integer; timeout: Integer): Integer;

implementation

uses wepoll_err, wepoll_poll_group, wepoll_sock;

function port__alloc: pport_state_t;
var
  port_state: pport_state_t;
begin
  port_state := malloc(sizeof(port_state_t));
  if port_state = nil then
  begin
    return_set_error(0, ERROR_NOT_ENOUGH_MEMORY);
    exit(nil);
  end;
  result := port_state;
end;

procedure port__free(port: pport_state_t);
begin
  assert(port <> nil);
  free(port);
end;

function port__create_iocp: THandle;
begin
  result := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
  if result = 0 then
    return_map_error(0);
end;

function port_new(iocp_handle_out: PHandle): pport_state_t;
label err1, err2;
var
  port_state: pport_state_t;
  iocp_handle: THandle;
begin
  port_state := port__alloc;
  if port_state = nil then
    goto err1;
  iocp_handle := port__create_iocp;
  if iocp_handle = 0 then
    goto err2;
  memset(port_state, 0, sizeof(port_state_t));
  port_state.iocp_handle := iocp_handle;
  tree_init(@port_state.sock_tree);
  queue_init(@port_state.sock_update_queue);
  queue_init(@port_state.sock_deleted_queue);
  queue_init(@port_state.poll_group_queue);
  ts_tree_node_init(@port_state.handle_tree_node);
  InitializeCriticalSection(port_state.lock);
  iocp_handle_out^ := iocp_handle;

  exit(port_state);
err2:
  port__free(port_state);
err1:
  result := nil;
end;

function port__close_iocp(port_state: pport_state_t): Integer;
var
  iocp_handle: THandle;
begin
  iocp_handle := port_state.iocp_handle;
  port_state.iocp_handle := 0;
  if not CloseHandle(iocp_handle) then
    exit(return_map_error(-1));
  result := 0;
end;

function port_close(port_state: pport_state_t): Integer;
begin
  EnterCriticalSection(port_state.lock);
  result := port__close_iocp(port_state);
  LeaveCriticalSection(port_state.lock);
end;

function port_delete(port_state: pport_state_t): Integer;
var
  tree_node: ptree_node_t;
  queue_node: pqueue_node_t;
  sock_state: psock_state_t;
  poll_group: ppoll_group_t;
begin
  // At this point the IOCP port should have been closed.
  assert(port_state.iocp_handle = 0);

  while true do
  begin
    tree_node := tree_root(@port_state.sock_tree);
    if tree_node = nil then
      break;
    sock_state := sock_state_from_tree_node(tree_node);
    sock_force_delete(port_state, sock_state);
  end;

  while true do
  begin
    queue_node := queue_first(@port_state.sock_deleted_queue);
    if queue_node = nil then
      break;

    sock_state := sock_state_from_queue_node(queue_node);
    sock_force_delete(port_state, sock_state);
  end;

  while true do
  begin
    queue_node := queue_first(@port_state.poll_group_queue);
    if queue_node = nil then
      break;

    poll_group := poll_group_from_queue_node(queue_node);
    poll_group_delete(poll_group);
  end;

  assert(queue_is_empty(@port_state.sock_update_queue));
  DeleteCriticalSection(port_state.lock);
  port__free(port_state);
  result := 0;
end;

function port__update_events(port_state: pport_state_t): Integer;
var
  sock_update_queue: pqueue_t;
  queue_node: pqueue_node_t;
  sock_state: psock_state_t;
begin
  sock_update_queue := @port_state.sock_update_queue;
  // Walk the queue, submitting new poll requests for every socket that needs it.
  while not queue_is_empty(sock_update_queue) do
  begin
    queue_node := queue_first(sock_update_queue);
    sock_state := sock_state_from_queue_node(queue_node);
    if sock_update(port_state, sock_state) < 0 then
      exit(-1);
    // sock_update() removes the socket from the update queue.
  end;
  result := 0;
end;

procedure port__update_events_if_polling(port_state: pport_state_t);
begin
  if port_state.active_poll_count > 0 then
    port__update_events(port_state);
end;

function port__feed_events(port_state: pport_state_t; epoll_events: pepoll_event; iocp_events: POverlappedEntry; iocp_event_count: Cardinal): Integer;
var
  epoll_event_count: Integer;
  i: Cardinal;
  io_status_block: PIO_STATUS_BLOCK;
  ev: pepoll_event;
begin
  epoll_event_count := 0;

  for i := 0 to iocp_event_count - 1 do
  begin
    io_status_block := PIO_STATUS_BLOCK(iocp_events[i].lpOverlapped);
    ev := @epoll_events[epoll_event_count];
    epoll_event_count := epoll_event_count + sock_feed_event(port_state, io_status_block, ev);
  end;
  result := epoll_event_count;
end;

function port__poll(port_state: pport_state_t; epoll_events: pepoll_event; iocp_events: POverlappedEntry; maxevents: DWORD; timeout: DWORD): Integer;
var
  completion_count: DWORD;
  r: Boolean;
begin
  if port__update_events(port_state) < 0 then
    exit(-1);
  inc(port_state.active_poll_count);
  LeaveCriticalSection(port_state.lock);
  r := GetQueuedCompletionStatusEx(port_state.iocp_handle, iocp_events^, maxevents, completion_count, timeout, FALSE);
  EnterCriticalSection(port_state.lock);
  dec(port_state.active_poll_count);
  if not r then
    exit(return_map_error(-1));
  result := port__feed_events(port_state, epoll_events, iocp_events, completion_count);
end;

function port_wait(port_state: pport_state_t; events: pepoll_event; maxevents: Integer; timeout: Integer): Integer;
var
  stack_iocp_events: array [0..PORT__MAX_ON_STACK_COMPLETIONS - 1] of OVERLAPPED_ENTRY;
  iocp_events: POverlappedEntry;
  due: UInt64;
  gqcs_timeout: DWORD;
  n: UInt64;
begin
  due := 0;
  // Check whether `maxevents` is in range.
  if maxevents <= 0 then
    exit(return_set_error(-1, ERROR_INVALID_PARAMETER));
  // Decide whether the IOCP completion list can live on the stack, or allocate
  // memory for it on the heap.
  if maxevents <= sizeof(stack_iocp_events) div sizeof(stack_iocp_events[0]) then
    iocp_events := @stack_iocp_events
  else
  begin
    iocp_events := malloc(maxevents * sizeof(iocp_events));
    if iocp_events = nil then
    begin
      iocp_events := @stack_iocp_events;
      maxevents := sizeof(stack_iocp_events) div sizeof(stack_iocp_events[0]);
    end;
  end;

  // Compute the timeout for GetQueuedCompletionStatus, and the wait end
  // time, if the user specified a timeout other than zero or infinite.
  if timeout > 0 then
  begin
    due := GetTickCount64() + UInt64(timeout);
    gqcs_timeout := timeout;
  end
  else
  if timeout = 0 then
    gqcs_timeout := 0
  else
    gqcs_timeout := INFINITE;

  EnterCriticalSection(port_state.lock);
  // Dequeue completion packets until either at least one interesting event
  // has been discovered, or the timeout is reached.
  while true do
  begin
    result := port__poll(port_state, events, iocp_events, maxevents, gqcs_timeout);
    if (result < 0) or (result > 0) then
      break; // Result, error, or time-out.
    if timeout < 0 then
      continue; // When timeout is negative, never time out.
    // Update time.
    n := GetTickCount64();
    // Do not allow the due time to be in the past.
    if n >= due then
    begin
      SetLastError(WAIT_TIMEOUT);
      break;
    end;
    // Recompute time-out argument for GetQueuedCompletionStatus.
    gqcs_timeout := due - n;
  end;
  port__update_events_if_polling(port_state);
  LeaveCriticalSection(port_state.lock);
  if iocp_events <> @stack_iocp_events then
    free(iocp_events);
  if result >= 0 then
    exit
  else
  if GetLastError = WAIT_TIMEOUT then
    result := 0
  else
    result := -1;
end;

function port__ctl_add(port_state: pport_state_t; sock: TSocket; ev: pepoll_event): Integer;
var
  sock_state: psock_state_t;
begin
  sock_state := sock_new(port_state, sock);
  if sock_state = nil then
    exit(-1);
  if sock_set_event(port_state, sock_state, ev) < 0 then
  begin
    sock_delete(port_state, sock_state);
    exit(-1);
  end;
  port__update_events_if_polling(port_state);
  result := 0;
end;

function port_find_socket(port_state: pport_state_t; sock: TSocket): psock_state_t;
var
  tree_node: ptree_node_t;
begin
  tree_node := tree_find(@port_state.sock_tree, sock);
  if tree_node = nil then
  begin
    return_set_error(0, ERROR_NOT_FOUND);
    exit(nil);
  end;

  result := sock_state_from_tree_node(tree_node);
end;

function port__ctl_mod(port_state: pport_state_t; sock: TSocket; ev: pepoll_event): Integer;
var
  sock_state: psock_state_t;
begin
  sock_state := port_find_socket(port_state, sock);
  if sock_state = nil then
    exit(-1);
  if sock_set_event(port_state, sock_state, ev) < 0 then
    exit(-1);
  port__update_events_if_polling(port_state);
  result := 0;
end;

function port__ctl_del(port_state: pport_state_t; sock: TSocket): Integer;
var
  sock_state: psock_state_t;
begin
  sock_state := port_find_socket(port_state, sock);
  if sock_state = nil then
    exit(-1);
  sock_delete(port_state, sock_state);
  result := 0;
end;

function port__ctl_op(port_state: pport_state_t; op: Integer; sock: TSocket; ev: pepoll_event): Integer;
begin
  case op of
    EPOLL_CTL_ADD:
      result := port__ctl_add(port_state, sock, ev);
    EPOLL_CTL_MOD:
      result := port__ctl_mod(port_state, sock, ev);
    EPOLL_CTL_DEL:
      result := port__ctl_del(port_state, sock);
    else
      result := return_set_error(-1, ERROR_INVALID_PARAMETER);
  end;
end;

function port_ctl(port_state: pport_state_t; op: Integer; sock: TSocket; ev: pepoll_event): Integer;
begin
  EnterCriticalSection(port_state.lock);
  result := port__ctl_op(port_state, op, sock, ev);
  LeaveCriticalSection(port_state.lock);
end;

//function port_register_socket(port_state: pport_state_t; sock_state: psock_state_t; sock: TSocket): Integer;
function port_register_socket(port_state: pport_state_t; sock_state: Pointer; sock: TSocket): Integer;
begin
  if tree_add(@port_state.sock_tree, sock_state_to_tree_node(sock_state), sock) < 0 then
    exit(return_set_error(-1, ERROR_ALREADY_EXISTS));
  result := 0;
end;

//procedure port_unregister_socket(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_unregister_socket(port_state: pport_state_t; sock_state: Pointer);
begin
  tree_del(@port_state.sock_tree, sock_state_to_tree_node(sock_state));
end;

//procedure port_request_socket_update(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_request_socket_update(port_state: pport_state_t; sock_state: Pointer);
begin
  if queue_is_enqueued(sock_state_to_queue_node(sock_state)) then
    exit;

  queue_append(@port_state.sock_update_queue, sock_state_to_queue_node(sock_state));
end;

//procedure port_cancel_socket_update(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_cancel_socket_update(port_state: pport_state_t; sock_state: Pointer);
begin
  if not queue_is_enqueued(sock_state_to_queue_node(sock_state)) then
    exit;

  queue_remove(sock_state_to_queue_node(sock_state));
end;

//procedure port_add_deleted_socket(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_add_deleted_socket(port_state: pport_state_t; sock_state: Pointer);
begin
  if queue_is_enqueued(sock_state_to_queue_node(sock_state)) then
    exit;

  queue_append(@port_state.sock_deleted_queue, sock_state_to_queue_node(sock_state));
end;

//procedure port_remove_deleted_socket(port_state: pport_state_t; sock_state: psock_state_t);
procedure port_remove_deleted_socket(port_state: pport_state_t; sock_state: Pointer);
begin
  if not queue_is_enqueued(sock_state_to_queue_node(sock_state)) then
    exit;

  queue_remove(sock_state_to_queue_node(sock_state));
end;

function port_get_iocp_handle(port_state: pport_state_t): THandle;
begin
  assert(port_state.iocp_handle <> 0);

  result := port_state.iocp_handle;
end;

function port_get_poll_group_queue(port_state: pport_state_t): pqueue_t;
begin
  result := @port_state.poll_group_queue;
end;

function port_state_from_handle_tree_node(tree_node: pts_tree_node_t): pport_state_t;
begin
  result := pport_state_t(PByte(tree_node) - NativeUInt(@pport_state_t(nil).handle_tree_node));
end;

function port_state_to_handle_tree_node(port_state: pport_state_t): pts_tree_node_t;
begin
  result := @port_state.handle_tree_node;
end;



end.
