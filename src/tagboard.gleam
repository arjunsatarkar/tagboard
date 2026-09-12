import dream_config/loader as config
import filepath
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/list
import gleam/otp/static_supervisor as supervisor
import gleam/result
import gleam/string_tree
import handles
import handles/ctx as handles_ctx
import mist
import pog
import simplifile
import tagboard/context.{type TemplateMapping, Context}
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
  let #(templates, partials) =
    prepare_templates(filepath.join(priv_directory, "frontend"))
  let ctx =
    Context(
      db: pog.named_connection(pool_name),
      templates: templates,
      partials: partials,
      static_pages: prepare_static_pages(templates, partials),
      assets_dir: filepath.join(priv_directory, "frontend/assets"),
    )

  let handler = router.handle_request(_, ctx)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

fn prepare_templates(
  template_directory: String,
) -> #(TemplateMapping, List(#(String, handles.Template))) {
  let partials =
    process_template_dir(filepath.join(template_directory, "partials"))
  let templates =
    process_template_dir(filepath.join(template_directory, "templates"))
    |> dict.from_list()

  #(templates, partials)
}

fn prepare_static_pages(
  templates: TemplateMapping,
  partials: List(#(String, handles.Template)),
) -> Dict(String, String) {
  ["home", "create", "404"]
  |> list.map(fn(name) {
    let assert Ok(template) = dict.get(templates, name)
    let assert Ok(template_result) =
      handles.run(template, handles_ctx.Dict([]), partials)
    #(name, string_tree.to_string(template_result))
  })
  |> dict.from_list
}

// TODO: The error handling should really be better, although it's not a
// major problem since none of this is user-controlled.
fn process_template_dir(dir: String) -> List(#(String, handles.Template)) {
  let assert Ok(paths) = simplifile.get_files(dir)

  let assert Ok(result) =
    paths
    |> list.map(fn(path) {
      use contents <- result.try(
        simplifile.read(path) |> result.replace_error(Nil),
      )
      use prepared <- result.try(
        handles.prepare(contents) |> result.replace_error(Nil),
      )

      Ok(#(path |> filepath.base_name() |> filepath.strip_extension(), prepared))
    })
    |> result.all()

  result
}
