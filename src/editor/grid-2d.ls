THREE = require 'three'
DymanicBufferGeometry = require '../3d/dynamic-buffer-geometry.ls'

grid-material = ({color, smooth-start, smooth-end, depth-test})->
  new THREE.ShaderMaterial do
    uniforms:
      color: {type: 'f', value: color}
      smooth-start: {type: 'f', value: smooth-start}
      smooth-end: {type: 'f', value: smooth-end}
      target: {type: 'f', value: new THREE.Vector2 0,0}
    vertex-shader: """
      varying vec2 vposition;
      void main () {
        vposition = position.xy;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    """
    fragment-shader: """
      uniform vec2 target;
      uniform vec3 color;
      uniform float smoothStart;
      uniform float smoothEnd;
      varying vec2 vposition;
      void main() {
          float dist = distance(target, vposition);
          float intensity = smoothstep(smoothStart, smoothEnd, dist);
          gl_FragColor = vec4(color * intensity, 1.0);
      }
    """
    depth-test: depth-test
    depth-write: false
    blending: THREE.AdditiveBlending

export class MapGrid2D extends THREE.Object3D
  (@map-model, @controls)->
    super!
    vectors = []
    for l in @map-model.linedefs
      vectors.push l.v-begin.x, l.v-begin.y, 0
      vectors.push l.v-end.x, l.v-end.y, 0
    line-geo = new THREE.BufferGeometry!
    line-geo.set-attribute 'position', new THREE.Float32BufferAttribute vectors, 3

    @lines = new THREE.LineSegments line-geo, grid-material do
      color: new THREE.Vector3 0.5,0.5,0.5
      smooth-start: 8192.0
      smooth-end: 256.0
      depth-test: false
    @add @lines
    #@lines-front = new THREE.LineSegments line-geo, grid-material do
    #  color: new THREE.Vector3 1.0,1.0,1.0
    #  smooth-start: 8192.0
    #  smooth-end: 256.0
    #  depth-test: true
    #@add @lines-front

    # Add grid
    x = -32768
    grid = []
    while x <= 32768
      grid.push x, -32768, 0
      grid.push x, 32768, 0
      grid.push -32768, x, 0
      grid.push 32768, x, 0
      x += 32
    @grid-geo = new THREE.BufferGeometry!
    @grid-geo.set-attribute 'position', new THREE.Float32BufferAttribute grid, 3
    #@grid-mat = new THREE.LineBasicMaterial do
    #  color: 0x222222ff
    #  depth-test: false
    #  blending: THREE.AdditiveBlending
    #@grid = new THREE.LineSegments @grid-geo, grid-material do
    #  color: new THREE.Vector3 0.3,0.3,0.3
    #  smooth-start: 2048.0
    #  smooth-end: 256.0
    #  depth-test: true
    #@add @grid
    @grid = new THREE.LineSegments @grid-geo, grid-material do
      color: new THREE.Vector3 0.3,0.3,0.3
      smooth-start: 2048.0
      smooth-end: 256.0
      depth-test: false
    @add @grid


  set-intensity: (val) ->
    #@grid.material.uniforms.color.value = new THREE.Vector3 0.3*val,0.3*val,0.3*val
    #@grid-front.material.uniforms.color.value = new THREE.Vector3 0.1*val,0.1*val,0.1*val
    #@lines-front.material.uniforms.color.value = new THREE.Vector3 val,val,val
    @lines.material.uniforms.color.value = new THREE.Vector3 val,val,val


  update: ->
    @position.setZ @controls.target.z
    for x in [@lines, @grid]
      x.material.uniforms.target.value = @controls.target.clone!.multiplyScalar 100
    #@grid-mat.uniforms-
