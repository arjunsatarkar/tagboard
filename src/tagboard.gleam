import gleam/erlang/process
import mist
import tagboard/context.{Context}
import tagboard/router
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  // TODO: load from config/env/whatever
  let secret_key_base = wisp.random_string(64)

  let assert Ok(priv_directory) = wisp.priv_directory("tagboard")
  let ctx =
    Context(static_directory: priv_directory <> "/tagboard-frontend/build")

  let handler = router.handle_request(_, ctx)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}
