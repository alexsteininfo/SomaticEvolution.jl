"""
    simulate!(population, tmax, maxmodules, birthrate, deathrate, moranrate, branchrate, 
        modulesize, branchinitsize, rng; moduleupdate=:branching[, t0])

Run a single multilevel simulation using the Gillespie algorithm, with the 
`population` giving the initial state. Simulation runs until the module population 
size reaches `maxmodules` or the age of the population reaches `tmax`. 

"""
function simulate!(population, tmax, maxmodules, birthrate, deathrate, moranrate, asymmetricrate, branchrate, 
    modulesize, branchinitsize, modulebranching, μ, mutationdist, moranincludeself, nextID, nextmoduleID, rng; moduleupdate=:branching, t0=nothing)

    t = isnothing(t0) ? age(population) : t0
    transitionrates = get_transitionrates(population, birthrate, deathrate, 
        moranrate, asymmetricrate, branchrate, modulesize)

    while t < tmax && (moduleupdate==:moran || length(population) < maxmodules)
        population, transitionrates, t, nextID, nextmoduleID = 
            update_population!(population, transitionrates, birthrate, deathrate, moranrate, asymmetricrate, branchrate,  modulesize, 
                branchinitsize, modulebranching, t, nextID, nextmoduleID, μ, mutationdist, tmax, maxmodules, moranincludeself, rng; moduleupdate)
        #returns empty list of modules if population dies out
        if length(population) == 0
            return population, nextID, nextmoduleID
        end
    end
    return population, nextID, nextmoduleID
end

"""
    update_population!(population, birthrate, deathrate, moranrate, branchrate, modulesize, 
        branchinitsize, nextID, t, tmax, rng)

Perform a single Gillespie step to advance the simulation of a multilevel population, and
increase the time t → t + Δt.

Calculates the transition rates for a Moran, birth, death or module branching event; then 
selects from these transitions with probability proportional to rate. Time is increased by
`Δt ~ Exp(sum(transitionrates))`. If new time exceeds `tmax` do not perform any transition.
"""

function update_population!(population, transitionrates, birthrate, deathrate, moranrate, asymmetricrate, branchrate, modulesize, 
    branchinitsize, modulebranching, t, nextID, nextmoduleID, μ, mutationdist, tmax, maxmodules, moranincludeself, rng; moduleupdate=:branching)

    t += exptime(rng, sum(transitionrates))
    #only update the population if t < tmax
    if t < tmax
        #choose transition type: 1=moran, 2=asymmetric, 3=birth, 4=death, 5=branch
        transitionid = sample(
            rng, 
            1:5, 
            ProbabilityWeights(transitionrates ./ sum(transitionrates))
        )
        population, nextID, nextmoduleID = transition!(
            population, 
            transitionid, 
            modulesize, 
            branchinitsize, 
            modulebranching, 
            t, 
            nextID,
            nextmoduleID,
            μ, 
            mutationdist,
            maxmodules,
            moranincludeself,
            rng;
            moduleupdate
        )
        if transitionid in 3:5
            update_transitionrates!(transitionrates, population, birthrate, deathrate, moranrate, asymmetricrate, branchrate, modulesize)
        end
    end
    return population, transitionrates, t, nextID, nextmoduleID
end

"""
    transition!(population, transitionid, modulesize, branchinitsize, nextID, t, 
        μ, rng)
    
Perform a single transition step on `population`, determined by `transitionid`.
"""
function transition!(population, transitionid, modulesize, branchinitsize, 
    modulebranching, t, nextID, nextmoduleID, μ, mutationdist, maxmodules, 
    moranincludeself, rng; moduleupdate=:branching)
    
    if transitionid == 1
        _, nextID = moranupdate!(population, modulesize, t, nextID, μ, mutationdist, rng; moranincludeself)
    elseif transitionid == 2
        _, nextID = asymmetricupdate!(population, modulesize, t, nextID, μ, mutationdist, rng)
    elseif transitionid == 3
        _, nextID = birthupdate!(population, modulesize, t, nextID, μ, mutationdist, rng)
    elseif transitionid == 4
        deathupdate!(population, modulesize, t, μ, mutationdist, rng)
    elseif transitionid == 5
        if moduleupdate == :branching || length(population) < maxmodules
            _, nextmoduleID, nextID = modulebranchingupdate!(
                population, nextmoduleID, modulesize, branchinitsize, t, rng; 
                modulebranching, nextID, μ, mutationdist
            )
        elseif moduleupdate == :moran
            _, nextmoduleID, nextID = modulemoranupdate!(
                population, nextmoduleID, modulesize, branchinitsize, t, rng; 
                modulebranching, nextID, μ, mutationdist
            )
        end
    end
    return population, nextID, nextmoduleID
