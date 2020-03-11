THREE = require 'three'

slope-from-vertices = (a,b,c)->
  a = a.clone!
  b = b.clone!
  c = c.clone!
  # Construct a skew matrix.
  #   1   0   0 0
  #   0   1   0 0
  #   dzx dzy 1 dzoffset
  #   0   0   0 1

  # a is the origin!
  # then, find the matrix that maps [b.x, b.y, 0] to [b.x,b.y,b.z]
  # and [c.x,c.y,0] to [c.x,c.y,c.z]
  # the new z = Δx*x + Δy*y
  b.sub a
  c.sub a
  {x: x1, y: y1, z: z1} = b
  {x: x2, y: y2, z: z2} = c
  Δx = (z1*y2 - z2*y1) / (x1*y2 - x2*y1)
  Δy = (z1*x2 - z2*x1) / (x2*y1 - x1*y2)
  Δoffset = Δx*a.x + Δy*a.y #+ a.z*Δx*Δy

  # First, the dzx component
  #if Math.abs(b.x - a.x) < Math.abs(c.x - a.x)
  #  # ac is a better choice
  #  [b,c] = [c,b]
  #dzx = (b.z - a.z) / (b.x - a.x)
  # dzy
  #if Math.abs(b.y - a.y) < Math.abs(c.y - a.y)
  #  # ac is a better choice
  #  [b,c] = [c,b]
  #dzy = (b.z - a.z) / (b.y - a.y)

  # Offset
  #dzoffset = a.z + dzx*a.x + dzy*a.y
  m = new THREE.Matrix4!.set(
    1,   0,   0, 0,
    0,   1,   0, 0,
    Δx, Δy, 1, -Δoffset,
    0,   0,   0, 1
  )


a = new THREE.Vector3 10, 15, 5
b = new THREE.Vector3 10, 20, 5
c = new THREE.Vector3 15, 15, 10
m = slope-from-vertices a,b,c
console.log "Before:", {a,b,c}
console.log "Matrix:", m
a.applyMatrix4 m
b.applyMatrix4 m
c.applyMatrix4 m
console.log "After:", {a,b,c}


export class Vertex
  ({@x, @y}) ->
    @linedefs = []

  # returns list of [linedef, vertex]
  neighbors: -> [[l, l.other-v @] for l in @linedefs]

export class Linedef
  ({@v-begin, @v-end, @flags, @action, @tag, @front-sidedef, @back-sidedef}) ->

  interesting: -> @front-sidedef?.sector != @back-sidedef?.sector
  vertices: -> [@v-begin, @v-end]
  other-sidedef: (s)->
    if s is @front-sidedef
        @back-sidedef
    else if s is @back-sidedef
        @front-sidedef
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
    # Ah yes, the cycle finder.
    #
    # Sectors may contain several regions of contiguous geometry
    # and any number of holes.
    # This function finds all cycles and holes, returning
    #  { boundary-cycles, hole-cycles }
    # where boundary-cycles : list of cycles, guaranteed
    #                         to be in CW order,
    #       hole-cycles :     list of cycles, guaranteed
    #                         to be in CCW order,
    #       cycle :           list of Vertex.
    # Broadly, the steps are:
    # 1. Find all cycles
    # 2. Determine which cycles are CW and CCW
    # 3. Determine which of those are holes and which are boundaries.

    # In this sector, only consider 'interesting' linedefs
    # that border other sectors.
    interesting-linedefs = new Set!
    for l in @linedefs
      if l.interesting!
        interesting-linedefs.add l

    # Find one cycle. Treat this sector as a graph where nodes
    # are vertices and edges are linedefs. Standard DFS.
    find-cycle = (v, seen=new Set!, lpath=[], vpath=[v])->
      # Try to find a path back to this vertex
      seen.add v
      for next-l in v.linedefs
        if next-l not in lpath.slice -1 and interesting-linedefs.has next-l
          # Traverse in whatever order
          next-v = next-l.other-v v
          if seen.has next-v
            # Found a cycle! Return the path we took to get there
            return lpath.slice vpath.index-of(next-v) .concat next-l
          else
            if find-cycle next-v, seen, lpath.concat(next-l), vpath.concat(next-v)
              return that

    # Incrementally find all cycles, and remove them
    # from the list of considered linedefs as we go.
    # This works because each linedef should only
    # occur in one cycle.
    cycles = []
    interesting-linedefs.for-each (l)->
      if find-cycle l.v-begin
        cycles.push that
        for that then interesting-linedefs.delete ..
    if interesting-linedefs.size > 0
      console.log "Unclosed linedefs in sector:", interesting-linedefs, @
      throw new Error "Sector is not closed"

    # Which cycles delimit sector boundaries and which
    # delimit holes? To find out, enumerate each cycle
    boundary-cycles = []
    hole-cycles = []
    for cycle, i in cycles
      area = 0
      vertexes = []
      # The vertex we should start from is the one that
      # doesn't link to the next line
      if cycle[0].v-begin not in cycle[1].vertices!
        a = cycle[0].v-begin
        # Following this line from begin to end.
        # If this is a boundary cycle, either
        #  - this sector is its back and we are iterating CCW, or
        #  - this sector is its front and we are iterating CW.
        # If this is a hole cycle, either
        #  - this sector is its back and we are iterating CW, or
        #  - this sector is its front and we are iterating CCW.
        follow-cw-order = true
      else
        a = cycle[0].v-end
        # following this line from end to begin
        # means we think CW cycles will be CCW and vice
        # versa
        follow-cw-order = false
      # calculate area
      for line in cycle
        vertexes.push a
        b = line.other-v a
        area += b.x*a.y - a.x * b.y
        a = b
      if not follow-cw-order
        area *= -1
        vertexes.reverse! # vertexes should always be in CW at this point
      if area > 0
        # cycle is CW.
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

  recalc-slope: (mode = 'floor')->
    # Linedef slopes!
    if mode == 'floor'
      for line in @linedefs
        if line.back-sidedef?.sector is @ and line.action in [710,712,713]
          reference-line = line
          other-sector-floor-height = line.front-sidedef.sector.floor-height
        if line.front-sidedef?.sector is @ and line.action in [700,702,703]
          reference-line = line
          other-sector-floor-height = line.back-sidedef.sector.floor-height
      if @id == 35
        console.log "Slope!", @, reference-line

      if reference-line
        a = reference-line.v-begin
        b = reference-line.v-end
        dx = b.x - a.x
        dy = b.y - a.y
        # Which vertex is farthest?
        farthest-dist = 0
        farthest-v = null
        for l in @linedefs
          for v in l.vertices!
            d = dy*v.x - dx*v.y + b.x*a.y - b.y*a.x
            # 2x the area of the triangle defined by a,b,v
            d = Math.abs(d*d / (dx*dx+dy*dy)) # squared distance
            if @id == 35
              console.log "Considering: ", v, d
            if d > farthest-dist
              farthest-v = v
              farthest-dist = d
        if @id == 35
          console.log farthest-v
        # Calculate three vertices
        v0 = new THREE.Vector3(farthest-v.x, farthest-v.y, @floor-height)
        v1 = new THREE.Vector3(a.x, a.y, other-sector-floor-height)
        v2 = new THREE.Vector3(b.x, b.y, other-sector-floor-height)
        @slope-floor-mat = slope-from-vertices v0, v1, v2





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

    # More advanced geometry inferences
    for @sectors then ..recalc-slope!



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
