import tagboard/context.{type Context}
import wisp

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  use <- wisp.log_request(req)

  use <- wisp.rescue_crashes

  use req <- wisp.handle_head(req)

  use req <- wisp.csrf_known_header_protection(req)

  use <- wisp.serve_static(req, under: "/assets", from: ctx.assets_dir)

  handle_request(req)
}
