THREE = require 'three'
BufferGeometryUtils = require('three-buffer-geometry-utils')(THREE)

export class Map3dObj
  (@model) ->
    sectors = @model.sectors

    # we hold a giant buffer of uints
    geometries = []
    for sector in @model.sectors
      for geo in @sector-to-geometry sector
        geometries.push geo
    for linedef in @model.linedefs
      for geo in @linedef-to-geometry linedef
        geometries.push geo

    #geometries = geometries[0 til 510]
    console.log geometries[1]
    console.log geometries[*-1]

    material = new THREE.MeshBasicMaterial do
                color: 0xdd88aa
                wireframe: true
    geo = BufferGeometryUtils.merge-buffer-geometries geometries, 0
    @mesh = new THREE.Mesh geo, material
    #@mesh.position.set 0,0,sector.floor-height*0.01
    @mesh.scale.set 0.01,0.01,0.01

  linedef-to-geometry: (linedef)->
    # Construct linedef face data!
    front = linedef.front-sidedef
    back = linedef.back-sidedef
    v-begin = linedef.v-begin
    v-end = linedef.v-end
    position = []
    index = []
    add-quad = (va, vb, ha1, ha2, hb1, hb2)->
      # add faces in CW order
      position.push va.x,va.y,ha1, va.x,va.y,ha2
      position.push vb.x,vb.y,ha1, vb.x,vb.y,ha2
      n = index.length
      index.push n, n+1, n+2
      index.push n+1, n+2, n+3

    if back isnt null
      front-floor = front.sector.floor-height
      back-floor = back.sector.floor-height

      # Lower texture, Front side
      if front-floor < back-floor and front.lower-tex != '-'
       add-quad v-begin,v-end,  front-floor,back-floor,front-floor,back-floor

      # Lower texture, Back side
      if front-floor > back-floor and back.lower-tex != '-'
       add-quad v-end,v-begin,  front-floor,back-floor,front-floor,back-floor

      # Middle texture, Front side
      # Middle texture, Back side
      # Upper texture, Front side
      # Upper texture, Back side
      if index.length > 0
          geo = new THREE.BufferGeometry!
          geo.set-index index
          geo.set-attribute 'position', new THREE.Float32BufferAttribute position,3
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

    m = new THREE.Matrix4!.make-translation 0,0, sector.floor-height
    floor.apply-matrix4 m

    return [ floor ]
