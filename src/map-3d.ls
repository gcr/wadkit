THREE = require 'three'
BufferGeometryUtils = require('three-buffer-geometry-utils')(THREE)

require! './type-specifications.ls'

export class Map3dObj
  (@model, @tex-manager) ->
    sectors = @model.sectors

    # we hold a giant buffer of uints
    geometries = []
    for sector in @model.sectors
      #console.log "generating", sector
      #sector.recalc-slope!
      for geo in @sector-to-geometry sector
        geometries.push geo
    for linedef in @model.linedefs
      #if linedef.id % 5 != 5 then continue
      #if linedef.id > 10000 then continue
      #if linedef.id < 8000 then continue
      #if linedef.id != -1 then continue
      for geo in @linedef-to-geometry linedef
        #console.log "linedef", linedef
        geometries.push geo

    # fixup geometries: we need to convert the index to a Float32 index to
    # avoid overflow!
    for geo in geometries
      geo.set-index new THREE.Uint32BufferAttribute(geo.index.array, 1)


    console.log "have #{@model.sectors.length} sectors"
    console.log "have #{@model.linedefs.length} linedefs"
    console.log "have #{geometries.length} geometries"
    # between 12000 and 12400
    #geometries = geometries[0 til 12000]  # 11314
    window.geometries = geometries
    #console.log geometries
    geo = BufferGeometryUtils.merge-buffer-geometries geometries, 0
    window.geo = geo

    @mesh = new THREE.Object3D!
    @tex-manager.fix-tex-bounds geo
    mesh = new THREE.Mesh geo, @tex-manager.get-shader-material!
    @mesh.add mesh
    # Add wireframe view
    wires-geo = new THREE.EdgesGeometry geo, 5
    wires-mat = new THREE.LineBasicMaterial do
        color:0xffffff
    line = new THREE.LineSegments wires-geo, wires-mat
    @mesh.add line
    @mesh.scale.set 0.01,0.01,0.01
    #@mesh.position.set 0,0,sector.floor-height*0.01

  linedef-to-geometry: (linedef)->
    # Construct linedef face data!
    {front-sidedef: front, back-sidedef: back, v-begin, v-end} = linedef
    geometries = []
    add-quad = (va, vb, z1, z2, sidedef, mode='lower')~>
      # add faces in CCW order:
      #    1----3     uv: top (=ha2-ha1)
      #    | \  |
      #    |  \ |
      #    0----2     uv: bottom (=0)

      ha1 = hb1 = z1
      ha2 = hb2 = z2
      if mode == 'lower' and sidedef.sector.slope-floor-mat
        [Δx, Δy, _, Δoffset] = sidedef.sector.slope-floor-mat.elements[2 til 15 by 4]
        ha1 = Δx*va.x + Δy*va.y + Δoffset
        hb1 = Δx*vb.x + Δy*vb.y + Δoffset
      other-sidedef = linedef.other-sidedef sidedef
      if other-sidedef? and mode == 'lower' and other-sidedef.sector.slope-floor-mat
        [Δx, Δy, _, Δoffset] = other-sidedef.sector.slope-floor-mat.elements[2 til 15 by 4]
        ha2 = Δx*va.x + Δy*va.y + Δoffset
        hb2 = Δx*vb.x + Δy*vb.y + Δoffset
      if ha1 > ha2 or hb1 > hb2
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
      uv-top = 0
      uv-bottom = 0
      uv-left = 0
      uv-right = 0
      geo.set-attribute 'uv', new THREE.Float32BufferAttribute([
          0 + xoffs,    ha2 + yoffs
          0 + xoffs,    ha1 + yoffs
          dist + xoffs, hb2 + yoffs
          dist + xoffs, hb1 + yoffs
      ],2)
      # note that our UVs have origin in bottom
      # left of the texture and units are texels
      # TODO: handle peggedness
      material = @tex-manager.get(sidedef["#{mode}Tex"])
      geo.set-attribute 'texIndex', new THREE.Float32BufferAttribute([
        material, material, material, material
      ],1)
      geo.set-attribute 'normal', new THREE.Float32BufferAttribute [0,0,0, 0,0,0, 0,0,0, 0,0,0],3
      geo.set-attribute 'texBounds', new THREE.Float32BufferAttribute [0 for [0 til 4*4]],4
      geometries.push geo

    # First, handle geometry for this sector.
    front-floor = front.sector.floor-height
    front-ceiling = front.sector.ceiling-height
    if back is null
      # Middle texture, Front side
      add-quad v-begin,v-end,  front-floor, front-ceiling, front, 'middle'
      # linedefs that border the outside of the level have no back side
    else
      back-floor = back.sector.floor-height
      back-ceiling = back.sector.ceiling-height

      # Lower texture, Front side
      if front.sector.floor-flat != 'F_SKY1'
        add-quad v-begin,v-end,  front-floor, back-floor, front, 'lower'
      # Lower texture, Back side
      if back.sector.floor-flat != 'F_SKY1'
        add-quad v-end,v-begin,  back-floor, front-floor, back, 'lower'

      # TODO: middle textures

      # Upper texture, Front side
      if front.sector.ceiling-flat != 'F_SKY1'
        add-quad v-begin,v-end,  back-ceiling, front-ceiling, front, 'upper'
      # Upper texture, Back side
      if back.sector.ceiling-flat != 'F_SKY1'
        add-quad v-end,v-begin,  back-ceiling, front-ceiling, back, 'upper'

      # FOFs on sector on the front side
      for control-linedef in front.sector.tagged-linedefs
        if type-specifications.fof-linedef-type control-linedef
          {draw-flats} = that
          control-sector = control-linedef.front-sidedef.sector
          h1 = control-sector.floor-height
          h2 = control-sector.ceiling-height
          sidedef = control-linedef.front-sidedef
          add-quad v-end, v-begin, h1, h2, sidedef, 'middle'
      # FOFs on sector on the back side
      for control-linedef in back.sector.tagged-linedefs
        if type-specifications.fof-linedef-type control-linedef
          {draw-flats} = that
          control-sector = control-linedef.front-sidedef.sector
          h1 = control-sector.floor-height
          h2 = control-sector.ceiling-height
          sidedef = control-linedef.front-sidedef
          add-quad v-begin, v-end, h1, h2, sidedef, 'middle'

    return geometries


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

    geometries = []

    # helper
    assign-flat = (geo, flat)~>
        tex-index = @tex-manager.get flat
        i = [tex-index for [0 til geo.get-attribute 'position' .count]]
        geo.set-attribute 'texIndex', new THREE.Float32BufferAttribute i,1
        i = [0 for [0 til 4 * geo.get-attribute 'position' .count]]
        geo.set-attribute 'texBounds', new THREE.Float32BufferAttribute i,4

    # lend us your energy, ShapeBufferGeometry-sempai
    sector-geo = new THREE.ShapeBufferGeometry shape-path.to-shapes!

    # Set up floor
    floor = sector-geo.clone!
    assign-flat floor, sector.floor-flat
    floor.apply-matrix4 sector.floor-matrix4!
    geometries.push floor

    # Set up ceiling
    ceiling = sector-geo.clone!
    ceiling.index.array.reverse! # flip CW and CCW
    if sector.ceiling-flat != 'F_SKY1'
      assign-flat ceiling, sector.ceiling-flat
      ceiling.apply-matrix4 sector.ceiling-matrix4!
      geometries.push ceiling

    # FOFs
    for control-linedef in sector.tagged-linedefs
      if type-specifications.fof-linedef-type control-linedef
        {draw-flats} = that
        control-sector = control-linedef.front-sidedef.sector
        if draw-flats
          fof-floor = sector-geo.clone!
          fof-floor.index.array.reverse!
          fof-floor.apply-matrix4 control-sector.floor-matrix4!
          assign-flat fof-floor, control-sector.floor-flat

          fof-ceiling = sector-geo.clone!
          fof-ceiling.apply-matrix4 control-sector.ceiling-matrix4!
          assign-flat fof-ceiling, control-sector.ceiling-flat
          geometries.push fof-floor, fof-ceiling

    return geometries
