# Docker Compose
# Pick the command without running docker (that cost ~90 ms per shell),
# using the same check as the OMZ docker-compose plugin.
if [[ -x "${commands[docker-compose]:A}" ]]; then
    alias dc="docker-compose"
else
    alias dc="docker compose"
    alias docker-compose="docker compose"
fi
