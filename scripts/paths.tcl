# Source through a script-relative path. No Synopsys commands or library settings.
set PROJECT_ROOT [file normalize [file join [file dirname [info script]] ..]]
proc project_path {path} {
    global PROJECT_ROOT
    if {[file pathtype $path] eq "absolute"} { return [file normalize $path] }
    return [file normalize [file join $PROJECT_ROOT $path]]
}
