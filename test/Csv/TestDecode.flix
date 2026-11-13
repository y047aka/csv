/*
 * Copyright 2021 Brian Hicks
 *
 * Ported from `tests/Csv/DecodeTest.elm` of BrianHicks/elm-csv 4.0.1, as the rest of this
 * repository under the BSD-3-Clause conditions at LICENSE.
 */

pub mod Csv.TestDecode {

    use Csv.Decode
    use Csv.Decode.{Decoder, FieldNames, Error, DecodingError, Column, Problem}

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    /// `Hex.fromString` from `rtfeldman/elm-hex`, for the `fromResult` tests.
    def hexFromString(input: String): Result[String, Int32] =
        def hexDigit(c) = match c {
            case '0' => Ok(0)
            case '1' => Ok(1)
            case '2' => Ok(2)
            case '3' => Ok(3)
            case '4' => Ok(4)
            case '5' => Ok(5)
            case '6' => Ok(6)
            case '7' => Ok(7)
            case '8' => Ok(8)
            case '9' => Ok(9)
            case 'a' => Ok(10)
            case 'b' => Ok(11)
            case 'c' => Ok(12)
            case 'd' => Ok(13)
            case 'e' => Ok(14)
            case 'f' => Ok(15)
            case 'A' => Ok(10)
            case 'B' => Ok(11)
            case 'C' => Ok(12)
            case 'D' => Ok(13)
            case 'E' => Ok(14)
            case 'F' => Ok(15)
            case bad => Err(bad)
        };
        let chars = String.toList(input);
        if (List.isEmpty(chars))
            Err("Empty strings are not valid hexadecimal strings.")
        else
            List.foldLeft(
                (acc, c) -> match acc {
                    case Ok(n) => match hexDigit(c) {
                        case Ok(d)  => Ok(n * 16 + d)
                        case Err(bad) =>
                            Err("\"${input}\" is not a valid hexadecimal string because ${bad} is not a valid hexadecimal character.")
                    }
                    case Err(e) => Err(e)
                },
                Ok(0),
                chars
            )

    /// Elm の `round : Float -> Int` 相当。`Float64.round` は half-to-even
    /// （偶数丸め）で、Elm の half-away-from-zero とは丸め方が異なるが、
    /// `testErrorToString_worksWithComplexDecoder` ではこの戻り値が期待出力に
    /// 現れないため挙動差は問題にならない。
    def round(f: Float64): Int32 =
        Float64.tryToInt32(Float64.round(f)) |> Option.getWithDefault(0)


    // ---------------------------------------------------------------------------
    // string
    // ---------------------------------------------------------------------------

