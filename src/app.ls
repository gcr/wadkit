THREE = require 'three'

m3d = require './map-3d.ls'

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
camera.up.set 0,0,1

animate = ->
  #cube.rotation.x += 0.01
  #cube.rotation.y += 0.01
  request-animation-frame animate
  renderer.render scene, camera
animate!

require! 'fs'

content = fs.readFileSync("Maps/MAP07.wad") #;)

require! './wad-parser.ls'
console.time "parse WAD"
wad <- wad-parser.wad-parse content .then
console.time-end "parse WAD"
console.time "read wad info"
map <- wad-parser.wad-read-map wad, "MAP07" .then
console.time-end "read wad info"
require! './map-model.ls'
console.time "map model"
model = new map-model.MapModel map
console.time-end "map model"

map3d = new m3d.Map3dObj model
scene.add map3d.mesh

window.model = model
window.map3d = map3d

#counts = {}
#for s in model.sectors
#  counts[s.linedefs.length] = 1 + (counts[s.linedefs.length] or 0)
#console.log counts

#scene.add model.obj
#console.time "create geometry"
#scene.add map3d.sector-to-mesh model.sectors[89]
#scene.add map3d.sector-to-mesh model.sectors[0]
#for sector,i in model.sectors
#    try
#        scene.add map3d.sector-to-mesh sector
#    catch e
#        console.log e
#console.time-end "create geometry"

##model.obj.scale = THREE.Vector3 0.01,0.01,0.01
#console.log model.obj
#
OrbitControls = require('three-orbit-controls')(THREE)

new OrbitControls(camera, renderer.domElement)
