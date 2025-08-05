unit wepoll;

interface

uses Winapi.Winsock2, Winapi.Windows, System.SysUtils, wepoll_ts_tree, wepoll_types;

function epoll_create(size: Integer): THandle;
function epoll_create1(flags: Integer): THandle;
function epoll_close(ephnd: THandle): Integer;
function epoll_ctl(ephnd: THandle; op: Integer; sock: TSocket; ev: pepoll_event): Integer;
function epoll_wait(ephnd: THandle; events: pepoll_event; maxevents: Integer; timeout: Integer): Integer;

function epoll_global_init: Integer;

function close(h: THandle): Integer;

var
  epoll__handle_tree: ts_tree_t;

implementation

uses wepoll_err, wepoll_port, wepoll_once, wepoll_ws, wepoll_reflock;

////////////////////////////////////////////////////

function epoll_global_init: Integer;
begin
  ts_tree_init(@epoll__handle_tree);
  result := 0;
end;

function epoll__create: THandle;
var
  port_state: pport_state_t;
  ephnd: THandle;
  tree_node: pts_tree_node_t;
begin
//  if init < 0 then
//    exit(0);
  port_state := port_new(@ephnd);
  if port_state = nil then
    exit(0);
  tree_node := port_state_to_handle_tree_node(port_state);
  if ts_tree_add(@epoll__handle_tree, tree_node, ephnd) < 0 then
  begin
    // This should never happen.
    port_delete(port_state);
    exit(return_set_error(0, ERROR_ALREADY_EXISTS));
  end;
  result := ephnd;
end;

function epoll_create(size: Integer): THandle;
begin
  if size <= 0 then
    exit(return_set_error(0, ERROR_INVALID_PARAMETER));

  result := epoll__create;
end;

function epoll_create1(flags: Integer): THandle;
begin
  if flags <> 0 then
    exit(return_set_error(0, ERROR_INVALID_PARAMETER));

  result := epoll__create;
end;

function epoll_close(ephnd: THandle): Integer;
label err;
var
  tree_node: pts_tree_node_t;
  port_state: pport_state_t;
begin
//  if init() < 0 then
//    exit(-1);

  tree_node := ts_tree_del_and_ref(@epoll__handle_tree, ephnd);
  if tree_node = nil then
  begin
    err_set_win_error(ERROR_INVALID_PARAMETER);
    goto err;
  end;

  port_state := port_state_from_handle_tree_node(tree_node);
  port_close(port_state);

  ts_tree_node_unref_and_destroy(tree_node);

  exit(port_delete(port_state));
err:
  err_check_handle(ephnd);
  exit(-1);
end;

function epoll_ctl(ephnd: THandle; op: Integer; sock: TSocket; ev: pepoll_event): Integer;
label err;
var
  tree_node: pts_tree_node_t;
  port_state: pport_state_t;
  r: Integer;
begin
//  if init() < 0 then
//    exit(-1);

  tree_node := ts_tree_find_and_ref(@epoll__handle_tree, ephnd);
  if tree_node = nil then
  begin
    err_set_win_error(ERROR_INVALID_PARAMETER);
    goto err;
  end;

  port_state := port_state_from_handle_tree_node(tree_node);
  r := port_ctl(port_state, op, sock, ev);

  ts_tree_node_unref(tree_node);

  if r < 0 then
    goto err;

  exit(0);
err:
  // On Linux, in the case of epoll_ctl(), EBADF takes priority over other
  // errors. Wepoll mimics this behavior.
  err_check_handle(ephnd);
  err_check_handle(sock);
  exit(-1);
end;

function epoll_wait(ephnd: THandle; events: pepoll_event; maxevents: Integer; timeout: Integer): Integer;
label err;
var
  tree_node: pts_tree_node_t;
  port_state: pport_state_t;
  num_events: Integer;
begin
  if maxevents <= 0 then
    exit(return_set_error(-1, ERROR_INVALID_PARAMETER));

//  if init() < 0 then
//    exit(-1);

  tree_node := ts_tree_find_and_ref(@epoll__handle_tree, ephnd);
  if tree_node = nil then
  begin
    err_set_win_error(ERROR_INVALID_PARAMETER);
    goto err;
  end;

  port_state := port_state_from_handle_tree_node(tree_node);
  num_events := port_wait(port_state, events, maxevents, timeout);

  ts_tree_node_unref(tree_node);

  if num_events < 0 then
    goto err;

  exit(num_events);

err:
  err_check_handle(ephnd);
  exit(-1);
end;

function close(h: THandle): Integer;
begin
	result := epoll_close(h);
end;

initialization
  ws_global_init;
  reflock_global_init;
  epoll_global_init;

end.
