THREE = require 'three'
BufferGeometryUtils = require('three-buffer-geometry-utils')(THREE)
DynamicBufferGeometry = require './dynamic-buffer-geometry.ls'
require! '../data/type-specifications.ls'

TAGS = do
  is-linedef: 1
  is-floor: 2
  is-ceiling: 4
  is-fof-floor: 8
  is-fof-ceiling: 16
  is-fof-linedef: 32

tag-geometry = (geo, id, tag) ->
  x = [tag for [0 til geo.get-attribute 'position' .array.length / 3]]
  y = [id for [0 til geo.get-attribute 'position' .array.length / 3]]
  geo.set-attribute 'attrType', new THREE.Float32BufferAttribute x, 1
  geo.set-attribute 'attrId', new THREE.Float32BufferAttribute y, 1

height-on-slope = (matrix, v)->
    [Δx, Δy, _, Δoffset] = matrix.elements[2 til 15 by 4]
    return Δx*v.x + Δy*v.y + Δoffset

export class Map3dObj extends THREE.Object3D
  (@model, @tex-manager) ->
    super!

    @geometry-aggregate = new DynamicBufferGeometry.BufferGeoAggregate 16, do
      position: 3
      uv: 2
      texIndex: 1
      texBounds: 4
      attrType: 1
      attrId: 1
    #@lines-aggregate = new DynamicBufferGeometry.BufferGeoAggregate 8, do
    #  position: 3

    sectors = @model.sectors

    # we hold a giant buffer of uints
    for linedef in @model.linedefs
      {faces, lines} = @linedef-to-geometry linedef
      @geometry-aggregate.set linedef, faces
      #@lines-aggregate.set linedef, lines
    for sector in @model.sectors
      {faces, lines} = @sector-to-geometry sector
      @geometry-aggregate.set sector, faces
      #@lines-aggregate.set linedef, lines

    console.log "have #{@model.sectors.length} sectors"
    console.log "have #{@model.linedefs.length} linedefs"
    #console.log "have #{geometries.length} geometries"

    @tex-manager.fix-tex-bounds @geometry-aggregate
    @map-mesh = new THREE.Mesh @geometry-aggregate, @tex-manager.get-shader-material!
    @add @map-mesh

    # Add wireframe view
    #wire-geo = new THREE.BufferGeometry!
    #wire-geo.set-attribute 'position', new THREE.Float32BufferAttribute line-geometries,3
    #wire-mat = new THREE.LineBasicMaterial do
    #    color:0xffffff
    #    blending: THREE.AdditiveBlending
    #    depth-write: false
    #@wireframe = new THREE.LineSegments @lines-aggregate, wire-mat
    #@add @wireframe

  linedef-to-geometry: (linedef)->
    # Construct linedef face data!
    {front-sidedef: front, back-sidedef: back, v-begin, v-end} = linedef
    faces = []
    lines = []
    add-quad = (va, vb, z1, z2, sidedef, mode='lower', geo-type, control-linedef)~>
      considered-linedef = linedef or control-linedef
      if not sidedef?.sector then return
      # add faces in CCW order:
      #    1----3     uv: top (=0, since tex origin is top)
      #    | \  |
      #    |  \ |
      #    0----2     uv: bottom (=ha2-ha1)

      ha1 = hb1 = z1
      ha2 = hb2 = z2
      other-sidedef = linedef.other-sidedef sidedef
      # Apply slopes
      if mode == 'lower' and sidedef.sector.slope-floor-mat
        ha1 = height-on-slope sidedef.sector.slope-floor-mat, va
        hb1 = height-on-slope sidedef.sector.slope-floor-mat, vb
      if mode == 'middle' and sidedef.sector.slope-floor-mat
        ha1 = height-on-slope sidedef.sector.slope-floor-mat, va
        hb1 = height-on-slope sidedef.sector.slope-floor-mat, vb
      if mode == 'lower' and other-sidedef?.sector.slope-floor-mat
        ha2 = height-on-slope other-sidedef.sector.slope-floor-mat, va
        hb2 = height-on-slope other-sidedef.sector.slope-floor-mat, vb
      if mode == 'upper' and sidedef.sector.slope-ceiling-mat
        ha2 = height-on-slope sidedef.sector.slope-ceiling-mat, va
        hb2 = height-on-slope sidedef.sector.slope-ceiling-mat, vb
      if mode == 'upper' and other-sidedef?.sector.slope-ceiling-mat
        ha1 = height-on-slope other-sidedef.sector.slope-ceiling-mat, va
        hb1 = height-on-slope other-sidedef.sector.slope-ceiling-mat, vb
      if mode == 'middle' and sidedef.sector.slope-ceiling-mat
        ha2 = height-on-slope sidedef.sector.slope-ceiling-mat, va
        hb2 = height-on-slope sidedef.sector.slope-ceiling-mat, vb

      if ha1 > ha2 or hb1 > hb2
        # normally we want just lines to be visible, even
        # if they're sloped
        return
      if mode == 'upper' and ha1 == ha2 and hb1 == hb2
        # upper textures are a special case. sometimes
        # people add upper textures to linedefs with F_SKY1
        # ceiling flats, so as a special case, we hide them.
        # this avoids lines in the sky.
        return

      # add vertices
      geo = new THREE.BufferGeometry!
      geo.set-attribute 'position', new THREE.Float32BufferAttribute([
        va.x,va.y,ha1, va.x,va.y,ha2
        vb.x,vb.y,hb1, vb.x,vb.y,hb2
      ],3)
      geo.set-index [2, 1, 0, 1, 2, 3]
      # add uv
      dx = vb.x - va.x
      dy = vb.y - va.y
      dist = Math.sqrt(dx*dx + dy*dy)
      xoffs = sidedef.tex-x-offset
      yoffs = sidedef.tex-y-offset
      if mode == 'lower' and considered-linedef.flags.lower-unpegged
        # draw bottom of texture on floor
        yoffs += -(ha2 - ha1)
      else if mode == 'upper' and not considered-linedef.flags.upper-unpegged
        yoffs += -(ha2 - ha1)
      else if mode == 'middle' and considered-linedef.flags.lower-unpegged
        yoffs += -(ha2 - ha1)
      geo.set-attribute 'uv', new THREE.Float32BufferAttribute([
          0 + xoffs,    (ha2 - ha1) + yoffs
          0 + xoffs,    0 + yoffs
          dist + xoffs, (hb2 - hb1) + yoffs
          dist + xoffs, 0 + yoffs
      ],2)
      # note that our UVs have origin in bottom
      # left of the texture and units are texels
      # TODO: handle peggedness
      material = @tex-manager.get(sidedef["#{mode}Tex"])
      geo.set-attribute 'texIndex', new THREE.Float32BufferAttribute([
        material, material, material, material
      ],1)
      geo.set-attribute 'texBounds', new THREE.Float32BufferAttribute [0 for [0 til 4*4]],4
      tag-geometry geo, considered-linedef.id, geo-type
      faces.push geo
      # Add vertices to lines
      lines.push va.x,va.y,ha1, va.x,va.y,ha2
      lines.push va.x,va.y,ha2, vb.x,vb.y,hb2
      lines.push vb.x,vb.y,hb2, vb.x,vb.y,hb1
      lines.push vb.x,vb.y,hb1, va.x,va.y,ha1

    # First, handle geometry for this sector.
    front-floor = front?.sector?.floor-height
    front-ceiling = front?.sector?.ceiling-height
    if not back?
      # Middle texture, Front side
      if front-floor isnt null
        add-quad v-begin,v-end,  front-floor, front-ceiling, front, 'middle', TAGS.is-linedef
      # linedefs that border the outside of the level have no back side
    else
      back-floor = back.sector.floor-height
      back-ceiling = back.sector.ceiling-height

      # Lower texture, Front side
      if front and front.sector.floor-flat != 'F_SKY1'
        add-quad v-begin,v-end,  front-floor, back-floor, front, 'lower', TAGS.is-linedef
      # Lower texture, Back side
      if back and back.sector.floor-flat != 'F_SKY1'
        add-quad v-end,v-begin,  back-floor, front-floor, back, 'lower', TAGS.is-linedef

      # TODO: middle textures

      # Upper texture, Front side
      if front and front.upper-tex != '-'
        add-quad v-begin,v-end,  back-ceiling, front-ceiling, front, 'upper', TAGS.is-linedef
      # Upper texture, Back side
      if back and back.upper-tex != '-'
        add-quad v-end,v-begin,  front-ceiling, back-ceiling, back, 'upper', TAGS.is-linedef

      # FOFs on sector on the front side
      for control-linedef in front?.sector?.tagged-linedefs or []
        if type-specifications.fof-linedef-type control-linedef
          {draw-lines} = that
          control-sector = control-linedef?.front-sidedef?.sector
          if draw-lines and control-sector
            h1 = control-sector.floor-height
            h2 = control-sector.ceiling-height
            sidedef = control-linedef.front-sidedef
            add-quad v-end, v-begin, h1, h2, sidedef, 'middle', TAGS.is-fof-linedef, control-linedef
      # FOFs on sector on the back side
      for control-linedef in back?.sector?.tagged-linedefs or []
        if type-specifications.fof-linedef-type control-linedef
          {draw-lines} = that
          control-sector = control-linedef?.front-sidedef?.sector
          if draw-lines and control-sector
            h1 = control-sector.floor-height
            h2 = control-sector.ceiling-height
            sidedef = control-linedef.front-sidedef
            add-quad v-begin, v-end, h1, h2, sidedef, 'middle', TAGS.is-fof-linedef, control-linedef

    return {faces, lines}


  sector-to-geometry: (sector)->
    {boundary-cycles, hole-cycles} = sector.cycles!
    # help us triangulate this sector, oh shapepath-sama~!
    shape-path = new THREE.ShapePath!
    for cycle in boundary-cycles
      # convention: vertices in all boundary cycles are CW,
      [head, ...rest] = cycle
      shape-path.moveTo head.x, head.y
      for rest then shape-path.lineTo ..x, ..y
    for cycle in hole-cycles
      # vertices in all hole cycles are already CCW
      [head, ...rest] = cycle
      shape-path.moveTo head.x, head.y
      for rest then shape-path.lineTo ..x, ..y

    faces = []

    # helper
    assign-flat = (geo, flat)~>
        tex-index = @tex-manager.get flat
        i = [tex-index for [0 til geo.get-attribute 'position' .count]]
        geo.set-attribute 'texIndex', new THREE.Float32BufferAttribute i,1
        i = [0 for [0 til 4 * geo.get-attribute 'position' .count]]
        geo.set-attribute 'texBounds', new THREE.Float32BufferAttribute i,4

    # lend us your energy, ShapeBufferGeometry-sempai
    sector-geo = new THREE.ShapeBufferGeometry shape-path.to-shapes!
    sector-geo.delete-attribute 'normal'

    # Set up floor
    floor = sector-geo.clone!
    assign-flat floor, sector.floor-flat
    tag-geometry floor, sector.id, TAGS.is-floor
    floor.apply-matrix4 sector.floor-matrix4!
    faces.push floor

    # Set up ceiling
    ceiling = sector-geo.clone!
    ceiling.index.array.reverse! # flip CW and CCW
    if sector.ceiling-flat != 'F_SKY1'
      assign-flat ceiling, sector.ceiling-flat
      tag-geometry ceiling, sector.id, TAGS.is-ceiling
      ceiling.apply-matrix4 sector.ceiling-matrix4!
      faces.push ceiling

    # FOFs
    for control-linedef in sector.tagged-linedefs
      if type-specifications.fof-linedef-type control-linedef
        {draw-flats} = that
        control-sector = control-linedef.front-sidedef?.sector
        if draw-flats and control-sector
          fof-floor = sector-geo.clone!
          fof-floor.index.array.reverse!
          fof-floor.apply-matrix4 control-sector.floor-matrix4!
          assign-flat fof-floor, control-sector.floor-flat
          tag-geometry fof-floor, sector.id, TAGS.is-fof-floor

          fof-ceiling = sector-geo.clone!
          fof-ceiling.apply-matrix4 control-sector.ceiling-matrix4!
          assign-flat fof-ceiling, control-sector.ceiling-flat
          tag-geometry fof-ceiling, sector.id, TAGS.is-fof-ceiling
          faces.push fof-floor, fof-ceiling

    return {faces, lines:[]}

  set-intensity: ({linedef= 1.0, floor= 1.0, ceiling= 1.0, fof-floor= 1.0, fof-ceiling= 1.0, fof-linedef= 1.0, wireframe= 1.0}={})->
    @map-mesh.material.uniforms.intensity-linedef.value = linedef
    @map-mesh.material.uniforms.intensity-floor.value = floor
    @map-mesh.material.uniforms.intensity-ceiling.value = ceiling
    @map-mesh.material.uniforms.intensity-fof-linedef.value = fof-linedef
    @map-mesh.material.uniforms.intensity-fof-floor.value = fof-floor
    @map-mesh.material.uniforms.intensity-fof-ceiling.value = fof-ceiling
    m = wireframe
    @wireframe.material.color = new THREE.Color m,m,m
    #@wireframe.alpha = val

  update-sector: (sector, new-vals)->
    sector <<< new-vals
    {faces, lines} = @sector-to-geometry sector
    @geometry-aggregate.set sector, faces
    #@lines-aggregate.set linedef, lines
    sector.recalc-slope!
    for linedef in sector.linedefs
      {faces, lines} = @linedef-to-geometry linedef
      @geometry-aggregate.set linedef, faces
      if linedef.front-sidedef?.sector?
        linedef.front-sidedef.sector.recalc-slope!
        {faces, lines} = @sector-to-geometry linedef.front-sidedef.sector
        @geometry-aggregate.set linedef.front-sidedef.sector, faces
        for ll in linedef.front-sidedef.sector.linedefs
          {faces, lines} = @linedef-to-geometry ll
          @geometry-aggregate.set ll, faces
      if linedef.back-sidedef?.sector?
        linedef.back-sidedef.sector.recalc-slope!
        {faces, lines} = @sector-to-geometry linedef.back-sidedef.sector
        @geometry-aggregate.set linedef.back-sidedef.sector, faces
        for ll in linedef.back-sidedef.sector.linedefs
          {faces, lines} = @linedef-to-geometry ll
          @geometry-aggregate.set ll, faces

      #@lines-aggregate.set linedef, lines
    console.time 'fix-tex-bounds'
    @tex-manager.fix-tex-bounds @geometry-aggregate
    console.time-end 'fix-tex-bounds'
