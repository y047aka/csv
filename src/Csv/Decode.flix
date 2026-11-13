/*
 * Copyright 2021 Brian Hicks
 *
 * The Flix port of `Csv/Decode.elm` of BrianHicks/elm-csv 4.0.1, and the whole of this
 * repository, is BSD-3-Clause; the conditions are at LICENSE, whose first one asks the
 * redistributed source to retain this notice.
 */

/// Type-safe CSV decoders, modelled after BrianHicks/elm-csv's
/// `Csv.Decode` module. Converts a parsed CSV row (a `List[String]`)
/// into a value of an arbitrary type via a small combinator language.
///
/// Declaration order mirrors the original `Csv.Decode` Elm module
/// (BASIC DECODERS / LOCATIONS / RUN DECODERS / MAPPING / FANCY
/// DECODING) so the two implementations can be reviewed side by side.
pub mod Csv.Decode {

    use Csv.Parser

    ///
    /// ===== BASIC DECODERS =====
    ///

    pub enum Decoder[a] {
        case Decoder((Location, ResolvedNames, Int32, List[String]) -> Result[List[DecodingError], a])
    }

    type alias ResolvedNames = {
        names     = Map[String, Int32],
        available = Bool
    }

    def fromString(convert: String -> Result[Problem, a]): Decoder[a] =
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            let error = problem ->
                Err(DecodingError.FieldDecodingError(rowNum, locationToColumn(fieldNames#names, location), problem) :: Nil);
            match location {
                case Location.Column_(colNum) =>
                    match List.drop(colNum, row) {
                        case value :: _ =>
                            match convert(value) {
                                case Ok(converted) => Ok(converted)
                                case Err(problem)  => error(problem)
                            }
                        case Nil => error(Problem.ColumnNotFound(colNum))
                    }
                case Location.Field_(name) =>
                    match Map.get(name, fieldNames#names) {
                        case Some(colNum) =>
                            match List.drop(colNum, row) {
                                case value :: _ =>
                                    match convert(value) {
                                        case Ok(converted) => Ok(converted)
                                        case Err(problem)  => error(problem)
                                    }
                                case Nil => error(Problem.FieldNotFound(name))
                            }
                        case None => Err(DecodingError.FieldNotProvided(name) :: Nil)
                    }
                case Location.OnlyColumn_ =>
                    match row {
                        case Nil       => error(Problem.ColumnNotFound(0))
                        case only :: Nil =>
                            match convert(only) {
                                case Ok(converted) => Ok(converted)
                                case Err(problem)  => error(problem)
                            }
                        case _ => error(Problem.ExpectedOneColumn(List.length(row)))
                    }
            }
        )

    pub def string(): Decoder[String] =
        fromString(s -> Ok(s))

    pub def int(): Decoder[Int32] =
        fromString(value ->
            match Int32.fromString(String.trim(value)) {
                case Some(parsed) => Ok(parsed)
                case None         => Err(Problem.ExpectedInt(value))
            }
        )

    pub def float(): Decoder[Float64] =
        fromString(value ->
            match Float64.fromString(String.trim(value)) {
                case Some(parsed) => Ok(parsed)
                case None         => Err(Problem.ExpectedFloat(value))
            }
        )

    /// Handle blank fields by turning them into `Option`s. A field is blank if
    /// it is empty or consists solely of whitespace characters.
    pub def blank(decoder: Decoder[a]): Decoder[Option[a]] =
        andThen(
            maybeBlank ->
                let isUnicodeWhitespace = c -> {
                    let cp = Char.toBmpCodePoint(c);
                    Char.isWhitespace(c)
                        or cp == 0x00A0
                        or cp == 0x2007
                        or cp == 0x202F
                        or cp == 0x1680
                        or (cp >= 0x2000 and cp <= 0x200A)
                        or cp == 0x2028
                        or cp == 0x2029
                        or cp == 0x205F
                        or cp == 0x3000
                };
                if (List.forAll(isUnicodeWhitespace, String.toList(maybeBlank)))
                    succeed(None)
                else
                    map(Some, decoder),
            string()
        )

    ///
    /// ===== LOCATIONS =====
    ///

    enum Location {
        case Column_(Int32)
        case Field_(String)
        case OnlyColumn_
    }

    /// Parse a value at a numbered column, starting from 0.
    pub def column(col: Int32, decoder: Decoder[a]): Decoder[a] =
        let Decoder.Decoder(decode) = decoder;
        Decoder.Decoder((_, fieldNames, rowNum, row) -> decode(Location.Column_(col), fieldNames, rowNum, row))

    /// Like `column`, but succeeds even if the column is missing.
    pub def optionalColumn(col: Int32, decoder: Decoder[a]): Decoder[Option[a]] =
        let Decoder.Decoder(decode) = decoder;
        Decoder.Decoder((_, fieldNames, rowNum, row) ->
            if (col < List.length(row))
                Result.map(Some, decode(Location.Column_(col), fieldNames, rowNum, row))
            else
                Ok(None)
        )

    /// Parse a value at a named column.
    pub def field(name: String, decoder: Decoder[a]): Decoder[a] =
        let Decoder.Decoder(decode) = decoder;
        Decoder.Decoder((_, fieldNames, rowNum, row) -> decode(Location.Field_(name), fieldNames, rowNum, row))

    /// Like `field`, but succeeds even if the column is missing.
    pub def optionalField(name: String, decoder: Decoder[a]): Decoder[Option[a]] =
        let Decoder.Decoder(decode) = decoder;
        Decoder.Decoder((_, fieldNames, rowNum, row) ->
            match Map.get(name, fieldNames#names) {
                case Some(_) => Result.map(Some, decode(Location.Field_(name), fieldNames, rowNum, row))
                case None    => Ok(None)
            }
        )

    /// Returns all available field names. The behavior depends on your configuration:
    ///
    ///   - `NoFieldNames`: The decoder fails.
    ///   - `CustomFieldNames`: Decodes to the provided list.
    ///   - `FieldNamesFromFirstRow`: Returns the first row of the CSV.
    pub def availableFields(): Decoder[List[String]] =
        Decoder.Decoder((_, fieldNames, _, _) ->
            if (fieldNames#available)
                Ok(
                    Map.toList(fieldNames#names)
                        |> List.sortBy(match (_, v) -> v)
                        |> List.map(match (k, _) -> k)
                )
            else
                Err(DecodingError.NoFieldNamesProvided :: Nil)
        )

    ///
    /// ===== RUN DECODERS =====
    ///

    /// Where do we get names for use with `field`?
    ///
    ///   - `NoFieldNames`: don't get field names at all. `field` will always fail.
    ///   - `CustomFieldNames`: use the provided field names in order.
    ///   - `FieldNamesFromFirstRow`: use the first row of the CSV as field names.
    pub enum FieldNames {
        case NoFieldNames
        case CustomFieldNames(List[String])
        case FieldNamesFromFirstRow
    }

    def getFieldNames(headers: FieldNames, rows: List[List[String]]): Result[Error, (ResolvedNames, Int32, List[List[String]])] =
        def fromList(names) =
            List.foldLeft(
                (acc, name) -> { let (soFar, i) = acc; (Map.insert(name, i, soFar), i + 1) },
                (Map.empty(), 0),
                names
            ) |> fst;
        match headers {
            case FieldNames.NoFieldNames =>
                Ok(({names = Map.empty(), available = false}, 0, rows))
            case FieldNames.CustomFieldNames(names) =>
                Ok(({names = fromList(names), available = true}, 0, rows))
            case FieldNames.FieldNamesFromFirstRow =>
                match rows {
                    case Nil =>
                        Err(Error.NoFieldNamesOnFirstRow)
                    case first :: rest =>
                        Ok(({names = fromList(List.map(String.trim, first)), available = true}, 1, rest))
                }
        }

    /// Decode every row of a CSV string.
    pub def decodeCsv(fieldNames: FieldNames, decoder: Decoder[a], source: String): Result[Error, List[a]] =
        decodeCustom({fieldSeparator = ','}, fieldNames, decoder, source)

    /// Convert something shaped roughly like a CSV (e.g. TSV with `fieldSeparator = '\t'`).
    pub def decodeCustom(config: {fieldSeparator = Char}, fieldNames: FieldNames, decoder: Decoder[a], source: String): Result[Error, List[a]] =
        Parser.parse(config, source)
            |> Result.mapErr(p -> Error.ParsingError(p))
            |> Result.flatMap(applyDecoder(fieldNames, decoder))

    def applyDecoder(fieldNames: FieldNames, decoder: Decoder[a], allRows: List[List[String]]): Result[Error, List[a]] =
        let Decoder.Decoder(decode) = decoder;
        let defaultLocation = Location.OnlyColumn_;
        Result.flatMap(
            t -> match t {
                case (resolvedNames, firstRowNumber, rows) =>
                    let (result, _) = List.foldLeft(
                        (acc, row) -> {
                            let (soFar, rowNum) = acc;
                            let newSoFar = match decode(defaultLocation, resolvedNames, rowNum, row) {
                                case Ok(val) =>
                                    match soFar {
                                        case Ok(values) => Ok(val :: values)
                                        case Err(errs)  => Err(errs)
                                    }
                                case Err(err) =>
                                    match soFar {
                                        case Ok(_)     => Err(err :: Nil)
                                        case Err(errs) => Err(err :: errs)
                                    }
                            };
                            (newSoFar, rowNum + 1)
                        },
                        (Ok(Nil), firstRowNumber),
                        rows
                    );
                    result
                        |> Result.map(List.reverse)
                        |> Result.mapErr(errs -> Error.DecodingErrors(List.flatten(List.reverse(errs))))
            },
            getFieldNames(fieldNames, allRows)
        )

    /// Errors that can occur while decoding a CSV.
    ///
    ///   - `ParsingError`: a problem parsing the CSV into rows and columns (quoting issues).
    ///   - `NoFieldNamesOnFirstRow`: tried to get field names from the first row but found none.
    ///   - `DecodingErrors`: one or more rows failed to decode.
    pub enum Error with Eq, ToString {
        case ParsingError(Csv.Parser.Problem)
        case NoFieldNamesOnFirstRow
        case DecodingErrors(List[DecodingError])
    }

    /// Errors when decoding a single row.
    ///
    ///   - `FieldDecodingError(row, column, problem)`: a specific field failed.
    ///   - `OneOfDecodingError(row, errors)`: all branches of `oneOf` failed.
    ///   - `FieldNotProvided(name)`: the named column was not in the header.
    ///   - `NoFieldNamesProvided`: `availableFields` used with `NoFieldNames`.
    pub enum DecodingError with Eq, ToString {
        case FieldDecodingError(Int32, Column, Problem)
        case OneOfDecodingError(Int32, List[DecodingError])
        case FieldNotProvided(String)
        case NoFieldNamesProvided
    }

    /// Where did the problem happen?
    ///
    ///   - `Column(n)`: at the given column number.
    ///   - `Field(name, maybeCol)`: at the given named column (with optional column number).
    ///   - `OnlyColumn`: at the only column in the row.
    pub enum Column with Eq, ToString {
        case Column(Int32)
        case Field(String, Option[Int32])
        case OnlyColumn
    }

    def locationToColumn(fieldNames: Map[String, Int32], location: Location): Column =
        match location {
            case Location.Column_(i)   => Column.Column(i)
            case Location.Field_(name) => Column.Field(name, Map.get(name, fieldNames))
            case Location.OnlyColumn_  => Column.OnlyColumn
        }

    /// Things that can go wrong while decoding.
    ///
    ///   - `ColumnNotFound(n)`: column `n` does not exist.
    ///   - `FieldNotFound(name)`: column `name` exists in headers but not in this row.
    ///   - `ExpectedOneColumn(n)`: basic decoders need exactly one column; found `n`.
    ///   - `ExpectedInt(s)` / `ExpectedFloat(s)`: failed to parse a number.
    ///   - `Failure(msg)`: custom failure from `fail`.
    pub enum Problem with Eq, ToString {
        case ColumnNotFound(Int32)
        case FieldNotFound(String)
        case ExpectedOneColumn(Int32)
        case ExpectedInt(String)
        case ExpectedFloat(String)
        case Failure(String)
    }

    pub def errorToString(error: Error): String =
        match error {
            case Error.ParsingError(Csv.Parser.Problem.SourceEndedWithoutClosingQuote(row)) =>
                "The source ended on row ${row} in a quoted field without a closing quote."
            case Error.ParsingError(Csv.Parser.Problem.AdditionalCharactersAfterClosingQuote(row)) =>
                "On row ${row} in the source, there were additional characters in a field after a closing quote."
            case Error.NoFieldNamesOnFirstRow =>
                "I expected to see field names on the first row, but there were none."
            case Error.DecodingErrors(errs) =>
                def problemString(problem) = match problem {
                    case Problem.ColumnNotFound(i)        => "I couldn't find column #${i}."
                    case Problem.FieldNotFound(name)      => "I couldn't find the `${name}` column."
                    case Problem.ExpectedOneColumn(n)     => "I expected exactly one column, but there were ${n}."
                    case Problem.ExpectedInt(notInt)      => "I could not parse an int from `${notInt}`."
                    case Problem.ExpectedFloat(notFloat)  => "I could not parse a float from `${notFloat}`."
                    case Problem.Failure(custom)          => custom
                };
                def columnString(col) = match col {
                    case Column.Column(c)            => "column ${c}"
                    case Column.Field(name, None)    => "in the `${name}` field"
                    case Column.Field(name, Some(c)) => "in the `${name}` field (column ${c})"
                    case Column.OnlyColumn           => "column 0 (the only column present)"
                };
                def rowString(startRow, endRow) = match endRow - startRow {
                    case 0 => "row ${startRow}"
                    case 1 => "rows ${startRow} and ${endRow}"
                    case _ => "rows ${startRow}–${endRow}"
                };
                def errString(err) = match err {
                    case DecodingError.FieldDecodingError(_, col, problem) =>
                        columnString(col) + ": " + problemString(problem)
                    case DecodingError.OneOfDecodingError(_, oodes) =>
                        "all of the following decoders failed, but at least one must succeed:\n"
                            + List.join("\n",
                                List.mapWithIndex(
                                    (i, e) -> "  (${i + 1}) " + errString(e),
                                    oodes
                                )
                              )
                    case DecodingError.FieldNotProvided(name) =>
                        "field ${name} was not provided"
                    case DecodingError.NoFieldNamesProvided =>
                        "Asked for available fields, but none were provided"
                };
                def topLevelErrString(startRow, endRow, err) =
                    (match err {
                        case DecodingError.FieldDecodingError(_, _, _) =>
                            "There was a problem on " + rowString(startRow, endRow) + ", "
                        case DecodingError.OneOfDecodingError(_, _) =>
                            "There was a problem on " + rowString(startRow, endRow) + " - "
                        case DecodingError.FieldNotProvided(_) =>
                            "There was a problem in the header: "
                        case DecodingError.NoFieldNamesProvided =>
                            ""
                    }) + errString(err);
                def isContiguous(errA, errB) = match (errA, errB) {
                    case (DecodingError.FieldDecodingError(aRow, aCol, aProblem),
                          DecodingError.FieldDecodingError(bRow, bCol, bProblem)) =>
                        aProblem == bProblem and aRow + 1 == bRow and aCol == bCol
                    case (DecodingError.OneOfDecodingError(aRow, aList),
                          DecodingError.OneOfDecodingError(bRow, bList)) =>
                        aRow + 1 == bRow
                            and List.length(aList) == List.length(bList)
                            and List.forAll(match (a, b) -> isContiguous(a, b), List.zip(aList, bList))
                    case _ => errA == errB
                };
                def getRow(decErr) = match decErr {
                    case DecodingError.FieldDecodingError(row, _, _) => row
                    case DecodingError.OneOfDecodingError(row, _)    => row
                    case DecodingError.FieldNotProvided(_)            => 0
                    case DecodingError.NoFieldNamesProvided           => 0
                };

                def dedupeHelp(soFar, prevGroup, errors) = match errors {
                    case Nil => match prevGroup {
                        case Nil => List.reverse(soFar)
                        case head :: tail =>
                            let startErr = match List.head(List.reverse(tail)) {
                                case Some(x) => x
                                case None    => head
                            };
                            List.reverse((getRow(startErr), getRow(head), head) :: soFar)
                    }
                    case err :: rest => match prevGroup {
                        case Nil => dedupeHelp(soFar, err :: prevGroup, rest)
                        case head :: tail =>
                            if (isContiguous(head, err))
                                dedupeHelp(soFar, err :: prevGroup, rest)
                            else
                                let startErr = match List.head(List.reverse(tail)) {
                                    case Some(x) => x
                                    case None    => head
                                };
                                dedupeHelp(
                                    (getRow(startErr), getRow(head), head) :: soFar,
                                    err :: Nil,
                                    rest
                                )
                    }
                };
                def sortKey(err) = match err {
                    case DecodingError.FieldDecodingError(row, _, problem) => match problem {
                        case Problem.ColumnNotFound(_)      => (1, "",            row)
                        case Problem.FieldNotFound(name)    => (2, name,          row)
                        case Problem.ExpectedOneColumn(n)   => (3, "${n}",        row)
                        case Problem.ExpectedInt(s)         => (4, s,             row)
                        case Problem.ExpectedFloat(s)       => (5, s,             row)
                        case Problem.Failure(s)             => (6, s,             row)
                    }
                    case DecodingError.OneOfDecodingError(row, list) =>
                        // Not completely foolproof when multiple OneOf errors per row share the same branch count.
                        (7, "${List.length(list)}", row)
                    case DecodingError.FieldNotProvided(name) => (8, name, 0)
                    case DecodingError.NoFieldNamesProvided    => (9, "",   0)
                };
                def dedupeErrs(es) =
                    es
                        |> List.sortBy(sortKey)
                        |> dedupeHelp(Nil, Nil)
                        |> List.sortBy(match (startRow, _, err) -> (startRow, sortKey(err)));
                match dedupeErrs(errs) {
                    case Nil =>
                        "Something went wrong, but I got an blank error list so I don't know what it was. Please open an issue!"
                    case (startRow, endRow, err) :: Nil =>
                        topLevelErrString(startRow, endRow, err)
                    case multiple =>
                        "I saw ${List.length(multiple)} problems while decoding this CSV:\n\n"
                            + List.join("\n\n",
                                List.map(match (startRow, endRow, err) -> topLevelErrString(startRow, endRow, err), multiple)
                              )
                }
        }

    ///
    /// ===== MAPPING =====
    ///

    pub def map(transform: a -> b, decoder: Decoder[a]): Decoder[b] =
        let Decoder.Decoder(decode) = decoder;
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            Result.map(transform, decode(location, fieldNames, rowNum, row))
        )

    pub def map2(transform: (a, b) -> c, decoderA: Decoder[a], decoderB: Decoder[b]): Decoder[c] =
        let Decoder.Decoder(decodeA) = decoderA;
        let Decoder.Decoder(decodeB) = decoderB;
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            match (decodeA(location, fieldNames, rowNum, row), decodeB(location, fieldNames, rowNum, row)) {
                case (Ok(a), Ok(b))     => Ok(transform(a, b))
                case (Err(a), Err(b))   => Err(a ++ b)
                case (Err(a), _)        => Err(a)
                case (_, Err(b))        => Err(b)
            }
        )

    /// Like `map2`, but with three decoders. Use `intoRecord` for more fields.
    pub def map3(transform: (a, b, c) -> d, decoderA: Decoder[a], decoderB: Decoder[b], decoderC: Decoder[c]): Decoder[d] =
        let Decoder.Decoder(decodeA) = decoderA;
        let Decoder.Decoder(decodeB) = decoderB;
        let Decoder.Decoder(decodeC) = decoderC;
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            match (decodeA(location, fieldNames, rowNum, row),
                   decodeB(location, fieldNames, rowNum, row),
                   decodeC(location, fieldNames, rowNum, row)) {
                case (Ok(a),  Ok(b),  Ok(c))  => Ok(transform(a, b, c))
                case (Err(a), Err(b), Err(c)) => Err(a ++ b ++ c)
                case (Err(a), Err(b), _)      => Err(a ++ b)
                case (_, Err(b), Err(c))      => Err(b ++ c)
                case (Err(a), _, Err(c))      => Err(a ++ c)
                case (_, _, Err(c))           => Err(c)
                case (_, Err(b), _)           => Err(b)
                case (Err(a), _, _)           => Err(a)
            }
        )

    /// Combine an arbitrary number of fields. Provide a curried function, then
    /// supply each argument with `pipeline`.
    pub def intoRecord(f: a): Decoder[a] =
        succeed(f)

    /// See `intoRecord`.
    pub def pipeline(decoder: Decoder[a], decoderFn: Decoder[a -> b]): Decoder[b] =
        map2((value, fn) -> fn(value), decoder, decoderFn)

    ///
    /// ===== FANCY DECODING =====
    ///

    /// Try several possible decoders in sequence, committing to the first one that passes.
    pub def oneOf(first: Decoder[a], rest: List[Decoder[a]]): Decoder[a] =
        match rest {
            case Nil          => first
            case next :: others => recover(first, oneOf(next, others))
        }

    def recover(first: Decoder[a], second: Decoder[a]): Decoder[a] =
        let Decoder.Decoder(decodeFirst)  = first;
        let Decoder.Decoder(decodeSecond) = second;
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            match decodeFirst(location, fieldNames, rowNum, row) {
                case Ok(value) => Ok(value)
                case Err(errs) =>
                    match decodeSecond(location, fieldNames, rowNum, row) {
                        case Ok(value) => Ok(value)
                        case Err(DecodingError.OneOfDecodingError(_, problems) :: Nil) =>
                            Err(DecodingError.OneOfDecodingError(rowNum, errs ++ problems) :: Nil)
                        case Err(problems) =>
                            Err(DecodingError.OneOfDecodingError(rowNum, errs ++ problems) :: Nil)
                    }
            }
        )

