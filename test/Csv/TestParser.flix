/*
 * Copyright 2021 Brian Hicks
 *
 * Ported from `tests/Csv/ParserTest.elm` of BrianHicks/elm-csv 4.0.1, as the rest of this
 * repository under the BSD-3-Clause conditions at LICENSE.
 */

pub mod Csv.TestParser {

    use Csv.Parser
    use Csv.Parser.Problem

    // ---------------------------------------------------------------------------
    // Configurations
    // ---------------------------------------------------------------------------

    def configurations(): List[{rowSeparator = String, fieldSeparator = Char}] =
        List#{
            { rowSeparator = "\r\n", fieldSeparator = ',' },  // CRLF CSV (US locale)
            { rowSeparator = "\r\n", fieldSeparator = ';' },  // CRLF CSV (EU locale, semicolon)
            { rowSeparator = "\n",   fieldSeparator = ',' },  // LF-only CSV
            { rowSeparator = "\r\n", fieldSeparator = '\t' }, // CRLF TSV
            { rowSeparator = "\n",   fieldSeparator = '\t' }  // LF-only TSV
        }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    def encode(config: {rowSeparator = String, fieldSeparator = Char}, rows: List[List[String]]): String =
        let sep = Char.toString(config#fieldSeparator);
        rows
            |> List.map(row -> joinWith(sep, row))
            |> joinWith(config#rowSeparator)

    def joinWith(sep: String, strs: List[String]): String =
        match strs {
            case Nil       => ""
            case x :: rest => List.foldLeft((acc, s) -> acc + sep + s, x, rest)
        }

    def expectRoundTrip(config: {rowSeparator = String, fieldSeparator = Char}, rows: List[List[String]]): Unit \ Assert =
        encode(config, rows)
            |> Parser.parse({fieldSeparator = config#fieldSeparator})
            |> Assert.assertEq({expected = Ok(rows)})

    // ---------------------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------------------

    @Test
    def testSingleValue(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                expectRoundTrip(config, List#{List#{"a"}}))

    @Test
    def testTwoFields(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                expectRoundTrip(config, List#{List#{"a", "b"}}))

    @Test
    def testTwoRows(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                expectRoundTrip(config, List#{List#{"a"}, List#{"b"}}))

    @Test
    def testTwoRowsOfTwoFields(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                expectRoundTrip(config, List#{List#{"a", "b"}, List#{"c", "d"}}))

    @Test
    def testBlankFields(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                expectRoundTrip(config, List#{List#{"", "", ""}}))

    @Test
    def testOnlyHalfOfRowSeparator(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                if (String.length(config#rowSeparator) <= 1)
                    // not relevant here
                    ()
                else {
                    let first = Char.toString(String.charAt(0, config#rowSeparator));
                    first
                        |> Parser.parse({fieldSeparator = config#fieldSeparator})
                        |> Assert.assertEq({expected = Ok(List#{List#{first}})})
                })

    // quoted values

    @Test
    def testQuotedSingleValues(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                "\"a\""
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Ok(List#{List#{"a"}})}))

    @Test
    def testQuotedRowSeparators(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                ("\"" + config#rowSeparator + "\"")
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Ok(List#{List#{config#rowSeparator}})}))

    @Test
    def testQuotedFieldSeparators(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                let sep = Char.toString(config#fieldSeparator);
                ("\"" + sep + "\"")
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Ok(List#{List#{sep}})}))

    @Test
    def testQuotedQuotes(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                "\"\"\"\""
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Ok(List#{List#{"\""}})}))

    @Test
    def testTwoQuotedValuesInARow(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                let sep = Char.toString(config#fieldSeparator);
                ("\"a\"" + sep + "\"b\"")
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Ok(List#{List#{"a", "b"}})}))

    @Test
    def testTwoRowsWithQuotedValues(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                ("\"a\"" + config#rowSeparator + "\"b\"")
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Ok(List#{List#{"a"}, List#{"b"}})}))

    @Test
    def testTrailingNewlineShouldBeIgnored(): Unit \ Assert =
        // https://github.com/BrianHicks/elm-csv/issues/8
        configurations()
            |> List.forEach(config ->
                let rows = List#{
                    List#{"Country", "Population"},
                    List#{"Agentina", "44361150"},
                    List#{"Brazil",  "212652000"}
                };
                (encode(config, rows) + config#rowSeparator)
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Ok(rows)}))

    @Test
    def testTrailingNewlineAfterQuotedFieldShouldBeIgnored(): Unit \ Assert =
        // https://github.com/BrianHicks/elm-csv/issues/24
        configurations()
            |> List.forEach(config ->
                ("\"val\"" + config#rowSeparator)
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Ok(List#{List#{"val"}})}))

    // errors

    @Test
    def testNotEndingAQuotedValueIsAnError(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                "\"a"
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Err(Problem.SourceEndedWithoutClosingQuote(1))}))

    @Test
    def testAdditionalCharactersAfterClosingQuoteBeforeFieldSeparatorIsAnError(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                ("\"a\"b" + config#rowSeparator)
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Err(Problem.AdditionalCharactersAfterClosingQuote(1))}))

    @Test
    def testAdditionalCharactersAfterClosingQuoteBeforeRowSeparatorIsAnError(): Unit \ Assert =
        configurations()
            |> List.forEach(config ->
                ("\"a\"b" + Char.toString(config#fieldSeparator))
                    |> Parser.parse({fieldSeparator = config#fieldSeparator})
                    |> Assert.assertEq({expected = Err(Problem.AdditionalCharactersAfterClosingQuote(1))}))

}
