unit wepoll_queue;

interface

type
  pqueue_node_t = ^queue_node_t;
  queue_node = record
    prev: pqueue_node_t;
    next: pqueue_node_t;
  end;
  queue_node_t = queue_node;

  pqueue_t = ^queue_t;
  queue = record
    head: queue_node_t;
  end;
  queue_t = queue;

procedure queue_init(queue: pqueue_t);
procedure queue_node_init(node: pqueue_node_t);
procedure queue_append(queue: pqueue_t; node: pqueue_node_t);
procedure queue_remove(node: pqueue_node_t);
function queue_is_empty(queue: pqueue_t): Boolean;
function queue_first(queue: pqueue_t): pqueue_node_t;
function queue_last(queue: pqueue_t): pqueue_node_t;
procedure queue_move_to_start(queue: pqueue_t; node: pqueue_node_t);
procedure queue_move_to_end(queue: pqueue_t; node: pqueue_node_t);
function queue_is_enqueued(node: pqueue_node_t): Boolean;

implementation

procedure queue_node_init(node: pqueue_node_t);
begin
  node.prev := node;
  node.next := node;
end;

procedure queue_init(queue: pqueue_t);
begin
  queue_node_init(@queue.head);
end;

procedure queue__detach_node(node: pqueue_node_t);
begin
  node.prev.next := node.next;
  node.next.prev := node.prev;
end;

function queue_is_enqueued(node: pqueue_node_t): Boolean;
begin
  result := node.prev <> node;
end;

function queue_is_empty(queue: pqueue_t): Boolean;
begin
  result := not queue_is_enqueued(@queue.head);
end;

function queue_first(queue: pqueue_t): pqueue_node_t;
begin
  if not queue_is_empty(queue) then
    result := queue.head.next
  else
    result := nil;
end;

function queue_last(queue: pqueue_t): pqueue_node_t;
begin
  if not queue_is_empty(queue) then
    result := queue.head.prev
  else
    result := nil;
end;

procedure queue_prepend(queue: pqueue_t; node: pqueue_node_t);
begin
  node.next := queue.head.next;
  node.prev := @queue.head;
  node.next.prev := node;
  queue.head.next := node;
end;

procedure queue_append(queue: pqueue_t; node: pqueue_node_t);
begin
  node.next := @queue.head;
  node.prev := queue.head.prev;
  node.prev.next := node;
  queue.head.prev := node;
end;

procedure queue_move_to_start(queue: pqueue_t; node: pqueue_node_t);
begin
  queue__detach_node(node);
  queue_prepend(queue, node);
end;

procedure queue_move_to_end(queue: pqueue_t; node: pqueue_node_t);
begin
  queue__detach_node(node);
  queue_append(queue, node);
end;

procedure queue_remove(node: pqueue_node_t);
begin
  queue__detach_node(node);
  queue_node_init(node);
end;

end.