    /// Decode some value and then make a decoding decision based on the outcome.
    pub def andThen(next: a -> Decoder[b], decoder: Decoder[a]): Decoder[b] =
        let Decoder.Decoder(decodeFirst) = decoder;
        Decoder.Decoder((location, fieldNames, rowNum, row) ->
            Result.flatMap(
                nextValue -> {
                    let Decoder.Decoder(decodeFinal) = next(nextValue);
                    decodeFinal(location, fieldNames, rowNum, row)
                },
                decodeFirst(location, fieldNames, rowNum, row)
            )
        )

    /// Always succeed, no matter what. Mostly useful with `andThen`.
    pub def succeed(value: a): Decoder[a] =
        Decoder.Decoder((_, _, _, _) -> Ok(value))

    /// Always fail with the given message, no matter what. Mostly useful with `andThen`.
    pub def fail(message: String): Decoder[a] =
        Decoder.Decoder((location, fieldNames, rowNum, _) ->
            Err(DecodingError.FieldDecodingError(rowNum, locationToColumn(fieldNames#names, location), Problem.Failure(message)) :: Nil)
        )

    /// Make creating custom decoders a little easier.
    pub def fromResult(result: Result[String, a]): Decoder[a] =
        match result {
            case Ok(value)    => succeed(value)
            case Err(problem) => fail(problem)
        }

    /// Like `fromResult` but you supply the error message since `None` has no information.
    pub def fromMaybe(problem: String, maybe: Option[a]): Decoder[a] =
        match maybe {
            case Some(value) => succeed(value)
            case None        => fail(problem)
        }

}
