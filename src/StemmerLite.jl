module StemmerLite

using Snowball_jll

export Stemmer, stem, stemmer_types

##
# character encodings supported by libstemmer
const UTF_8         = "UTF_8"
const ISO_8859_1    = "ISO_8859_1"
const CP850         = "CP850"
const KOI8_R        = "KOI8_R"

"""
    stemmer_types()

List all the stemmer algorithms loaded.
"""
function stemmer_types()
    cptr = ccall((:sb_stemmer_list, libstemmer), Ptr{Ptr{UInt8}}, ())
    (C_NULL == cptr) && error("error getting stemmer types")

    stypes = AbstractString[]
    i = 1
    while true
        name_ptr = unsafe_load(cptr, i)
        (C_NULL == name_ptr) && break
        push!(stypes, unsafe_string(name_ptr))
        i += 1
    end
    stypes
end

"""
    Stemmer(stemmer_type, charenc=UTF_8)

The `Stemmer` object stores a reference to the underlying `libstemmer` handle
"""
mutable struct Stemmer
    cptr::Ptr{Cvoid}
    alg::String
    enc::String

    function Stemmer(stemmer_type, charenc=UTF_8)
        cptr = ccall((:sb_stemmer_new, libstemmer),
                    Ptr{Cvoid},
                    (Ptr{UInt8}, Ptr{UInt8}),
                    String(stemmer_type), String(charenc))

        if cptr == C_NULL
            if charenc == UTF_8
                error("stemmer '$(stemmer_type)' is not available")
            else
                error("stemmer '$(stemmer_type)' is not available for encoding '$(charenc)'")
            end
        end

        stm = new(cptr, stemmer_type, charenc)
        finalizer(release, stm)
        stm
    end
end

Base.show(io::IO, stm::Stemmer) = println(io, "Stemmer algorithm:$(stm.alg) encoding:$(stm.enc)")

"""
    release(stemmer::Stemmer)

Release resources held by `libstemmer`
"""
function release(stm::Stemmer)
    (C_NULL == stm.cptr) && return
    ccall((:sb_stemmer_delete, libstemmer), Cvoid, (Ptr{Cvoid},), stm.cptr)
    stm.cptr = C_NULL
    nothing
end

"""
    stem(stemmer::Stemmer, str)
    stem(stemmer::Stemmer, words::Vector)

Stem the input with the Stemming algorthm of `stemmer`.

See also: [`stem_all`](@ref)
"""
function stem(stemmer::Stemmer, bstr::AbstractString)::String
    sres = ccall((:sb_stemmer_stem, libstemmer),
                Ptr{UInt8},
                (Ptr{UInt8}, Ptr{UInt8}, Cint),
                stemmer.cptr, bstr, sizeof(bstr))
    (C_NULL == sres) && error("error in stemming")
    slen = ccall((:sb_stemmer_length, libstemmer), Cint, (Ptr{Cvoid},), stemmer.cptr)
    bytes = unsafe_wrap(Array, sres, Int(slen), own=false)
    String(copy(bytes))
end

stem(stemmer::Stemmer, words::Vector{<:AbstractString})::Vector{String} =
    map(w -> stem(stemmer, w), words)

end # module StemmerLite
