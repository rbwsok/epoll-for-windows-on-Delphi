unit wepoll_reflock;

interface

uses Winapi.Windows, System.SysUtils, wepoll_types;

const
  REFLOCK__REF          = $00000001;
  REFLOCK__REF_MASK     = $0fffffff;
  REFLOCK__DESTROY      = $10000000;
  REFLOCK__DESTROY_MASK = $f0000000;
  REFLOCK__POISON       = $300dead0;

var
  reflock__keyed_event: THandle;

type

  reflock = record
    [volatile] state: Long; // 32-bit Interlocked APIs operate on `long` values.
  end;
  reflock_t = reflock;
  preflock_t = ^reflock_t;

procedure reflock_init(reflock: preflock_t);
procedure reflock_ref(reflock: preflock_t);
procedure reflock_unref(reflock: preflock_t);
procedure reflock_unref_and_destroy(reflock: preflock_t);
function reflock_global_init: Integer;

implementation

uses wepoll_err;

function reflock_global_init: Integer;
var
  status: NTSTATUS;
begin
  status := NtCreateKeyedEvent(@reflock__keyed_event, KEYEDEVENT_ALL_ACCESS, nil, 0);
  if status <> STATUS_SUCCESS then
    exit(return_set_error(-1, RtlNtStatusToDosError(status)));
  result := 0;
end;

procedure reflock_init(reflock: preflock_t);
begin
  reflock.state := 0;
end;

procedure reflock__signal_event(address: Pointer);
var
  status: NTSTATUS;
begin
  status := NtReleaseKeyedEvent(reflock__keyed_event, address, FALSE, nil);
  if status <> STATUS_SUCCESS then
    raise Exception.Create('reflock__signal_event');
//    abort();
end;

procedure reflock__await_event(address: Pointer);
var
  status: NTSTATUS;
begin
  status := NtWaitForKeyedEvent(reflock__keyed_event, address, FALSE, nil);
  if status <> STATUS_SUCCESS then
    raise Exception.Create('reflock__signal_event');
//    abort();
end;

procedure reflock_ref(reflock: preflock_t);
var
  state: long;
begin
  state := InterlockedAdd(reflock.state, REFLOCK__REF);
  // Verify that the counter didn't overflow and the lock isn't destroyed.
  Assert((state and REFLOCK__DESTROY_MASK) = 0);
//  unused_var(state);
end;

procedure reflock_unref(reflock: preflock_t);
var
  state: long;
begin
  state := InterlockedAdd(reflock.state, 0 - REFLOCK__REF);
  // Verify that the lock was referenced and not already destroyed.
  Assert((state and REFLOCK__DESTROY_MASK and (not REFLOCK__DESTROY)) = 0);
  if state = REFLOCK__DESTROY then
    reflock__signal_event(reflock);
end;

procedure reflock_unref_and_destroy(reflock: preflock_t);
var
  state: long;
  ref_count: long;
begin
  state := InterlockedAdd(reflock.state, REFLOCK__DESTROY - REFLOCK__REF);
  ref_count := state and REFLOCK__REF_MASK;
  // Verify that the lock was referenced and not already destroyed.
  assert((state and REFLOCK__DESTROY_MASK) = REFLOCK__DESTROY);
  if ref_count <> 0 then
    reflock__await_event(reflock);
  state := InterlockedExchange(reflock.state, REFLOCK__POISON);
  assert(state = REFLOCK__DESTROY);
end;


end.
