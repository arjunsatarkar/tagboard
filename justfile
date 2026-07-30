run: build-frontend
    gleam run

build: build-frontend
    gleam build

build-frontend:
    cd priv/tagboard-frontend && pnpm run build
