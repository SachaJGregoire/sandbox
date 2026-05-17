#ifndef SANDBOX_HPP
#define SANDBOX_HPP

#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include "grid.hpp"

namespace godot {

class Sandbox : public TextureRect {
    GDCLASS(Sandbox, TextureRect)

private:
    const int SANDBOX_WIDTH = 600;
    const int SANDBOX_HEIGHT = 300;

    Grid grid;
    Ref<Image> image;
    Ref<ImageTexture> texture;

protected:
    static void _bind_methods();

public:
    Sandbox();
    ~Sandbox();

    void _ready() override;
    void _process(double delta) override;
};

} // namespace godot

#endif // SANDBOX_HPP