import gleam/dict.{type Dict}
import handles
import pog

pub type Context {
  Context(
    db: pog.Connection,
    templates: TemplateMapping,
    partials: List(#(String, handles.Template)),
    static_pages: Dict(String, String),
    assets_dir: String,
  )
}

pub type TemplateMapping =
  Dict(String, handles.Template)
