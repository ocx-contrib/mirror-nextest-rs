# mirror-nextest-rs

OCX mirror for the tooling published by the
[nextest-rs](https://github.com/nextest-rs) project. One repository, one spec
directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [cargo-nextest](https://github.com/nextest-rs/nextest) | [`cargo-nextest/mirror.yml`](cargo-nextest/mirror.yml) | `ghcr.io/ocx-contrib/nextest-rs/cargo-nextest` | [`ocx.sh/nextest-rs/cargo-nextest`](https://index.ocx.sh/nextest-rs/cargo-nextest) | `Apache-2.0 OR MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
cargo-nextest/          one directory per package — same five files each
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated edit
happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim goes
back to being asserted rather than verified. Restate a block in full or not at
all.

## Upstream is a monorepo — the tag anchor is load-bearing

`nextest-rs/nextest` tags six independent crates from one repository
(`cargo-nextest`, `nextest-runner`, `nextest-metadata`, `nextest-filtering`,
`internal-test`, `quick-junit`), each on its own version line. The spec anchors
`^cargo-nextest-(?P<version>\d+\.\d+\.\d+)$`, which also rejects both prerelease
schemes upstream uses (`-b.N` and `-rc.N`) without relying on
`skip_prereleases` alone.

The mirrored sequence legitimately jumps **0.9.138 → 0.9.140**: the tag
`cargo-nextest-0.9.139` exists in the repository but carries no GitHub Release
object, so there is nothing to mirror for it.

## Platforms

Six declared: both Linux arches, both macOS arches, both Windows arches.

**macOS is one asset for two platforms.** Upstream ships no per-arch macOS
build — `-universal-apple-darwin.tar.gz` is a Mach-O universal binary with
`x86_64` and `arm64` slices lipo-ed together. Two platform keys resolving to the
same asset is fine; the rule is that each *platform* matches exactly one asset,
not that each asset serves one platform.

**`windows/arm64` IS shipped** (`aarch64-pc-windows-msvc`, every in-range
release), so it is declared rather than excluded — this upstream is the
exception to the fleet's usual omission.

Upstream also builds `riscv64gc-unknown-linux-gnu`, `i686-pc-windows-msvc`,
`x86_64-unknown-freebsd` and `x86_64-unknown-illumos`. None is declarable: ocx's
architecture enum is `amd64 | arm64` and its OS enum is
`linux | darwin | windows`. Every platform ocx *can* express is declared.

Linux takes the **musl** asset under a **bare** `os.features` key. Upstream
ships both `-gnu` and `-musl` for each arch and they measure differently: the
musl builds have no `PT_INTERP` and no `DT_NEEDED` on either arch (`static-pie
linked` / `statically linked`, and not UPX-packed), while the gnu builds are
dynamically linked against `/lib64/ld-linux-x86-64.so.2` resp.
`/lib/ld-linux-aarch64.so.1`. `os.features` states what an artifact *requires of
the host*, so a proven-static build takes the bare key — tagging it `+libc.musl`
would be a false requirement that hid it from every glibc host. A second
`+libc.glibc` key for the gnu build was considered and rejected: it earns its
keep only where the gnu build has capability the static one lacks (usually
glibc's NSS/DNS resolver), and cargo-nextest is a local test runner, not a
network client. The `alpine:3.20` container leg is what turns the universal
claim into evidence; the measurements are recorded above `assets:` in the spec.

## Archive layout and the binaries claim

Every upstream asset is a **flat** `tar.gz` containing exactly one member — the
bare executable (`cargo-nextest`, or `cargo-nextest.exe` on Windows), mode 0755,
with no wrapper directory, no `bin/` and no bundled README or LICENSE. So
`strip_components: 0` is forced in the opposite direction from the usual wrapper
case: there is nothing to strip, and `strip_components: 1` would delete the only
member. That puts the executable at the content root, which makes `PATH` a bare
`${installPath}`. `bin_scan` only looks *below* an `${installPath}/<dir>` entry,
so `auto`/`verify` is rejected at spec load with exit 65; `mirror-base.yml`
therefore sets `bin_scan: off` and `metadata.json` hand-lists its `binaries`.

Windows ships a `.zip` twin beside every `.tar.gz`; the spec takes the
`.tar.gz`, which is the only format present for all six declared platforms
across the whole range. The `.exe` suffix is already inside the archive, so no
per-platform name override is needed.

## The smoke test is offline, and does not need cargo

cargo-nextest's headline verbs — `run`, `list`, `bench`, `archive`, and even
`show-config` — resolve the workspace by shelling out to
`cargo locate-project` / `cargo metadata`. Neither `ubuntu:24.04`,
`alpine:3.20`, `fedora:40` nor this bundle provides cargo, so an assertion
reaching them would red every container leg for a reason unrelated to the
mirrored artifact. Installing a Rust toolchain through `containers[].setup`
would be wrong for the same reason: cargo is a dependency of the *workflow*
those verbs perform, not a runtime dependency of the shipped binary.

What the smoke asserts instead, all measured on each of the three in-range
releases:

- the version *shape* (`\d+\.\d+\.\d+`), never the version or the banner text;
- the **compiled-in target triple** from `--version`'s `host:` line
  (`NEXTEST_BUILD_HOST_TARGET`, captured from `env!("TARGET")` by upstream's
  `build.rs`), which proves the asset regex put the right binary in the right
  bundle. It matters most on macOS, where both platforms resolve to the *same*
  universal asset: it is the only evidence that the darwin/amd64 leg's
  `arch -x86_64` prefix really selected the x86_64 slice;
- the **cargo-subcommand argv contract** — `cargo-nextest nextest --version`
  must be byte-identical to `cargo-nextest --version`, because cargo invokes a
  subcommand with the subcommand's own name as `argv[1]` and the binary has to
  absorb it;
- one hermetic operation over the tool's own encoder: `nextest self schema
  repo-config` printing the embedded JSON Schema for `.config/nextest.toml`,
  asserted as exact **counts** of quoted top-level keys (parser-free, and
  structural rather than prose).

Two negative controls, because the positive is document-shaped: `self schema
user-config` must return a genuinely *different* document (a binary that cats
one embedded blob would pass otherwise), and an unknown schema name must be
refused with exit **2** and empty stdout.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `<pkg>/mirror.yml` | hand | yes — see below |
| `<pkg>/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `<pkg>/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci \
  --spec cargo-nextest/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