end

"""
    moranupdate!(population, modulesize, t, nextID, μ, mutationdist, rng; moranincludeself=false)

Selects a homeostatic module uniformly at random to undergo a single Moran update. From 
that module one cell divides and one cell dies.
"""
function moranupdate!(population, modulesize, t, nextID, μ, mutationdist, rng; moranincludeself=true)
    cellmodule, parentcell, deadcell = 
        choose_homeostaticmodule_cells(population, modulesize, rng; moranincludeself)
    _, nextID = celldivision!(cellmodule, parentcell, t, nextID, μ, mutationdist, rng)
    celldeath!(cellmodule, deadcell, t, μ, mutationdist, rng)
    updatetime!(cellmodule, t)
    return population, nextID
end

"""
    asymmetricupdate!(population, modulesize, t, nextID, μ, mutationdist, rng)

Selects a homeostatic module uniformly at random to undergo a single asymmetric update. From 
that module one cell divides, producing a single offspring.
"""
function asymmetricupdate!(population, modulesize, t, nextID, μ, mutationdist, rng)
    cellmodule, parentcell =
        choose_homeostaticmodule_cells(population, modulesize, rng; twocells=false)
    _, nextID = celldivision!(cellmodule, parentcell, t, nextID, μ, mutationdist, rng; nchildcells=1)
    updatetime!(cellmodule, t)
    return population, nextID
end


"""
    birthupdate!(population, modulesize, t, nextID, μ, mutationdist, rng)

Selects a cell uniformly at random from all cells in non-homeostatic modules to divide.
"""
function birthupdate!(population, modulesize, t, nextID, μ, mutationdist, rng)
    cellmodule, parentcell = 
        choose_growingmodule_cell(population, modulesize, rng)
    _, nextID = celldivision!(cellmodule, parentcell, t, nextID, μ, mutationdist, rng)
    updatetime!(cellmodule, t)
    return population, nextID
end


"""
    deathupdate!(population, modulesize, t, rng)

Selects a cell uniformly at random from all cells in non-homeostatic modules to die. If 
cell death results in an empty module, remove that module from the population.
"""

function deathupdate!(population, modulesize, t, μ, mutationdist, rng)
    cellmodule, deadcell = 
        choose_growingmodule_cell(population, modulesize, rng)
    celldeath!(cellmodule, deadcell, t, μ, mutationdist, rng)
    updatetime!(cellmodule, t)
    if length(cellmodule) == 0
        moduledeath!(population, cellmodule, t, μ, mutationdist, rng)
    end
    return population
end

"""
    modulebranchingupdate!(population, modulesize, branchinitsize, t, rng)
Select a homeostatic module, uniformly at random, to undergo branching. Cells are sampled 
(number of cells giving by `branchinitsize`) from the parent module to form a new module, 
which is added to `population`
"""
function modulebranchingupdate!(population, nextmoduleID, modulesize, branchinitsize, t, rng; 
    modulebranching=:split, nextID=nothing, μ=nothing, mutationdist=nothing)
    
    parentmodule, = choose_homeostaticmodule(population, modulesize, rng)
    parentmodule, newmodule, nextID = 
        modulesplitting!(parentmodule, nextmoduleID, branchinitsize, t, rng; 
            modulebranching, nextID, μ, mutationdist)
    push!(population, newmodule)
    return population, nextmoduleID + 1, nextID
end

function modulemoranupdate!(population, nextmoduleID, modulesize, branchinitsize, t, rng; 
    modulebranching=:split, nextID=nothing, μ=nothing, mutationdist=nothing)

    parentmodule, = choose_homeostaticmodule(population, modulesize, rng)
    parentmodule, newmodule, nextID = 
        modulesplitting!(parentmodule, nextmoduleID, branchinitsize, t, rng; 
            modulebranching, nextID, μ, mutationdist)
    push!(population, newmodule)
    deadmodule = rand(rng, population)
    moduledeath!(population, deadmodule, t, μ, mutationdist, rng)
    return population, nextmoduleID + 1, nextID
end

function modulesplitting!(parentmodule, nextmoduleID, branchinitsize::Int, t, rng; 
        modulebranching=:split, nextID=nothing, μ=nothing, mutationdist=nothing)
    if modulebranching == :withreplacement
        return sample_new_module_with_replacement!(parentmodule, nextmoduleID, 
            branchinitsize, t, nextID, μ, mutationdist, rng)
    elseif modulebranching == :withoutreplacement
        return sample_new_module_without_replacement!(parentmodule, nextmoduleID, 
            branchinitsize, t, nextID, μ, mutationdist, rng)
    elseif modulebranching == :withreplacement_nomutations
                return sample_new_module_with_replacement!(parentmodule, nextmoduleID, 
                    branchinitsize, t, nextID, 0, :fixed, rng)
    elseif modulebranching == :withoutreplacement_nomutations
        return sample_new_module_without_replacement!(parentmodule, nextmoduleID, 
            branchinitsize, t, nextID, 0, :fixed, rng)
    elseif modulebranching == :split
        cellmodule, newcellmodule =
            sample_new_module_split!(parentmodule, nextmoduleID, 
                branchinitsize, t, rng)
        return cellmodule, newcellmodule, nextID
    else error("$modulebranching is not a valid module branching option")
    end
