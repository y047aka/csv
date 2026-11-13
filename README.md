# csv

CSV parsing and decoding for Flix, ported from [BrianHicks/elm-csv](https://github.com/BrianHicks/elm-csv) 4.0.1. Function names, declaration order, and error messages are the Elm module's own, so the two implementations can be reviewed side by side.

```scala
use Csv::Csv.Decode
use Csv::Csv.Decode.FieldNames

let csv = "name,laps\nPorsche,387\nToyota,349\n";

let decoder =
    Decode.map2(
        (name, laps) -> (name, laps),
        Decode.field("name", Decode.string()),
        Decode.field("laps", Decode.int())
    );

Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, decoder, csv)
// Ok(List#{("Porsche", 387), ("Toyota", 349)})
```

## Modules

- `Csv.Parser` — `parse({fieldSeparator = ','}, source)`, a string to `List[List[String]]`. Quoted fields, `""` escapes, `\n` and `\r\n` row separators, a trailing newline ignored. No encoding: elm-csv's `Csv.Encode` has no port here.
- `Csv.Decode` — the decoder combinators. `string()`, `int()`, `float()`, `blank(decoder)` to `Option`; `column`, `field`, `optionalColumn`, `optionalField`, `availableFields()`; `map`, `map2`, `map3`, `intoRecord`, `pipeline`, `oneOf`, `andThen`, `succeed`, `fail`, `fromResult`, `fromMaybe`; `decodeCsv`, `decodeCustom`, `errorToString`.

`decodeCsv` splits on `,`; anything else, including a TSV, goes through `decodeCustom({fieldSeparator = '\t'}, …)`.

## Install

```toml
[dependencies]
"github:y047aka/csv" = { version = "0.1.0", mount = "Csv" }
```

`csv` is a legal mount name — no hyphen to read as a minus — so the prefix and the module coincide and a `use` line reads `Csv::Csv.Decode`. A signature still writes the type `Decoder[a]`, not the mount.

## Licence

BSD-3-Clause, `Copyright 2021 Brian Hicks` and `Copyright 2026 Yoshitaka Totsuka`, at `LICENSE`. The port's licence covers the whole repository, which is the simpler arrangement and the one the code was already under: the parser, the decoder, and the tests that came with them are elm-csv 4.0.1's, and only the parent module, the README, the flake, and CI are new here.

The notice is repeated in the header of every source file, and that is not decoration: `flix build-pkg` ships `flix.toml`, `README.md`, and `src/` and nothing else, so `LICENSE` is not in the package and the headers are the only route by which the notice reaches a package consumer.

## What is not here

`Csv.Encode`, which upstream has. `Csv.Decode.Extra` and its `traverse`, which upstream has no counterpart to and which therefore counts as this port's own addition rather than as the port; a caller that wants it can write it in five lines over `map2` and `succeed`, both of which are public here. Reading a file, stripping a UTF-8 BOM, and mapping a decode failure onto a domain error type, which are the caller's business — the consumer of this library does all three in twenty lines of its own.
