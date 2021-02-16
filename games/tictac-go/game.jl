@debug("opening tictac-go game file")

import AlphaZero.GI
using StaticArrays
using Profile
const BOARD_SIDE = 5
const NUM_POSITIONS = BOARD_SIDE^2
const PlayerDict = Dict{Bool,String}(true=>"White",false=>"Black")
const Player = Bool
const WHITE = true
const BLACK = false

const Cell = Union{Nothing,Player}
const Board = SVector{NUM_POSITIONS,Cell}
const INITIAL_BOARD = Board(repeat([nothing], NUM_POSITIONS))
const INITIAL_STATE = (board=INITIAL_BOARD, curplayer=WHITE)

mutable struct Game <: GI.AbstractGame
    board::Board
    curplayer::Player
    function Game(state=INITIAL_STATE)
        new(state.board, state.curplayer)
    end
end

GI.State(::Type{Game}) = typeof(INITIAL_STATE)

GI.Action(::Type{Game}) = Int

GI.two_players(::Type{Game}) = true

#####
##### Defining helper functions, e.g. surrounded cells
#####
function get_neighbours(board, pos)
    #@debug("getting neighbours of cell $pos, namely $(board[pos])")
    #global BOARD_SIDE
    neighbours = Cell[]
    plus_one = pos + 1
    minus_one = pos - 1
    plus_side = pos + BOARD_SIDE
    minus_side = pos - BOARD_SIDE
    try
        push!(neighbours, board[minus_one])
        #@debug("minus_one = $(board[minus_one])")
    catch

    end
    try
        push!(neighbours, board[plus_side])
    catch
        #@debug("no right neighbour")
    end
    try
        push!(neighbours, board[plus_one])
    catch e
        #@debug("no bottom neighbour, error is $e")
    end
    try
        push!(neighbours, board[minus_side])
    catch
        #@debug("no left neighbour")
    end
    return neighbours
end
function check_equality(a, b)
    if a == b
        #@debug("$a equal to $b")
        return true
    else
        #@debug("$a not equal to $b")
        return false
    end
end

allsame(x) = all(y -> check_equality(first(x), y), x)

# function returning a board with removed surrounded stones
function stone_removal(board)
    for (index, cell) in enumerate(board)
        neighbours = get_neighbours(board, index)
        if cell == nothing
            continue
        end
        if allsame(neighbours) && !cell == first(neighbours)
            board = setindex(board, nothing, index)
        end
    end
    return board
end

# function to determine winning conditions better
function get_controlled_area(board, player)
    area = 0
    for (index, content) in enumerate(board)
        if content == player
            area += 1
            continue
        end
        neighbours = get_neighbours(board, index)
        if allsame(neighbours) && player == first(neighbours)
            area += 1
            continue
        end
    end
    return area
end

# test if `position` is playable by stones of `color`
function is_playable(board, pos, color)
    #@debug("checking if cell $pos is playable")
    #@debug("board = $board")
    if !isnothing(board[pos])
        # cell is full
        return false
    end
    neighbours = get_neighbours(board, pos)

    if allsame(neighbours)
        if color == first(neighbours) || first(neighbours) == nothing
            @debug "$pos playable, surrounded by same color/nothing"
            return true
        else
            @debug "$pos surrounded by enemy"
            return false
        end
    end
    return true
end

#####
##### Defining winning conditions
#####

pos_of_xy((x, y)) = (y - 1) * BOARD_SIDE + (x - 1) + 1

xy_of_pos(pos) = ((pos - 1) % BOARD_SIDE + 1, (pos - 1) ÷ BOARD_SIDE + 1)
#=
const ALIGNMENTS = let N = BOARD_SIDE
    let XY = [
            [[(i, j) for j = 1:N] for i = 1:N]
            [[(i, j) for i = 1:N] for j = 1:N]
            [[(i, i) for i = 1:N]]
            [[(i, N - i + 1) for i = 1:N]]
        ]
        [map(pos_of_xy, al) for al in XY]
    end
end
=#
function has_won(g::Game, player)
    if any((GI.actions_mask(g))) && any((GI.actions_mask(g,True)))
        return false
    end
    player_area(player) = get_controlled_area(g.board, player)
    @debug player_area(player)
    if player_area(player) > player_area(!player)
        #@info "$(PlayerDict[player]) has won, $(player_area(player)) against $(player_area(!player))"
        return true
    else
        #@info "$(PlayerDict[!player]) has won, $(player_area(!player)) against $(player_area(player))"
        return false
    end
end
#####
##### Game API
#####

const ACTIONS = collect(1:NUM_POSITIONS)

GI.actions(::Type{Game}) = ACTIONS

#Base.copy(g::Game) = Game(g.board, g.curplayer)

function GI.actions_mask(g::Game, manual_player=False) # = false)
    #@debug("curplayer = $(g.curplayer)")
    if !manual_player
        curplayer=g.curplayer
    else
        curplayer=!(g.curplayer)
    end
    mask = map(isnothing, g.board)
    mask = [
        is_playable(g.board, i, g.curplayer) for i = 1:length(g.board)
    ]
    #@debug("action mask for $(g.board) \n is $mask")
    return mask
end
#GI.actions_mask(g::Game) = map(isnothing, g.board)

GI.board(g::Game) = g.board

function GI.board_symmetric(g::Game)
    symmetric(c::Cell) = isnothing(c) ? nothing : !c
    # Inference fails when using `map`
    @SVector Cell[symmetric(g.board[i]) for i = 1:NUM_POSITIONS]
end

GI.white_playing(g::Game) = g.curplayer