end

"""
    sample_new_module_with_replacement!(cellmodule, newmoduleid, branchinitsize, branchtime, 
        rng::AbstractRNG)

Sample cells with replacement, uniformly at random, from `cellmodule`. Each of these cells 
divides, with one offspring remaining in `cellmodule`, the other becoming part of the new 
module. 

The number of cells is given by `branchinitsize` and the newmodule is given initial time
`branchtime`.

"""
function sample_new_module_with_replacement!(cellmodule, nextmoduleID, branchinitsize, 
    branchtime, nextID, μ, mutationdist, rng::AbstractRNG)

    ncells = length(cellmodule.cells)
    newcells = eltype(cellmodule.cells)[]
    for i in 1:branchinitsize
        randcellid = rand(rng, 1:ncells)
        cellmodule, nextID = 
            celldivision!(cellmodule, randcellid, branchtime, nextID, μ, mutationdist, rng)
        newcell = pop!(cellmodule.cells)
        push!(newcells, newcell)
    end        

    newcellmodule = 
        new_module_from_cells(newcells, branchtime, [branchtime], cellmodule.subclones, nextmoduleID, 
            cellmodule.id, cellmodule.structure)
    updatetime!(cellmodule, branchtime)
    push!(cellmodule.branchtimes, branchtime)
    return cellmodule, newcellmodule, nextID
end

"""
    sample_new_module_without_replacement!(cellmodule::T, nextmoduleID, branchinitsize, 
    branchtime, nextID, μ, mutationdist, rng::AbstractRNG) where T<: AbstractModule

Sample cells without replacement, uniformly at random, from `cellmodule`. Each of these 
cells divides, with one offspring remaining in `cellmodule`, the other becoming part of the 
new module. 

The number of cells is given by `branchinitsize` and the newmodule is given initial time
`branchtime`.

"""
function sample_new_module_without_replacement!(cellmodule, nextmoduleID, branchinitsize, 
    branchtime, nextID, μ, mutationdist, rng::AbstractRNG)

    sampleids = sample(rng, 1:length(cellmodule.cells), branchinitsize, replace=false)
    newcells = eltype(cellmodule.cells)[]
    for cellid in sampleids
        cellmodule, nextID = 
            celldivision!(cellmodule, cellid, branchtime, nextID, μ, mutationdist, rng)
        newcell = pop!(cellmodule.cells)
        push!(newcells, newcell)
    end        

    newcellmodule = 
        new_module_from_cells(newcells, branchtime, [branchtime], cellmodule.subclones, nextmoduleID, 
            cellmodule.id, cellmodule.structure)
    updatetime!(cellmodule, branchtime)
    push!(cellmodule.branchtimes, branchtime)

    return cellmodule, newcellmodule, nextID
end

"""
    sample_new_module_split!(cellmodule::T, nextmoduleID, branchinitsize, branchtime, 
    rng::AbstractRNG) where T<: AbstractModule

Sample cells without replacement, uniformly at random, from `cellmodule` to form the new 
module. Remaining cells form the parent module.

The number of cells is given by `branchinitsize` and the newmodule is given initial time
`branchtime`.

"""
function sample_new_module_split!(cellmodule, nextmoduleID, branchinitsize, branchtime, 
    rng::AbstractRNG)

    sampleids = sample(rng, 1:length(cellmodule.cells), branchinitsize, replace=false)
    newcellmodule = 
        new_module_from_cells(cellmodule.cells[sampleids], branchtime, [branchtime], cellmodule.subclones, nextmoduleID, 
            cellmodule.id, cellmodule.structure)
    updatetime!(cellmodule, branchtime)
    push!(cellmodule.branchtimes, branchtime)
    cellremoval!(cellmodule, sampleids)

    return cellmodule, newcellmodule
end


"""
    choose_homeostaticmodule(population, maxmodulesize, rng::AbstractRNG)
Select a homeostatic module, i.e. module of size `maxmodulesize`, uniformly at random.
"""
function choose_homeostaticmodule(population, maxmodulesize, rng::AbstractRNG)
    modulesizes = map(length, population)
    homeostatic_module_ids = findall(x -> x .== maxmodulesize, modulesizes)
    homeostatic_module_id = rand(rng, homeostatic_module_ids)
    return population[homeostatic_module_id], homeostatic_module_id
