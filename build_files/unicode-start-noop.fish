# Shadow kbd(1) unicode_start so it never runs from a fish login shell.
#
# fish's /usr/share/fish/config.fish runs `unicode_start` on a login shell
# when TERM=linux and the locale is UTF-8. niri-session re-execs the session
# through a login shell on tty1, so that branch fires on every graphical
# login. unicode_start then calls kbd_mode and setfont, which need
# CAP_SYS_TTY_CONFIG; as an unprivileged user they fail and print onto tty1
# while niri starts.
#
# systemd-vconsole-setup already applies KEYMAP and FONT at boot, as root,
# so the call is redundant. An autoloaded function shadows it:
# fish_function_path is set at config.fish:70, before the call at :165,
# while conf.d is not sourced until :215.
function unicode_start
end

# Installed to /etc/fish/functions at build time, which the image commit
# moves to /usr/etc/fish/functions. That is fish's compiled sysconfdir
# ($__fish_sysconf_dir), so it lands on fish_function_path; /etc/fish is
# only the ostree runtime merge and fish does not read it directly.
