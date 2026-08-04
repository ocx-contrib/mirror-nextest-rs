# cargo-nextest/tests/smoke.star — hermetic, offline, and cargo-free.
#
# Assert on the contract (exit code, version shape, the compiled-in target
# triple, structural properties of a machine-generated document), never on help
# or banner prose.
#
# ⚠️ WHAT IS DELIBERATELY NOT ASSERTED, and why. cargo-nextest's headline verbs
# — `run`, `list`, `bench`, `archive`, and even `show-config` — all resolve the
# workspace first by SHELLING OUT to cargo. Measured, in a directory with no
# Cargo.toml:
#
#   $ cargo-nextest nextest show-config version --config-file <path>
#   error: could not find `Cargo.toml` in `…` or any parent directory
#   error: command `cargo locate-project --workspace '--message-format=plain'`
#          failed with exit status: 101
#
# ubuntu:24.04, alpine:3.20 and fedora:40 ship no cargo and this bundle carries
# none, so any assertion reaching those verbs would red every container leg for
# a reason that has nothing to do with the mirrored artifact. Installing a Rust
# toolchain via `containers[].setup` would be wrong too: cargo is a dependency
# of the WORKFLOW those verbs perform, not a runtime dependency of the binary
# this package ships.
#
# `--version` and `nextest self schema` are the verbs the binary answers
# entirely from its own code — no cargo, no network, no filesystem beyond
# scratch. Both were measured present and identical in behaviour on ALL THREE
# in-range releases (0.9.137, 0.9.138, 0.9.140).

NEXTEST = "cargo-nextest.exe" if ocx.target_platform.os == ocx.os.Windows else "cargo-nextest"

# Rust target triples spell the two architectures ocx can express as `x86_64`
# and `aarch64` on every OS, so one ternary covers the arch half.
ARCH = "x86_64" if ocx.target_platform.arch == ocx.arch.Amd64 else "aarch64"

# macOS `arch(1)` uses the Darwin spelling, not the Rust one.
ARCH_FLAG = "-x86_64" if ocx.target_platform.arch == ocx.arch.Amd64 else "-arm64"


def expected_os_suffix():
    # `if` STATEMENTS are legal only inside a `def` in this Bazel dialect.
    o = ocx.target_platform.os
    if o == ocx.os.Darwin:
        return "-apple-darwin"
    if o == ocx.os.Windows:
        return "-pc-windows-msvc"
    # Linux: this mirror ships the MUSL asset under a BARE os.features key
    # (proven static: no PT_INTERP, no DT_NEEDED — see mirror.yml). The `-musl`
    # token below is therefore load-bearing, not incidental: if someone
    # re-points the linux asset regex at the `-gnu` build without also adding
    # the `+libc.glibc` key, this line reds instead of the mirror silently
    # publishing a glibc-requiring binary under a universal claim.
    return "-unknown-linux-musl"


OS_SUFFIX = expected_os_suffix()