end

"""
    choose_homeostaticmodule_cells(population, maxmodulesize, rng::AbstractRNG)
Select a homeostatic module and the ids of two cells from the module, uniformly at random.
"""
function choose_homeostaticmodule_cells(population, maxmodulesize, rng::AbstractRNG; twocells=true, moranincludeself=true)
    chosenmodule, chosenmodule_id = choose_homeostaticmodule(population, maxmodulesize, rng)
    dividecellidx = rand(rng, 1:maxmodulesize) 
    deadcellidx = begin 
        if !twocells
            deadcellidx = nothing
        elseif moranincludeself 
            deadcellidx = rand(rng, 1:maxmodulesize)
            #if dead cell and divide cell are the same kill one of the offspring
            deadcellidx = deadcellidx == dividecellidx ? maxmodulesize + 1 : deadcellidx
        else
            #exclude dividecellidx
            deadcellidx = rand(rng, deleteat!(collect(1:maxmodulesize), dividecellidx))
        end
    end
    return chosenmodule, dividecellidx, deadcellidx, chosenmodule_id
end

"""
    choose_growingmodule_cells(population, maxmodulesize, rng::AbstractRNG)
Select a cell uniformly at random from all cells in growing (non-homeostatic) modules, and
return the module and cell id.
"""
function choose_growingmodule_cell(population, maxmodulesize, rng::AbstractRNG)
    modulesizes = map(length, population)
    moduleids = collect(1:length(population))[modulesizes .< maxmodulesize]
    modulesizes = modulesizes[modulesizes .< maxmodulesize]
    chosenmoduleid = sample(rng, moduleids, ProbabilityWeights(modulesizes ./ sum(modulesizes)))
    chosenmodule = population[chosenmoduleid]
    chosencell = rand(rng, 1:length(chosenmodule))
    return chosenmodule, chosencell, chosenmoduleid
end

"""
    get_transitionrates(population, birthrate, deathrate, moranrate, branchrate, modulesize)
Compute the rates for moran update, cell division, death and module branching and return as 
a Vector.
"""
function get_transitionrates(population, birthrate, deathrate, moranrate, asymmetricrate, branchrate, modulesize)
    rates = zeros(Float64, 5)
    number_homeostatic_modules = 0
    for (i, cellmodule) in enumerate(population)
        N = length(cellmodule)
        if N < modulesize
            rates[3] += N * birthrate
            rates[4] += N * deathrate
        elseif N == modulesize
            number_homeostatic_modules += 1
        else 
            error("module size exceeds homeostatic size")
        end
    end
    rates[1] = number_homeostatic_modules * moranrate * modulesize
    rates[2] = number_homeostatic_modules * asymmetricrate * modulesize
    rates[5] = number_homeostatic_modules * branchrate
    return rates
end

function update_transitionrates!(rates, population, birthrate, deathrate, moranrate, asymmetricrate, branchrate, modulesize)
    rates[3] = rates[4] = 0
    number_homeostatic_modules = 0
    for (i, cellmodule) in enumerate(population)
        N = length(cellmodule)
        if N < modulesize
            rates[3] += N * birthrate
            rates[4] += N * deathrate
        elseif N == modulesize
            number_homeostatic_modules += 1
        else 
            error("module size exceeds homeostatic size")
        end
    end
    rates[1] = number_homeostatic_modules * moranrate * modulesize
    rates[2] = number_homeostatic_modules * asymmetricrate * modulesize
    rates[5] = number_homeostatic_modules * branchrate
    return rates
end

"""
    moduledeath!(population, cellmodule)
Kill all live cells in `cellmodule` and remove it from `population`.
    """
function moduledeath!(population, cellmodule, t, μ, mutationdist, rng)
    length(cellmodule) == 0 || killallcells!(cellmodule.cells, t, μ, mutationdist, rng)
    return deleteat!(population, findall(x->x==cellmodule, population))
end

function moduledeath!(population, cellmodule)
    @assert length(cellmodule) == 0 "trying to delete non-empty module"
    return deleteat!(population, findall(x->x==cellmodule, population))
end

killallcells!(population::CellVector, args...) = nothing

getnextID(population::Vector{CellModule{S}}) where S = maximum(map(x->getnextID(x.cells), population))

function getnextID(population::Vector{TreeModule{T,S}}) where {T,S}
    nextID = 1
    for treemodule in population
        for cellnode in treemodule.cells
            if id(cellnode) + 1 > nextID
                nextID = id(cellnode) + 1
            end
        end
    end
    return nextID
end