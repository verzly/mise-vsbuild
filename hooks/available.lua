local versions = require("lib/vsbuildtools_versions")

--- Returns available Visual Studio Build Tools release lines.
--- Known releases are always included. Additional Microsoft.VisualStudio.*.BuildTools
--- package lines may be loaded from the repository cache branch.
--- @param ctx table Context provided by mise/vfox
--- @return table Available versions
function PLUGIN:Available(ctx)
    local result = {}

    for _, release in ipairs(versions.releases()) do
        table.insert(result, {
            version = release.version,
            note = release.note,
            addition = {
                { name = "vs", version = release.major or "auto" },
                { name = "product", version = release.winget or "" },
                { name = "source", version = release.cached and "cache" or "built-in" },
            },
        })
    end

    table.insert(result, {
        version = "latest",
        note = "Alias for the Visual Studio Build Tools current channel",
        addition = {
            { name = "vs", version = "current" },
            { name = "product", version = "Microsoft.VisualStudio.BuildTools" },
            { name = "source", version = "alias" },
        },
    })

    table.insert(result, {
        version = "stable",
        note = "Alias for the Visual Studio Build Tools current channel",
        addition = {
            { name = "vs", version = "current" },
            { name = "product", version = "Microsoft.VisualStudio.BuildTools" },
            { name = "source", version = "alias" },
        },
    })

    return result
end
