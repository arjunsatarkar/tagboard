import filepath
import gleam/dict
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri
import marceau
import pog
import tagboard/context.{type Context}
import tagboard/web
import wisp.{type Request, type Response, File}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)

  let path_segments = wisp.path_segments(req)
  case path_segments {
    ["api", "search"] -> search(req)
    ["api", "create"] -> create(req, ctx)
    ["api", ..] -> wisp.not_found()

    _ ->
      case dict.get(ctx.static_file_mapping, path_segments) {
        Ok(file_path) -> serve_frontend(req, file_path)
        Error(_) ->
          wisp.not_found()
          |> wisp.set_body(File(ctx.not_found_path, 0, option.None))
          |> wisp.set_header("content-type", "text/html; charset=utf-8")
      }
  }
}

fn serve_frontend(req: Request, file_path: String) -> Response {
  use <- wisp.require_method(req, Get)
  wisp.ok()
  |> wisp.set_header(
    "content-type",
    filepath.extension(file_path)
      |> result.unwrap("")
      |> marceau.extension_to_mime_type(),
  )
  |> wisp.set_body(File(file_path, 0, option.None))
}

fn search(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.html_body("Hello, Mike!")
}

fn create(req: Request, ctx: Context) -> Response {
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
