// красно-черное дерево для храннеия хендлов

unit wepoll_tree;

interface

uses Winapi.Windows, System.Win.Crtl;

type

  ptree_node_t = ^tree_node_t;
  tree_node = record
    left: ptree_node_t;
    right: ptree_node_t;
    parent: ptree_node_t;
    key: NativeUInt;
    red: Boolean;
  end;
  tree_node_t = tree_node;

  ptree_t = ^tree_t;
  tree = record
    root: ptree_node_t;
  end;
  tree_t = tree;

procedure tree_init(tree: ptree_t);
procedure tree_node_init(node: ptree_node_t);
function tree_add(tree: ptree_t; node: ptree_node_t; key: NativeUInt): Integer;
procedure tree_del(tree: ptree_t; node: ptree_node_t);
function tree_find(tree: ptree_t; key: NativeUInt): ptree_node_t;
function tree_root(tree: ptree_t): ptree_node_t;

implementation

procedure tree_init(tree: ptree_t);
begin
  memset(tree, 0, sizeof(tree));
end;

procedure tree_node_init(node: ptree_node_t);
begin
  memset(node, 0, sizeof(node));
end;

procedure tree__rotate_left(tree: ptree_t; node: ptree_node_t);
var
  p: ptree_node_t;
  q: ptree_node_t;
  parent: ptree_node_t;
begin
  p := node;
  q := node.right;
  parent := p.parent;
  if parent <> nil then
  begin
    if parent.left = p then
      parent.left := q
    else
      parent.right := q;
  end
  else
    tree.root := q;

  q.parent := parent;
  p.parent := q;
  p.right := q.left;
  if p.right <> nil then
    p.right.parent := p;
  q.left := p;
end;

procedure tree__rotate_right(tree: ptree_t; node: ptree_node_t);
var
  p: ptree_node_t;
  q: ptree_node_t;
  parent: ptree_node_t;
begin
  p := node;
  q := node.left;
  parent := p.parent;

  if parent <> nil then
  begin
    if parent.left = p then
      parent.left := q
    else
      parent.right := q;
  end
  else
    tree.root := q;

  q.parent := parent;
  p.parent := q;
  p.left := q.right;
  if p.left <> nil then
    p.left.parent := p;
  q.right := p;
end;

function tree_add(tree: ptree_t; node: ptree_node_t; key: NativeUInt): Integer;
var
  parent: ptree_node_t;
  grandparent: ptree_node_t;
  uncle: ptree_node_t;
begin
  parent := tree.root;
  if parent <> nil then
  begin
    while true do
    begin
      if key < parent.key then
      begin
        if parent.left <> nil then
          parent := parent.left
        else
        begin
          parent.left := node;
          break;
        end;
      end
      else
      if key > parent.key then
      begin
        if parent.right <> nil then
          parent := parent.right
        else
        begin
          parent.right := node;
          break;
        end;
      end
      else
        exit(-1);
    end;
  end
  else
    tree.root := node;

  node.key := key;
  node.right := nil;
  node.left := nil;
  node.parent := parent;
  node.red := true;

  parent := node.parent;
  while (parent <> nil) and parent.red do
  begin
    if parent = parent.parent.left then
    begin
      grandparent := parent.parent;
      uncle := grandparent.right;
      if (uncle <> nil) and uncle.red then
      begin
        parent.red := false;
        uncle.red := false;
        grandparent.red := true;
        node := grandparent;
      end
      else
      begin
        if node = parent.right then
        begin
          tree__rotate_left(tree, parent);
          node := parent;
          parent := node.parent;
        end;
        parent.red := false;
        grandparent.red := true;
        tree__rotate_right(tree, grandparent);
      end;
    end
    else
    begin
      grandparent := parent.parent;
      uncle := grandparent.left;
      if (uncle <> nil) and uncle.red then
      begin
        parent.red := false;
        uncle.red := false;
        grandparent.red := true;
        node := grandparent;
      end
      else
      begin
        if node = parent.left then
        begin
          tree__rotate_right(tree, parent);
          node := parent;
          parent := node.parent;
        end;
        parent.red := false;
        grandparent.red := true;
        tree__rotate_left(tree, grandparent);
      end;
    end;

    parent := node.parent;
  end;

  tree.root.red := false;

  result := 0;
end;

procedure tree_del(tree: ptree_t; node: ptree_node_t);
var
  parent: ptree_node_t;
  left: ptree_node_t;
  right: ptree_node_t;
  next: ptree_node_t;
  red: Boolean;
  sibling: ptree_node_t;
begin
  parent := node.parent;
  left := node.left;
  right := node.right;

  if left = nil then
    next := right
  else
  if right = nil then
    next := left
  else
  begin
    next := right;
    while next.left <> nil do
      next := next.left;
  end;

  if parent <> nil then
  begin
    if parent.left = node then
      parent.left := next
    else
      parent.right := next;
  end
  else
    tree.root := next;

  if (left <> nil) and (right <> nil) then
  begin
    red := next.red;
    next.red := node.red;
    next.left := left;
    left.parent := next;
    if next <> right then
    begin
      parent := next.parent;
      next.parent := node.parent;
      node := next.right;
      parent.left := node;
      next.right := right;
      right.parent := next;
    end
    else
    begin
      next.parent := parent;
      parent := next;
      node := next.right;
    end;
  end
  else
  begin
    red := node.red;
    node := next;
  end;

  if node <> nil then
    node.parent := parent;
  if red then
    exit;
  if (node <> nil) and (node.red) then
  begin
    node.red := false;
    exit;
  end;

  repeat
    if node = tree.root then
      break;

    if node = parent.left then
    begin
        sibling := parent.right;
        if sibling.red then
        begin
          sibling.red := false;
          parent.red := true;
          tree__rotate_left(tree, parent);
          sibling := parent.right;
        end;
        if ((sibling.left <> nil) and sibling.left.red) or
           ((sibling.right <> nil) and sibling.right.red) then
        begin
          if (sibling.right = nil) or (not sibling.right.red) then
          begin
            sibling.left.red := false;
            sibling.red := true;
            tree__rotate_right(tree, sibling);
            sibling := parent.right;
          end;
          sibling.red := parent.red;
          parent.red := false;
          sibling.right.red := false;
          tree__rotate_left(tree, parent);
          node := tree.root;
          break;
        end;
        sibling.red := true;
    end
    else
    begin
      sibling := parent.left;
      if sibling.red then
      begin
        sibling.red := false;
        parent.red := true;
        tree__rotate_right(tree, parent);
        sibling := parent.left;
      end;
      if ((sibling.left <> nil) and sibling.left.red) or
         ((sibling.right <> nil) and sibling.right.red) then
      begin
        if (sibling.left = nil) or (not sibling.left.red) then
        begin
          sibling.right.red := false;
          sibling.red := true;
          tree__rotate_left(tree, sibling);
          sibling := parent.left;
        end;
        sibling.red := parent.red;
        parent.red := false;
        sibling.left.red := false;
        tree__rotate_right(tree, parent);
        node := tree.root;
        break;
      end;
      sibling.red := true;
    end;

    node := parent;
    parent := parent.parent;
  until node.red;

  if node <> nil then
    node.red := false;
end;

function tree_find(tree: ptree_t; key: NativeUInt): ptree_node_t;
var
  node: ptree_node_t;
begin
  node := tree.root;
  while node <> nil do
  begin
    if key < node.key then
      node := node.left
    else
    if key > node.key then
      node := node.right
    else
      exit(node);
  end;
  result := nil;
end;

function tree_root(tree: ptree_t): ptree_node_t;
begin
  result := tree.root;
end;

end.
