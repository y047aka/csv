/*
 * Copyright 2026 Yoshitaka Totsuka
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Use of this source code is governed by the Apache 2.0 license
 * that can be found in the LICENSE file.
 */

///
/// CSV parsing and decoding, ported from BrianHicks/elm-csv 4.0.1.
///
/// The two modules are the upstream's own, and are named for them:
/// `Csv.Parser` turns a string into rows of fields, `Csv.Decode` turns
/// a row into a value through a combinator language. `Csv.Decode.Extra`
/// is the one module here that upstream has no counterpart to.
///
/// The parent module is declared for its children to hang from; Flix
/// refuses a child module whose parent is undeclared, and reports the
/// omission as a cascade of `Orphaned module` errors.
///
pub mod Csv { }
