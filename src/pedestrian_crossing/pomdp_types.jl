

"""
Representation of a state for the SingleOCcludedCrosswalk POMDP,
depends on ADM VehicleState type
"""

#### State type

 struct SingleOCFState
    ego_y::Float64
    ego_v::Float64    
    ped_s::Float64
    ped_T::Float64
    ped_theta::Float64
    ped_v::Float64
end

struct SingleOCFPedState   
    ped_s::Float64
    ped_T::Float64
    ped_theta::Float64
    ped_v::Float64
end

#### Action type

 struct SingleOCFAction
    acc::Float64
    lateral_movement::Float64
end

#### Observaton type

const SingleOCFObs = SingleOCFState




#### POMDP type

@with_kw mutable struct SingleOCFPOMDP <: POMDP{SingleOCFState, SingleOCFAction, SingleOCFObs}
    env::CrosswalkEnv = CrosswalkEnv()
    ego_type::VehicleDef = VehicleDef()
    ped_type::VehicleDef = VehicleDef(AgentClass.PEDESTRIAN, 1.0, 1.0)
    longitudinal_actions::Vector{Float64} = [1.0, 0.0, -1.0, -2.0, -4.0]
    lateral_actions::Vector{Float64} = [1.0, 0.0, -1.0]
    ΔT::Float64 = 0.5
    PED_A_RANGE::Vector{Float64} = linspace(-2.0, 2.0, 5)
    PED_THETA_NOISE::Vector{Float64} = [0]#linspace(-0.39/2., 0.39/2., 3)
    PED_SAFETY_DISTANCE::Float64 = 1.0
    
    EGO_Y_MIN::Float64 = -1.
    EGO_Y_MAX::Float64 = 1.
    EGO_Y_RANGE::Vector{Float64} = [0] #linspace(EGO_Y_MIN, EGO_Y_MAX, 5)

    EGO_V_MIN::Float64 = 0.
    EGO_V_MAX::Float64 = 14.
    EGO_V_RANGE::Vector{Float64} = linspace(EGO_V_MIN, EGO_V_MAX, 15)#29)

    S_MIN::Float64 = 0.
    S_MAX::Float64 = 50.
    S_RANGE::Vector{Float64} = linspace(S_MIN, S_MAX, 21)#51)

    T_MIN::Float64 = -5.
    T_MAX::Float64 = 5.
    T_RANGE::Vector{Float64} = linspace(T_MIN, T_MAX, 21)

    PED_V_MIN::Float64 = 0.
    PED_V_MAX::Float64 = 2.
    PED_V_RANGE::Vector{Float64} = linspace(PED_V_MIN, PED_V_MAX, 5)

    PED_THETA_MIN::Float64 = 1.57-1.57/2
    PED_THETA_MAX::Float64 = 1.57+1.57/2
    PED_THETA_RANGE::Vector{Float64} = [1.57] #linspace(PED_THETA_MIN, PED_THETA_MAX, 7)


    
    collision_cost::Float64 = -10.0
    action_cost_lon::Float64 = -1.0
    action_cost_lat::Float64 = -1.0
    goal_reward::Float64 = 10.0
    γ::Float64 = 0.99
    
    state_space_grid::GridInterpolations.RectangleGrid = initStateSpace(EGO_Y_RANGE, EGO_V_RANGE, S_RANGE, T_RANGE, PED_THETA_RANGE, PED_V_RANGE)

    state_space_ped::Vector{SingleOCFPedState} = initStateSpacePed(S_RANGE, T_RANGE, PED_THETA_RANGE, PED_V_RANGE)


    state_space::Vector{SingleOCFState} = getStateSpaceVector(state_space_grid)
    action_space::Vector{SingleOCFAction} = initActionSpace(longitudinal_actions, lateral_actions)

    absent::Bool = true
    obstacles::Vector{ConvexPolygon} = []
    ego_vehicle::Vehicle = Vehicle(VehicleState(VecSE2(0.0, 0.0, 0.0), 0.0), VehicleDef(), 1)

    desired_velocity::Float64 = 40.0 / 3.6

end


### REWARD MODEL ##################################################################################

function POMDPs.reward(pomdp::SingleOCFPOMDP, s::SingleOCFState, action::SingleOCFAction, sp::SingleOCFState) 
    
    r = 0.

        #object_b_def.length = object_b_def.length + pomdp.PED_SAFETY_DISTANCE
    #object_b_def.width  = object_b_def.width + pomdp.PED_SAFETY_DISTANCE

    if (action.acc > 0.0 && sp.ego_v > pomdp.desired_velocity )
        r += (-1)
    end

    if (action.lateral_movement == 1.0 && sp.ego_y > pomdp.EGO_Y_MAX )
        r += (-10)
    end

    if (action.lateral_movement == -1.0 && sp.ego_y < pomdp.EGO_Y_MIN )
        r += (-10)
    end

    collision = collision_checker(pomdp,sp)

    if collision
        r += pomdp.collision_cost
    end
    if sp.ped_s == 0
        r += pomdp.goal_reward
    end
 #   if !collision
 #       r += pomdp.goal_reward
 #   end

    if action.acc > 0. ||  action.acc < 0.0
        r += pomdp.action_cost_lon * abs(action.acc)^2
    end
        
    if abs(action.lateral_movement) > 0 
        r += pomdp.action_cost_lat * abs(action.lateral_movement)
    end
    
    return r
    
