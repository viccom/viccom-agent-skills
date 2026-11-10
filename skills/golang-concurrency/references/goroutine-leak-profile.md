# Goroutine Leak Profile (`goroutineleak`) — Go 1.27+

Stable since Go 1.27 (introduced experimentally in 1.26 behind `GOEXPERIMENT=goroutineleakprofile`; that gate is removed). Built on research from Uber, Aarhus University, and Washington University in St. Louis (ASPLOS 2025).

A goroutine is *leaked* when it is blocked on a concurrency primitive whose acquisition can never succeed again. Detection reuses the GC: it proves the primitive is unreachable from any goroutine that could still run.

## Usage

Two collection paths; services already importing `net/http/pprof` need zero code changes:

```go
import _ "net/http/pprof" // exposes /debug/pprof/goroutineleak automatically
```

```bash
# Binary profile — the only useful form (debug=2 degrades to printing the
# current goroutine's stack, NOT a leak listing)
curl -s http://localhost:6060/debug/pprof/goroutineleak > leak.prof
go tool pprof leak.prof
(pprof) list SuspectFunc   # marks the exact blocking line
```

Programmatic access:

```go
p := pprof.Lookup("goroutineleak")
n := p.Count()             // leaked-goroutine count as of the last scan
```

Key operational fact: **each profile fetch triggers a dedicated leak-detection GC cycle** (`runtime_goroutineLeakGC`, invoked from `runtime/pprof`). Ordinary GCs do not run leak detection. Sampling cadence is therefore fully under your control; the official reference figure is once every 4 hours, which amortizes scan overhead to near zero.

## Verified walkthrough (Go 1.27.1)

The classic leak — unbuffered result channel + early return (common in real codebases, including Uber's):

```go
func processWorkItems(ws []workItem) ([]workResult, error) {
	ch := make(chan result) // unbuffered: every send blocks on the receiver
	for _, w := range ws {
		go func() {
			res, err := processWorkItem(w)
			ch <- result{res, err} // ← profile pins this line
		}()
	}
	var results []workResult
	for range len(ws) {
		r := <-ch
		if r.err != nil {
			return nil, r.err // early return: remaining workers block forever
		}
		results = append(results, r.res)
	}
	return results, nil
}
```

Measured with 6 rounds × 10 items (one failing item per round): profile reported 29–30 leaks, all attributed to the send line.

```
(pprof) list processWorkItems
Total: 30
ROUTINE ======================== main.processWorkItems.func1 in .../main.go
         0         29 (flat, cum) 96.67% of Total
         .          .     32:      go func() {
         .         29     34:              ch <- result{res, err}
```

Fix: `ch := make(chan result, len(ws))` — every worker can deliver and exit even when the caller bails early.

## Leak pattern catalog

Review hotspots; each of these has shipped in major projects:

| Pattern | Shape | Real-world case |
| --- | --- | --- |
| Double send | error branch sends but forgets `return`; more sends than receives | — |
| Early return | receiver exits on one control-flow path; senders block forever | — |
| Timeout race | `ctx.Done()` branch wins the `select`; worker's send has no receiver | — |
| Range without close | channel never closed; workers stuck in `for item := range ch` | — |
| Start/Stop contract violation | `Start` spawns a background goroutine; caller never calls `Stop` | — |
| Missing `Unlock` before `break` | next iteration's `Lock` blocks on itself | CockroachDB #584 |
| Goroutine trio, one send orphaned | `Stop`/`run` synchronize and exit; `Status`'s send never received | etcd #6857 |
| Channel + mutex deadlock cycle | lock holder blocked sending; waiter blocked on lock | Kubernetes #6632, Moby #28462 |
| `WaitGroup.Wait` inside the loop | first `Wait` blocks before later goroutines start | Moby (plugin manager `init`) |

These hide behind interface boundaries — the caller often cannot see which concurrency primitive the implementation uses. The profile reports the blocked line directly, which manual review cannot.

## What counts as blocking (exact tracked set)

From `runtime.internalBlocked()` (Go 1.27.1 source), the only wait reasons eligible for leak detection:

- channel receive/send, including on a **nil channel**
- blocking `select` (no `default`) — down to `select{}` with zero cases
- `sync.Cond.Wait`, `sync.Mutex.Lock`, `sync.RWMutex.RLock`/`Lock`, `sync.WaitGroup.Wait`

Everything else is invisible to this profile: `time.Sleep`, timer waits, file/network I/O (netpoll), syscalls, `semacquire`, and any hand-rolled primitive not built on the above.

Gotcha (verified): a goroutine parked forever in `select{}` — e.g. a `main` that parks to keep the process alive — **is itself reported as leaked with an empty-looking stack**. In one measurement, 10 leaked workers + 1 `select{}` parker reported 11; switching the park to `time.Sleep` reported exactly 10. Don't park with `select{}` in services that read this profile, or always subtract the known parker.

## Blind spots (read before trusting an empty profile)

1. **Memory overreach via globals (verified).** Global variables remain mark roots even in leak-detection GC (`gcPrepareMarkRoots` scans data/BSS unconditionally; only stack roots are filtered to runnable goroutines). A primitive referenced by a global map — even if no live goroutine will ever use it — keeps its blocked goroutines unreported. Measured 10/10 runs: 10 senders blocked on channels stored in a global map → 0 reported; same program without the global store → 10/10 reported. Mitigate by narrowing the reference scope and making lifetimes explicit.
2. **Only first-class primitives are tracked** — see the exact set above.
3. **Post-hoc only.** A leak is visible only after it happens, and the result reflects the scan GC triggered by this fetch. Non-deterministic paths may need targeted reproduction. Recommended mix: production `goroutineleak` profile + `goleak` and `synctest` in tests.

## How it works (mental model)

Same tri-color concurrent mark-sweep as the GC, two differences:

1. Stack roots are only *unblocked* goroutines (regular GC roots all goroutine stacks); global variables remain roots — hence the overreach above.
2. After a mark round, any blocked goroutine whose primitive was marked is promoted to root; repeat until the set stops growing (the inductive "liveness" definition). Remaining blocked goroutines are marked leaked, added back as roots for one final mark round so their memory is not collected.

## Triage workflow

When the profile is non-empty, look at three things:

1. The stack line the leak is pinned to (the blocking send/recv/lock).
2. The count's growth trend across samples — flat vs. unbounded.
3. Where the leaked goroutine got the primitive reference from — that holder is what fails to release or close it.

## References

- Go blog: goroutine leak detection (Go 1.27)
- ASPLOS 2025 paper: Uber + Aarhus University + Washington University in St. Louis
- Runtime source (1.27.1): `runtime/mgcmark.go` (`internalBlocked`, `gcPrepareMarkRoots`), `runtime/mgc.go` (`goroutineLeakGC`), `runtime/pprof/pprof.go`
