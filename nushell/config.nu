# ~/.dotfiles/nushell/config.nu  (symlinked to ~/.config/nushell/config.nu)

# Disable nushell's own startup banner — we use fastfetch instead.
$env.config.show_banner = false

# System-info banner, only when attached to a real terminal.
if (is-terminal --stdout) and (which fastfetch | is-not-empty) {
    ^fastfetch
}
