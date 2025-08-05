unit wepoll_sock;

interface

uses Winapi.Windows, Winapi.Winsock2, System.Win.Crtl, wepoll_types, wepoll_afd, wepoll_queue, wepoll_tree, wepoll_poll_group;

const
  SOCK__KNOWN_EPOLL_EVENTS = EPOLLIN or EPOLLPRI or EPOLLOUT or EPOLLERR or EPOLLHUP or EPOLLRDNORM or EPOLLRDBAND or EPOLLWRNORM or EPOLLWRBAND or EPOLLMSG or EPOLLRDHUP;

type
  sock__poll_status = (
    SOCK__POLL_IDLE = 0,
    SOCK__POLL_PENDING,
    SOCK__POLL_CANCELLED
  );
  sock__poll_status_t = sock__poll_status;

  sock_state = record
    io_status_block: IO_STATUS_BLOCK;
    poll_info: AFD_POLL_INFO;
    queue_node: queue_node_t;
    tree_node: tree_node_t;
    poll_group: ppoll_group_t;
    base_socket: TSocket;
    user_data: epoll_data_t;
    user_events: Cardinal;
    pending_events: Cardinal;
    poll_status: sock__poll_status_t;
    delete_pending: Boolean;
  end;
  sock_state_t = sock_state;
  psock_state_t = ^sock_state_t;

function sock_state_from_tree_node(tree_node: ptree_node_t): psock_state_t;
//procedure sock_force_delete(port_state: pport_state_t; sock_state: psock_state_t);
procedure sock_force_delete(port_state: Pointer; sock_state: psock_state_t);
function sock_state_from_queue_node(queue_node: pqueue_node_t): psock_state_t;
//function sock_update(port_state: pport_state_t; sock_state: psock_state_t): Integer;
function sock_update(port_state: Pointer; sock_state: psock_state_t): Integer;
//function sock_feed_event(port_state: pport_state_t; io_status_block: PIO_STATUS_BLOCK; ev: pepoll_event): Integer;
function sock_feed_event(port_state: Pointer; io_status_block: PIO_STATUS_BLOCK; ev: pepoll_event): Integer;
//function sock_new(port_state: pport_state_t; sockt: TSocket): psock_state_t;
function sock_new(port_state: Pointer; sockt: TSocket): psock_state_t;
//function sock_set_event(port_state: pport_state_t; sock_state: psock_state_t; ev: pepoll_event): Integer;
function sock_set_event(port_state: Pointer; sock_state: psock_state_t; ev: pepoll_event): Integer;
//procedure sock_delete(port_state: pport_state_t; sock_state: psock_state_t);
procedure sock_delete(port_state: Pointer; sock_state: psock_state_t);
function sock_state_to_tree_node(sock_state: psock_state_t): ptree_node_t;
function sock_state_to_queue_node(sock_state: psock_state_t): pqueue_node_t;

implementation

uses wepoll_err, wepoll_port, wepoll_ws;

function sock_state_from_tree_node(tree_node: ptree_node_t): psock_state_t;
begin
  result := psock_state_t(PByte(tree_node) - NativeUInt(@psock_state_t(nil).tree_node));
end;

function sock__alloc: psock_state_t;
var
  sock_state: psock_state_t;
begin
  sock_state := malloc(sizeof(sock_state_t));
  if sock_state = nil then
  begin
    return_set_error(0, ERROR_NOT_ENOUGH_MEMORY);
    exit(nil);
  end;
  result := sock_state;
end;

procedure sock__free(sock_state: psock_state_t);
begin
  assert(sock_state <> nil);
  free(sock_state);
end;

function sock__cancel_poll(sock_state: psock_state_t): Integer;
begin
  assert(sock_state.poll_status = SOCK__POLL_PENDING);

  if afd_cancel_poll(poll_group_get_afd_device_handle(sock_state.poll_group), @sock_state.io_status_block) < 0 then
    exit(-1);

  sock_state.poll_status := SOCK__POLL_CANCELLED;
  sock_state.pending_events := 0;
  result := 0;
