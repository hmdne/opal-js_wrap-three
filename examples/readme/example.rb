# This example is adapted from three.js README document.

require 'js_wrap/three'

camera = Three::PerspectiveCamera.new(
            70,
            JSGlobal.inner_width / JSGlobal.inner_height,
            0.01,
            10
          )
camera.position.z = 1

scene = Three::Scene.new

geometry = Three::BoxGeometry.new(0.2, 0.2, 0.2)
material = Three::MeshNormalMaterial.new

mesh = Three::Mesh.new(geometry, material)
scene.add(mesh)

renderer = Three::WebGLRenderer.new(antialias: true)
renderer.set_size(JSGlobal.inner_width, JSGlobal.inner_height)

renderer.set_animation_loop do |time|
	mesh.rotation.x = time / 2000
	mesh.rotation.y = time / 1000

  renderer.render(scene, camera)
end

JSGlobal.add_event_listener("DOMContentLoaded") do
  JSGlobal.document.body.append_child(renderer.dom_element)
end
