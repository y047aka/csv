# AGENTS.md

The CSV parser and decoder that `elm-motorsport-analysis` grew out of. Extracted so the two are not the same source file twice; the consumer still has its own copy at `backend/src/Util/Csv/` and does not reference this package yet.

## Where the boundary is

- The library owns parsing a string into rows, and a row into a value. It does not own reading a file, stripping a UTF-8 BOM, or naming a failure in domain terms — the consumer does all three in `Cli.Load.CsvInput` and `Cli.Load.CsvDecode`, and those stay there.
- `Csv.Parser` and `Csv.Decode` are elm-csv 4.0.1's `Csv.Parser` and `Csv.Decode`, and their declaration order, function names, argument order, and `errorToString` phrasing are upstream's on purpose: the two implementations are meant to be read side by side. A rename inside them is a decision to break that, not a cleanup.
- `Csv.Decode.Extra` is not here, by decision: it is the one module the extraction carried that upstream has no counterpart to, so it is the port's own addition rather than the port, and a library whose premise is side-by-side review with elm-csv has no business carrying it. The consumer keeps its own copy — `traverse` is five lines over `map2` and `succeed`, both public here — and `Motorsport.Wec` keeps calling it at its one call site.
- elm-csv's `Csv.Encode` is not ported. Nothing downstream needed it.
- The extraction renamed one thing: every `Util.Csv.` became `Csv.`, and nothing else in the two source files and two test files changed. That is the whole of the local diff, and a divergence from it is a bug. `Csv.Decode.Extra` was then dropped, which is the only removal, and a licence header was put on all four files, which is the only addition.

## Facts about Flix and about these modules already paid for; do not re-derive them

- One licence, BSD-3-Clause, `Copyright 2021 Brian Hicks` and `Copyright 2026 Yoshitaka Totsuka` at `LICENSE`. The repository could be collapsed onto the port's licence because nothing in it came from the Flix standard library — the sibling `ordered-json` cannot do this, since its module is the standard library's `Util/Json.flix` and Apache 2.0 does not downgrade. What the collapse cost is Apache's explicit patent grant, §3; the port is a 2021 Elm module with one author, so the grant was buying little, and it is unrecoverable without upstream's consent now. The header is load-bearing either way: `flix build-pkg` ships `flix.toml`, `README.md`, and `src/` and nothing else, so `LICENSE` never reaches a package consumer and the file headers are the only route the notice has. The consumer's own project is Apache 2.0 and takes this as a dependency, which is the direction that works — BSD-3 code inside an Apache-2.0 project is ordinary — and asks nothing of it beyond keeping the source headers it will be reading anyway.
- `Csv.Parser.Problem` (2 cases) and `Csv.Decode.Problem` (6 cases) are different enums with the same name, as they are upstream. `Csv.Decode.Error.ParsingError` carries the parser's, and a `use Csv.Decode.{…}` that also names `Problem` is how a call site gets the wrong one.
- `Csv.Decode.Decoder` is a `pub enum` whose single case is also `Decoder`, so `use Csv.Decode.Decoder` is needed before `Decoder.Decoder(…)` matches, and a custom decoder is written by unwrapping and rewrapping it.
- `Location` and its cases (`Column_`, `Field_`, `OnlyColumn_`) are not `pub`, and carry a trailing underscore because `Column` is already the public error-location enum. `ResolvedNames`, `getFieldNames`, `applyDecoder`, and `recover` are likewise private; upstream keeps them so and there is no reason to widen them.
- `parse` specialises `,` and `;` into two literal copies of `parseHelp`. In Elm that duplication existed so the compiler emitted literal `===` comparisons; on the JVM the reason is gone, and the copies are kept only for parity. Do not "fix" it by collapsing them.
- Row separators are `\n` and `\r\n` only; a bare `\r` is data. A trailing newline is not an empty last row.
- `int()` and `float()` trim, and `blank()` treats a field as blank on a wider whitespace class than `Char.isWhitespace` (NBSP, figure space, the `U+2000`–`U+200A` run, line/paragraph separators, ideographic space), because that is what upstream's `isBlank` does.
- `decodeCsv` is `,`; anything else, including a TSV, is `decodeCustom({fieldSeparator = …}, …)`.
- Flix needs the parent module declared before its children hang from it: `src/Csv.flix` is an empty `pub mod Csv { }` for exactly that reason, and without it every child file errors as `Orphaned module`.
- `flix install` resolves `owner/name[@ver]` from GitHub, a dependency is declared `"github:owner/name" = { version, mount }`, and there is no local-path dependency. The consumer therefore cannot point at this checkout; the swap is verifiable only after `flix release` publishes the tag `v0.1.0`.
- `flix release` refuses without `repository` in the manifest, takes its token from `--github-token`, a `.GITHUB_TOKEN` file at the root, or `GITHUB_TOKEN`, and publishes `v<version>`. The `package` table accepts only `version`, `repository`, and `flix` — `name`, `description`, and `licenses` there fail the manifest, which is why the licence is carried by `LICENSE` and the file headers and not by the metadata.

## Commands

| Command | Purpose |
| --- | --- |
| `nix run .#check` \| `flix check` | type-check |
| `nix run .#test` \| `flix test` | 77 tests |
| `nix run .#build` \| `flix build` | compile |
| `nix run .#pkg` \| `flix build-pkg` | an `.fpkg`, at `artifact/package.fpkg` |
| `nix run .#doc` \| `flix doc` | API documentation, at `build/doc` |
| `nix run .#clean` \| `flix clean` | remove `build/` and `artifact/` |
| `flix release` | publish a version to GitHub |

Flix is 0.79.0, the same as the consumer's. The repository's own flake pins it, because nixos-26.05 carries 0.69.1; the pin is copied from the consumer's `overrideAttrs`, jar URL and hash included, so both build the same Flix version from the same jar. `nix develop --command flix …` therefore works from a clone alone.

CI runs `nix flake check`, `nix run .#test`, and `nix run .#pkg` on `main` and on every PR. There is no app for `release`: publishing a version stays a human act, and its token is never a repository secret.

## Verification

The 77 tests that came with the port are elm-csv's own, and passing them against the Elm behaviour they were written for is the specification. There is no test here that the port did not arrive with; the README example was checked against the suite while a test pinned it, and nothing now re-checks it, so a change to `decodeCsv` or to the README is where it goes stale.

The second half is the consumer, and it cannot run here: `Motorsport.Wec.decoder()` is a 16-stage `intoRecord`/`pipeline` decoder over the WEC timing CSVs, and its exported JSON is committed bytes. When the consumer is switched over, the check is that its suite still passes and its exported files still hash to what it has committed.

Switching it over is:

```toml
# backend/flix.toml
"github:y047aka/csv" = { version = "0.1.0", mount = "Csv" }
```

then `use Util.Csv.Decode` → `use Csv::Csv.Decode` in the eight files that write it, and `src/Util/Csv/` and `test/Util/Csv/` deleted — except `Extra.traverse`, which stays with its only caller. It cannot keep its path: `Util.Csv.Decode.Extra` is a child module, and a child cannot be declared once its parent is gone, so `traverse` moves into `Motorsport.Wec` and is written over `Csv::Csv.Decode.map2` and `Csv::Csv.Decode.succeed`, both public here.

## Comments and committing

Prose breaks its lines only at sentence ends. A comment says only what the code cannot — an outside constraint, a hazard, a decision whose alternatives looked equal — and the reasoning for a change belongs in its commit message. Commit prefixes in use: `feat:` `refactor:` `chore:` `docs:` `build:` `fix:`.
