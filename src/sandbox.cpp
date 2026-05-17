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

    for (int x = 60; x < 150; x++)
        for (int y = 150; y < 200; y++)
            grid.set(x, y, Particle::Sand());

    for (int x = 260; x < 390; x++)
        for (int y = 100; y < 150; y++)
            grid.set(x, y, Particle::Water());

    for (int x = 280; x < 320; x++)
        for (int y = 10; y < 50; y++)
            grid.set(x, y, Particle::Sand());
}

void Sandbox::_process(double delta) {
    grid.update();

    for (size_t y = 0; y < SANDBOX_HEIGHT; ++y) {
        for (size_t x = 0; x < SANDBOX_WIDTH; ++x) {
            Particle p = grid.get(x, y);
            Color color = Color(0.1, 0.1, 0.1, 1.0);

            if(p.type == ParticleType::Sand)
                color = Color(0.86, 0.73, 0.36, 1.0);
            else if(p.type == ParticleType::Water)
                color = Color(0.0, 0.4, 0.9, 1.0);

            image->set_pixel(x, y, color);
        }
    }

    texture->update(image);
}