end;

//function sock_new(port_state: pport_state_t; sockt: TSocket): psock_state_t;
function sock_new(port_state: Pointer; sockt: TSocket): psock_state_t;
label err1, err2;
var
  base_socket: TSocket;
  poll_group: ppoll_group_t;
  sock_state: psock_state_t;
begin

  if (sockt = 0) or (sockt = INVALID_SOCKET) then
  begin
    return_set_error(0, ERROR_INVALID_HANDLE);
    exit(nil);
  end;

  base_socket := ws_get_base_socket(sockt);
  if base_socket = INVALID_SOCKET then
    exit(nil);

  poll_group := poll_group_acquire(port_state);
  if poll_group = nil then
    exit(nil);

  sock_state := sock__alloc();
  if sock_state = nil then
    goto err1;

  memset(sock_state, 0, sizeof(sock_state));

  sock_state.base_socket := base_socket;
  sock_state.poll_group := poll_group;

  tree_node_init(@sock_state.tree_node);
  queue_node_init(@sock_state.queue_node);

  if port_register_socket(port_state, sock_state, sockt) < 0 then
    goto err2;

  exit(sock_state);

err2:
  sock__free(sock_state);
err1:
  poll_group_release(poll_group);

  result := nil;
end;

function sock__delete(port_state: pport_state_t; sock_state: psock_state_t; force: Boolean): Integer;
begin
  if not sock_state.delete_pending then
  begin
    if sock_state.poll_status = SOCK__POLL_PENDING then
      sock__cancel_poll(sock_state);

    port_cancel_socket_update(port_state, sock_state);
    port_unregister_socket(port_state, sock_state);

    sock_state.delete_pending := true;
  end;

  // If the poll request still needs to complete, the sock_state object can't
  // be free()d yet. `sock_feed_event()` or `port_close()` will take care
  // of this later.
  if force or (sock_state.poll_status = SOCK__POLL_IDLE) then
  begin
    // Free the sock_state now.
    port_remove_deleted_socket(port_state, sock_state);
    poll_group_release(sock_state.poll_group);
    sock__free(sock_state);
  end
  else
    // Free the socket later.
    port_add_deleted_socket(port_state, sock_state);

  result := 0;
end;

//procedure sock_delete(port_state: pport_state_t; sock_state: psock_state_t);
procedure sock_delete(port_state: Pointer; sock_state: psock_state_t);
begin
  sock__delete(port_state, sock_state, false);
end;

//procedure sock_force_delete(port_state: pport_state_t; sock_state: psock_state_t);
procedure sock_force_delete(port_state: Pointer; sock_state: psock_state_t);
begin
  sock__delete(port_state, sock_state, true);
end;

//function sock_set_event(port_state: pport_state_t; sock_state: psock_state_t; ev: pepoll_event): Integer;
function sock_set_event(port_state: Pointer; sock_state: psock_state_t; ev: pepoll_event): Integer;
var
  events: Cardinal;
begin
  // EPOLLERR and EPOLLHUP are always reported, even when not requested by the
  // caller. However they are disabled after a event has been reported for a
  // socket for which the EPOLLONESHOT flag was set.
  events := ev.events or EPOLLERR or EPOLLHUP;

  sock_state.user_events := events;
  sock_state.user_data := ev.data;

  if events and SOCK__KNOWN_EPOLL_EVENTS and (not sock_state.pending_events) <> 0 then
    port_request_socket_update(port_state, sock_state);

  result := 0;
end;

function sock__epoll_events_to_afd_events(epoll_events: Cardinal): Cardinal;
var
  afd_events: DWORD;
