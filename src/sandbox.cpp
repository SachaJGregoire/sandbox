#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include "sandbox.hpp"

using namespace godot;

void Sandbox::_bind_methods() {}

Sandbox::Sandbox() : grid(SANDBOX_WIDTH, SANDBOX_HEIGHT) {}
Sandbox::~Sandbox() {}

void Sandbox::_ready() {
    image = Image::create_empty(SANDBOX_WIDTH, SANDBOX_HEIGHT, false, Image::FORMAT_RGBA8);
    
    texture = ImageTexture::create_from_image(image);
    set_texture(texture);

    grid.preset(2);
}

void Sandbox::_process(double delta) {
    grid.update();

    for (size_t y = 0; y < SANDBOX_HEIGHT; ++y) {
        for (size_t x = 0; x < SANDBOX_WIDTH; ++x) {
            image->set_pixel(x, y, get_color(grid.get(x, y)));
        }
    }
    texture->update(image);
}
