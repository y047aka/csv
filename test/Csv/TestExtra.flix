/*
 * Copyright 2026 Yoshitaka Totsuka
 *
 * Use of this source code is governed by the Apache 2.0 license
 * that can be found in the LICENSE file.
 */

pub mod Csv.TestExtra {

    use Csv.Decode
    use Csv.Decode.{Column, DecodingError, Error, FieldNames, Problem}
    use Csv.Decode.Extra.traverse

    // `Extra.traverse` has no upstream counterpart, so it has no upstream test either.
    // The two below are the ones the consumer's `Motorsport.Wec` decoder relies on.

    @Test
    def testTraverseDecodesOneDecoderPerElement(): Unit \ Assert =
        Decode.decodeCsv(
            FieldNames.NoFieldNames,
            traverse(col -> Decode.column(col, Decode.int()), List#{0, 1, 2}),
            "1,2,3"
        )
            |> Assert.assertEq({expected = Ok(List#{List#{1, 2, 3}})})

    /// The failure is the one worth pinning: `traverse` accumulates through `map2`, so a
    /// row that fails names the column that failed rather than the first one it looked at.
    @Test
    def testTraverseReportsTheFailingColumn(): Unit \ Assert =
        Decode.decodeCsv(
            FieldNames.NoFieldNames,
            traverse(col -> Decode.column(col, Decode.int()), List#{0, 1, 2}),
            "1,x,3"
        )
            |> Assert.assertEq({
                expected = Err(Error.DecodingErrors(
                    List#{DecodingError.FieldDecodingError(0, Column.Column(1), Problem.ExpectedInt("x"))}
                ))
            })

}
