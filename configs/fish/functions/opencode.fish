function opencode --wraps opencode --description 'opencode v1 on an isolated DB so opencode2 (v2 beta) cannot migrate its schema out from under it'
    # opencode (v1 stable) and opencode2 (v2 beta) both default to
    # ~/.local/share/opencode/opencode.db. v2 migrates it to a schema that drops
    # workspace.project_id, which crashes v1 on boot ("no such column: project_id").
    # Pin v1 to its own DB. opencode2 keeps the default (shared) file.
    set -lx OPENCODE_DB $HOME/.local/share/opencode/opencode-v1.db
    command opencode $argv
end
