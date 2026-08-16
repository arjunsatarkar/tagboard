import Handlebars from "handlebars";
import fs from "node:fs/promises";
import path from "node:path";

const PARTIALS_PATH = "src/partials";
const ASSETS_PATH = "src/assets";
const TEMPLATES_PATH = "src/templates";

await fs.rm("build", { recursive: true, force: true });
console.info("Cleared build/");

// Copy assets directly
await fs.cp(ASSETS_PATH, "build/assets", { recursive: true });
console.info(`Copied assets from ${ASSETS_PATH}`);

// Register partials (no nesting)
const partialsDirEntries = await fs.readdir(PARTIALS_PATH, {
  withFileTypes: true,
});
for (const partialsDirEntry of partialsDirEntries) {
  const partialName = path.parse(partialsDirEntry.name).name;
  const joinedPath = path.join(
    partialsDirEntry.parentPath,
    partialsDirEntry.name,
  );
  Handlebars.registerPartial(
    partialName,
    await fs.readFile(joinedPath, "utf-8"),
  );

  console.info(`Registered partial ${partialName} from ${joinedPath}`);
}

// Compile and output the result of evaluating regular templates
const entries = await fs.readdir(TEMPLATES_PATH, {
  recursive: true,
  withFileTypes: true,
});

for (const entry of entries) {
  const joinedPath = path.join(entry.parentPath, entry.name);
  const parsedPath = path.parse(joinedPath);
  if (!entry.isFile()) {
    continue;
  }

  const template = Handlebars.compile(await fs.readFile(joinedPath, "utf-8"), {
    preventIndent: true,
  });

  const outDir = path.join(
    "build",
    path.relative(TEMPLATES_PATH, entry.parentPath),
  );
  await fs.mkdir(outDir, { recursive: true });
  const outPath = path.join(outDir, parsedPath.name + ".html");
  await fs.writeFile(outPath, template());

  console.info(`Wrote result of ${joinedPath} to ${outPath}`);
}