begin
  // Always monitor for AFD_POLL_LOCAL_CLOSE, which is triggered when the
  // socket is closed with closesocket() or CloseHandle().
  afd_events := AFD_POLL_LOCAL_CLOSE;

  if epoll_events and (EPOLLIN or EPOLLRDNORM) > 0 then
    afd_events := afd_events or AFD_POLL_RECEIVE or AFD_POLL_ACCEPT;
  if epoll_events and (EPOLLPRI or EPOLLRDBAND) > 0 then
    afd_events := afd_events or AFD_POLL_RECEIVE_EXPEDITED;
  if epoll_events and (EPOLLOUT or EPOLLWRNORM or EPOLLWRBAND) > 0 then
    afd_events := afd_events or AFD_POLL_SEND;
  if epoll_events and (EPOLLIN or EPOLLRDNORM or EPOLLRDHUP) > 0 then
    afd_events := afd_events or AFD_POLL_DISCONNECT;
  if epoll_events and EPOLLHUP > 0 then
    afd_events := afd_events or AFD_POLL_ABORT;
  if epoll_events and EPOLLERR > 0 then
    afd_events := afd_events or AFD_POLL_CONNECT_FAIL;

  result := afd_events;
end;

function sock__afd_events_to_epoll_events(afd_events: Cardinal): Cardinal;
var
  epoll_events: DWORD;
begin
  epoll_events := 0;

  if afd_events and (AFD_POLL_RECEIVE or AFD_POLL_ACCEPT) > 0 then
    epoll_events := epoll_events or EPOLLIN or EPOLLRDNORM;
  if afd_events and AFD_POLL_RECEIVE_EXPEDITED > 0 then
    epoll_events := epoll_events or EPOLLPRI or EPOLLRDBAND;
  if afd_events and AFD_POLL_SEND > 0 then
    epoll_events := epoll_events or EPOLLOUT or EPOLLWRNORM or EPOLLWRBAND;
  if afd_events and AFD_POLL_DISCONNECT > 0 then
    epoll_events := epoll_events or EPOLLIN or EPOLLRDNORM or EPOLLRDHUP;
  if afd_events and AFD_POLL_ABORT > 0 then
    epoll_events := epoll_events or EPOLLHUP;
  if afd_events and AFD_POLL_CONNECT_FAIL > 0 then
    // Linux reports all these events after connect() has failed.
    epoll_events := epoll_events or EPOLLIN or EPOLLOUT or EPOLLERR or EPOLLRDNORM or EPOLLWRNORM or EPOLLRDHUP;

  result := epoll_events;
end;

//function sock_update(port_state: pport_state_t; sock_state: psock_state_t): Integer;
function sock_update(port_state: Pointer; sock_state: psock_state_t): Integer;
begin
  assert(not sock_state.delete_pending);

  if (sock_state.poll_status = SOCK__POLL_PENDING) and
      (sock_state.user_events and SOCK__KNOWN_EPOLL_EVENTS and (not sock_state.pending_events) = 0) then
  begin
    // All the events the user is interested in are already being monitored by
    // the pending poll operation. It might spuriously complete because of an
    // event that we're no longer interested in; when that happens we'll submit
    // a new poll operation with the updated event mask.
  end
  else
  if sock_state.poll_status = SOCK__POLL_PENDING then
  begin
    // A poll operation is already pending, but it's not monitoring for all the
    // events that the user is interested in. Therefore, cancel the pending
    // poll operation; when we receive it's completion package, a new poll
    // operation will be submitted with the correct event mask.
    if sock__cancel_poll(sock_state) < 0 then
      exit(-1);
  end
  else
  if sock_state.poll_status = SOCK__POLL_CANCELLED then
  begin
    // The poll operation has already been cancelled, we're still waiting for
    // it to return. For now, there's nothing that needs to be done.
  end
  else
  if sock_state.poll_status = SOCK__POLL_IDLE then
  begin
    // No poll operation is pending; start one.
    sock_state.poll_info.Exclusive := 0;
    sock_state.poll_info.NumberOfHandles := 1;
    sock_state.poll_info.Timeout.QuadPart := High(Int64);
    sock_state.poll_info.Handles[0].Handle := sock_state.base_socket;
    sock_state.poll_info.Handles[0].Status := 0;
    sock_state.poll_info.Handles[0].Events := sock__epoll_events_to_afd_events(sock_state.user_events);

    if afd_poll(poll_group_get_afd_device_handle(sock_state.poll_group), @sock_state.poll_info, @sock_state.io_status_block) < 0 then
    begin
      case GetLastError() of
        ERROR_IO_PENDING: ;
          // Overlapped poll operation in progress; this is expected.
        ERROR_INVALID_HANDLE:
          // Socket closed; it'll be dropped from the epoll set.
          exit(sock__delete(port_state, sock_state, false));
        else
          // Other errors are propagated to the caller.
          exit(return_map_error(-1));
      end;
    end;

    // The poll request was successfully submitted.
    sock_state.poll_status := SOCK__POLL_PENDING;
    sock_state.pending_events := sock_state.user_events;
  end
  else
  begin
    // Unreachable.
    assert(false);
  end;

  port_cancel_socket_update(port_state, sock_state);
  result := 0;
