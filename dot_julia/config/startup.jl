if isinteractive()
    try
        using Revise
    catch err
        @warn "Could not load Revise" exception = (err, catch_backtrace())
    end
end
