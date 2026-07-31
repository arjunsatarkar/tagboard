import gleam/http/response
import gleam/regexp
import gleam/string
import tagboard/context.{type Context}
import wisp

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  use <- wisp.log_request(req)

  use <- wisp.rescue_crashes

  use req <- redirect_trailing_slashes(req, ctx)

  use req <- wisp.handle_head(req)

  use req <- wisp.csrf_known_header_protection(req)

  handle_request(req)
}

fn redirect_trailing_slashes(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> response.Response(wisp.Body) {
  case construct_path_without_trailing_slashes(req.path, ctx) {
    Ok(new_path) -> wisp.permanent_redirect(new_path)
    Error(Nil) -> handle_request(req)
  }
}

/// If path has trailing slashes (and is not the root path "/"), remove them and return the
/// new path wrapped in an Ok(), except if we would return an empty string we return "/" instead.
/// 
/// If path has no removable trailing slashes, return Error(nil).
/// 
/// The use of a Result return is to help the caller decide whether to redirect.
fn construct_path_without_trailing_slashes(
  path: String,
  ctx: Context,
) -> Result(String, Nil) {
  case path != "/" && string.ends_with(path, "/") {
    True -> {
      let replaced =
        regexp.replace(ctx.trailing_slash_regexp, in: path, with: "")
      case replaced {
        "" -> Ok("/")
        _ -> Ok(replaced)
      }
    }
    False -> Error(Nil)
  }
}
