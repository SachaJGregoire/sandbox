#ifndef SANDBOX_HPP
#define SANDBOX_HPP

#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include "grid.hpp"
#include "materials.hpp"

namespace godot {

class Sandbox : public TextureRect {
    GDCLASS(Sandbox, TextureRect)

private:
    const int SANDBOX_WIDTH = 1600;
    const int SANDBOX_HEIGHT = 900;

    int start_x = SANDBOX_WIDTH - 100;
    int start_y = 20;
    int btn_width = 80;
    int btn_height = 35;
    int spacing = 10;

    Grid grid;
    Ref<Image> image;
    Ref<ImageTexture> texture;

    Mat current_user_material = Mat::Sand;

    bool is_frozen = false;

protected:
    static void _bind_methods();

public:
    Sandbox();
    ~Sandbox();

    void _ready() override;
    void _process(double delta) override;

    void set_material(int material_index);
    void reset_scene();
    void toggle_freeze();};

} // namespace godot

#endif // SANDBOX_HPP