import filepath
import gleam/bool
import gleam/http.{Get, Post}
import gleam/list
import gleam/option
import gleam/result
import gleam/string
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

  // We don't strip the slash before the file name
  use <- bool.guard(
    when: string.ends_with(req.path, "/index.html"),
    return: wisp.permanent_redirect(string.remove_suffix(req.path, "index.html")),
  )

  let file_path = {
    use path <- result.try(uri.percent_decode(req.path))
    // filepath.expand is documented to not go up past the root of the given path, i.e. the expanded path will have no .. in it
    // This prevents directory traversal vulnerabilities when the path is appended to ctx.static_directory
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

  case file_path {
    Ok(file_path) ->
      wisp.ok()
      |> wisp.set_header(
        "content-type",
        filepath.extension(file_path)
          |> result.unwrap("")
          |> marceau.extension_to_mime_type(),
      )
      |> wisp.set_body(File(file_path, 0, option.None))
    Error(_) ->
      wisp.not_found()
      |> wisp.set_body(File(ctx.static_directory <> "/404.html", 0, option.None))
      |> wisp.set_header("content-type", "text/html; charset=utf-8")
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
