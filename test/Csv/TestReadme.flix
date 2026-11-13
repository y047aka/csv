/*
 * Copyright 2026 Yoshitaka Totsuka
 *
 * Use of this source code is governed by the Apache 2.0 license
 * that can be found in the LICENSE file.
 */

/// The README example, kept executable: the distributed documentation is the README, and
/// `flix build-pkg` ships nothing else that a reader would copy from.
pub mod Csv.TestReadme {

    use Csv.Decode
    use Csv.Decode.FieldNames

    @Test
    def testReadmeExample(): Unit \ Assert =
        let csv = "name,laps\nPorsche,387\nToyota,349\n";
        let decoder =
            Decode.map2(
                (name, laps) -> (name, laps),
                Decode.field("name", Decode.string()),
                Decode.field("laps", Decode.int())
            );
        Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, decoder, csv)
            |> Assert.assertEq({expected = Ok(List#{("Porsche", 387), ("Toyota", 349)})})

}
