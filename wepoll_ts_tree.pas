// потокобезопасное красно-черное дерево (для хранения хендлов)
unit wepoll_ts_tree;

interface

uses Winapi.Windows, wepoll_types, wepoll_tree, wepoll_reflock;

type
  ts_tree = record
    tree: tree_t;
    lock: SRWLOCK;
  end;
  ts_tree_t = ts_tree;
  pts_tree_t = ^ts_tree_t;

  ts_tree_node = record
    tree_node: tree_node_t;
    reflock: reflock_t;
  end;
  ts_tree_node_t = ts_tree_node;
  pts_tree_node_t = ^ts_tree_node_t;

procedure ts_tree_init(ts_tree: pts_tree_t);
procedure ts_tree_node_init(node: pts_tree_node_t);
function ts_tree_add(ts_tree: pts_tree_t; node: pts_tree_node_t; key: NativeUInt): Integer;
function ts_tree_del_and_ref(ts_tree: pts_tree_t; key: NativeUInt): pts_tree_node_t;
procedure ts_tree_node_unref_and_destroy(node: pts_tree_node_t);
function ts_tree_find_and_ref(ts_tree: pts_tree_t; key: NativeUInt): pts_tree_node_t;
procedure ts_tree_node_unref(node: pts_tree_node_t);

implementation

procedure ts_tree_init(ts_tree: pts_tree_t);
begin
  tree_init(@ts_tree.tree);
  InitializeSRWLock(ts_tree.lock);
end;

procedure ts_tree_node_init(node: pts_tree_node_t);
begin
  tree_node_init(@node.tree_node);
  reflock_init(@node.reflock);
end;

function ts_tree_add(ts_tree: pts_tree_t; node: pts_tree_node_t; key: NativeUInt): Integer;
begin
  AcquireSRWLockExclusive(ts_tree.lock);
  result := tree_add(@ts_tree.tree, @node.tree_node, key);
  ReleaseSRWLockExclusive(ts_tree.lock);
end;

function ts_tree__find_node(ts_tree: pts_tree_t; key: NativeUInt): pts_tree_node_t;
var
  tree_node: ptree_node_t;
begin
  tree_node := tree_find(@ts_tree.tree, key);
  if tree_node = nil then
    exit(nil);

  result := pts_tree_node_t(PByte(tree_node) - NativeUInt(@pts_tree_node_t(nil).tree_node));
end;

function ts_tree_del_and_ref(ts_tree: pts_tree_t; key: NativeUInt): pts_tree_node_t;
var
  ts_tree_node: pts_tree_node_t;
begin
  AcquireSRWLockExclusive(ts_tree.lock);

  ts_tree_node := ts_tree__find_node(ts_tree, key);
  if ts_tree_node <> nil then
  begin
    tree_del(@ts_tree.tree, @ts_tree_node.tree_node);
    reflock_ref(@ts_tree_node.reflock);
  end;

  ReleaseSRWLockExclusive(ts_tree.lock);

  result := ts_tree_node;
end;

function ts_tree_find_and_ref(ts_tree: pts_tree_t; key: NativeUInt): pts_tree_node_t;
var
  ts_tree_node: pts_tree_node_t;
begin
  AcquireSRWLockShared(ts_tree.lock);

  ts_tree_node := ts_tree__find_node(ts_tree, key);
  if ts_tree_node <> nil then
    reflock_ref(@ts_tree_node.reflock);

  ReleaseSRWLockShared(ts_tree.lock);

  result := ts_tree_node;
end;

procedure ts_tree_node_unref(node: pts_tree_node_t);
begin
  reflock_unref(@node.reflock);
end;

procedure ts_tree_node_unref_and_destroy(node: pts_tree_node_t);
begin
  reflock_unref_and_destroy(@node.reflock);
end;


end.
