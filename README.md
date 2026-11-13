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

## Interface

`Csv.Parser.parse({fieldSeparator = ','}, source)` turns a string into `List[List[String]]`: quoted fields, `""` escapes, `\n` and `\r\n` row separators, and a trailing newline that is not an empty last row. `Csv.Decode` is the combinator language over those rows, and `flix doc` is its inventory. `decodeCsv` splits on `,`; anything else, a TSV included, is `decodeCustom({fieldSeparator = '\t'}, …)`.

## Install

```toml
[dependencies]
"github:y047aka/csv" = { version = "0.1.0", mount = "Csv" }
```

`csv` is a legal mount name — no hyphen to read as a minus — so the prefix and the module coincide and a `use` line reads `Csv::Csv.Decode`. A signature still writes the type `Decoder[a]`, not the mount.

## What is not here

`Csv.Encode`, which upstream has. `traverse`, which upstream has no counterpart to and which therefore went back to the caller that wanted it; it is five lines over `map2` and `succeed`, both public here. Reading a file, stripping a UTF-8 BOM, and naming a decode failure in domain terms, which are the caller's business.
