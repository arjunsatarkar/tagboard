run:
    gleam run

build:
    gleam build

format:
    gleam format
    pnpm exec prettier --write .
    find priv/frontend -name '*.handles' -exec uvx djlint --reformat --warn {} +
    pg_format --inplace src/tagboard/sql/*.sql

migrate:
    gleam run -m migrate
