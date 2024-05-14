const rl = @import("raylib");
const rmath = @import("raylib-math");
const rgui = @cImport(@cInclude("raygui.h"));
const rl_c = @cImport(@cInclude("raylib.h"));
const std = @import("std");

const Bullet = struct {
    pos: rl.Vector2,
    texture: rl.Texture2D,
    dead: bool,
    pub fn init(position: rl.Vector2, texture: rl.Texture2D) Bullet {
        return Bullet{ .pos = rmath.vector2Subtract(position, rl.Vector2.init(0, @as(f32, @floatFromInt(texture.height)) / 2.0 * 0.2)), .texture = texture, .dead = false };
    }

    pub fn update(self: *Bullet) void {
        self.*.pos.x += 1000 * rl.getFrameTime();

        rl.drawTextureEx(self.texture, self.pos, 0, 0.2, rl.Color.white);
        if (self.pos.x > 800) {
            self.*.dead = true;
        }
    }
};

pub fn main() anyerror!void {
    // Initialization
    const allocator = std.heap.page_allocator;
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    rl.setExitKey(rl.KeyboardKey.key_null);
    //--------------------------------------------------------------------------------------
    var counter: i32 = 0;

    //var player = rl.Rectangle.init(400, 280, 40, 40);
    const player_speed = 400;
    const texture = rl.loadTexture("fenegun.png");
    var player_pos = rl.Vector2.init(30, 280);
    const bullet_spawn = rl.Vector2.init(50, 72);
    var bullets = std.ArrayList(Bullet).init(allocator);
    defer bullets.deinit();
    var dead_bullets = std.ArrayList(usize).init(allocator);
    defer dead_bullets.deinit();
    const bullet_texture = rl.loadTexture("tangerina.png");
    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------
        const width = @as(f32, @floatFromInt(texture.width));
        const height = @as(f32, @floatFromInt(texture.height));
        var walk_direction = rl.Vector2.init(0, 0);
        if (rl.isKeyDown(rl.KeyboardKey.key_up)) {
            counter += 1;
            walk_direction.y = -1;
        } else if (rl.isKeyDown(rl.KeyboardKey.key_down)) {
            counter -= 1;
            walk_direction.y = 1;
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_right)) {
            counter += 1;
            walk_direction.x = 1;
        } else if (rl.isKeyDown(rl.KeyboardKey.key_left)) {
            counter -= 1;
            walk_direction.x = -1;
        }
        if (rmath.vector2Length(walk_direction) != 0) {
            walk_direction = rmath.vector2Normalize(walk_direction);
            const speed = rl.getFrameTime() * player_speed;
            const speed_vector = rl.Vector2.init(speed, speed);
            walk_direction = rmath.vector2Multiply(walk_direction, speed_vector);
            player_pos.x += walk_direction.x;
            player_pos.y += walk_direction.y;
        }

        if (player_pos.x < 0) {
            player_pos.x = 0;
        } else if (player_pos.x > 800 - width * 0.1) {
            player_pos.x = 800 - width * 0.1;
        }

        if (player_pos.y < 0) {
            player_pos.y = 0;
        } else if (player_pos.y > 450 - height * 0.1) {
            player_pos.y = 450 - height * 0.1;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
            const bullet = Bullet.init(rmath.vector2Add(player_pos, bullet_spawn), bullet_texture);
            try bullets.append(bullet);
        }

        const message = try std.fmt.allocPrintZ(allocator, "Counter: {d}", .{counter});
        defer allocator.free(message);
        // const converted_message = try std.mem.Allocator.dupeZ(allocator, u8, message);
        // defer allocator.free(converted_message);
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.light_gray);
        //rl.drawRectangleRec(player, rl.Color.red);

        const source_rec = rl.Rectangle.init(0, 0, -width, height);
        const dest_rec = rl.Rectangle.init(player_pos.x, player_pos.y, width * 0.1, height * 0.1);
        rl.drawTexturePro(texture, source_rec, dest_rec, rl.Vector2.init(0, 0), 0, rl.Color.white);

        for (0..bullets.items.len) |i| {
            bullets.items[i].update();
            if (bullets.items[i].dead == true) {
                try dead_bullets.append(i);
            }
        }

        for (dead_bullets.items) |index| {
            _ = bullets.orderedRemove(index);
        }
        dead_bullets.clearAndFree();
        //----------------------------------------------------------------------------------
        if (rgui.GuiButton(.{ .x = 24, .y = 24, .width = 120, .height = 30 }, "cuuuuu") == 1) {
            std.debug.print("oiiii", .{});
        }
    }
}
