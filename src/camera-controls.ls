THREE = require 'three'

export class OrbitalPanCameraControls
  # References:
  # https://andreasrohner.at/posts/Web%20Development/JavaScript/Simple-orbital-camera-controls-for-THREE-js/
  # https://medium.com/@auchenberg/detecting-multi-touch-trackpad-gestures-in-javascript-a2505babb10e
  (@camera, @elt)->
    ## so camera.up is the orbit axis
    @up-quat = new THREE.Quaternion!.setFromUnitVectors @camera.up, new THREE.Vector3 0, 1, 0
    @up-quat-inverse = @up-quat.clone!.inverse!
    @mode = 'pan'

    #@camera.position.set 3, -3, 3
    @spherical = new THREE.Spherical 5, Math.PI*0.25, Math.PI*-0.25
    @target = new THREE.Vector3!
    @v = new THREE.Vector3!
    @m = new THREE.Matrix4!

    # handle mouse wheel scrolls
    # (this also works super nicely for mackbook trackpads!)
    @elt.add-event-listener 'keydown', @~handle-keydown, false
    @elt.add-event-listener 'keyup', @~handle-keyup, false
    @elt.add-event-listener 'wheel', @~handle-wheel, false
    @elt.add-event-listener 'gesturestart', (e) ~>
      e.prevent-default!
      # TODO
      return false
    @elt.add-event-listener 'gesturechange', (e) ~>
      e.prevent-default!
      # TODO
      return false
    @elt.add-event-listener 'gestureend', (e) ~>
      e.prevent-default!
      # TODO
      return false

  handle-wheel: (e)->
    e.prevent-default!
    if e.ctrlKey
      @zoom e.deltaY * 0.01
    else if e.shiftKey
      @pan-Z e.deltaY * 0.01
    else
      @move-X e.deltaX * 0.01
      @move-Y e.deltaY * 0.01
    return false

  handle-keydown: (e)->
    if e.code == 'Space' and not e.repeat
      @mode = 'orbit'
    #if e.code == 'Tab' and not e.repeat
    #  @mode = 'rise'
    #  e.prevent-default!
    return true
  handle-keyup: (e)->
    if e.code == 'Space'
      @mode = 'pan'
    return true
    #if e.code == 'Tab'
    #  @mode = 'pan'
    #  e.prevent-default!
    #  set-timeout @elt~focus, 25

  update: ->
    # clamp
    @spherical.phi = Math.max Math.PI*0.025, Math.min Math.PI*0.975, @spherical.phi
    @spherical.radius = Math.max 0.1, @spherical.radius
    @spherical.make-safe!
    @v.copy @camera.position .sub @target

    # rotate v to "y-axis-is-up" space
    @v.apply-quaternion @up-quat
    # Do the movement
    @v.set-from-spherical @spherical
    # And rotate back
    @v.apply-quaternion @up-quat-inverse

    @camera.position.copy @v .add @target
    @camera.look-at @target
    #console.log @serialize!

  pan: (x, y)->
    @v.copy @camera.position .sub @target
    @v.z = 0
    @v.normalize!
    @v.multiply-scalar y
    @target.add @v
    #@v.apply- new THREE.Vector3 1,0,0
    @v.set-from-matrix-column @camera.matrix, 0 # get X column of objectMatrix
    @v.multiply-scalar -x
    @target.add @v
    #@m.extract-rotation @camera.matrix
    #e = new THREE.Euler
    #e.set-from-rotation-matrix @m
    #e.y = 0
    #@v.apply-euler e


  move-X: (delta)->
    if @mode == 'orbit'
      # positive values: rotate CW around the target
      @spherical.theta += delta
    else if @mode == 'pan'
      @pan -delta, 0
  move-Y: (delta)->
    # positive values: rotate CW around the target (down)
    if @mode == 'orbit'
      @spherical.phi += delta
    else if @mode == 'pan'
      @pan 0, delta

  pan-Z: (delta) ->
    @target.setZ @target.z - delta

  zoom: (delta) ->
    @spherical.radius *= (1.0 + delta)

  serialize: ->
    # Save our state to a simple string that
    # can be restored later
    buf = new ArrayBuffer(24)
    dv = new DataView(buf)
    dv.setFloat32 0, @target.x
    dv.setFloat32 4, @target.y
    dv.setFloat32 8, @target.z
    dv.setFloat32 12, @spherical.phi
    dv.setFloat32 16, @spherical.theta
    dv.setFloat32 20, @spherical.radius
    s = ''
    for new Uint8Array buf then s += ..
    return btoa s