    /// a blank string
    @Test
    def testString_aBlankString(): Unit \ Assert =
        "\"\""
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.string())
            |> Assert.assertEq({expected = Ok(List#{""})})

    /// a unquoted value
    @Test
    def testString_aUnquotedValue(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.string())
            |> Assert.assertEq({expected = Ok(List#{"a"})})

    /// an integer
    @Test
    def testString_anInteger(): Unit \ Assert =
        "1"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.string())
            |> Assert.assertEq({expected = Ok(List#{"1"})})

    /// multiple columns
    @Test
    def testString_multipleColumns(): Unit \ Assert =
        "1,2"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.string())
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.ExpectedOneColumn(2)) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // int
    // ---------------------------------------------------------------------------

    /// a valid integer
    @Test
    def testInt_aValidInteger(): Unit \ Assert =
        "1"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.int())
            |> Assert.assertEq({expected = Ok(List#{1})})

    /// an integer with spaces around
    @Test
    def testInt_anIntegerWithSpacesAround(): Unit \ Assert =
        " 1 "
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.int())
            |> Assert.assertEq({expected = Ok(List#{1})})

    /// an invalid integer
    @Test
    def testInt_anInvalidInteger(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.int())
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.ExpectedInt("a")) :: Nil
                ))
            })

    /// multiple columns
    @Test
    def testInt_multipleColumns(): Unit \ Assert =
        "1,2"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.int())
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.ExpectedOneColumn(2)) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // float
    // ---------------------------------------------------------------------------

    /// a float shaped like an integer
    @Test
    def testFloat_aFloatShapedLikeAnInteger(): Unit \ Assert =
        "1"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.float())
            |> Assert.assertEq({expected = Ok(List#{1.0})})

    /// a float shaped like a floating-point number
    @Test
    def testFloat_aFloatShapedLikeAFloatingPointNumber(): Unit \ Assert =
        "3.14"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.float())
            |> Assert.assertEq({expected = Ok(List#{3.14})})

    /// a float with spaces around
    @Test
    def testFloat_aFloatWithSpacesAround(): Unit \ Assert =
        " 3.14 "
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.float())
            |> Assert.assertEq({expected = Ok(List#{3.14})})

    /// an invalid float
    @Test
    def testFloat_anInvalidFloat(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.float())
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.ExpectedFloat("a")) :: Nil
                ))
            })

    /// multiple columns
    @Test
    def testFloat_multipleColumns(): Unit \ Assert =
        "1,2"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.float())
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.ExpectedOneColumn(2)) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // blank
    // ---------------------------------------------------------------------------

    /// when the field is blank
    @Test
    def testBlank_whenTheFieldIsBlank(): Unit \ Assert =
        ""
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.blank(Decode.int()))
            |> Assert.assertEq({expected = Ok(Nil)})

    /// when the field contains spaces
    @Test
    def testBlank_whenTheFieldContainsSpaces(): Unit \ Assert =
        "  "
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.blank(Decode.int()))
            |> Assert.assertEq({expected = Ok(List#{None})})

    /// when the field contains whitespace characters
    @Test
    def testBlank_whenTheFieldContainsWhitespaceCharacters(): Unit \ Assert =
        "\" \t\n\""
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.blank(Decode.int()))
            |> Assert.assertEq({expected = Ok(List#{None})})

    /// when the field is non-blank but not valid for the decoder
    @Test
    def testBlank_whenTheFieldIsNonBlankButNotValid(): Unit \ Assert =
        "banana"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.blank(Decode.int()))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.ExpectedInt("banana")) :: Nil
                ))
            })

    /// when the field is non-blank and valid for the decoder
    @Test
    def testBlank_whenTheFieldIsNonBlankAndValid(): Unit \ Assert =
        "1"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.blank(Decode.int()))
            |> Assert.assertEq({expected = Ok(List#{Some(1)})})


    // ---------------------------------------------------------------------------
    // column
    // ---------------------------------------------------------------------------

    /// can get the only column
    @Test
    def testColumn_canGetTheOnlyColumn(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.column(0, Decode.string()))
            |> Assert.assertEq({expected = Ok(List#{"a"})})

    /// can get an arbitrary column
    @Test
    def testColumn_canGetAnArbitraryColumn(): Unit \ Assert =
        "a,b,c"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.column(1, Decode.string()))
            |> Assert.assertEq({expected = Ok(List#{"b"})})

    /// issues an error if the column doesn't exist
    @Test
    def testColumn_issuesAnErrorIfTheColumnDoesntExist(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.column(1, Decode.string()))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.Column(1), Problem.ColumnNotFound(1)) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // field
    // ---------------------------------------------------------------------------

    /// fails when no field names are provided or present
    @Test
    def testField_failsWhenNoFieldNamesAreProvidedOrPresent(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.field("Name", Decode.string()))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(DecodingError.FieldNotProvided("Name") :: Nil))
            })

    /// fails when the provided headers don't contain the name
    @Test
    def testField_failsWhenTheProvidedHeadersDontContainTheName(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.CustomFieldNames(Nil), Decode.field("Name", Decode.string()))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(DecodingError.FieldNotProvided("Name") :: Nil))
            })

    /// fails when the first row doesn't contain the name
    @Test
    def testField_failsWhenTheFirstRowDoesntContainTheName(): Unit \ Assert =
        "Blah\r\na"
            |> Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, Decode.field("Name", Decode.string()))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(DecodingError.FieldNotProvided("Name") :: Nil))
            })

    /// fails when there is no first row
    @Test
    def testField_failsWhenThereIsNoFirstRow(): Unit \ Assert =
        ""
            |> Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, Decode.field("Name", Decode.string()))
            |> Assert.assertEq({expected = Err(Error.NoFieldNamesOnFirstRow)})

    /// fails when name is not present in the first row
    @Test
    def testField_failsWhenNameIsNotPresentInTheFirstRow(): Unit \ Assert =
        "Bad\r\nAtlas"
            |> Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, Decode.field("Name", Decode.string()))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(DecodingError.FieldNotProvided("Name") :: Nil))
            })

    /// fails when the associated column is not present in the row
    @Test
    def testField_failsWhenTheAssociatedColumnIsNotPresentInTheRow(): Unit \ Assert =
        "Name,Other\r\nAtlas"
            |> Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, Decode.field("Other", Decode.string()))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(1, Column.Field("Other", Some(1)), Problem.FieldNotFound("Other")) :: Nil
                ))
            })

    /// retrieves the field from custom-provided fields
    @Test
    def testField_retrievesTheFieldFromCustomProvidedFields(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.CustomFieldNames("Name" :: Nil), Decode.field("Name", Decode.string()))
            |> Assert.assertEq({expected = Ok(List#{"a"})})

    /// uses the headers on the first row, if present
    @Test
    def testField_usesTheHeadersOnTheFirstRowIfPresent(): Unit \ Assert =
        "Name\r\nAtlas"
            |> Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, Decode.field("Name", Decode.string()))
            |> Assert.assertEq({expected = Ok(List#{"Atlas"})})

    /// uses the headers on the first row, trimmed
    @Test
    def testField_usesTheHeadersOnTheFirstRowTrimmed(): Unit \ Assert =
        " Name \r\nAtlas"
            |> Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, Decode.field("Name", Decode.string()))
            |> Assert.assertEq({expected = Ok(List#{"Atlas"})})

    /// fails with the right line number after getting field names from the first row
    @Test
    def testField_failsWithTheRightLineNumberAfterGettingFieldNamesFromTheFirstRow(): Unit \ Assert =
        "Number\r\nnot a number"
            |> Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, Decode.field("Number", Decode.int()))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(1, Column.Field("Number", Some(0)), Problem.ExpectedInt("not a number")) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // map functions
    // ---------------------------------------------------------------------------

    /// can map a single value
    @Test
    def testMap_canMapASingleValue(): Unit \ Assert =
        "5"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.column(0, Decode.int()) |> Decode.map(i -> i * 2))
            |> Assert.assertEq({expected = Ok(List#{10})})

    /// map2
    @Test
    def testMap_map2(): Unit \ Assert =
        "1,Atlas"
            |> Decode.decodeCsv(
                FieldNames.NoFieldNames,
                Decode.map2(
                    (a, b) -> (a, b),
                    Decode.column(0, Decode.int()),
                    Decode.column(1, Decode.string())
                )
            )
            |> Assert.assertEq({expected = Ok(List#{(1, "Atlas")})})

    /// map3
    @Test
    def testMap_map3(): Unit \ Assert =
        "1,Atlas,Cat"
            |> Decode.decodeCsv(
                FieldNames.NoFieldNames,
                Decode.map3(
                    (id, name, species) -> (id, name, species),
                    Decode.column(0, Decode.int()),
                    Decode.column(1, Decode.string()),
                    Decode.column(2, Decode.string())
                )
            )
            |> Assert.assertEq({expected = Ok(List#{(1, "Atlas", "Cat")})})


    // ---------------------------------------------------------------------------
    // oneOf
    // ---------------------------------------------------------------------------

    /// decodes a value
    @Test
    def testOneOf_decodesAValue(): Unit \ Assert =
        "1"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.oneOf(Decode.int(), Nil))
            |> Assert.assertEq({expected = Ok(List#{1})})

    /// uses a fallback
    @Test
    def testOneOf_usesAFallback(): Unit \ Assert =
        let decoder: Decoder[Option[Int32]] =
            Decode.oneOf(
                Decode.map(x -> Some(x), Decode.int()),
                Decode.succeed(None) :: Nil
            );
        "a"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, decoder)
            |> Assert.assertEq({expected = Ok(List#{None})})

    /// gives all the errors if all the decoders fail
    @Test
    def testOneOf_givesAllTheErrorsIfAllTheDecodersFail(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(
                FieldNames.NoFieldNames,
                Decode.oneOf(
                    (Decode.fail("ONE"): Decoder[Unit]),
                    Decode.fail("TWO") ::
                    Decode.fail("THREE") ::
                    Nil
                )
            )
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.OneOfDecodingError(0,
                        DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.Failure("ONE")) ::
                        DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.Failure("TWO")) ::
                        DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.Failure("THREE")) ::
                        Nil
                    ) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // succeed
    // ---------------------------------------------------------------------------

    /// ignores the values you send it in favor of the value you provide
    @Test
    def testSucceed_ignoresTheValues(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.succeed(()))
            |> Assert.assertEq({expected = Ok(List#{()})})

    /// provides one value for each row
    @Test
    def testSucceed_providesOneValueForEachRow(): Unit \ Assert =
        "a\r\nb"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.succeed(()))
            |> Assert.assertEq({expected = Ok(List#{(), ()})})


    // ---------------------------------------------------------------------------
    // fail
    // ---------------------------------------------------------------------------

    /// ignores the values you send it in favor of the value you provide
    @Test
    def testFail_ignoresTheValues(): Unit \ Assert =
        "a"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, (Decode.fail("a nice description"): Decoder[Unit]))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.Failure("a nice description")) :: Nil
                ))
            })

    /// fails on every row where it's attempted
    @Test
    def testFail_failsOnEveryRowWhereItsAttempted(): Unit \ Assert =
        "a\r\nb"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, (Decode.fail("a nice description"): Decoder[Unit]))
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.Failure("a nice description")) ::
                    DecodingError.FieldDecodingError(1, Column.OnlyColumn, Problem.Failure("a nice description")) ::
                    Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // andThen — for validation
    // ---------------------------------------------------------------------------

    def positiveInteger(): Decoder[Int32] =
        Decode.andThen(
            value ->
                if (value > 0)
                    Decode.succeed(value)
                else
                    Decode.fail("Only positive integers are allowed!"),
            Decode.int()
        )

    /// allows positive integers
    @Test
    def testAndThen_allowsPositiveIntegers(): Unit \ Assert =
        "1"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, positiveInteger())
            |> Assert.assertEq({expected = Ok(List#{1})})

    /// disallows negative integers
    @Test
    def testAndThen_disallowsNegativeIntegers(): Unit \ Assert =
        "-1"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, positiveInteger())
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.Failure("Only positive integers are allowed!")) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // andThen — for fields depending on each other
    // ---------------------------------------------------------------------------

    def followThePointer(): Decoder[String] =
        Decode.column(0, Decode.int())
            |> Decode.andThen(column -> Decode.column(column, Decode.string()))

    /// get the second column
    @Test
    def testAndThen_getTheSecondColumn(): Unit \ Assert =
        "1,a,b"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, followThePointer())
            |> Assert.assertEq({expected = Ok(List#{"a"})})

    /// get the third column
    @Test
    def testAndThen_getTheThirdColumn(): Unit \ Assert =
        "2,a,b"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, followThePointer())
            |> Assert.assertEq({expected = Ok(List#{"b"})})

    /// has a reasonable error message for missing a column
    @Test
    def testAndThen_hasAReasonableErrorMessageForMissingAColumn(): Unit \ Assert =
        "3,a,b"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, followThePointer())
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.Column(3), Problem.ColumnNotFound(3)) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // fromResult
    // ---------------------------------------------------------------------------

    def hex(): Decoder[Int32] =
        Decode.string()
            |> Decode.andThen(s -> Decode.fromResult(hexFromString(s)))

    /// succeeds when the function returns Ok
    @Test
    def testFromResult_succeedsWhenTheFunctionReturnsOk(): Unit \ Assert =
        "ff"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, hex())
            |> Assert.assertEq({expected = Ok(List#{255})})

    /// fails when the function returns Err
    @Test
    def testFromResult_failsWhenTheFunctionReturnsErr(): Unit \ Assert =
        "banana"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, hex())
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(
                        0,
                        Column.OnlyColumn,
                        Problem.Failure("\"banana\" is not a valid hexadecimal string because n is not a valid hexadecimal character.")
                    ) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // fromMaybe
    // ---------------------------------------------------------------------------

    def myInt(): Decoder[Int32] =
        Decode.string()
            |> Decode.andThen(s -> Decode.fromMaybe("Expected an int", Int32.fromString(s)))

    /// succeeds when the function returns Just
    @Test
    def testFromMaybe_succeedsWhenTheFunctionReturnsJust(): Unit \ Assert =
        "123"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, myInt())
            |> Assert.assertEq({expected = Ok(List#{123})})

    /// fails when the function returns Nothing
    @Test
    def testFromMaybe_failsWhenTheFunctionReturnsNothing(): Unit \ Assert =
        "banana"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, myInt())
            |> Assert.assertEq({expected =
                Err(Error.DecodingErrors(
                    DecodingError.FieldDecodingError(0, Column.OnlyColumn, Problem.Failure("Expected an int")) :: Nil
                ))
            })


    // ---------------------------------------------------------------------------
    // errorToString
    // ---------------------------------------------------------------------------

    /// groups simple errors
    @Test
    def testErrorToString_groupsSimpleErrors(): Unit \ Assert =
        "a\na\na"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.int())
            |> Result.mapErr(Decode.errorToString)
            |> Assert.assertEq({expected = Err("There was a problem on rows 0–2, column 0 (the only column present): I could not parse an int from `a`.")})

    /// groups simple errors in more complex settings - errors are sorted by row occurence
    @Test
    def testErrorToString_groupsSimpleErrorsInMoreComplexSettings(): Unit \ Assert =
        "a\na\nb\na\na"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.int())
            |> Result.mapErr(Decode.errorToString)
            |> Assert.assertEq({expected = Err("I saw 3 problems while decoding this CSV:\n\nThere was a problem on rows 0 and 1, column 0 (the only column present): I could not parse an int from `a`.\n\nThere was a problem on row 2, column 0 (the only column present): I could not parse an int from `b`.\n\nThere was a problem on rows 3 and 4, column 0 (the only column present): I could not parse an int from `a`.")})

    /// works with map2
    @Test
    def testErrorToString_worksWithMap2(): Unit \ Assert =
        "foo,bar\na,2\na,b\na,c"
            |> Decode.decodeCsv(
                FieldNames.FieldNamesFromFirstRow,
                Decode.map2(
                    (a, b) -> (a, b),
                    Decode.field("foo", Decode.int()),
                    Decode.field("bar", Decode.int())
                )
            )
            |> Result.mapErr(Decode.errorToString)
            |> Assert.assertEq({expected = Err("I saw 3 problems while decoding this CSV:\n\nThere was a problem on rows 1–3, in the `foo` field (column 0): I could not parse an int from `a`.\n\nThere was a problem on row 2, in the `bar` field (column 1): I could not parse an int from `b`.\n\nThere was a problem on row 3, in the `bar` field (column 1): I could not parse an int from `c`.")})

    /// works with oneOf
    @Test
    def testErrorToString_worksWithOneOf(): Unit \ Assert =
        "a\n1\n1.2"
            |> Decode.decodeCsv(
                FieldNames.NoFieldNames,
                Decode.oneOf(
                    Decode.map(Int32.toFloat64, Decode.int()),
                    Decode.float() :: Nil
                )
            )
            |> Result.mapErr(Decode.errorToString)
            |> Assert.assertEq({expected = Err("There was a problem on row 0 - all of the following decoders failed, but at least one must succeed:\n  (1) column 0 (the only column present): I could not parse an int from `a`.\n  (2) column 0 (the only column present): I could not parse a float from `a`.")})

    /// works with nested oneOf
    @Test
    def testErrorToString_worksWithNestedOneOf(): Unit \ Assert =
        "a\n1\n1.2"
            |> Decode.decodeCsv(
                FieldNames.NoFieldNames,
                Decode.oneOf(
                    Decode.float(),
                    Decode.oneOf(
                        Decode.map(Int32.toFloat64, Decode.int()),
                        Decode.float() :: Nil
                    ) :: Nil
                )
            )
            |> Result.mapErr(Decode.errorToString)
            |> Assert.assertEq({expected = Err("There was a problem on row 0 - all of the following decoders failed, but at least one must succeed:\n  (1) column 0 (the only column present): I could not parse a float from `a`.\n  (2) column 0 (the only column present): I could not parse an int from `a`.\n  (3) column 0 (the only column present): I could not parse a float from `a`.")})

    /// works with complex decoder
    @Test
    def testErrorToString_worksWithComplexDecoder(): Unit \ Assert =
        "foo,bar\na,2\na,b\na,c"
            |> Decode.decodeCsv(
                FieldNames.FieldNamesFromFirstRow,
                Decode.map2(
                    (a, b) -> (a, b),
                    Decode.oneOf(
                        Decode.field("foo", Decode.int()),
                        Decode.field("bar", Decode.map(round, Decode.float())) :: Nil
                    ),
                    Decode.field("bar", Decode.int())
                )
            )
            |> Result.mapErr(Decode.errorToString)
            |> Assert.assertEq({expected = Err("I saw 4 problems while decoding this CSV:\n\nThere was a problem on row 2, in the `bar` field (column 1): I could not parse an int from `b`.\n\nThere was a problem on row 2 - all of the following decoders failed, but at least one must succeed:\n  (1) in the `foo` field (column 0): I could not parse an int from `a`.\n  (2) in the `bar` field (column 1): I could not parse a float from `b`.\n\nThere was a problem on row 3, in the `bar` field (column 1): I could not parse an int from `c`.\n\nThere was a problem on row 3 - all of the following decoders failed, but at least one must succeed:\n  (1) in the `foo` field (column 0): I could not parse an int from `a`.\n  (2) in the `bar` field (column 1): I could not parse a float from `c`.")})


    // ---------------------------------------------------------------------------
    // availableFields
    // ---------------------------------------------------------------------------

    /// returns header row in order
    @Test
    def testAvailableFields_returnsHeaderRowInOrder(): Unit \ Assert =
        "foo,bar\na,a\na,b\na,c"
            |> Decode.decodeCsv(FieldNames.FieldNamesFromFirstRow, Decode.availableFields())
            |> Assert.assertEq({expected = Ok(List#{
                List#{"foo", "bar"},
                List#{"foo", "bar"},
                List#{"foo", "bar"}
            })})

    /// allows conditional decoding based on header row
    @Test
    def testAvailableFields_allowsConditionalDecodingBasedOnHeaderRow(): Unit \ Assert =
        "foo,bar\na,a\na,b\na,c"
            |> Decode.decodeCsv(
                FieldNames.FieldNamesFromFirstRow,
                Decode.availableFields()
                    |> Decode.andThen(
                        headers ->
                            if (List.memberOf("bar", headers))
                                Decode.field("bar", Decode.string())
                            else
                                Decode.field("foo", Decode.string())
                    )
            )
            |> Assert.assertEq({expected = Ok(List#{"a", "b", "c"})})

    /// returns configured fields
    @Test
    def testAvailableFields_returnsConfiguredFields(): Unit \ Assert =
        "\n"
            |> Decode.decodeCsv(
                FieldNames.CustomFieldNames("Foo" :: "Bar" :: Nil),
                Decode.availableFields()
            )
            |> Assert.assertEq({expected = Ok(List#{List#{"Foo", "Bar"}})})

    /// fails when no named fields
    @Test
    def testAvailableFields_failsWhenNoNamedFields(): Unit \ Assert =
        "\n"
            |> Decode.decodeCsv(FieldNames.NoFieldNames, Decode.availableFields())
            |> Result.mapErr(Decode.errorToString)
            |> Assert.assertEq({expected = Err("Asked for available fields, but none were provided")})

}
