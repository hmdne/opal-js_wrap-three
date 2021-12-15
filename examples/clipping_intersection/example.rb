# This example is adapted from https://threejs.org/examples/#webgl_clipping_intersection

require 'pp'
require 'js_wrap/three'

clip_planes = [
  Three::Plane.new(Three::Vector3.new(1, 0, 0), 0),
  Three::Plane.new(Three::Vector3.new(0, -1, 0), 0),
  Three::Plane.new(Three::Vector3.new(0, 0, -1), 0),  
]

renderer, scene, camera = nil

init = proc do
  renderer = Three::WebGLRenderer.new(antialias: true)
  renderer.set_pixel_ratio(JSGlobal.device_pixel_ratio)
  renderer.set_size(JSGlobal.inner_width, JSGlobal.inner_height)
  renderer.local_clipping_enabled = true
  JSGlobal.document.body.append_child(renderer.dom_element)

  scene = Three::Scene.new

  wdh = JSGlobal.inner_width / JSGlobal.inner_height
  $camera = camera = Three::PerspectiveCamera.new(40, wdh, 1, 200)
  camera.position.set(-1.5, 2.5, 3.0)
  camera.quaternion.set(0.122, -0.355, -0.905, 0.202)

  light = Three::HemisphereLight.new(0xffffff, 0x080808, 1.5)
  light.position.set(-1.25, 1, 1.25)
  scene << light

  # helper = Three::CameraHelper.new(light.shadow.camera)
  # scene << helper

  group = Three::Group.new
  (1..30).step(2).each do |i|
    geometry = Three::SphereGeometry.new(i/30, 48, 24)
    material = Three::MeshLambertMaterial.new(
      color: Three::Color.new.setHSL(rand, 0.5, 0.5),
      side: Three::DoubleSide,
      clipping_planes: clip_planes,
      clip_intersection: true
    )
    # line_material = Three::LineBasicMaterial.new(
    #   color: 0xffffff,
    #   transparent: true,
    #   opacity: 0.5
    # )
    # group.add Three::LineSegments.new(geometry, line_material)
    group << Three::Mesh.new(geometry, material)
  end
  scene << group

  # helpers = Three::Group.new
	# helpers << Three::PlaneHelper.new( clip_planes[0], 2, 0xff0000 )
	# helpers << Three::PlaneHelper.new( clip_planes[1], 2, 0x00ff00 )
	# helpers << Three::PlaneHelper.new( clip_planes[2], 2, 0x0000ff )
	# scene << helpers
end

render = proc do
  renderer.render(scene, camera)
end

JSGlobal.add_event_listener("DOMContentLoaded") do
  init.call
  render.call
end