# ── Tier 1 + 2: liveness on the composed PATH, version SHAPE ────────────────
# Measured stdout (0.9.138, linux/amd64):
#
#   cargo-nextest 0.9.138 (fc97e97bb 2026-06-21)
#   release: 0.9.138
#   commit-hash: fc97e97bbe0a3927482a694247da00c099f4269e
#   commit-date: 2026-06-21
#   host: x86_64-unknown-linux-musl
#
# The digits are the contract; the exact version is not, and neither is the
# leading token — a rebrand must not red this.
r_version = ocx.run(NEXTEST, "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Platform identity — the one bug class the platform gate cannot see ──────
# `host:` is `env!("TARGET")` captured at BUILD time by cargo-nextest's
# build.rs (`NEXTEST_BUILD_HOST_TARGET`), so it identifies the artifact, not the
# runner. Asserting it proves the asset regex shipped the RIGHT binary into the
# RIGHT bundle — a swap between two platforms' assets would otherwise stay green
# on both legs.
expect.contains(r_version.stdout, OS_SUFFIX)


def check_native_arch():
    # ⚠️ The arch half is asserted on Linux and Windows only, and the reason is
    # measured, not assumed. On macOS BOTH declared platforms resolve to the
    # SAME `universal-apple-darwin` asset — a Mach-O fat binary whose two slices
    # were compiled separately and therefore carry different TARGET strings. An
    # UNPREFIXED run executes whichever slice the host prefers, so on GitHub's
    # arm64 `macos-14` runner the darwin/amd64 leg legitimately reports
    # `aarch64-apple-darwin`:
    #
    #   error: expected cargo-nextest 0.9.137 (75ddba7e9 2026-05-26)
    #   …
    #   host: aarch64-apple-darwin
    #    to contain host: x86_64-apple-darwin
    #
    # (run 30872088150, darwin/amd64 leg). That is a property of the runner, not
    # of the artifact — check_universal_slice() below asserts the arch half on
    # macOS by selecting the slice explicitly instead.
    if ocx.target_platform.os == ocx.os.Darwin:
        return
    expect.contains(r_version.stdout, "host: " + ARCH + "-")


check_native_arch()


def check_universal_slice():
    # macOS only: prove the slice this platform key EXISTS FOR is really in the
    # fat binary and really runs on this host, by launching it through
    # `arch(1)`. Without this, declaring darwin/amd64 would rest on a `file`
    # reading taken at authoring time, and its CI leg would re-test the arm64
    # slice under an amd64 label — green, having verified nothing new.
    #
    # The spec's `platforms.darwin/amd64.prefix: ["arch", "-x86_64"]` cannot do
    # this job: `package validate` accepts the key, but the ocx-mirror v0.5.2 CI
    # renderer emits NOTHING for it (the generated darwin/amd64 matrix entry is
    # identical to darwin/arm64 but for the label), so no prefix ever reaches
    # the runner. Selecting the slice from inside the test is the only place it
    # can be done today.
    #
    # `/usr/bin/arch` is spelled absolutely so it never depends on how the
    # bundle composes PATH.
    if ocx.target_platform.os != ocx.os.Darwin:
        return
    r = ocx.run("/usr/bin/arch", ARCH_FLAG, NEXTEST, "--version")
    expect.ok(r)
    expect.contains(r.stdout, "host: " + ARCH + "-apple-darwin")


check_universal_slice()

# ── The cargo-subcommand argv contract ──────────────────────────────────────
# cargo-nextest is a CARGO SUBCOMMAND: invoked as `cargo nextest run`, cargo
# execs `cargo-nextest nextest run`, so the binary receives its own subcommand
# name as argv[1] and must absorb it. That is a real interface this mirror
# ships, and it is testable with no cargo present — the same command with and
# without the injected `nextest` token must produce byte-identical output.
# (Measured identical on 0.9.137, 0.9.138 and 0.9.140.)
r_plugin = ocx.run(NEXTEST, "nextest", "--version")
expect.ok(r_plugin)
expect.eq(r_plugin.stdout, r_version.stdout)

# ── Tier 3: a hermetic functional operation over the tool's own encoder ─────
# `nextest self schema repo-config` prints the JSON Schema for
# `.config/nextest.toml` from an embedded, machine-generated document. It is the
# tool's own format engine: colourless, byte-stable, and it exercises the whole
# config type graph in one run — strictly better than parsing human output.
#
# Assertions are COUNTS of exact quoted keys rather than substring presence, so
# they are parser-free and still structural. Every count below was measured on
# all three in-range releases and was identical on each (the document is 38396
# bytes on every one of them).
r_repo = ocx.run(NEXTEST, "nextest", "self", "schema", "repo-config")
expect.ok(r_repo)
repo = r_repo.stdout

expect.contains(repo, "https://json-schema.org/draft/2020-12/schema")
# The five documented `.config/nextest.toml` top-level sections. `"script"` is
# counted with its closing quote so it does not also match the sibling
# `"scripts"` key.
expect.eq(repo.count("\"nextest-version\""), 1)
expect.eq(repo.count("\"profile\""), 1)
expect.eq(repo.count("\"test-groups\""), 1)
expect.eq(repo.count("\"store\""), 1)
expect.eq(repo.count("\"script\""), 1)
# `ui` belongs to the USER config surface and must not appear here.
expect.eq(repo.count("\"ui\""), 0)

# ── Negative control #1: a different argument must yield a different document ─
# Without this, "printed a big JSON blob" would be satisfied by a binary that
# cats one embedded string regardless of its arguments. The user-config schema
# is a genuinely disjoint surface (15801 bytes, properties experimental /
# overrides / record / ui) and shares only the dialect URL with the repo one.
r_user = ocx.run(NEXTEST, "nextest", "self", "schema", "user-config")
expect.ok(r_user)
user = r_user.stdout

expect.ne(user, repo)
expect.contains(user, "https://json-schema.org/draft/2020-12/schema")
expect.eq(user.count("\"ui\""), 2)
expect.eq(user.count("\"test-groups\""), 0)
expect.eq(user.count("\"nextest-version\""), 0)

# ── Negative control #2: an unknown schema name must be REFUSED ─────────────
# An exact exit code, not "non-zero": a range would tolerate a crash. Measured
# exit 2 (clap's usage-error code) with EMPTY stdout on all three releases.
r_neg = ocx.run(NEXTEST, "nextest", "self", "schema", "no-such-schema")
expect.eq(r_neg.exit_code, 2)
expect.eq(r_neg.stdout, "")

# No Tier 4: metadata.json declares PATH only, and Tier 1 already proved it.
