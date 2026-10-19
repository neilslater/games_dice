# Parser preparation research

This directory is development-only and excluded from the built gem, as are
`spec/`. Nothing here is required by `lib/games_dice.rb`. Production now uses the direct
scanner under `lib/games_dice/`; Parslet is a development dependency only.

## Implementations

- `reference_parser.rb`: snapshot of `lib/games_dice/parser.rb` at
  `610b670524410c91fe2daac6c1199f1f61d1b4df`. Only module/class names and a
  provenance comment differ. A source checksum test guards this reference.
- `scanner.rb` and `scanner_modifiers.rb`: retained StringScanner prototype at
  preparation commit `5c41efe`,
  emitting constructor hashes directly. Each parse owns its scanning state;
  the reusable entry point caches no definitions or mutable parse results.
- `factory.rb`: equivalent construction and optional PRNG injection for the
  historical parsers. Production benchmarks call `GamesDice.create` itself.

Keep reference semantics stable. If a future Ruby or Parslet version requires
adaptation, preserve the original revision and document the adapted runnable
version rather than silently replacing historical behavior. Parslet is explicit
in the development Gemfile so future production migration does not remove the
comparison oracle. Git history records candidate progression; compare old and
new candidates with the same corpus, Ruby and hardware whenever possible.

## Validation

Follow `docs/agent/testing.md` for the default RVM runtime prerequisite and full
local gate. Tests in `spec/games_dice_parser_research/` run with the ordinary
suite. They cover curated grammar behavior, generated valid expressions,
seeded mutations, rejection, encodings, independent outputs, recovery after
failure, PRNG isolation and agreement of rolls/explanations.

Differential tests compare acceptance and complete constructor data, not exact
exception classes or messages. They only normalize expected parse/encoding
failures; unexpected implementation errors must escape. Explicit characterization
checks also cover invalid-input rejection and constructor validation boundaries.
No test constructs dice for enormous integer grammar cases.

## Benchmark

From the repository root, in a non-login shell:

```sh
test -f ~/.rvm/environments/default && source ~/.rvm/environments/default
ruby --version
test "$(ruby -e 'print RUBY_VERSION')" = "${RUBY_VERSION#ruby-}" || exit 1
for sample in 1 2 3; do
  SEED=$((20261018 + sample)) bundle exec ruby -Ilib research/parser/benchmark.rb > /private/tmp/parser-${sample}.jsonl || exit 1
done
```

Run serially without concurrent tests or builds. JSONL metadata records Ruby,
Parslet, JIT, source identity and research-file SHA-256 checksums, seeds and iteration settings. Record CPU/OS and
native build mode alongside retained results. Corpus version 1 has six ordinary
expressions selected before measuring the candidate. The agreed acceptance is
full text-to-roll <=3 times cached rolling for each ordinary expression;
parse <=1 times cached rolling is a stretch target. Allocations are supporting
evidence with no threshold.

The runner compares the retained Parslet reference, the preparation prototype,
and the production parser. Production timings use the actual public factory;
metadata also records all production Ruby source checksums.

The runner reuses parsers, enables GC, warms each operation, starts GC before
measurement, and uses monotonic elapsed time. It prepares all data before timing
and randomizes job order with a recorded seed. The built-in PRNG is seeded for
each job. Default ordinary/varied measurements use 1,000 iterations after 100
warmups; stress cases use 200 iterations and failures use 100. `ITERATIONS`,
`WARMUP` and `SEED` can be overridden. Report per-input medians and observed
ranges across fresh processes, not just a weighted average. Allocation counts
include tiny measurement overhead. Process startup and require time are excluded.

Each ordinary input also has a stream of 16 definitions with differing constant
suffixes; the matching cached-roll stream uses the same definitions and cycling
overhead. Constants, large dice pools, many bunches/modifiers and malformed
inputs are separate groups. Failure creation/rescue and diagnostic rendering
are separate operations. Constructor-validation failures are also measured
separately from syntax failures, both with and without parsing. Rendering differs in detail between parsers and is
not an equal-feature throughput comparison.

## Error interface and history

The prototype uses `GamesDiceParserResearch::Error` and `ParseError` to keep
research isolated. Production exposes
`GamesDice::Error < StandardError` and `GamesDice::ParseError < GamesDice::Error`.
Exact Parslet exception identity is explicitly not required. Prototype failures
report zero-based original-input byte offsets without an inserted leading `+`;
malformed modifiers point to their start, and duplicate keepers to the end of
the duplicate modifier. The user accepted the diagnostic contract for the production recommendation
on 2026-10-19. Input encoding failures are wrapped with their original exception
as the cause and byte offset zero, identifying the input as a whole.

Readable error messages have no exact-wording compatibility guarantee. No
Parslet failure tree is promised. Exceptions raised by custom `to_s` methods
and subsequent constructors propagate unchanged.
The old parser exposes grammar methods and Parslet failure trees; repository
search found no runtime callers of these outside the parser, but cannot establish
that external users never depend on them. The user accepted the migration on 2026-10-19, including removal of the
undocumented inherited Parslet grammar/combinator surface. The historical
prototype/reference remain isolated; production behavior has its own specs.

For a larger reproducible sweep, after the same runtime prerequisite:

```sh
SEED=20261021 COUNT=2000 bundle exec ruby -Ilib research/parser/compare.rb
```

This generates 2,000 valid expressions and four mutations of each, compares
10,000 outcomes, reports every mismatch, and exits nonzero if any differ.
It compares production against the reference by default. Set
`IMPLEMENTATION=scanner` to rerun the retained prototype comparison. It does not
execute the resulting dice recipes. Earlier result files remain tied to their
recorded commits; use those revisions to reproduce the historical harness.
