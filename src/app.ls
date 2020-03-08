THREE = require 'three'
require! './wad-parser.ls'
tex3d = require './tex-3d.ls'
require! 'fs'

fetch-remote-file = (url) ->>
    response = await fetch url
    buf = await response.arrayBuffer()
    return buf

m3d = require './map-3d.ls'

# Make renderer
scene = new THREE.Scene()
camera = new THREE.PerspectiveCamera( 90, window.innerWidth / window.innerHeight, 0.1, 1000 )
renderer = new THREE.WebGLRenderer(antialias: true)
renderer.setSize( window.innerWidth, window.innerHeight )
document.body.appendChild( renderer.domElement )

# Make a cuuuuube ??
#geometry = new THREE.BoxGeometry!
#material = new THREE.MeshBasicMaterial color: 0x00ff00
#cube = new THREE.Mesh geometry, material
#scene.add cube


camera.position.z = 4
camera.up.set 0,0,1

animate = ->
  #cube.rotation.x += 0.01
  #cube.rotation.y += 0.01
  request-animation-frame animate
  renderer.render scene, camera
animate!

MAP = "MAP01"

buf <- fetch-remote-file "assets/#{MAP}.wad" .then
console.time "parse WAD"
wad <- wad-parser.wad-parse buf .then
console.time-end "parse WAD"
console.time "read wad info"
map <- wad-parser.wad-read-map wad, MAP .then
console.time-end "read wad info"

require! './map-model.ls'
console.time "map model"
model = new map-model.MapModel map
console.time-end "map model"

# Load textures
buf <- fetch-remote-file "assets/gfx.wad" .then
gfx-wad <- wad-parser.wad-parse buf .then
tex-man = new tex3d.TextureManager!
tex-man.ingest-wad gfx-wad

# Construct geometry
console.time 'map3d'
map3d = new m3d.Map3dObj model, tex-man
console.time-end 'map3d'

scene.add map3d.mesh
window.model = model
window.map3d = map3d
OrbitControls = require('three-orbit-controls')(THREE)
new OrbitControls(camera, renderer.domElement)
