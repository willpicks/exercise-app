# Run Together

A private iOS app for two people running together — one returning from a meniscus
repair under a physio's protocol, one building a base from low fitness.

## The idea

Two ladders, one shared lane.

**Paired runs** are done side by side: same walk cues, same run cues, same time, start
to finish. Nobody loops back and nobody waits at a lamppost. The shared session is
composed from both runners' current stages, taking the conservative side of every
axis independently, so it can never ask either person to do more than their own plan
allows.

**Solo runs** are where fitness gets built, each on their own ladder, on their own days.

Rest is part of the plan. The adherence streak counts *planned sessions honoured*, and
a rest day taken counts as honoured. Running on a prescribed rest day breaks the streak
and is recorded as an overshoot. A conventional consecutive-days streak would reward
exactly the behaviour a repaired meniscus cannot tolerate.

## Layout

```
RunTogetherKit/          Swift package — all training logic, Foundation only
  Plan/                  PlanSpec, PlanStage, LadderGenerator, Governance, Runner
  Session/               CueTrack, SessionTimeline, SessionComposer, SessionClock
  Analysis/              StreakCalculator, DriftAnalysis
```

The engine depends on nothing but Foundation — no HealthKit, no CloudKit, no SwiftUI.
That is what lets the whole of the training logic be tested in milliseconds on any
machine, without a device, without HealthKit permissions, and without waiting out a
real run.

## Running the tests

```sh
swift test --package-path RunTogetherKit
```

CI runs this on `macos-latest` for every push.

## Status

Built:

- Ladder generation from a plan spec, with medical caps that cannot be breached
- Shared-lane composition with the never-exceed invariant
- Cue track expansion and absolute-anchor session progress
- Adherence streak and drift analysis

Not yet built — see the plan for the full sequence:

- iOS app target (SwiftUI): today view, session runner, feed, plan review
- watchOS companion for haptic cues
- HealthKit ingestion of finished workouts and routes
- CloudKit pairing and the shared feed

## Design notes worth knowing

**Caps round down.** Where rounding could push a stage over a cap, the generator floors
it. In this domain the conservative direction is the correct one.

**Progression survives the cap.** Once the run interval hits its ceiling, later stages
add repeats rather than lengthening the interval, so the ladder keeps climbing without
ever breaching the limit on continuous running.

**Composition is per-axis, not overall.** Picking whichever stage is "gentler overall"
is wrong: 1 × 5:00 has less total running than 10 × 1:00, so that rule would select it
and hand the other runner a five-minute continuous interval when their own plan says
one minute. Taking the minimum of each axis separately cannot make that mistake.

**Sync is an absolute timestamp, not a stream.** The host writes the session's
`startedAt` as wall-clock time and both devices compute their position from that anchor.
A device that receives the push eight seconds late starts eight seconds *in*, correctly
aligned — so push latency cannot accumulate as drift, and nothing needs streaming
during a run.

**The protocol is a record, not a recommendation.** A `.physioProtocol` plan carries its
source and date, never auto-advances, and never generates rungs beyond the caps it was
given. The app executes what the clinician prescribed; it does not author rehab plans.
