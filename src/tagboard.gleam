import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/regexp
import gleam/result
import gleam/string
import mist
import simplifile
import tagboard/context.{type StaticFileMapping, Context}
import tagboard/router
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  // TODO: load from config/env/whatever
  let secret_key_base = wisp.random_string(64)

  let assert Ok(priv_directory) = wisp.priv_directory("tagboard")
  let static_file_path = priv_directory <> "/tagboard-frontend/build"
  let assert Ok(trailing_slash_regexp) = regexp.from_string("\\/+$")
  let ctx =
    Context(
      static_file_mapping: get_static_file_mapping(static_file_path),
      not_found_path: static_file_path <> "/404.html",
      trailing_slash_regexp: trailing_slash_regexp,
    )

  let handler = router.handle_request(_, ctx)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

fn get_static_file_mapping(static_directory: String) -> StaticFileMapping {
  let assert Ok(files) = simplifile.get_files(in: static_directory)
  files
  |> list.filter_map(fn(path) {
    // The order of the string operations is load-bearing
    let relative_path =
      path
      |> string.remove_suffix("/index.html")
      |> string.remove_prefix(static_directory)
      |> string.remove_prefix("/")
    use path_segments <- result.try(
      case relative_path == "404.html", string.is_empty(relative_path) {
        True, _ -> Error(Nil)
        False, True -> Ok([])
        False, False -> Ok(string.split(relative_path, on: "/"))
      },
    )
    Ok(#(path_segments, path))
  })
  |> dict.from_list()
}
