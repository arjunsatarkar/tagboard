import filepath
import gleam/dict
import gleam/http.{Get, Post}
import gleam/list
import gleam/option
import gleam/result
import marceau
import tagboard/context.{type Context}
import tagboard/web
import wisp.{type Request, type Response, File}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)

  let path_segments = wisp.path_segments(req)
  case path_segments {
    ["api", "search"] -> search(req)
    ["api", "create"] -> create(req)
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

fn create(req: Request) -> Response {
  use <- wisp.require_method(req, Post)

  use formdata <- wisp.require_form(req)
  let result = {
    use uri <- result.try(list.key_find(formdata.values, "uri"))
    use tags_string <- result.try(list.key_find(formdata.values, "tags_string"))
    Ok(uri <> tags_string)
  }

  case result {
    Ok(content) -> {
      wisp.ok()
      |> wisp.html_body("Hello " <> content)
    }
    Error(_) -> {
      wisp.bad_request("Invalid form")
    }
  }
}
