THREE = require 'three'

# References:
# - Unofficial Doom Specification 1.666

export class MapModel
  # A class that encapsulates:
  # - Link de-indexing
  # - An event dispatcher that helps changes in this state
  #   propogate to interested parties
  # - A standard API to mutate this state

  (@wad, {sectors, things, linedefs, sidedefs, vertexes}) ->
    @vertexes = [ new Vertex @, .. for vertexes ]
    @linedefs = [ new Linedef @, .. for linedefs ]
    @sectors  = [ new Sector @, .. for sectors ]
    @sidedefs  = [ new Sidedef @, .. for sidedefs ]

    for v,i in @vertexes then v.id = i
    for l,i in @linedefs then l.id = i
    for s,i in @sectors then s.id = i

    # Fix direct links
    for l in @linedefs
      if not l.v-begin
        throw new Error "Could not parse linedef #{l.id} : No begin vertex"
      if not l.v-end
        throw new Error "Could not parse linedef #{l.id} : No end vertex"
    for s in @sidedefs
      if not s.sector
        throw new Error "Could not parse sidedef #{s.id} : no front sector"

    # maintain cached links
    @_vertex-to-linedefs = {}
    @_sector-to-linedefs = {}
    for l in @linedefs
      for v in l.vertices!
        (@_vertex-to-linedefs[v.id] ?= []).push l
      (@_sector-to-linedefs[l.front-sidedef.sector.id] ?= []) .push l if l.front-sidedef?.sector?
      (@_sector-to-linedefs[l.back-sidedef.sector.id] ?= []) .push l if l.back-sidedef?.sector?

    # Tags
    @_sector-tags = {}
    @_linedef-tags = {}
    for @sectors then (@_sector-tags[..tag] ?= []).push .. if ..tag != 0
    for @linedefs then (@_linedef-tags[..tag] ?= []).push .. if ..tag != 0

    # Slopes
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

slope-from-vertices = (a,b,c)->
  a = a.clone!
  b = b.clone!
  c = c.clone!
  # Construct a skew matrix, describing the plane of this slope that
  # passes through these three points.
  #   1   0   0 0
  #   0   1   0 0
  #   dzx dzy 0 dzoffset  <-note we discord the existing z component
  #   0   0   0 1
  # This plane maps any point within the sector to the x,y,z
  # point that lies on that sector's slope plane. Note that this
  # discards the existing z component, so you don't offset the floor
  # or ceiling height.

  # a is the origin
  # find the matrix that maps [b.x, b.y, 0] to [b.x,b.y,b.z]
  # and [c.x,c.y,0] to [c.x,c.y,c.z].
  # the new z = Δx*x + Δy*y
  b.sub a
  c.sub a
  {x: x1, y: y1, z: z1} = b
  {x: x2, y: y2, z: z2} = c
  Δx = (z1*y2 - z2*y1) / (x1*y2 - x2*y1)
  Δy = (z1*x2 - z2*x1) / (x2*y1 - x1*y2)
  Δoffset = Δx*a.x + Δy*a.y - a.z#+ a.z*Δx*Δy

  # ...huh, it's interesting to me that this is similar
  # to the ∧ operation from https://marctenbosch.com/quaternions/
  # it looks like Δx and Δy is the division
  # of two bivectors. i'm to tired to understand what that
  # actually means tho. someone explain it to me!!!

  m = new THREE.Matrix4!.set(
    1,   0,   0, 0,
    0,   1,   0, 0,
    Δx, Δy, 0, -Δoffset,
    0,   0,   0, 1
  )

export class Vertex
  (@model, {@x, @y}) ->
    @id = null

  linedefs:~ -> @model._vertex-to-linedefs[@id] or []

  # returns list of [linedef, vertex]
  neighbors: -> [[l, l.other-v @] for l in @linedefs]

export class Linedef
  (@model, {v-begin: @_v-begin-id, v-end: @_v-end-id, @flags, @action, @tag, front-sidedef: @_front-sidedef-id, back-sidedef: @_back-sidedef-id}) ->
    @id = null
  tagged-sectors:~ -> (@model._sector-tags[@tag] if @tag) or []

  v-begin:~ -> @model.vertexes[@_v-begin-id]
  v-end:~ -> @model.vertexes[@_v-end-id]
  front-sidedef:~ -> @model.sidedefs[@_front-sidedef-id]
  back-sidedef:~ -> @model.sidedefs[@_back-sidedef-id]

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
  (@model, {@tex-x-offset, @tex-y-offset, @upper-tex, @lower-tex, @middle-tex, sector: @_sector-id}) ->
    @id = null
  sector:~ ->
    @model.sectors[@_sector-id]
  @linedefs = []

