//// This module contains the code to run the sql queries defined in
//// `./src/tagboard/sql`.
//// > 🐿️ This module was generated automatically using v4.7.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `get_tag_ids` query
/// defined in `./src/tagboard/sql/get_tag_ids.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetTagIdsRow {
  GetTagIdsRow(id: Int)
}

/// Runs the `get_tag_ids` query
/// defined in `./src/tagboard/sql/get_tag_ids.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_tag_ids(
  db: pog.Connection,
  arg_1: List(String),
) -> Result(pog.Returned(GetTagIdsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(GetTagIdsRow(id:))
  }

  "SELECT
    id
FROM
    items
WHERE
    uri = ANY ($1)
"
  |> pog.query
  |> pog.parameter(pog.array(fn(value) { pog.text(value) }, arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_item` query
/// defined in `./src/tagboard/sql/insert_item.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_item(
  db: pog.Connection,
  arg_1: String,
  arg_2: List(Int),
  arg_3: Timestamp,
  arg_4: Timestamp,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO items (uri, tags, created_at, modified_at)
    VALUES ($1, $2, $3, $4)
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.array(fn(value) { pog.int(value) }, arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.parameter(pog.timestamp(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `insert_new_tag` query
/// defined in `./src/tagboard/sql/insert_new_tag.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type InsertNewTagRow {
  InsertNewTagRow(id: Int)
}

/// The WITH is to make sure we always get an id back
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_new_tag(
  db: pog.Connection,
  uri: String,
  arg_2: Timestamp,
  arg_3: Timestamp,
) -> Result(pog.Returned(InsertNewTagRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(InsertNewTagRow(id:))
  }

  "-- The WITH is to make sure we always get an id back
WITH r AS (
INSERT INTO items (uri, created_at, modified_at)
        VALUES ($1, $2, $3)
    ON CONFLICT
        DO NOTHING
    RETURNING
        id)
    SELECT
        *
    FROM
        r
    UNION
    SELECT
        id
    FROM
        items
    WHERE
        uri = $1
"
  |> pog.query
  |> pog.parameter(pog.text(uri))
  |> pog.parameter(pog.timestamp(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `search_by_tags` query
/// defined in `./src/tagboard/sql/search_by_tags.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SearchByTagsRow {
  SearchByTagsRow(uri: String, array: List(String))
}

/// Runs the `search_by_tags` query
/// defined in `./src/tagboard/sql/search_by_tags.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn search_by_tags(
  db: pog.Connection,
  arg_1: List(Int),
) -> Result(pog.Returned(SearchByTagsRow), pog.QueryError) {
  let decoder = {
    use uri <- decode.field(0, decode.string)
    use array <- decode.field(1, decode.list(decode.string))
    decode.success(SearchByTagsRow(uri:, array:))
  }

  "SELECT
    items_outer.uri,
    ARRAY(
        SELECT
            items_inner.uri
        FROM
            items items_inner
        WHERE
            items_inner.id = ANY (items_outer.tags))
FROM
    items items_outer
WHERE
    $1 <@ items_outer.tags
ORDER BY
    items_outer.created_at DESC
LIMIT 100
"
  |> pog.query
  |> pog.parameter(pog.array(fn(value) { pog.int(value) }, arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
