import filepath
import gleam/http.{Get, Post}
import gleam/list
import gleam/option
import gleam/result
import gleam/uri
import marceau
import simplifile
import tagboard/context.{type Context}
import tagboard/web
import wisp.{type Request, type Response, File}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    ["api", "search"] -> search(req)
    ["api", "create"] -> create(req)

    _ -> serve_frontend(req, ctx)
  }
}

fn serve_frontend(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)

  let found_path = {
    use path <- result.try(uri.percent_decode(req.path))
    // filepath.expand is documented to not go up past the root of the given path, i.e. the expanded path will have no .. in it
    // This prevents directory traversal vulnerabilities
    use path <- result.try(filepath.expand(path))
    let path = ctx.static_directory <> path
    case simplifile.is_file(path) {
      Ok(True) -> {
        Ok(path)
      }
      Ok(False) -> {
        let path = path <> "/index.html"
        case simplifile.is_file(path) {
          Ok(True) -> Ok(path)
          _ -> Error(Nil)
        }
      }

      _ -> Error(Nil)
    }
  }

  case found_path {
    Ok(path) ->
      wisp.ok()
      |> wisp.set_header(
        "content-type",
        filepath.extension(path)
          |> result.unwrap("")
          |> marceau.extension_to_mime_type(),
      )
      |> wisp.set_body(File(path, 0, option.None))
    Error(_) -> wisp.not_found()
  }
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
