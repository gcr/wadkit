THREE = require 'three'

export class BufferGeoAggregate extends THREE.BufferGeometry

  # You apparently can't resize attributes.
  # So, allocate a Metric Fuckton of these attributes.

  (initial_alloc_mb, attributes)->
    super!
    all_attr_size = 0
    for k,size of attributes then all_attr_size += size

    @_allocated-n-elements = Math.ceil initial_alloc_mb*1024*1024/4/all_attr_size

    for attr_name, size of attributes
      arr = new Float32Array(size * @_allocated-n-elements)
      @set-attribute attr_name, new THREE.Float32BufferAttribute arr, size

    @_index-offset = 0
    @_attr-offset = 0
    @_metadata = new Map!
    @index = new THREE.Uint32BufferAttribute(new Uint32Array(@_allocated-n-elements * 3), 1)

  set: (key, geometries)->
    if @_metadata.has key
      m = @_metadata.get key
      n-vertices = n-index = 0
      for geometries then n-vertices += ..attributes.position.count
      for geometries then n-index += ..index.count
      if m.attr-used == n-vertices and m.index-used == n-index
        @_update key, geometries
      else
        @_delete key
        @_create key, geometries
    else
      @_create key, geometries

  _update: (key, geometries)->
    {attr-offset, index-offset} = @_metadata.get key
    for geo in geometries
      for name,attr of @attributes
        other-attr = geo.get-attribute name
        attr.set other-attr.array, attr-offset * attr.item-size
        attr.needs-update = true
      for i in [0 til geo.index.count]
        @index.setX index-offset + i, geo.index.getX(i)+attr-offset
      @index.needs-update = true
      index-offset += geo.index.count
      attr-offset += geo.attributes.position.count

  _delete: (key)->
    {attr-offset, index-offset, attr-used, index-used} = @_metadata.get key
    # For each attribute: Delete from attr-offset to attr-used
    for name,attr of @attributes
      sz = attr.item-size
      attr.array.copy-within attr-offset*sz, (attr-offset+attr-used)*sz
      attr.needs-update = true
    # Adjust the index
    # First, delete the portion of the index
    @index.array.copy-within index-offset, index-offset + index-used
    # Then, iterate through and change all the values
    for i in [0 til @_index-offset]
      arr = @index.array
      if arr[i] > attr-offset
        arr[i] -= attr-used
    @index.needs-update = true
    @_attr-offset -= attr-used
    @_index-offset -= index-used
    @set-draw-range 0, @_index-offset

    @_metadata.delete key

    # Next, fixup all metadata
    entries = @_metadata.values!
    until (itt = entries.next!).done
      if itt.value.attr-offset >= attr-offset
        itt.value.attr-offset -= attr-used
      if itt.value.index-offset >= index-offset
        itt.value.index-offset -= index-used


  _create: (key, geometries)->
    # Number of used vertices
    attr-offset = @_attr-offset
    # Number of used indices that represent vertices.
    # Typically grows much faster than attr-offset.
    index-offset = @_index-offset

    for geo in geometries
      for name,attr of @attributes
        other-attr = geo.get-attribute name
        attr.set other-attr.array, attr-offset * attr.item-size
      for i in [0 til geo.index.count]
        @index.setX index-offset + i, geo.index.getX(i)+attr-offset
      index-offset += geo.index.count
      attr-offset += geo.attributes.position.count


    m = {
      attr-offset: @_attr-offset, index-offset: @_index-offset,
      attr-used: attr-offset - @_attr-offset, index-used: index-offset - @_index-offset
    }
    @_attr-offset = attr-offset
    @_index-offset = index-offset

    if m.attr-used > 0
      @_metadata.set key, m
    @set-draw-range 0, @_index-offset