export class Sector
  (@model, {@floor-height, @ceiling-height, @floor-flat, @ceiling-flat, @brightness, @special, @tag}) ->
    @id = null

  linedefs:~ -> @model._sector-to-linedefs[@id] or []
  tagged-linedefs:~ -> (@model._linedef-tags[@tag] if @tag) or []

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
      console.error "Unclosed linedefs in sector:", interesting-linedefs, @
      return {boundary-cycles: [], hole-cycles: []}

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

  recalc-slope: ->
    if @_recursion_loop
      console.error "Sector #{@id} slope copies from itself in a cycle", @
      return
    farthest-vertex-from = (a,b)~>
      # Which vertex is farthest from line a-b?
      farthest-dist = 0
      farthest-v = null
      dx = b.x - a.x
      dy = b.y - a.y
      for l in @linedefs
        for v in l.vertices!
          d = dy*v.x - dx*v.y + b.x*a.y - b.y*a.x
          # 2x the area of the triangle defined by a,b,v
          d = Math.abs(d*d / (dx*dx+dy*dy)) # squared distance
          if d > farthest-dist
            farthest-v = v
            farthest-dist = d
      farthest-v

    for line in @linedefs
      # Back Floor slopes
      if line.back-sidedef?.sector is @ and line.action in [710,712,713]
        reference-floor-line = line
        other-sector-floor-height = line.front-sidedef.sector.floor-height
      # Front Floor slopes
      if line.front-sidedef?.sector is @ and line.action in [700,702,703]
        reference-floor-line = line
        other-sector-floor-height = line.back-sidedef.sector.floor-height

      # Slope copy for floors
      if line.front-sidedef?.sector is @ and line.action in [720, 722]
        console.log "Copy floor slope"
        for s in line.tagged-sectors
          if s is @ then continue
          try
            @_recursion_loop = true
            s.recalc-slope!
          finally
            @_recursion_loop = false
          if s.slope-floor-mat
            @slope-floor-mat = s.slope-floor-mat.clone!

      # Back Ceiling slopes
      if line.back-sidedef?.sector is @ and line.action in [703,711,712]
        reference-ceiling-line = line
        other-sector-ceiling-height = line.front-sidedef.sector.ceiling-height
      # Front Ceiling slopes
      if line.front-sidedef?.sector is @ and line.action in [701,702,713]
        reference-ceiling-line = line
        other-sector-ceiling-height = line.back-sidedef.sector.ceiling-height
      # Slope copy for ceilings
      if line.front-sidedef?.sector is @ and line.action in [721, 722]
        for s in line.tagged-sectors
          if s is @ then continue
          try
            @_recursion_loop = true
            s.recalc-slope!
          finally
            @_recursion_loop = false
          if s.slope-ceiling-mat
            @slope-ceiling-mat = s.slope-ceiling-mat.clone!

    if reference-floor-line
      a = reference-floor-line.v-begin
      b = reference-floor-line.v-end
      far-v = farthest-vertex-from a,b
      if not far-v
        console.error "Could not calculate floor slope for sector #{@id}: no farthest vertex"
        return
      # Calculate three vertices
      v0 = new THREE.Vector3(far-v.x, far-v.y, @floor-height)
      v1 = new THREE.Vector3(a.x, a.y, other-sector-floor-height)
      v2 = new THREE.Vector3(b.x, b.y, other-sector-floor-height)
      @slope-floor-mat = slope-from-vertices v0, v1, v2

    if reference-ceiling-line
      a = reference-ceiling-line.v-begin
      b = reference-ceiling-line.v-end
      far-v = farthest-vertex-from a,b
      if not far-v
        console.error "Could not calculate ceiling slope for sector #{@id}: no farthest vertex"
        return
      # Calculate three vertices
      v0 = new THREE.Vector3(far-v.x, far-v.y, @ceiling-height)
      v1 = new THREE.Vector3(a.x, a.y, other-sector-ceiling-height)
      v2 = new THREE.Vector3(b.x, b.y, other-sector-ceiling-height)
      @slope-ceiling-mat = slope-from-vertices v0, v1, v2

  floor-matrix4: ->
    if @slope-floor-mat
      @slope-floor-mat
    else
      new THREE.Matrix4!.make-translation 0,0, @floor-height

  ceiling-matrix4: ->
    if @slope-ceiling-mat
      @slope-ceiling-mat
    else
      new THREE.Matrix4!.make-translation 0,0, @ceiling-height
