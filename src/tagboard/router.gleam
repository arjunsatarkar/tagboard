import gleam/dict
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import pog
import tagboard/context.{type Context}
import tagboard/web
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)

  let assert Ok(not_found_page) = dict.get(ctx.static_pages, "404")

  let path_segments = wisp.path_segments(req)
  case path_segments {
    [] -> home(req, ctx)
    ["create"] -> create(req, ctx)

    ["api", "search"] -> api_search(req)
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

fn api_search(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.html_body("Hello, Mike!")
}

fn api_create(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)

  use formdata <- wisp.require_form(req)
  let result = {
    use uri <- result.try(list.key_find(formdata.values, "uri"))
    use tags_string <- result.try(list.key_find(formdata.values, "tags_string"))
    Ok(#(uri, tags_string))
  }

  case result {
    Ok(#(uri, tags_string)) -> {
      let insert_new_tags_query =
        pog.query(
          "WITH r AS (
            INSERT INTO items(uri) VALUES ($1) ON CONFLICT DO NOTHING RETURNING id
           ) SELECT * FROM r UNION SELECT id FROM items WHERE uri=$1
           ",
        )
        |> pog.returning({
          use id <- decode.field(0, decode.int)
          decode.success(id)
        })

      let assert Ok(insert_new_tags_returns) =
        tags_string
        |> string.split(" ")
        |> list.map(uri.percent_encode)
        |> list.map(fn(percent_encoded) {
          pog.parameter(
            insert_new_tags_query,
            pog.text("tagboard-tag:" <> percent_encoded),
          )
        })
        |> list.map(pog.execute(_, ctx.db))
        |> result.all()

      let assert Ok(tag_ids) =
        insert_new_tags_returns
        |> list.map(fn(returned) {
          case returned.rows {
            [id] -> Ok(id)
            _ -> Error(Nil)
          }
        })
        |> result.all()

      let insert_item_result =
        pog.query("INSERT INTO items(uri, tags) VALUES($1, $2)")
        |> pog.parameter(pog.text(uri))
        |> pog.parameter(pog.array(pog.int, tag_ids))
        |> pog.execute(ctx.db)

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
