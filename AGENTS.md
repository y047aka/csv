# AGENTS.md

The CSV parser and decoder that `elm-motorsport-analysis` grew out of. Extracted so the two are not the same source file twice; the consumer still has its own copy at `backend/src/Util/Csv/` and does not reference this package yet.

## Where the boundary is

- The library owns parsing a string into rows, and a row into a value. It does not own reading a file, stripping a UTF-8 BOM, or naming a failure in domain terms — the consumer does all three in `Cli.Load.CsvInput` and `Cli.Load.CsvDecode`, and those stay there.
- `Csv.Parser` and `Csv.Decode` are elm-csv 4.0.1's `Csv.Parser` and `Csv.Decode`, and their declaration order, function names, argument order, and `errorToString` phrasing are upstream's on purpose: the two implementations are meant to be read side by side. A rename inside them is a decision to break that, not a cleanup.
- `Csv.Decode.Extra` is the only module here with no upstream counterpart. It exists because `Util.Csv.Decode.Extra` was written to avoid an `andThen` that rebuilds a decoder per row.
- elm-csv's `Csv.Encode` is not ported. Nothing downstream needed it.
- The extraction renamed one thing: every `Util.Csv.` became `Csv.`, and nothing else in the two source files and two test files changed. That is the whole of the local diff, and a divergence from it is a bug.

## Facts about Flix and about these modules already paid for; do not re-derive them

- Two licences. This repository is Apache 2.0; `src/Csv/Parser.flix` and `src/Csv/Decode.flix` are BSD-3-Clause, `Copyright 2021 Brian Hicks`, notice at `LICENSE.elm-csv` and in each file's header. The header is load-bearing: `flix build-pkg` ships `flix.toml`, `README.md`, and `src/` and nothing else, so `LICENSE` and `LICENSE.elm-csv` never reach a package consumer and the file headers are the only route the BSD notice has.
- `Csv.Parser.Problem` (2 cases) and `Csv.Decode.Problem` (6 cases) are different enums with the same name, as they are upstream. `Csv.Decode.Error.ParsingError` carries the parser's, and a `use Csv.Decode.{…}` that also names `Problem` is how a call site gets the wrong one.
- `Csv.Decode.Decoder` is a `pub enum` whose single case is also `Decoder`, so `use Csv.Decode.Decoder` is needed before `Decoder.Decoder(…)` matches, and a custom decoder is written by unwrapping and rewrapping it.
- `Location` and its cases (`Column_`, `Field_`, `OnlyColumn_`) are not `pub`, and carry a trailing underscore because `Column` is already the public error-location enum. `ResolvedNames`, `getFieldNames`, `applyDecoder`, and `recover` are likewise private; upstream keeps them so and there is no reason to widen them.
- `parse` specialises `,` and `;` into two literal copies of `parseHelp`. In Elm that duplication existed so the compiler emitted literal `===` comparisons; on the JVM the reason is gone, and the copies are kept only for parity. Do not "fix" it by collapsing them.
- Row separators are `\n` and `\r\n` only; a bare `\r` is data. A trailing newline is not an empty last row.
- `int()` and `float()` trim, and `blank()` treats a field as blank on a wider whitespace class than `Char.isWhitespace` (NBSP, figure space, the `U+2000`–`U+200A` run, line/paragraph separators, ideographic space), because that is what upstream's `isBlank` does.
- `decodeCsv` is `,`; anything else, including a TSV, is `decodeCustom({fieldSeparator = …}, …)`.
- Flix needs the parent module declared before its children hang from it: `src/Csv.flix` is an empty `pub mod Csv { }` for exactly that reason, and without it every child file errors as `Orphaned module`.
- `flix install` resolves `owner/name[@ver]` from GitHub, a dependency is declared `"github:owner/name" = { version, mount }`, and there is no local-path dependency. The consumer therefore cannot point at this checkout; the swap is verifiable only after `flix release` publishes the tag `v0.1.0`.
- `flix release` refuses without `repository` in the manifest, takes its token from `--github-token`, a `.GITHUB_TOKEN` file at the root, or `GITHUB_TOKEN`, and publishes `v<version>`. The `package` table accepts only `version`, `repository`, and `flix` — `name`, `description`, and `licenses` there fail the manifest, which is why the licences are carried by the two files and the headers and not by the metadata.

## Commands

| Command | Purpose |
| --- | --- |
| `nix run .#check` \| `flix check` | type-check |
| `nix run .#test` \| `flix test` | 80 tests |
| `nix run .#build` \| `flix build` | compile |
| `nix run .#pkg` \| `flix build-pkg` | an `.fpkg`, at `artifact/package.fpkg` |
| `nix run .#doc` \| `flix doc` | API documentation, at `build/doc` |
| `nix run .#clean` \| `flix clean` | remove `build/` and `artifact/` |
| `flix release` | publish a version to GitHub |

Flix is 0.79.0, the same as the consumer's. The repository's own flake pins it, because nixos-26.05 carries 0.69.1; the pin is copied from the consumer's `overrideAttrs`, jar URL and hash included, so both build the same Flix version from the same jar. `nix develop --command flix …` therefore works from a clone alone.

CI runs `nix flake check`, `nix run .#test`, and `nix run .#pkg` on `main` and on every PR. There is no app for `release`: publishing a version stays a human act, and its token is never a repository secret.

## Verification

The 77 tests that came with the port are elm-csv's own, and passing them against the Elm behaviour they were written for is the specification. Beyond them, `test/Csv/TestReadme.flix` pins the README example, and `test/Csv/TestExtra.flix` is the only coverage `Extra.traverse` has anywhere.

The second half is the consumer, and it cannot run here: `Motorsport.Wec.decoder()` is a 16-stage `intoRecord`/`pipeline` decoder over the WEC timing CSVs, and its exported JSON is committed bytes. When the consumer is switched over, the check is that its suite still passes and its exported files still hash to what it has committed.

Switching it over is:

```toml
# backend/flix.toml
"github:y047aka/csv" = { version = "0.1.0", mount = "Csv" }
```

then `use Util.Csv.Decode` → `use Csv::Csv.Decode` in the eight files that write it, `src/Util/Csv/` and `test/Util/Csv/` deleted, and `Util.Csv.Decode.Extra.traverse` reached as `Csv::Csv.Decode.Extra.traverse`.

## Comments and committing

Prose breaks its lines only at sentence ends. A comment says only what the code cannot — an outside constraint, a hazard, a decision whose alternatives looked equal — and the reasoning for a change belongs in its commit message. Commit prefixes in use: `feat:` `refactor:` `chore:` `docs:` `build:` `fix:`.
