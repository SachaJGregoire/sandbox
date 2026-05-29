#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/button.hpp>
#include "sandbox.hpp"
#include "materials.hpp"

using namespace godot;

void Sandbox::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_material", "material_index"), &Sandbox::set_material);
    ClassDB::bind_method(D_METHOD("reset_scene"), &Sandbox::reset_scene);
    ClassDB::bind_method(D_METHOD("toggle_freeze"), &Sandbox::toggle_freeze);
}

Sandbox::Sandbox() : grid(SANDBOX_WIDTH, SANDBOX_HEIGHT) {}
Sandbox::~Sandbox() {}

void Sandbox::_ready() {
    image = Image::create_empty(SANDBOX_WIDTH, SANDBOX_HEIGHT, false, Image::FORMAT_RGBA8);
    texture = ImageTexture::create_from_image(image);
    set_texture(texture);

    VBoxContainer *ui_column = memnew(VBoxContainer);
    
    ui_column->set_position(Vector2(start_x, start_y)); 
    ui_column->add_theme_constant_override("separation", spacing);
    add_child(ui_column);

    // generate the material buttons
    for (int i = 0; i < static_cast<int>(Mat::Count); ++i) {
        Button *btn = memnew(Button);
        btn->set_text(String(properties[i].name.c_str()));        
        btn->set_custom_minimum_size(Vector2(btn_width, btn_height));
        btn->connect("pressed", Callable(this, "set_material").bind(i));
        ui_column->add_child(btn);

        int btn_y = start_y + (i * (btn_height + spacing));

        for (int x = start_x; x < start_x + btn_width; ++x) {
            for (int y = btn_y; y < btn_y + btn_height; ++y) {
                if (x >= 0 && x < SANDBOX_WIDTH && y >= 0 && y < SANDBOX_HEIGHT) {
                    grid.set(x, y, Mat::Stone);
                }
            }
        }
    }

    // generate freeze button
    Button *btn_freeze = memnew(Button);
    btn_freeze->set_text("Freeze");
    btn_freeze->set_custom_minimum_size(Vector2(btn_width, btn_height));
    btn_freeze->connect("pressed", Callable(this, "toggle_freeze"));
    ui_column->add_child(btn_freeze);

    // generate reset button
    Button *btn_reset = memnew(Button);
    btn_reset->set_text("Reset");
    btn_reset->set_custom_minimum_size(Vector2(btn_width, btn_height));
    btn_reset->connect("pressed", Callable(this, "reset_scene"));
    ui_column->add_child(btn_reset);

    reset_scene();

}

void Sandbox::_process(double delta) {

    Input *input = Input::get_singleton();

    if (input->is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) {
        Vector2 mouse_pos = get_local_mouse_position();

        int mx = static_cast<int>(mouse_pos.x);
        int my = static_cast<int>(mouse_pos.y);
        int brush_radius = 15;

        for (int dx = -brush_radius; dx <= brush_radius; dx++) {
            for (int dy = -brush_radius; dy <= brush_radius; dy++) {
                
                if (dx * dx + dy * dy <= brush_radius * brush_radius) {
                    int target_x = mx + dx;
                    int target_y = my + dy;

                    if (target_x >= 0 && target_x < SANDBOX_WIDTH && target_y >= 0 && target_y < SANDBOX_HEIGHT && grid.get(target_x, target_y) == Mat::Air) {
                        grid.set(target_x, target_y, current_user_material);
                        grid.set_updated(target_x, target_y);
                    }
                }
            }
        }
    }

    if (!is_frozen) {
        grid.update();
    }

    for (size_t y = 0; y < SANDBOX_HEIGHT; ++y) {
        for (size_t x = 0; x < SANDBOX_WIDTH; ++x) {
            if (grid.get_updated(x, y)) image->set_pixel(x, y, get_color(grid.get(x, y)));
        }
    }
    grid.reset_updated();
    texture->update(image);
}

void Sandbox::set_material(int material_index) {
    current_user_material = static_cast<Mat>(material_index);
}

void Sandbox::toggle_freeze() {
    is_frozen = !is_frozen;
}

void Sandbox::reset_scene() {
    for (int x = 0; x < SANDBOX_WIDTH; ++x) {
        for (int y = 0; y < SANDBOX_HEIGHT; ++y) {
            grid.set(x, y, Mat::Air);
        }
    }
    // grid.preset();

    int total_buttons = static_cast<int>(Mat::Count) + 2; 

    for (int i = 0; i < total_buttons; ++i) {
        int btn_y = start_y + (i * (btn_height + spacing));

        for (int x = start_x; x < start_x + btn_width; ++x) {
            for (int y = btn_y; y < btn_y + btn_height; ++y) {
                if (x >= 0 && x < SANDBOX_WIDTH && y >= 0 && y < SANDBOX_HEIGHT) {
                    grid.set(x, y, Mat::Stone);
                }
            }
        }
    }

    for (size_t y = 0; y < SANDBOX_HEIGHT; ++y) {
        for (size_t x = 0; x < SANDBOX_WIDTH; ++x) {
            image->set_pixel(x, y, get_color(grid.get(x, y)));
        }
    }
    texture->update(image);
}
