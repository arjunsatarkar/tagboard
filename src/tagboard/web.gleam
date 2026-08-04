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
  case replace_trailing_slashes(req.path, ctx) {
    #(_, False) -> handle_request(req)
    #(new_path, True) -> wisp.permanent_redirect(new_path)
  }
}

/// Return the path without any removable trailing slashes
/// The second element in the tuple is whether it is necessary to redirect,
/// i.e. whether anything changed.
fn replace_trailing_slashes(path: String, ctx: Context) -> #(String, Bool) {
  case path != "/" && string.ends_with(path, "/") {
    True -> {
      let replaced =
        regexp.replace(ctx.trailing_slash_regexp, in: path, with: "")
      case replaced {
        "" -> #("/", True)
        _ -> #(replaced, True)
      }
    }
    False -> #(path, False)
  }
}
