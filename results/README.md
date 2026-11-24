# Result provenance

- `tt/`: historical results and inputs at the TT corner, preserved from the
  pre-organization repository. See its index before comparing runs.
- `ss/`: instructions and a destination for the server's SS result imports.
  No SS measurements have been imported yet.
- `legacy/`: older GDS, a loose synthesis log/archive, and the original README.
  Their provenance is not promoted to the final baseline.
- `migration.json`: 320 old/new paths and SHA-256 values for preserved payloads
  and unchanged RTL. `make check` verifies these files byte for byte.

Do not rewrite old paths inside historical logs, reports, netlists, or activity
files: they are recorded evidence. Fix maintained commands and documentation
instead. New scratch outputs belong in `build/`. Import evidence with exact flow
and source snapshots; never relabel TT data as SS or silently overwrite a run.
