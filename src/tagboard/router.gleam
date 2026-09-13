import gleam/dict
import gleam/http.{Get, Post}
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import gleam/time/timestamp
import handles
import handles/ctx as handles_ctx
import pog
import tagboard/context.{type Context}
import tagboard/sql
import tagboard/utils
import tagboard/web
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)

  let assert Ok(not_found_page) = dict.get(ctx.static_pages, "404")

  let path_segments = wisp.path_segments(req)
  case path_segments {
    [] -> home(req, ctx)
    ["create"] -> create(req, ctx)
    ["search"] -> search(req, ctx)
    ["search_by_uri"] -> search_by_uri(req, ctx)

    ["api", "create"] -> api_create(req, ctx)
    ["api", ..] -> wisp.not_found()

    _ ->
      wisp.not_found()
      |> wisp.html_body(not_found_page)
  }
}

fn home(req: Request, ctx: Context) -> Response {
  let assert Ok(page) = dict.get(ctx.static_pages, "home")

  use <- wisp.require_method(req, Get)
  wisp.ok()
  |> wisp.html_body(page)
}

fn create(req: Request, ctx: Context) -> Response {
  let assert Ok(page) = dict.get(ctx.static_pages, "create")

  use <- wisp.require_method(req, Get)
  wisp.ok()
  |> wisp.html_body(page)
}

fn search(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)

  let query_params = wisp.get_query(req)

  let #(tags, tags_param_present) = case
    list.key_find(query_params, "tags_string")
  {
    Ok(tags_string) -> #(utils.parse_tags_string(tags_string), True)
    Error(_) -> #([], False)
  }

  let assert Ok(tag_ids_query_returned) = sql.get_tag_ids(ctx.db, tags)
  let tag_ids = tag_ids_query_returned.rows |> list.map(fn(row) { row.id })

  let assert Ok(search_query_returned) = sql.search_by_tags(ctx.db, tag_ids)

  let matching_items_handles =
    handles_ctx.List(
      search_query_returned.rows
      |> list.map(fn(row) {
        handles_ctx.Dict([
          handles_ctx.Prop("uri", handles_ctx.Str(row.uri)),
          handles_ctx.Prop(
            "tags_string",
            handles_ctx.Str(utils.create_tags_string_from_tag_uris(row.array)),
          ),
        ])
      }),
    )
  let assert Ok(search_template) = dict.get(ctx.templates, "search")
  let assert Ok(rendered) =
    handles.run(
      search_template,
      handles_ctx.Dict([
        handles_ctx.Prop("matching_item", matching_items_handles),
        handles_ctx.Prop(
          "tags_param_present",
          handles_ctx.Bool(tags_param_present),
        ),
      ]),
      ctx.partials,
    )
  wisp.ok()
  |> wisp.html_body(string_tree.to_string(rendered))
}

fn search_by_uri(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)

  let query_params = wisp.get_query(req)

  let uri = case list.key_find(query_params, "uri") {
    Ok(uri) -> uri
    Error(Nil) -> ""
  }

  let escaped_uri =
    uri
    |> string.replace("\\", "\\\\")
    |> string.replace("%", "\\%")
    |> string.replace("_", "\\_")

  let exact_search_result = {
    use exact_search_returned <- result.try(sql.search_by_exact_uri(ctx.db, uri))
    case exact_search_returned.rows {
      [tags] -> Ok(#(True, tags.array))
      _ -> Ok(#(False, []))
    }
  }

  let contains_search_result = {
    use contains_search_returned <- result.try(sql.search_by_contains_uri(
      ctx.db,
      escaped_uri,
    ))
    Ok(
      contains_search_returned.rows
      |> list.map(fn(row) { #(row.uri, row.array) }),
    )
  }

  case exact_search_result, contains_search_result {
    Ok(#(exact_match_present, exact_search_matched)),
      Ok(contains_search_matched)
    -> {
      let assert Ok(template) = dict.get(ctx.templates, "search_by_uri")

      let contains_search_matched_handles =
        contains_search_matched
        |> list.map(fn(row) {
          let #(uri, tag_uris) = row
          handles_ctx.Dict([
            handles_ctx.Prop("uri", handles_ctx.Str(uri)),
            handles_ctx.Prop(
              "tags_string",
              handles_ctx.Str(utils.create_tags_string_from_tag_uris(tag_uris)),
            ),
          ])
        })
        |> handles_ctx.List

      let assert Ok(rendered) =
        handles.run(
          template,
          handles_ctx.Dict([
            handles_ctx.Prop(
              "exact_match_present",
              handles_ctx.Bool(exact_match_present),
            ),
            handles_ctx.Prop(
              "exact_match",
              handles_ctx.Dict([
                handles_ctx.Prop("uri", handles_ctx.Str(uri)),
                handles_ctx.Prop(
                  "tags_string",
                  handles_ctx.Str(utils.create_tags_string_from_tag_uris(
                    exact_search_matched,
                  )),
                ),
              ]),
            ),
            handles_ctx.Prop(
              "containing_match",
              contains_search_matched_handles,
            ),
          ]),
          ctx.partials,
        )
      wisp.ok()
      |> wisp.html_body(string_tree.to_string(rendered))
    }
    _, _ -> wisp.internal_server_error()
  }
}

fn api_create(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)

  let now = timestamp.system_time()

  use formdata <- wisp.require_form(req)
  let form_result = {
    use uri <- result.try(list.key_find(formdata.values, "uri"))
    use tags_string <- result.try(list.key_find(formdata.values, "tags_string"))
    Ok(#(uri, tags_string))
  }

  case form_result {
    Ok(#(uri, tags_string)) -> {
      let assert Ok(insert_new_tags_returns) =
        tags_string
        |> utils.parse_tags_string()
        |> list.map(fn(tag) { sql.insert_new_tag(ctx.db, tag, now, now) })
        |> result.all()

      let assert Ok(tag_id_rows) =
        insert_new_tags_returns
        |> list.map(fn(returned) {
          case returned.rows {
            [id] -> Ok(id)
            _ -> Error(Nil)
          }
        })
        |> result.all()

      let tag_ids = tag_id_rows |> list.map(fn(row) { row.id })

      let insert_item_result = sql.insert_item(ctx.db, uri, tag_ids, now, now)

      case insert_item_result {
        Ok(_) -> wisp.ok() |> wisp.html_body("Done!")
        Error(pog.ConstraintViolated(_, "items_uri_key", _)) ->
          wisp.bad_request("Item with that URI already exists")
        Error(_) -> wisp.internal_server_error()
      }
    }
    Error(_) -> {
      wisp.bad_request("Invalid form")
    }
  }
}
