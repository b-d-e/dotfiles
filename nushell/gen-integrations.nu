#!/usr/bin/env nu
# Generates starship + atuin init into nushell's vendor autoload dir, which
# nushell auto-sources at startup. Run this after installing/upgrading nushell,
# starship, or atuin. Invoked by symlinks.sh during bootstrap.

let autoload_dir = ($nu.data-dir | path join "vendor" "autoload")
mkdir $autoload_dir

if (which starship | is-not-empty) {
    starship init nu | save -f ($autoload_dir | path join "starship.nu")
    print $"wrote ($autoload_dir | path join 'starship.nu')"
}
if (which atuin | is-not-empty) {
    atuin init nu | save -f ($autoload_dir | path join "atuin.nu")
    print $"wrote ($autoload_dir | path join 'atuin.nu')"
}
if (which zoxide | is-not-empty) {
    zoxide init nushell | save -f ($autoload_dir | path join "zoxide.nu")
    print $"wrote ($autoload_dir | path join 'zoxide.nu')"
}
