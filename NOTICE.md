# NOTICE

This repository packages and redistributes upstream software published by the
[nextest-rs](https://github.com/nextest-rs) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — the redistributed bytes carry their
own license, recorded below.

The package logo is an original mark authored for this catalog, not an upstream
asset: `nextest-rs/nextest` ships no logo file, and its documentation site uses
the stock mkdocs-material theme assets. Upstream names are used for
identification only, under nominative fair use; no endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `cargo-nextest` | `ghcr.io/ocx-contrib/nextest-rs/cargo-nextest` | `Apache-2.0 OR MIT` |

---

## `cargo-nextest`

Upstream: <https://github.com/nextest-rs/nextest>
Published to `ghcr.io/ocx-contrib/nextest-rs/cargo-nextest`.

| Component | SPDX | Holder |
|---|---|---|
| cargo-nextest (`cargo-nextest`) | **Apache-2.0 OR MIT** | The nextest Contributors |

Permissive, dual-licensed at the recipient's option. Redistribution of the
compiled binary is granted under either
<https://github.com/nextest-rs/nextest/blob/main/LICENSE-MIT> or
<https://github.com/nextest-rs/nextest/blob/main/LICENSE-APACHE>.

> The GitHub license API reports only one half of the grant
> (`gh api repos/nextest-rs/nextest/license --jq '.license.spdx_id'` →
> `Apache-2.0`) because it detects a single license per repository. The crate
> that is actually mirrored declares both: `cargo-nextest/Cargo.toml` carries
> `license = "Apache-2.0 OR MIT"`, and `LICENSE-APACHE` + `LICENSE-MIT` sit at
> the repository root **and** inside `cargo-nextest/`. The SPDX expression above
> is therefore the dual one rather than the API's single id.

Upstream's release archives are **flat** — each contains exactly the executable
and nothing else — so unlike some Rust projects the license files do **not**
travel inside the redistributed bytes. They are referenced above instead, and
this NOTICE ships with the mirror repository.

The published binaries statically link third-party Rust crates under permissive
licenses, enumerated in upstream's `Cargo.lock`.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
