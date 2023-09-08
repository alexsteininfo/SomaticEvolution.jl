"""
    initialize_population(::Type{T}, ::Type{S}, clonalmutations, N, Nmodules=1; rng=Random.GLOBAL_RNG) where {T<: AbstractCell, S<: ModuleStructure}

Create a Vector{CellModule} or Vector{TreeModule} of length `Nmodules` each containing a 
single cell at time `t=0`. 
"""
function initialize_population(
    ::Type{T}, 
    ::Type{S}, 
    clonalmutations, 
    N,
    Nmodules=1;
    rng=Random.GLOBAL_RNG
) where {T<: AbstractCell, S<: ModuleStructure}
    return moduletype(T,S)[initialize(T, S, clonalmutations, N; rng) for _ in 1:Nmodules]
end


"""
    initialize(::Type{T}, ::Type{S}, input, rng::AbstractRNG=Random.GLOBAL_RNG)

Initialise population of cells based on `input` and return as a `TreeModule{T, S} or
if `T == Cell` as a`CellModule{S}`.
"""
function initialize(
    ::Type{T}, 
    ::Type{S},
    clonalmutations,
    N;
    rng::AbstractRNG=Random.GLOBAL_RNG,
) where {T <: AbstractCell, S <: ModuleStructure}

    modulestructure = create_modulestructure(S, N)
    cells = create_cells(T, modulestructure, clonalmutations, N; rng)
    return new_module_from_cells(
        cells,
        0.0,
        Float64[0.0],
        CloneTracker[],
        1,
        0,
        modulestructure
    )
end

getNinit(input::Union{BranchingInput, BranchingMoranInput}) = 1
getNinit(input::MoranInput) = input.N
getNinit(input::MultilevelInput) = 1



function newcell(::Type{Cell}, id, mutations)
    return Cell(
        collect(1:mutations), 
        1,  #clonetype (wild-type)
        0,  #birthtime
        id, #unique cell id
        0   #parent id
    )
end

function newcell(::Type{T}, id, mutations) where T <: AbstractTreeCell
    return BinaryNode{T}(T(;id, mutations))
end

function create_cells(::Type{T}, structure::ModuleStructure, initialmutations, N=1; 
    rng=Random.GLOBAL_RNG) where T <:AbstractCell

    alivecells = [newcell(T, id, initialmutations) for id in 1:N]
    return position_cells(alivecells, structure, rng)
end

position_cells(alivecells, structure, rng) = alivecells

function position_cells(cells, structure::Linear, rng)
    N = length(cells)
    pad1 = round(Int64, (structure.size - N - 1)/2)
    pad2 = structure.size - pad1 - 1
    if rand(rng, 1:2) == 2 
        pad1, pad2 = pad2, pad1 
    end
    return [fill(nothing, pad1); cells; fill(nothing, pad2)]
end

function new_module_from_cells(cells::T, t, branchtimes, subclones, id, parentid, modulestructure::S) where {T, S}
    cellmodule = moduletype(T, S)(
        cells,
        t,
        branchtimes,
        subclones,
        id,
        parentid,
        modulestructure
    )
    return cellmodule
end