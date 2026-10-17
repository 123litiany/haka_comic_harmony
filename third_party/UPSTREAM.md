# Vendored OpenHarmony platform plugins

Source repository: https://gitcode.com/CPF-Flutter/flutter_packages

These packages are copied from the following exact revisions to avoid downloading the entire multi-plugin repository during every clean build. Their original LICENSE files and source headers are retained. They are not relicensed by this port.

| Package | Revision | Original path |
| --- | --- | --- |
| shared_preferences_ohos | `4a7a536bba8447c7d4eacde2fb1a2e0fbe2da044` | packages/shared_preferences/shared_preferences_ohos |
| path_provider_ohos | `d4e49daa0acbd0bc419d58b1da27d64d44fab54b` | packages/path_provider/path_provider_ohos |
| url_launcher_ohos | `ae4494a78db5a9e0fe760b0eba9231605ae45716` | packages/url_launcher/url_launcher_ohos |

Import date: 2026-10-15. Source modifications: none at import. Any future local changes must be recorded here.

## Additions and changes, 2026-10-16

- `file_picker_ohos`: native `ohos/` subtree only from https://gitcode.com/CPF-Flutter/fluttertpc_file_picker , commit `ecbb5855cfe2439dc797cff8d0005d752db1a73a`, path `packages/file_picker_ohos`. Root MIT LICENSE and native Apache-2.0 headers retained. Local pubspec registers the native plugin against file_picker 11.0.2's existing method-channel implementation; the upstream v12 Dart API is intentionally not imported. Image selection and byte-based document saving are wired; folder URIs still require a dedicated filesystem bridge and must not be treated as sandbox paths.

- `local_auth_ohos` 3.0.1: same Flutter packages repository, commit `a454494d5f387aa88a09377dc868a57ec25c0b1e`, path `packages/local_auth/local_auth_ohos`. Original license retained. Widened intl upper bound from <0.19.0 to <0.21.0 for the application's intl 0.20.x; device authentication still needs runtime verification.
- `sqlite3` 3.3.4: pub.dev package archive, MIT, original LICENSE retained. Removed workspace resolution and added an OHOS compiler-specific native hook branch; other platform behavior is retained.
- `sqlite3_connection_pool` 0.2.4: pub.dev package archive, MIT, original LICENSE retained. Removed workspace resolution and added an OHOS compiler-specific native hook branch. Included original Rust sources and lockfile for cross-compilation.
- `sqlite-amalgamation/sqlite3.c` and `sqlite3.h`: SQLite 3.54.0, public domain, original headers retained. Source: https://www.sqlite.org/2026/sqlite-amalgamation-3540000.zip ; archive SHA-256 `68e913b0fe8ec6b4e5f391c594a28872884e80d6cd042a1e50c957be46b5aa4d`. No local source changes; compile flags are recorded in `script/harmony-native.ps1`.

Native binaries are generated locally and ignored by Git. This directory contains corresponding sources, not permission to redistribute third-party content accessed by the application.

The OHOS platform packages' demonstration `example/` projects are excluded from this port's Git snapshot; they are not needed to build the app. The sqlite3_connection_pool package's original multi-platform precompiled runtime assets are retained alongside its Rust source, Cargo lockfile and original MIT license. The OHOS build uses locally generated libraries instead of those assets.

Additional local file-picker native change (2026-10-16): document saving takes the current call's filename and bytes, including empty bytes. It no longer derives a filename or file contents from a previous picker operation. Apache-2.0 license text is included alongside the original root MIT license.
