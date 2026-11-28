# Command plugins

Add a command plugin (`swift package <verb>`): a row in `PLUGINS` (name, verb, description, and
the reason it writes to the package directory, or `None` when it writes nothing there), its
sources in `Plugins/<name>/` (an `@main` `CommandPlugin`), then `just modules`. Package.swift gets
a `.plugin` target and product; Bazel builds none of it, so no test reaches the plugin. Keep it
thin, its logic in a module or an executable it builds and runs, and run it on the package
(`swift package --allow-writing-to-package-directory <verb>`) after a change to it.
