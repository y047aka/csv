/*
 * Copyright 2021 Brian Hicks
 *
 * The Flix port of `Csv/Parser.elm` of BrianHicks/elm-csv 4.0.1, which is BSD-3-Clause.
 * The upstream notice is kept in full at LICENSE.elm-csv, as its first condition requires
 * the copyright notice to be retained in redistributed source.
 */

/// CSV parser modelled after BrianHicks/elm-csv's `Csv.Parser`.
/// Function names and call structure mirror the elm-csv 4.0.1
/// source so the two implementations can be reviewed side by side.
pub mod Csv.Parser {

    /// Something went wrong during parsing! What was it?
    ///
    /// - `SourceEndedWithoutClosingQuote`: we started parsing a quoted field,
    ///   but the file ended before we saw a closing quote. If you meant to have
    ///   a literal quote in your data, quote the whole field and then escape the
    ///   literal quote by replacing it with `""`. For example, `": double prime`
    ///   would be encoded as `""": double prime"`.
    /// - `AdditionalCharactersAfterClosingQuote`: we found the closing pair of a
    ///   quoted field, but there was data after it but before a separator or the
    ///   end of the file. Follow the quote-escaping advice above to get around this.
    pub enum Problem with Eq, ToString {
        case SourceEndedWithoutClosingQuote(Int32)
        case AdditionalCharactersAfterClosingQuote(Int32)
    }

