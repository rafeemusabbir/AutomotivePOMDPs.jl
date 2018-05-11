module AutomotivePOMDPs

using POMDPs, StatsBase, POMDPToolbox, DeepRL, Parameters, GridInterpolations
using AutomotiveDrivingModels, AutoUrban, AutoViz
using Reel

# helpers
export
        # for rendering
        animate_hist,
        animate_record,
        animate_scenes,
        IDOverlay,

        # helpers
        get_lane,
        get_end,
        get_lanes,
        get_start_lanes,
        get_exit_lanes,
        get_ego,
        is_crash,
        random_route,
        is_observable_dyna,
        is_observable_fixed,
        off_the_grid,
        get_conflict_lanes,
        get_colors,
        next_car_id,
        next_ped_id,
        EGO_ID

include("constants.jl")
include("utils/helpers.jl")
include("utils/occlusions.jl")
include("utils/rendering.jl")

# envs
export
    OccludedEnv,
    CrosswalkParams,
    CrosswalkEnv,
    TInterParams,
    IntersectionEnv,
    SimpleInterParams,
    SimpleInterEnv,
    gen_T_roadway,
    UrbanParams,
    UrbanEnv,
    ObstacleDistribution,
    sample_obstacles!,
    empty_obstacles!,
    add_obstacle!

include("envs/occluded_crosswalk_env.jl")
include("envs/multi_lane_T_env.jl")
include("envs/urban_env.jl")
include("envs/obstacles.jl")
include("envs/rendering.jl")

# driver models and action types
export
    action_space,
    get_distribution,
    ConstantPedestrian,
    ConstantSpeedDawdling,
    IntelligentDriverModel2D,
    KeepLaneAcc,
    RouteFollowingIDM,
    set_direction!,
    LonAccelDirection,
    CrosswalkDriver,
    StopIntersectionDriver,
    TTCIntersectionDriver,
    UrbanDriver,
    LidarOverlay

include("driver_models/route_following_idm.jl")
include("driver_models/stop.jl")
include("driver_models/stop_intersection_driver.jl")
include("driver_models/ttc_intersection_driver.jl")
include("driver_models/constant_pedestrian.jl")
include("driver_models/crosswalk_driver.jl")
include("driver_models/urban_driver.jl")
include("driver_models/lidar_sensor.jl")

export
    # pomdp types
    OCPOMDP,
    OCAction,
    OCState,
    OCObs,
    SingleOCPOMDP,
    SingleOCAction,
    SingleOCState,
    SingleOCObs,
    SingleOCBelief,
    SingleOCDistribution,
    SingleOCUpdater,
    OIPOMDP,
    OIAction,
    OIState,
    OIObs,
    SingleOIPOMDP,
    SingleOIAction,
    SingleOIState,
    SingleOIObs,
    state_to_scene,
    UrbanPOMDP,
    UrbanState,
    UrbanAction,
    UrbanObs,
    initial_car,
    initial_pedestrian,
    initial_ego,
    obs_weight,
    rescale!,
    unrescale!,
    obs_to_scene

# single crosswalk
include("single_crosswalk/pomdp_types.jl")
include("single_crosswalk/spaces.jl")
include("single_crosswalk/transition.jl")
include("single_crosswalk/observation.jl")
include("single_crosswalk/belief.jl")
include("single_crosswalk/adm_helpers.jl")
include("single_crosswalk/render_helpers.jl")

# multi crowsswalk
include("multi_crosswalk/pomdp_types.jl")
include("multi_crosswalk/generative_model.jl")
include("multi_crosswalk/render_helpers.jl")

# single intersection
include("single_intersection/occluded_intersection_env.jl")
include("single_intersection/pomdp_types.jl")
include("single_intersection/spaces.jl")
include("single_intersection/transition.jl")
include("single_intersection/observation.jl")
include("single_intersection/belief.jl")
include("single_intersection/render_helpers.jl")

# multi intersection
include("multi_lane_T_intersection/pomdp_types.jl")
include("multi_lane_T_intersection/generative_model.jl")
include("multi_lane_T_intersection/render_helpers.jl")

#urban
include("urban/pomdp_types.jl")
include("urban/generative_model.jl")
include("urban/render_helpers.jl")

export
    # decomposition stuff
    TwoCars,
    PedCar,
    ObsPed,
    ObsCar,
    TwoCarsScenario,
    PedCarScenario,
    ObsPedScenario,
    ObsCarScenario,
    decompose_input,
    DecomposedPolicy,
    KMarkovDecUpdater,
    KMarkovDecBelief,
    PreviousObsDecUpdater,
    PreviousObsDecBelief,
    initialize_dec_belief,
    BeliefOverlay

include("decomposition/base_scenarios.jl")
include("decomposition/decomposition_wrapper.jl")
include("decomposition/rendering.jl")



end