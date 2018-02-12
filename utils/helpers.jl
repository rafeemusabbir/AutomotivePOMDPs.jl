# Some useful function for the multiple user occluded crosswalk environment


#### POMDP related stuff #################################################################################
# Dummy type since the action is given by the policy
mutable struct EgoDriver{A} <: DriverModel{A}
    a::A
end

Base.rand(model::EgoDriver) = model.a

mutable struct GenerativeDist
    problem::POMDP
end

function Base.rand(rng::AbstractRNG, d::GenerativeDist)
    return initial_state(d.problem, rng)
end


"""
    is_crash(scene::Scene)
return true if the ego car is in collision in the given scene, do not check for collisions between
other participants
"""
function is_crash(scene::Scene)
    ego = scene[findfirst(scene, EGO_ID)]
    for veh in scene
        if veh.id != 1
            if is_colliding(ego, veh)
                return true
            end
        end
    end
    return false
end

"""
Remove vehicles that have reached an end scene or that have collided
"""
function clean_scene!(env::OccludedEnv, scene::Scene)
    exit_lanes = get_exit_lanes(env.roadway)
    for veh in scene
        if veh.id == 1
            continue
        end
        s = veh.state.posF.s
        lane = get_lane(env.roadway, veh)
        s_end = get_end(lane)
        if s >= s_end && lane ∈ exit_lanes
            deleteat!(scene, findfirst(scene, veh.id))
        end
    end
    for veh in scene
        # if veh.id == 1; continue; end
        # fore = get_neighbor_fore_along_lane(scene, findfirst(scene, veh.id), env.roadway,
        #                                     VehicleTargetPointFront(), VehicleTargetPointRear(), VehicleTargetPointFront())
        # if fore.ind != 0
        #     headway, v_oth = fore.Δs, scene[fore.ind].state.v
        # else
        #     headway, v_oth = NaN, NaN
        # end
        # if !isnan(headway) && headway < 0.
        #     deleteat!(scene, findfirst(scene, veh.id))
        # end
        for veh_ in scene
            if is_colliding(veh, veh_) && veh.id != 1 && veh_.id != 1 && veh.id != veh_.id
                deleteat!(scene, findfirst(scene, veh_.id))
            end
        end
    end
end


"""
Heuristic to check if a vehicle can be added to a given scene
"""
function can_push(env, scene::Scene, car::Vehicle, delta_headway::Float64 = 2.0)
    car_lane = get_lane(env.roadway, car)
    min_headway = Inf
    headway = min_headway
    for veh in scene
        if is_colliding(car, veh) || car.id == veh.id
            return false
        end
        veh_lane = get_lane(env.roadway, veh)
        if veh_lane == car_lane
            headway = veh.state.posF.s - car.state.posF.s
        end
        if headway <= min_headway
            min_headway = headway
        end
    end
    if min_headway < delta_headway
        return false
    end
    return true
end


"""
return the ego vehicle from a given scene
"""
function get_ego(scene::Scene)
    return scene[findfirst(scene, EGO_ID)]
end


### ROADWAY STUFF


function get_lane(roadway::Roadway, vehicle::Vehicle)
    lane_tag = vehicle.state.posF.roadind.tag
    return roadway[lane_tag]
end
function get_lane(roadway::Roadway, vehicle::VehicleState)
    lane_tag = vehicle.posF.roadind.tag
    return roadway[lane_tag]
end

function get_end(lane::Lane)
    s_end = round(lane.curve[end].s)
    if s_end % 2 == 1
        s_end -= 1
    end
    return s_end
end



"""
Generate a random route starting from start_lane to a random end node
"""
function random_route(rng::AbstractRNG, roadway::Roadway, start_lane::Lane)
    lanes = Lane[start_lane]
    cur_lane = start_lane
    while !isempty(cur_lane.exits)
        rand_exit = rand(rng, cur_lane.exits)
        next_lane_tag = rand_exit.target.tag
        next_lane = env.roadway[next_lane_tag]
        push!(lanes, next_lane)
        cur_lane = next_lane
    end
    return lanes
end

"""
return the list of entrance lanes, i.e. the one that does not have any entrances
"""
function get_start_lanes(roadway::Roadway)
    lanes = Lane[]
    for i=1:length(roadway.segments)
        for lane in roadway.segments[i].lanes
            if isempty(lane.entrances)
                push!(lanes, lane)
            end
        end
    end
    return lanes
