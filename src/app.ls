THREE = require 'three'

# Make renderer
scene = new THREE.Scene()
camera = new THREE.PerspectiveCamera( 90, window.innerWidth / window.innerHeight, 0.1, 1000 )
renderer = new THREE.WebGLRenderer()
renderer.setSize( window.innerWidth, window.innerHeight )
document.body.appendChild( renderer.domElement )

# Make a cuuuuube ??
#geometry = new THREE.BoxGeometry!
#material = new THREE.MeshBasicMaterial color: 0x00ff00
#cube = new THREE.Mesh geometry, material
#scene.add cube


camera.position.z = 4

animate = ->
  #cube.rotation.x += 0.01
  #cube.rotation.y += 0.01
  request-animation-frame animate
  renderer.render scene, camera
animate!


require! 'fs'
content = fs.readFileSync("Maps/MAPM8.wad") #;)

require! './wad-parser.ls'
wad <- wad-parser.parse-wad content .then
map <- wad-parser.wad-read-map wad, "MAPM8" .then
console.log "Loading...", map
require! './map-model.ls'
model = new map-model.MapModel map


scene.add model.obj
#model.obj.scale = THREE.Vector3 0.01,0.01,0.01
console.log model.obj

OrbitControls = require('three-orbit-controls')(THREE)

new OrbitControls(camera, renderer.domElement)
