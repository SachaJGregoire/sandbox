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

    grid.set(40, 10, Particle(false, true, 0.5));
}

void Sandbox::_process(double delta) {
    grid.update_seq(); 

    for (size_t y = 0; y < SANDBOX_HEIGHT; ++y) {
        for (size_t x = 0; x < SANDBOX_WIDTH; ++x) {
            Particle p = grid.get(x, y);
            
            Color color = p.air ? Color(0.1, 0.1, 0.1, 1.0) : Color(0.86, 0.73, 0.36, 1.0);
            image->set_pixel(x, y, color);
        }
    }

    texture->update(image);
}