end

function get_lanes(roadway::Roadway)
    lanes = Lane[]
    for i=1:length(roadway.segments)
        for lane in roadway.segments[i].lanes
            push!(lanes, lane)
        end
    end
    return lanes
end

"""
return the list of exit lanes, i.e. the one that does not have any exits
"""
function get_exit_lanes(roadway::Roadway)
    lanes = Lane[]
    for i=1:length(roadway.segments)
        for lane in roadway.segments[i].lanes
            if isempty(lane.exits)
                push!(lanes, lane)
            end
        end
    end
    return lanes
end

"""
Given a list of lanes returns the list of exits
"""
function get_exit_lanes(lanes::Vector{Lane}, roadway::Roadway)
    exits = Lane[]
    for lane in lanes
        for exit in lane.exits
            tag = exit.target.tag
            new_exit = roadway[tag]
            if !(new_exit ∈ exits)
                push!(exits, new_exit)
            else
                continue
            end
        end
    end
    return exits
end

mutable struct LonAccelDirection
    a_lon::Float64
    direction::Int
end


function AutomotiveDrivingModels.propagate{D<:Union{VehicleDef, BicycleModel}}(veh::Entity{VehicleState, D, Int}, action::LonAccelDirection,  roadway::Roadway, Δt::Float64)
    previousInd = veh.state.posF.roadind
    a_lon = action.a_lon
    v = veh.state.v
    a_lat = 0.

    v = veh.state.v
       ϕ = veh.state.posF.ϕ
      ds = v*cos(ϕ)
       t = veh.state.posF.t
      dt = v*sin(ϕ)

      ΔT = Δt
      ΔT² = ΔT*ΔT
      Δs = ds*ΔT + 0.5*a_lon*ΔT²
      Δs = max(0, Δs) # no backup
      Δt = dt*ΔT + 0.5*a_lat*ΔT²

      ds₂ = ds + a_lon*ΔT
    ds₂ = max(0, ds₂) # no backup
      dt₂ = dt + a_lat*ΔT
      speed₂ = sqrt(dt₂*dt₂ + ds₂*ds₂)
      v₂ = sign(ds₂)*speed₂
      ϕ₂ = atan2(dt₂, ds₂) + (v₂ < 0.0)*π # handle negative speeds
      roadind = AutoUrban.move_along_with_direction(veh.state.posF.roadind, roadway, Δs, direction = action.direction)
      footpoint = roadway[roadind]
      posF = Frenet(roadind, roadway, t=t+Δt, ϕ = ϕ₂)
      # posG = convert(VecE2, footpoint.pos) + polar(t + Δt, footpoint.pos.θ + π/2)
      # posG = VecSE2(posG.x, posG.y, footpoint.pos.θ + ϕ₂)

    state = VehicleState(posF, roadway, v₂)
    # state = VehicleState(posG, roadway[roadind.tag], roadway, v₂)
    return state
end

mutable struct LonAccel
    a_lon::Float64
end

function AutomotiveDrivingModels.propagate{D<:Union{VehicleDef, BicycleModel}}(veh::Entity{VehicleState, D, Int}, action::LonAccel,  roadway::Roadway, Δt::Float64)
    a_lat = action.a_lat
   a_lon = action.a_lon

    v = veh.state.v
    ϕ = veh.state.posF.ϕ
   ds = v*cos(ϕ)
    t = veh.state.posF.t
   dt = v*sin(ϕ)

   ΔT² = ΔT*ΔT
   Δs = ds*ΔT + 0.5*a_lon*ΔT²
   Δt = dt*ΔT + 0.5*a_lat*ΔT²

   ds₂ = ds + a_lon*ΔT
   dt₂ = dt + a_lat*ΔT
   speed₂ = sqrt(dt₂*dt₂ + ds₂*ds₂)
   v₂ = sqrt(dt₂*dt₂ + ds₂*ds₂) # v is the magnitude of the velocity vector
   ϕ₂ = atan2(dt₂, ds₂)

   roadind = move_along(veh.state.posF.roadind, roadway, Δs)
   footpoint = roadway[roadind]

   posG = convert(VecE2, footpoint.pos) + polar(t + Δt, footpoint.pos.θ + π/2)

   posG = VecSE2(posG.x, posG.y, footpoint.pos.θ + ϕ₂)

   return VehicleState(posG, roadway, v₂)
end