function terminal_white_reward(g::Game)
    has_won(g, WHITE) && return 1.0
    has_won(g, BLACK) && return -1.0
    isempty(GI.available_actions(g)) && return 0.0
    return nothing
end

function GI.white_reward(g::Game)
  z = terminal_white_reward(g)
  return isnothing(z) ? 0. : z
end

function GI.play!(g::Game, pos)
    #tim = time_ns()
    #=
        prob = 0.1
        if rand() < prob
            if rand() < 0.1
                @debug()
                @debug(g.board)
                @debug(count(y -> typeof(y) == Bool, g.board))
            else
                @debug(count(y -> typeof(y) == Bool, g.board))
            end
        end
        =#
    g.board = setindex(g.board, g.curplayer, pos)
    #=
    Profile.init(delay = 0.001)
    Profile.clear()
    a=stone_removal(g.board)
    a=nothing
    @profile stone_removal(g.board)
    =#
    #tim2 = time_ns()
    g.board = stone_removal(g.board)
    #println("action and board $(time_ns()-tim) ns, board $(time_ns()-tim2)")
    #Profile.print()
    #exit(1)
    g.curplayer = !g.curplayer
end

#####
##### Simple heuristic for minmax
##### (not working yet)
#=
function alignment_value_for(g::Game, player, alignment)
    γ = 0.3
    N = 0
    for pos in alignment
        mark = g.board[pos]
        if mark == player
            N += 1
        elseif !isnothing(mark)
            return 0.0
        end
    end
    return γ^(BOARD_SIDE - 1 - N)
end

function heuristic_value_for(g::Game, player)
    return sum(alignment_value_for(g, player, al) for al in ALIGNMENTS)
end

function GI.heuristic_value(g::Game)
    mine = heuristic_value_for(g, g.curplayer)
    yours = heuristic_value_for(g, !g.curplayer)
    return mine - yours
end
=#
#####
##### Machine Learning API
#####

function flip_colors(board)
  flip(cell) = isnothing(cell) ? nothing : !cell
  # Inference fails when using `map`
  return @SVector Cell[flip(board[i]) for i in 1:NUM_POSITIONS]
end

# Vectorized representation: 3x3x3 array
# Channels: free, white, black
function GI.vectorize_state(::Type{Game}, state)
  board = GI.white_playing(Game, state) ? state.board : flip_colors(state.board)
  return Float32[
    board[pos_of_xy((x, y))] == c
    for x in 1:BOARD_SIDE,
        y in 1:BOARD_SIDE,
        c in [nothing, WHITE, BLACK]]
end

#####
##### Symmetries
##### temporarily disabled

function generate_dihedral_symmetries()
    N = BOARD_SIDE
    rot((x, y)) = (y, N - x + 1) # 90° rotation
    flip((x, y)) = (x, N - y + 1) # flip along vertical axis
    ap(f) = p -> pos_of_xy(f(xy_of_pos(p)))
    sym(f) = map(ap(f), collect(1:NUM_POSITIONS))
    rot2 = rot ∘ rot
    rot3 = rot2 ∘ rot
    return [
        sym(rot) #=,
        sym(rot2),
        sym(rot3),
        sym(flip),
        sym(flip ∘ rot),
        sym(flip ∘ rot2),
        sym(flip ∘ rot3), =#
    ]
end

const SYMMETRIES = generate_dihedral_symmetries()

function GI.symmetries(::Type{Game}, board)
    return [(board[sym], sym) for sym in SYMMETRIES]
end

#####
##### Interaction API
#####

function GI.action_string(::Type{Game}, a)
    string(Char(Int('A') + a - 1))
end

function GI.parse_action(g::Game, str)
    length(str) == 1 || (return nothing)
    x = Int(str[1]) - Int('A')
    (0 <= x < NUM_POSITIONS) ? x + 1 : nothing
end

function read_board(::Type{Game})
    n = BOARD_SIDE
    str = reduce(*, ((readline()*"   ")[1:n] for i = 1:n))
    white = ['w', 'r', 'o']
    black = ['b', 'b', 'x']
    function cell(i)
        if (str[i] ∈ white)
            WHITE
        elseif (str[i] ∈ black)
            BLACK
        else
            nothing
        end
    end
    @SVector [cell(i) for i = 1:NUM_POSITIONS]
end

function GI.read_state(::Type{Game})
    b = read_board(Game)
    nw = count(==(WHITE), b)
    nb = count(==(BLACK), b)
    if nw == nb
        Game(b, WHITE)
    elseif nw == nb + 1
        Game(b, BLACK)
    else
        nothing
    end
end

using Crayons

player_color(p) = p == WHITE ? crayon"white" : crayon"light_blue"
player_name(p) = p == WHITE ? "White" : "Black"
player_mark(p) = p == WHITE ? "w" : "b"

function GI.print_state(g::Game; with_position_names = true, botmargin = true)
    pname = player_name(g.curplayer)
    pcol = player_color(g.curplayer)
    println(GI.actions_mask(g)) #, false))
    print(pcol, pname, " plays:", crayon"reset", "\n\n")
    for y = 1:BOARD_SIDE
        for x = 1:BOARD_SIDE
            pos = pos_of_xy((x, y))
            c = g.board[pos]
            if isnothing(c)
                print(" ")
            else
                print(player_color(c), player_mark(c), crayon"reset")
            end
            print(" ")
        end
        if with_position_names
            print(" | ")
            for x = 1:BOARD_SIDE
                print(GI.action_string(Game, pos_of_xy((x, y))), " ")
            end
        end
        print("\n")
    end
    botmargin && print("\n")
end