    /// Turn a CSV string into a list of rows.
    pub def parse(config: {fieldSeparator = Char}, source: String): Result[Problem, List[List[String]]] =
        if (String.isEmpty(source))
            Ok(Nil)
        else
            let finalLength = String.length(source);
            if (config#fieldSeparator == ',')
                parseComma(source, finalLength, Nil, Nil, 0, 0)
            else if (config#fieldSeparator == ';')
                parseSemicolon(source, finalLength, Nil, Nil, 0, 0)
            else
                parseHelp(c -> c == config#fieldSeparator, source, finalLength, Nil, Nil, 0, 0)

    def parseQuotedField(
        isFieldSeparator: Char -> Bool,
        source: String,
        finalLength: Int32,
        soFar: String,
        startOffset: Int32,
        endOffset: Int32
    ): Result[Int32 -> Problem, (String, Int32, Bool)] =
        if (endOffset >= finalLength)
            Err(n -> Problem.SourceEndedWithoutClosingQuote(n))
        else if (String.charAt(endOffset, source) == '"')
            let segment = String.slice({start = startOffset}, {end = endOffset}, source);
            if (endOffset + 1 >= finalLength)
                Ok((soFar + segment, endOffset + 1, false))
            else
                let next = String.charAt(endOffset + 1, source);
                if (next == '"')
                    // "" is a quoted ". Unescape it and keep going.
                    let newPos = endOffset + 2;
                    parseQuotedField(isFieldSeparator, source, finalLength, soFar + segment + "\"", newPos, newPos)
                else if (isFieldSeparator(next))
                    Ok((soFar + segment, endOffset + 2, false))
                else if (next == '\n')
                    Ok((soFar + segment, endOffset + 2, true))
                else if (next == '\r' and endOffset + 2 < finalLength and String.charAt(endOffset + 2, source) == '\n')
                    Ok((soFar + segment, endOffset + 3, true))
                else
                    Err(n -> Problem.AdditionalCharactersAfterClosingQuote(n))
        else
            parseQuotedField(isFieldSeparator, source, finalLength, soFar, startOffset, endOffset + 1)

    def parseHelp(
        isFieldSeparator: Char -> Bool,
        source: String,
        finalLength: Int32,
        row: List[String],
        rows: List[List[String]],
        startOffset: Int32,
        endOffset: Int32
    ): Result[Problem, List[List[String]]] =
        if (endOffset >= finalLength)
            let finalField = String.slice({start = startOffset}, {end = endOffset}, source);
            if (finalField == "" and row == Nil)
                Ok(List.reverse(rows))
            else
                Ok(List.reverse(List.reverse(finalField :: row) :: rows))
        else
            let first = String.charAt(endOffset, source);
            if (isFieldSeparator(first))
                let newPos = endOffset + 1;
                parseHelp(isFieldSeparator, source, finalLength, String.slice({start = startOffset}, {end = endOffset}, source) :: row, rows, newPos, newPos)
            else if (first == '\n')
                let newPos = endOffset + 1;
                parseHelp(isFieldSeparator, source, finalLength, Nil, List.reverse(String.slice({start = startOffset}, {end = endOffset}, source) :: row) :: rows, newPos, newPos)
            else if (first == '\r' and endOffset + 1 < finalLength and String.charAt(endOffset + 1, source) == '\n')
                let newPos = endOffset + 2;
                parseHelp(isFieldSeparator, source, finalLength, Nil, List.reverse(String.slice({start = startOffset}, {end = endOffset}, source) :: row) :: rows, newPos, newPos)
            else if (first == '"')
                let newPos = endOffset + 1;
                match parseQuotedField(isFieldSeparator, source, finalLength, "", newPos, newPos) {
                    case Ok((value, afterQuotedField, rowEnded)) =>
                        if (afterQuotedField >= finalLength)
                            Ok(List.reverse(List.reverse(value :: row) :: rows))
                        else if (rowEnded)
                            parseHelp(isFieldSeparator, source, finalLength, Nil, List.reverse(value :: row) :: rows, afterQuotedField, afterQuotedField)
                        else
                            parseHelp(isFieldSeparator, source, finalLength, value :: row, rows, afterQuotedField, afterQuotedField)
                    case Err(problem) =>
                        Err(problem(List.length(rows) + 1))
                }
            else
                parseHelp(isFieldSeparator, source, finalLength, row, rows, startOffset, endOffset + 1)

    /// `parseComma` and `parseSemicolon` are specialised copies of
    /// `parseHelp` for the two most common CSV separators. In the
    /// original Elm source this duplication exists so the compiler
    /// emits literal `===` comparisons in the generated JavaScript.
    /// On the JVM that codegen rationale does not apply, but the
    /// duplication is kept here for parity with the original.
    def parseComma(
        source: String,
        finalLength: Int32,
        row: List[String],
        rows: List[List[String]],
        startOffset: Int32,
        endOffset: Int32
    ): Result[Problem, List[List[String]]] =
        if (endOffset >= finalLength)
            let finalField = String.slice({start = startOffset}, {end = endOffset}, source);
            if (finalField == "" and row == Nil)
                Ok(List.reverse(rows))
            else
                Ok(List.reverse(List.reverse(finalField :: row) :: rows))
        else
            let first = String.charAt(endOffset, source);
            if (first == ',')
                let newPos = endOffset + 1;
                parseComma(source, finalLength, String.slice({start = startOffset}, {end = endOffset}, source) :: row, rows, newPos, newPos)
            else if (first == '\n')
                let newPos = endOffset + 1;
                parseComma(source, finalLength, Nil, List.reverse(String.slice({start = startOffset}, {end = endOffset}, source) :: row) :: rows, newPos, newPos)
            else if (first == '\r' and endOffset + 1 < finalLength and String.charAt(endOffset + 1, source) == '\n')
                let newPos = endOffset + 2;
                parseComma(source, finalLength, Nil, List.reverse(String.slice({start = startOffset}, {end = endOffset}, source) :: row) :: rows, newPos, newPos)
            else if (first == '"')
                let newPos = endOffset + 1;
                match parseQuotedField(c -> c == ',', source, finalLength, "", newPos, newPos) {
                    case Ok((value, afterQuotedField, rowEnded)) =>
                        if (afterQuotedField >= finalLength)
                            Ok(List.reverse(List.reverse(value :: row) :: rows))
                        else if (rowEnded)
                            parseComma(source, finalLength, Nil, List.reverse(value :: row) :: rows, afterQuotedField, afterQuotedField)
                        else
                            parseComma(source, finalLength, value :: row, rows, afterQuotedField, afterQuotedField)
                    case Err(problem) =>
                        Err(problem(List.length(rows) + 1))
                }
            else
                parseComma(source, finalLength, row, rows, startOffset, endOffset + 1)

    def parseSemicolon(
        source: String,
        finalLength: Int32,
        row: List[String],
        rows: List[List[String]],
        startOffset: Int32,
        endOffset: Int32
    ): Result[Problem, List[List[String]]] =
        if (endOffset >= finalLength)
            let finalField = String.slice({start = startOffset}, {end = endOffset}, source);
            if (finalField == "" and row == Nil)
                Ok(List.reverse(rows))
            else
                Ok(List.reverse(List.reverse(finalField :: row) :: rows))
        else
            let first = String.charAt(endOffset, source);
            if (first == ';')
                let newPos = endOffset + 1;
                parseSemicolon(source, finalLength, String.slice({start = startOffset}, {end = endOffset}, source) :: row, rows, newPos, newPos)
            else if (first == '\n')
                let newPos = endOffset + 1;
                parseSemicolon(source, finalLength, Nil, List.reverse(String.slice({start = startOffset}, {end = endOffset}, source) :: row) :: rows, newPos, newPos)
            else if (first == '\r' and endOffset + 1 < finalLength and String.charAt(endOffset + 1, source) == '\n')
                let newPos = endOffset + 2;
                parseSemicolon(source, finalLength, Nil, List.reverse(String.slice({start = startOffset}, {end = endOffset}, source) :: row) :: rows, newPos, newPos)
            else if (first == '"')
                let newPos = endOffset + 1;
                match parseQuotedField(c -> c == ';', source, finalLength, "", newPos, newPos) {
                    case Ok((value, afterQuotedField, rowEnded)) =>
                        if (afterQuotedField >= finalLength)
                            Ok(List.reverse(List.reverse(value :: row) :: rows))
                        else if (rowEnded)
                            parseSemicolon(source, finalLength, Nil, List.reverse(value :: row) :: rows, afterQuotedField, afterQuotedField)
                        else
                            parseSemicolon(source, finalLength, value :: row, rows, afterQuotedField, afterQuotedField)
                    case Err(problem) =>
                        Err(problem(List.length(rows) + 1))
                }
            else
                parseSemicolon(source, finalLength, row, rows, startOffset, endOffset + 1)

}