end




### HELPERS

function POMDPs.isterminal(pomdp::SingleOCFPOMDP, s::SingleOCFState)

    if collision_checker(pomdp,s)
        return true
    end
    
    if s.ped_s < 0
        return true
    end 
    
    return false
end


function POMDPs.discount(pomdp::SingleOCFPOMDP)
    return pomdp.γ
end


function AutomotivePOMDPs.collision_checker(pomdp::SingleOCFPOMDP, s::SingleOCFState)
    
    object_a_def = pomdp.ego_type
    object_b_def = pomdp.ped_type

    center_a = VecSE2(0, s.ego_y, 0)
    center_b = VecSE2(s.ped_s, s.ped_T, s.ped_theta)
    # first fast check:
    @fastmath begin
        Δ = sqrt((center_a.x - center_b.x)^2 + (center_a.y - center_b.y)^2)
        r_a = sqrt(object_a_def.length*object_a_def.length/4 + object_a_def.width*object_a_def.width/4)
        r_b = sqrt(object_b_def.length*object_b_def.length/4 + object_b_def.width*object_b_def.width/4)
    end
    if Δ ≤ r_a + r_b
        # fast check is true, run parallel axis theorem
        Pa = AutomotivePOMDPs.polygon(center_a, object_a_def)
        Pb = AutomotivePOMDPs.polygon(center_b, object_b_def)
        return AutomotivePOMDPs.overlap(Pa, Pb)
    end
    return false
end



function initStateSpace(EGO_Y_RANGE, EGO_V_RANGE, S_RANGE, T_RANGE, PED_THETA_RANGE, PED_V_RANGE)
    
    return RectangleGrid(EGO_Y_RANGE, EGO_V_RANGE, S_RANGE, T_RANGE, PED_THETA_RANGE, PED_V_RANGE) 
end

function initStateSpacePed(S_RANGE, T_RANGE, PED_THETA_RANGE, PED_V_RANGE)

    ped_grid = RectangleGrid(S_RANGE, T_RANGE, PED_THETA_RANGE, PED_V_RANGE) 
    state_space_ped = SingleOCFPedState[]
    
    for i = 1:length(ped_grid)
        s = ind2x(ped_grid,i)
        push!(state_space_ped,SingleOCFPedState(s[1], s[2], s[3], s[4]))
    end
    # add absent state
    push!(state_space_ped,SingleOCFPedState(-10., -10., 0., 0.))
    return state_space_ped
end


function getStateSpaceVector(grid_space)
    
    state_space = SingleOCFState[]
    
    for i = 1:length(grid_space)
        s = ind2x(grid_space,i)
        push!(state_space,SingleOCFState(s[1], s[2], s[3], s[4], s[5], s[6]))
    end

    # add absent state
    push!(state_space,SingleOCFState(0., 0., -10., -10., 0., 0.))
    return state_space
end


function initActionSpace(longitudinal_actions, lateral_actions)
    
  action_space = SingleOCFAction[]

  for lat_a in lateral_actions
    for lon_a in longitudinal_actions
      push!(action_space, SingleOCFAction(lon_a, lat_a))
    end
  end

  return action_space
    
end

function getEgoDataInStateSpace(pomdp::SingleOCFPOMDP, y::Float64, v::Float64)
    y_grid = RectangleGrid(pomdp.EGO_Y_RANGE)
    (id, weight) = interpolants(y_grid, [y])
    id_max = indmax(weight)
    ego_y = ind2x(y_grid, id[id_max])[1]
    
    v_grid = RectangleGrid(pomdp.EGO_V_RANGE)
    (id, weight) = interpolants(v_grid, [v])
    id_max = indmax(weight)
    ego_v = ind2x(v_grid, id[id_max])[1]
    return ego_y, ego_v
end


#=
mdp = UnderlyingMDP(pomdp)
struct OCMDPPolicy <: Policy
    policy::AlphaVectorPolicy
    pomdp::SingleOCFPOMDP
end

function POMDPs.action(policy::OCMDPPolicy, s::SingleOCFState)
    si = state_index(policy.pomdp, s)
    ai = indmax(policy.policy.alphas[si])
    a = actions(policy.pomdp, ai)
    return a
end

=#

#=
hr = HistoryRecorder()

s0 = 
hist = simulate(hr, mdp, policy, s0)
=#