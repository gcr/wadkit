THREE = require 'three'

export class Vertex
  ({@x, @y}) ->
    @linedefs = []

  # returns list of [linedef, vertex]
  neighbors: -> [[l, l.other-v @] for l in @linedefs]

export class Linedef
  ({@v-begin, @v-end, @flags, @action, @tag, @front-sidedef, @back-sidedef}) ->

  interesting: -> @front-sidedef?.sector != @back-sidedef?.sector
  vertices: -> [@v-begin, @v-end]
  other-v: (v)->
    if v is @v-begin
        @v-end
    else if v is @v-end
        @v-begin

export class Sidedef
  ({@tex-x-offset, @tex-y-offset, @upper-tex, @lower-tex, @middle-tex, @sector}) ->
    @linedefs = []

export class Sector
  ({@floor-height, @ceiling-height, @floor-flat, @ceiling-flat, @brightness, @special, @tag}) ->
    @linedefs = []

  cycles: ->

    # Sectors may contain several regions of contiguous geometry
    # and any number of holes.

    interesting-linedefs = new Set!
    for l in @linedefs
      if l.interesting!
        interesting-linedefs.add l

    # Find one cycle
    find-cycle = (v, seen=new Set!, lpath=[], vpath=[v])->
      # try to find a path back to this linedef
      seen.add v
      for next-l in v.linedefs
        if next-l not in lpath.slice -1 and interesting-linedefs.has next-l
          next-v = next-l.other-v v
          # each linedef will only occur in one cycle
          if seen.has next-v
            # return the path we took to get there
            return lpath.slice vpath.index-of(next-v) .concat next-l
          else
            if find-cycle next-v, seen, lpath.concat(next-l), vpath.concat(next-v)
              return that

    # Find all cycles
    cycles = []
    interesting-linedefs.for-each (l)->
      if find-cycle l.v-begin
        cycles.push that
        for that then interesting-linedefs.delete ..
    if interesting-linedefs.size > 0
      console.log "Unclosed linedefs in sector", interesting-linedefs, @
      throw new Error "Sector is not closed"

    # Which cycles delimit sector boundaries and which
    # delimit holes?
    boundary-cycles = []
    hole-cycles = []
    for cycle in cycles
      area = 0
      vertexes = []
      # pick the right vertex to start from...
      if cycle[0].v-begin not in cycle[1].vertices!
        a = cycle[0].v-begin
      else
        a = cycle[0].v-end
      for line in cycle
        b = line.other-v a
        area += b.x*a.y - a.x * b.y
        vertexes.push a
        a = b
      if area > 0
        # cycle is CW. since we
        # started at linedef.v-start,
        # if this line is *facing* the sector, it's
        # a boundary.
        if cycle[0].front-sidedef.sector is @
            boundary-cycles.push vertexes
        else
            hole-cycles.push vertexes.reverse!
      else
        # cycle is CCW.
        if cycle[0].front-sidedef.sector is @
            hole-cycles.push vertexes
        else
            boundary-cycles.push vertexes.reverse!

    return {boundary-cycles, hole-cycles}

export class MapModel

  # A class that encapsulates:
  # - Link de-indexing
  # - An event dispatcher that helps changes in this state
  #   propogate to interested parties
  # - A standard API to mutate this state

  ({sectors, things, linedefs, sidedefs, vertexes}) ->
    @vertexes = [ new Vertex .. for vertexes ]
    @linedefs = [ new Linedef .. for linedefs ]
    @sectors  = [ new Sector .. for sectors ]
    @sidedefs  = [ new Sidedef .. for sidedefs ]

    # Fix direct links
    for @linedefs then ..v-begin = @vertexes[..v-begin]
    for @linedefs then ..v-end = @vertexes[..v-end]
    for @linedefs then ..front-sidedef = @sidedefs[..front-sidedef] or null
    for @linedefs then ..back-sidedef = @sidedefs[..back-sidedef] or null
    for @sidedefs then ..sector = @sectors[..sector] or null

    for v,i in @vertexes then v.id = i
    for l,i in @linedefs then l.id = i
    for s,i in @sectors then s.id = i

    # Fix indirect links
    for l in @linedefs
      l.v-begin.linedefs.push l
      l.v-end.linedefs.push l
      l.front-sidedef?.linedefs.push l
      l.back-sidedef?.linedefs.push l
      l.front-sidedef?.sector?.linedefs.push l
      l.back-sidedef?.sector?.linedefs.push l



#    # Make vertex geometry
#    vertices = []
#    lines = []
#    for v in @vertexes
#      SCALE = 0.001
#      vertices.push(v.x * SCALE, v.y * SCALE, 0.0)
#    for l in @linedefs
#      lines.push(l.v-begin, l.v-end)
#
#    @material = new THREE.LineBasicMaterial color: 0xffffff, linewidth: 5
#    @geometry = new THREE.BufferGeometry!
#      ..setAttribute 'position', new THREE.Float32BufferAttribute(vertices, 3)
#      ..setIndex lines
#      ..computeBoundingSphere!
#
#    @obj = new THREE.LineSegments @geometry, @material
