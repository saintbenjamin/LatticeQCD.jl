module Transform_oldinputfile
import ..Parameter_structs:
    Print_Physical_parameters,
    Print_Fermions_parameters,
    Print_System_control_parameters,
    Print_HMCrelated_parameters,
    construct_printable_parameters_fromdict!,
    remove_default_values!,
    struct2dict,
    initialize_fermion_parameters,
    Measurement_parameters,
    initialize_measurement_parameters,
    generate_printlist

using TOML

function default_system()
    system = Dict()
    system["Dirac_operator"] = "Wilson"
    system["quench"] = false
    system["initial"] = "cold"
    system["BoundaryCondition"] = [1, 1, 1, -1]
    system["Nwing"] = 1
    system["randomseed"] = 111

    system["verboselevel"] = 2

    system["saveU_format"] = "JLD"
    system["saveU_every"] = 1
    system["saveU_dir"] = "./confs"

    system["initialtrj"] = 1

    system["update_method"] = "HMC"
    system["isevenodd"] = true

    system["Nsteps"] = 100
    system["Nthermalization"] = 0

    system["julian_random_number"] = false
    return system
end

function default_md()
    md = Dict()
    md["Δτ"] = 0.05
    md["MDsteps"] = 20
    md["SextonWeingargten"] = false

    return md
end

function default_defaultmeasures()
    defaultmeasures = Array{Dict,1}(undef, 2)
    for i = 1:length(defaultmeasures)
        defaultmeasures[i] = Dict()
    end
    defaultmeasures[1]["methodname"] = "Plaquette"
    defaultmeasures[1]["measure_every"] = 1
    defaultmeasures[1]["fermiontype"] = nothing
    defaultmeasures[2]["methodname"] = "Polyakov_loop"
    defaultmeasures[2]["measure_every"] = 1
    defaultmeasures[2]["fermiontype"] = nothing

    return defaultmeasures
end


function default_actions()
    actions = Dict()

    actions["use_autogeneratedstaples"] = false
    #actions["couplinglist"] = []
    actions["couplingcoeff"] = []
    actions["coupling_loops"] = nothing
    return actions
end

function default_cg()
    cg = Dict()
    cg["eps"] = 1e-19
    cg["MaxCGstep"] = 3000
    return cg
end

function default_wilson()
    wilson = Dict()
    wilson["r"] = 1
    wilson["Clover_coefficient"] = 1.5612

    return wilson
end

function default_staggered()
    staggered = Dict()
    staggered["Nf"] = 4
    return staggered
end

function default_measurement()
    measurement = Dict()
    measurement["measurement_methods"] = defaultmeasures
    return measurement
end

system = default_system()
md = default_md()
defaultmeasures = default_defaultmeasures()
actions = default_actions()
cg = default_cg()
wilson = default_wilson()
staggered = default_staggered()
measurement = default_measurement()

function transform_to_toml(filename)
    include(abspath(filename))


    physical = Print_Physical_parameters()
    fermions = Print_Fermions_parameters()
    control = Print_System_control_parameters()
    hmc = Print_HMCrelated_parameters()

    for (key, value) in system
        hasvalue = construct_printable_parameters_fromdict!(
            key,
            value,
            physical,
            fermions,
            control,
            hmc,
        )

    end

    for (key, value) in md
        hasvalue = construct_printable_parameters_fromdict!(
            key,
            value,
            physical,
            fermions,
            control,
            hmc,
        )

    end

    for (key, value) in cg
        hasvalue = construct_printable_parameters_fromdict!(
            key,
            value,
            physical,
            fermions,
            control,
            hmc,
        )
    end

    for (key, value) in wilson
        hasvalue = construct_printable_parameters_fromdict!(
            key,
            value,
            physical,
            fermions,
            control,
            hmc,
        )

    end

    for (key, value) in staggered
        hasvalue = construct_printable_parameters_fromdict!(
            key,
            value,
            physical,
            fermions,
            control,
            hmc,
        )
    end

    measurement_dict = Dict()
    for (key, value) in measurement
        if key == "measurement_methods"
            valuem = transform_measurement_dict(value)
            measurement_dict[key] = valuem
        else
            hasvalue = construct_printable_parameters_fromdict!(
                key,
                value,
                physical,
                fermions,
                control,
                hmc,
            )
        end
    end

    #println(control)

    #=
    display(physical)
    println("\t")
    display(fermions)
    println("\t")
    display(control)
    println("\t")
    display(hmc)
    println("\t")
    =#

    system_parameters_dict = Dict()

    system_parameters_dict["Physical setting"] = struct2dict(physical)
    system_parameters_dict["Physical setting(fermions)"] = struct2dict(fermions)
    system_parameters_dict["System Control"] = struct2dict(control)
    system_parameters_dict["HMC related"] = struct2dict(hmc)
    system_parameters_dict["Measurement set"] = measurement_dict
    #system_parameters_dict["Measurement set"] = struct2dict(measurement)

    #=
    display(system_parameters_dict)
    println("\t")
    =#

    #println(system_parameters_dict["System Control"])

    remove_default_values!(system_parameters_dict)

    #println(system_parameters_dict["System Control"])

    filename_toml = splitext(filename)[1] * ".toml"

    open(filename_toml, "w") do io
        TOML.print(io, system_parameters_dict)
    end

end

function transform_measurement_dict(value)
    #println(value)
    nummeasure = length(value)
    value_out = Vector{Measurement_parameters}(undef, nummeasure)
    for i = 1:nummeasure
        value_i = value[i]
        @assert haskey(value_i, "methodname") "methodname should be set in measurement."
        methodname = value_i["methodname"]
        method = initialize_measurement_parameters(methodname)
        method_dict = struct2dict(method)
        if haskey(value_i, "fermiontype")
            fermiontype = value_i["fermiontype"]
        else
            fermiontype = "nothing"

        end
        fermion_parameters = initialize_fermion_parameters(fermiontype)
        fermion_parameters_dict = struct2dict(fermion_parameters)

        for (key_ii, value_ii) in value_i
            #println("$key_ii $value_ii")
            if haskey(method_dict, key_ii)
                keytype = typeof(getfield(method, Symbol(key_ii)))
                setfield!(method, Symbol(key_ii), keytype(value_ii))
            else
                if haskey(fermion_parameters_dict, key_ii)
                    #println("fermion $key_ii $value_ii")
                    keytype = typeof(getfield(fermion_parameters, Symbol(key_ii)))
                    setfield!(fermion_parameters, Symbol(key_ii), keytype(value_ii))
                else
                    @warn "$key_ii is not found!"
                end
            end
        end

        if haskey(method_dict, "fermion_parameters")
            setfield!(method, Symbol("fermion_parameters"), fermion_parameters)
        end
        value_out[i] = deepcopy(method)
    end

    #println("--------------------")
    #println(value_out)
    return value_out
end



function demo_transform()
    filename = "demo.jl"
    transform_to_toml(filename)
end




#demo_transform()

end
