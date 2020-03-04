THREE = require 'three'

export class MapModel
  ({@sectors, @things, @linedefs, @sidedefs, @vertexes}) ->
    # Make vertex geometry
    vertices = []
    lines = []
    for v in @vertexes
      SCALE = 0.001
      vertices.push(v.x * SCALE, v.y * SCALE, 0.0)
    for l in @linedefs
      lines.push(l.v-begin, l.v-end)

    @material = new THREE.LineBasicMaterial color: 0xffffff, linewidth: 5
    @geometry = new THREE.BufferGeometry!
      ..setAttribute 'position', new THREE.Float32BufferAttribute(vertices, 3)
      ..setIndex lines
      ..computeBoundingSphere!

    @obj = new THREE.LineSegments @geometry, @material
