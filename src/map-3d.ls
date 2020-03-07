THREE = require 'three'

export class Map3dObj
  (@model) ->
    sectors = @model.sectors

    # Construct vertices buffers
    vertices = []
    faces = []

    # Geometry

  sector-to-mesh: (sector)->
    {boundary-cycles, hole-cycles} = sector.cycles!
    shape-path = new THREE.ShapePath!
    # add vertices in all boundary cycles in CW,
    # add vertices in all hole cycles in reverse.
    for cycle in boundary-cycles
      [head, ...rest] = cycle
      shape-path.moveTo head.x, head.y
      for rest then shape-path.lineTo ..x, ..y
    for cycle in hole-cycles
      [head, ...rest] = cycle
      shape-path.moveTo head.x, head.y
      for rest then shape-path.lineTo ..x, ..y
    shapes = shape-path.to-shapes!

    geometry = new THREE.ShapeBufferGeometry shapes
    material = new THREE.MeshBasicMaterial color: Math.floor(0xffffff*Math.random!)
    mesh = new THREE.Mesh geometry, material
    mesh.position.set 0,0,sector.floor-height*0.01
    mesh.scale.set 0.01,0.01,0.01
    return mesh
