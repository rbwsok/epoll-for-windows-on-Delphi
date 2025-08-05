unit wepoll_poll_group;

interface

uses Winapi.Windows, System.Win.Crtl, wepoll_port, wepoll_queue;

type
  poll_group = record
    port_state: pport_state_t;
    queue_node: queue_node_t;
    afd_device_handle: THandle;
    group_size: size_t;
  end;
  poll_group_t = poll_group;
  ppoll_group_t = ^poll_group_t;

const
  POLL_GROUP__MAX_GROUP_SIZE = 32;

function poll_group_get_afd_device_handle(poll_group: ppoll_group_t): THandle;
function poll_group_acquire(port_state: pport_state_t): ppoll_group_t;
procedure poll_group_release(poll_group: ppoll_group_t);
function poll_group_from_queue_node(queue_node: pqueue_node_t): ppoll_group_t;
procedure poll_group_delete(poll_group: ppoll_group_t);

implementation

uses wepoll_err, wepoll_afd;

function poll_group__new(port_state: pport_state_t): ppoll_group_t;
var
  iocp_handle: THandle;
  poll_group_queue: pqueue_t;
  poll_group: ppoll_group_t;
begin
  iocp_handle := port_get_iocp_handle(port_state);
  poll_group_queue := port_get_poll_group_queue(port_state);

  poll_group := malloc(sizeof(poll_group_t));

  if poll_group = nil then
  begin
    return_set_error(0, ERROR_NOT_ENOUGH_MEMORY);
    exit(nil);
  end;

  memset(poll_group, 0, sizeof(poll_group));

  queue_node_init(@poll_group.queue_node);
  poll_group.port_state := port_state;

  if afd_create_device_handle(iocp_handle, @poll_group.afd_device_handle) < 0 then
  begin
    free(poll_group);
    exit(nil);
  end;

  queue_append(poll_group_queue, @poll_group.queue_node);

  result := poll_group;
end;

procedure poll_group_delete(poll_group: ppoll_group_t);
begin
  assert(poll_group.group_size = 0);
  CloseHandle(poll_group.afd_device_handle);
  queue_remove(@poll_group.queue_node);

  free(poll_group);
end;

function poll_group_from_queue_node(queue_node: pqueue_node_t): ppoll_group_t;
begin
  result := ppoll_group_t(PByte(queue_node) - NativeUInt(@ppoll_group_t(nil).queue_node));
end;

function poll_group_get_afd_device_handle(poll_group: ppoll_group_t): THandle;
begin
  result := poll_group.afd_device_handle;
end;

function poll_group_acquire(port_state: pport_state_t): ppoll_group_t;
var
  poll_group_queue: pqueue_t;
  poll_group: ppoll_group_t;
begin
  poll_group_queue := port_get_poll_group_queue(port_state);
  if not queue_is_empty(poll_group_queue) then
    poll_group := ppoll_group_t(PByte(queue_last(poll_group_queue)) - NativeUInt(@ppoll_group_t(nil).queue_node))
  else
    poll_group := nil;

  if (poll_group = nil) or (poll_group.group_size >= POLL_GROUP__MAX_GROUP_SIZE) then
    poll_group := poll_group__new(port_state);
  if poll_group = nil then
    exit(nil);

  inc(poll_group.group_size);
  if poll_group.group_size = POLL_GROUP__MAX_GROUP_SIZE then
    queue_move_to_start(poll_group_queue, @poll_group.queue_node);

  result := poll_group;
end;

procedure poll_group_release(poll_group: ppoll_group_t);
var
  port_state: pport_state_t;
  poll_group_queue: pqueue_t;
begin
  port_state := poll_group.port_state;
  poll_group_queue := port_get_poll_group_queue(port_state);

  dec(poll_group.group_size);

  assert(poll_group.group_size < POLL_GROUP__MAX_GROUP_SIZE);

  queue_move_to_end(poll_group_queue, @poll_group.queue_node);

  // Poll groups are currently only freed when the epoll port is closed.
end;




end.
