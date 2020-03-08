THREE = require 'three'
BufferGeometryUtils = require('three-buffer-geometry-utils')(THREE)

export class Map3dObj
  (@model, @tex-manager) ->
    sectors = @model.sectors

    # we hold a giant buffer of uints
    geometries = []
    for sector in @model.sectors
      for geo in @sector-to-geometry sector
        #geometries.push geo
        35
    for linedef in @model.linedefs
      for geo in @linedef-to-geometry linedef
        geometries.push geo

    geo = BufferGeometryUtils.merge-buffer-geometries geometries, 0
    console.log geo
    mesh = new THREE.Mesh geo, @tex-manager.get-shader-material!
    # Add wireframe view
    wires-geo = new THREE.EdgesGeometry geo, 25
    m = new THREE.Matrix4!.make-translation 0,0, 0.5
    wires-geo.apply-matrix4 m
    wires-mat = new THREE.LineBasicMaterial do
        color:0xffffff
        linewidth: 4
    line = new THREE.LineSegments wires-geo, wires-mat
    @mesh = new THREE.Object3D!
    @mesh.add mesh
    @mesh.add line
    @mesh.scale.set 0.01,0.01,0.01
    #@mesh.position.set 0,0,sector.floor-height*0.01

  linedef-to-geometry: (linedef)->
    # Construct linedef face data!
    front = linedef.front-sidedef
    back = linedef.back-sidedef
    v-begin = linedef.v-begin
    v-end = linedef.v-end
    position = []
    index = []
    uv = []
    tex-index = []
    add-quad = (va, vb, ha1, ha2, hb1, hb2, material)->
      # add faces in CCW order
      position.push va.x,va.y,ha1, va.x,va.y,ha2
      position.push vb.x,vb.y,ha1, vb.x,vb.y,ha2
      uv.push 0,0, 0,1, 1,0, 1,1
      n = index.length
      index.push n+2, n+1, n
      index.push n+1, n+2, n+3
      tex-index.push material, material, material, material

    if back isnt null
      front-floor = front.sector.floor-height
      back-floor = back.sector.floor-height

      # Lower texture, Front side
      if front-floor < back-floor #and front.lower-tex != '-'
       add-quad v-begin,v-end,  front-floor,back-floor,front-floor,back-floor, @tex-manager.get front.lower-tex

      # Lower texture, Back side
      if front-floor > back-floor #and back.lower-tex != '-'
       add-quad v-begin,v-end,  front-floor,back-floor,front-floor,back-floor, @tex-manager.get back.lower-tex

      # Middle texture, Front side
      # Middle texture, Back side
      # Upper texture, Front side
      # Upper texture, Back side
      if index.length > 0
          geo = new THREE.BufferGeometry!
          geo.set-index index
          geo.set-attribute 'position', new THREE.Float32BufferAttribute position,3
          geo.set-attribute 'uv', new THREE.Float32BufferAttribute uv,2
          geo.set-attribute 'texIndex', new THREE.Float32BufferAttribute tex-index,1
          return [geo]
    return []

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

    # lend us your energy, ShapeBufferGeometry-sempai
    floor = new THREE.ShapeBufferGeometry shape-path.to-shapes!
    tex-index = @tex-manager.get '-'
    i = [tex-index for [0 til floor.get-index!.length]]
    floor.set-attribute 'texIndex', new THREE.Float32BufferAttribute i,1

    m = new THREE.Matrix4!.make-translation 0,0, sector.floor-height
    floor.apply-matrix4 m

    return [ floor ]
