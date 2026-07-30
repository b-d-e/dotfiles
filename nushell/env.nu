# ~/.dotfiles/nushell/env.nu  (symlinked to ~/.config/nushell/env.nu)
# Runs before config.nu. Environment / PATH setup lives here.

# --- PATH ---
# Prepend the same dirs our POSIX shells add (brew, cargo, uv, LM Studio),
# keeping only those that actually exist on this machine (macOS or Linux).
$env.PATH = (
    $env.PATH
    | split row (char esep)
    | prepend [
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
        "/home/linuxbrew/.linuxbrew/bin"
        "/usr/local/bin"
        ($env.HOME | path join ".cargo" "bin")
        ($env.HOME | path join ".local" "bin")
        ($env.HOME | path join ".lmstudio" "bin")
    ]
    | uniq
    | where { |p| $p | path exists }
)

# --- Integrations ---
# starship + atuin init are generated into nushell's vendor autoload dir by
# symlinks.sh (run `nushell/gen-integrations.nu` to refresh after upgrades).
# nushell auto-sources every *.nu found there at startup.
