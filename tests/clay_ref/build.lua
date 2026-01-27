local function build()
    local cc = os.getenv("CC") or "gcc"
    local src = "tests/clay_ref/clay_impl.c"
    local out = "tests/clay_ref/libclay_ref.so"
    local clay_dir = "clay"

    print("Building Clay reference library...")

    local cmd = string.format(
        "%s -shared -fPIC -O2 -o %s %s -I%s -lm",
        cc, out, src, clay_dir
    )

    print("Running: " .. cmd)
    local ok = os.execute(cmd)

    if ok ~= 0 and ok ~= true then
        error("Failed to build libclay_ref.so")
    end

    print("Built " .. out)
    return out
end

return {
    build = build
}
