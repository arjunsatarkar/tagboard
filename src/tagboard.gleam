import dream_config/loader as config
import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/otp/static_supervisor as supervisor
import gleam/regexp
import gleam/result
import gleam/string
import mist
import pog
import simplifile
import tagboard/context.{type StaticFileMapping, Context}
import tagboard/router
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let assert Ok(_) = config.load_dotenv()

  let assert Ok(db_connection_uri) = config.get_required("DB_CONNECTION_URI")
  let assert Ok(secret_key_base) = config.get_required("SECRET_KEY_BASE")

  let pool_name = process.new_name("pog_db_pool")

  let assert Ok(db_config) = pog.url_config(pool_name, db_connection_uri)
  let pool_child =
    db_config
    |> pog.supervised

  let assert Ok(_) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.add(pool_child)
    |> supervisor.start

  let assert Ok(priv_directory) = wisp.priv_directory("tagboard")
  let static_file_path = priv_directory <> "/frontend"
  let assert Ok(trailing_slash_regexp) = regexp.from_string("\\/+$")
  let ctx =
    Context(
      db: pog.named_connection(pool_name),
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
