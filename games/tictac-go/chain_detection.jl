const Player = Bool
const WHITE = true
const BLACK = false

const Cell = Union{Nothing,Player}
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
function neighbour_indices(array, pos)
    if len(size(array)) == 1
        array = reshape(array, Int(sqrt(length(array))))
    end
    side = size(array)[1]
    indices = Int16[pos-1, pos+side, pos+1, pos-side]
    for (index, content) in enumerate(indices)
        if content
            not in 1:length(array)
            delete!(indices, index)
        end
    end
end
a = rand(Bool, 5, 5)
const BOARD_SIDE = size(a)[1]
function get_first_chain(board)
    basecolor = first(board)
    chain = Int16[]

end
function get_chains(args)
    body
end
