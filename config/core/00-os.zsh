# OS Detection
case "$(uname -s)" in
    Darwin)
        export IS_MACOS=true
        export IS_LINUX=false
        ;;
    Linux)
        export IS_MACOS=false
        export IS_LINUX=true
        ;;
    *)
        export IS_MACOS=false
        export IS_LINUX=false
        ;;
esac
