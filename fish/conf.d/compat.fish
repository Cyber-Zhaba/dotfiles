# Debian and Ubuntu rename these binaries to avoid clashes with older packages.
# conf.d is sourced before config.fish, so the aliases below are in place by the
# time config.fish builds `ff` on top of bat.
if not command -q bat; and command -q batcat
    alias bat batcat
end

if not command -q fd; and command -q fdfind
    alias fd fdfind
end
