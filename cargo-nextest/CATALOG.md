---
title: cargo-nextest
description: Next-generation Rust test runner - process-per-test execution, flaky-test retries, partitioned CI sharding and JUnit output
keywords: cargo-nextest,nextest,cargo,rust,test-runner,testing,junit,flaky-tests,ci,sharding,retries
---

# cargo-nextest

cargo-nextest is a test runner for Rust that replaces `cargo test`. Its defining
choice is the execution model: every test runs in **its own process**, listed
first and then scheduled across a thread pool, instead of many tests sharing one
process and one global state.

That single change is what the rest follows from:

- **Isolation** — a test that aborts, segfaults, deadlocks or leaks global state
  takes down only itself, and the run reports it instead of losing the whole
  binary's results.
- **Per-test timeouts** — a hung test is detected and terminated
  (`slow-timeout`, with an optional `terminate-after`), rather than hanging CI.
- **Retries for flaky tests** — a configurable retry policy per test or per
  profile, with flaky outcomes reported distinctly from clean passes.
- **Partitioning** — `--partition count:1/8` or `hash:…` shards a suite
  deterministically across CI machines without hand-maintained test lists.
- **Filtersets** — a real query language (`test(foo) & !package(bar)`) over the
  test/package graph, not just substring matching.
- **Machine-readable output** — JUnit XML for CI, plus `--message-format json`
  for tooling.
- **Profiles** — named configurations in `.config/nextest.toml` (`ci`, `local`,
  …) so CI and developer runs differ by name rather than by flags.

## What's included

- **cargo-nextest** — the runner. Invoked as `cargo nextest run` once it is on
  `PATH` (cargo finds it by name), or directly as `cargo-nextest nextest run`.

`cargo nextest run` / `list` / `archive` build and enumerate the test binaries
of a real workspace, so they need a Rust toolchain on `PATH` alongside this
package. `cargo-nextest --version` and `cargo-nextest nextest self schema …`
answer entirely from the binary itself and need nothing else.

## Links

- [nextest documentation](https://nexte.st)
- [nextest on GitHub](https://github.com/nextest-rs/nextest)
- [Configuration reference](https://nexte.st/docs/configuration/)
- [Running tests in CI](https://nexte.st/docs/ci-features/)