end;

//function sock_feed_event(port_state: pport_state_t; io_status_block: PIO_STATUS_BLOCK; ev: pepoll_event): Integer;
function sock_feed_event(port_state: Pointer; io_status_block: PIO_STATUS_BLOCK; ev: pepoll_event): Integer;
var
  sock_state: psock_state_t;
  poll_info: PAFD_POLL_INFO;
  epoll_events: Cardinal;
begin
  sock_state := psock_state_t(PByte(io_status_block) - NativeUInt(@psock_state_t(nil).io_status_block));

  poll_info := @sock_state.poll_info;
  epoll_events := 0;

  sock_state.poll_status := SOCK__POLL_IDLE;
  sock_state.pending_events := 0;

  if sock_state.delete_pending then
  begin
    // Socket has been deleted earlier and can now be freed.
    exit(sock__delete(port_state, sock_state, false));
  end
  else
  if io_status_block.Status = STATUS_CANCELLED then
  begin
    // The poll request was cancelled by CancelIoEx.

  end
  else
  if io_status_block.Status < 0 then
  begin
    // The overlapped request itself failed in an unexpected way.
    epoll_events := EPOLLERR;
  end
  else
  if poll_info.NumberOfHandles < 1 then
  begin
    // This poll operation succeeded but didn't report any socket events.

  end
  else
  if (poll_info.Handles[0].Events and AFD_POLL_LOCAL_CLOSE) <> 0 then
  begin
    // The poll operation reported that the socket was closed.
    exit(sock__delete(port_state, sock_state, false));
  end
  else
  begin
    // Events related to our socket were reported.
    epoll_events := sock__afd_events_to_epoll_events(poll_info.Handles[0].Events);
  end;

  // Requeue the socket so a new poll request will be submitted.
  port_request_socket_update(port_state, sock_state);

  // Filter out events that the user didn't ask for.
  epoll_events := epoll_events and sock_state.user_events;

  // Return if there are no epoll events to report.
  if epoll_events = 0 then
    exit(0);

  // If the the socket has the EPOLLONESHOT flag set, unmonitor all events,
  // even EPOLLERR and EPOLLHUP. But always keep looking for closed sockets.
  if (sock_state.user_events and EPOLLONESHOT) <> 0 then
    sock_state.user_events := 0;

  ev.data := sock_state.user_data;
  ev.events := epoll_events;
  result := 1;
end;

function sock_state_from_queue_node(queue_node: pqueue_node_t): psock_state_t;
begin
  result := psock_state_t(PByte(queue_node) - NativeUInt(@psock_state_t(nil).queue_node));
end;

function sock_state_to_queue_node(sock_state: psock_state_t): pqueue_node_t;
begin
  result := @sock_state.queue_node;
end;

function sock_state_to_tree_node(sock_state: psock_state_t): ptree_node_t;
begin
  result := @sock_state.tree_node;
end;



end.
