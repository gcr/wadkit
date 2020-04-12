Vue = require 'vue/dist/vue.js'

Vue.component 'wad-upload-zone' do
  template: '''
  <div class="fullsize"
       @drop="drop"
       @dragover.prevent="dragging=true"
       @dragleave.prevent="dragging=false"
       >
      <div style="margin: auto;"
          class="editor-panel"
          :class="{pink: dragging}"
          >
          <h4>Drag a file over me...</h4>
            <input type='file'
                   ref='file'
                   style='display: none;'
                   accept='.wad,.pk3,.kart'
                   @input='inputfile'
                   />
            <button @click="$refs.file.click()"
              class="add-file"
              >Open...</button>
          </div>
  </div>
  '''
  data: ->
    dragging: false
  methods:
    inputfile: ->
      file = @$refs.file.files[0]
      @$emit "file", file
    drop: (ev)->
      @dragging = false
      ev.prevent-default!
      file = null
      if ev.data-transfer.items
        for item in ev.data-transfer.items
          if item.kind == 'file'
            file = item.get-as-file!
            break
      else
        for file in ev.data-transfer.files
          break
      if file
        @$emit "file", file

    dragover: (ev)->
      @dragging = true
      ev.prevent-default!
    dragend: (ev)->
      @dragging = false
      ev.prevent-default!
