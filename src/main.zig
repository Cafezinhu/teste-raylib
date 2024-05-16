const rl = @import("raylib");
const rmath = @import("raylib-math");
//const rgui = @cImport(@cInclude("raygui.h"));
//const rl_c = @cImport(@cInclude("raylib.h"));
const std = @import("std");

const allocator = std.heap.c_allocator;

const Team = enum { Player, Enemy };

const Entity = union(enum) {
    Enemy: Enemy,
    Bullet: Bullet,
    fn isDead(self: *Entity) bool {
        return switch (self.*) {
            inline else => |*entity| entity.*.isDead(),
        };
    }
    fn onCollideWith(self: *Entity, other: *Entity) void {
        switch (self.*) {
            inline else => |*entity| entity.onCollideWith(other),
        }
    }
};

const CircleCollider = struct { pos: rl.Vector2, radius: f32 };

const Enemy = union(enum) {
    BasicEnemy: BasicEnemy,
    fn takeDamage(self: *Enemy, ammount: f32) void {
        switch (self.*) {
            inline else => |*enemy| {
                if (enemy.dead) return;
                enemy.takeDamage(ammount);
            },
        }
    }

    fn update(self: *Enemy) void {
        switch (self.*) {
            inline else => |*enemy| enemy.update(),
        }
    }

    fn onCollideWith(self: *Enemy, other: *Entity) void {
        switch (self.*) {
            inline else => |*enemy| enemy.onCollideWith(other),
        }
    }

    fn getCircleCollider(self: *Enemy) CircleCollider {
        return switch (self.*) {
            inline else => |*enemy| enemy.getCircleCollider(),
        };
    }
    fn isDead(self: *Enemy) bool {
        return switch (self.*) {
            inline else => |*enemy| enemy.isDead(),
        };
    }
};

const BasicEnemy = struct {
    pos: rl.Vector2,
    texture: rl.Texture2D,
    hp: f32,
    scale: f32 = 1.5,
    dead: bool = false,
    colliderRadius: f32 = 30,

    fn init(position: rl.Vector2, texture: rl.Texture2D) BasicEnemy {
        return BasicEnemy{ .pos = rmath.vector2Subtract(position, rl.Vector2.init(0, @as(f32, @floatFromInt(texture.height)) / 2.0 * 0.2)), .texture = texture, .hp = 1 };
    }

    fn update(self: *BasicEnemy) void {
        self.*.pos.x -= 400 * rl.getFrameTime();
        rl.drawTextureEx(self.texture, self.pos, 0, self.scale, rl.Color.white);

        if (self.*.pos.x < 0) {
            self.*.dead = true;
        }
    }
    fn onCollideWith(_: *BasicEnemy, _: *Entity) void {}

    fn takeDamage(self: *BasicEnemy, amt: f32) void {
        self.*.hp -= amt;
        if (self.hp <= 0) {
            self.*.dead = true;
        }
    }
    fn getCircleCollider(self: *BasicEnemy) CircleCollider {
        return CircleCollider{ .pos = self.pos, .radius = self.colliderRadius };
    }
    fn isDead(self: *BasicEnemy) bool {
        return self.dead;
    }
};

const Bullet = struct {
    pos: rl.Vector2,
    texture: rl.Texture2D,
    dead: bool,
    team: Team,
    colliderRadius: f32 = 30,
    fn init(position: rl.Vector2, texture: rl.Texture2D, team: Team) Bullet {
        return Bullet{ .pos = rmath.vector2Subtract(position, rl.Vector2.init(0, @as(f32, @floatFromInt(texture.height)) / 2.0 * 0.2)), .texture = texture, .dead = false, .team = team };
    }

    fn update(self: *Bullet) void {
        self.*.pos.x += 1000 * rl.getFrameTime();

        rl.drawTextureEx(self.texture, self.pos, 0, 0.2, rl.Color.white);
        if (self.*.pos.x > 800) {
            self.*.dead = true;
        }
    }
    fn onCollideWith(self: *Bullet, other: *Entity) void {
        switch (other.*) {
            .Enemy => |*enemy| {
                switch (enemy.*) {
                    inline else => |*e| {
                        e.takeDamage(1);
                        self.*.dead = true;
                    },
                }
            },
            inline else => {},
        }
    }
    fn getCircleCollider(self: *Bullet) CircleCollider {
        return CircleCollider{ .pos = self.pos, .radius = self.colliderRadius };
    }
    fn isDead(self: *Bullet) bool {
        return self.dead;
    }
};

pub fn main() anyerror!void {
    // Initialization

    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Fenko pew pew");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    rl.setExitKey(rl.KeyboardKey.key_null);
    //--------------------------------------------------------------------------------------
    //entitidades do jogo

    var entities = std.ArrayList(Entity).init(allocator);

    defer entities.deinit();

    const bullet_texture = rl.loadTexture("resources/tangerina.png");
    const winton = rl.loadTexture("resources/winton.png");
    const texture = rl.Texture.init("resources/fenegun.png");
    defer rl.unloadTexture(texture);
    //
    const attack_speed: f32 = 5;
    var attack_cooldown: f32 = 0;
    const player_speed = 400;
    var player_pos = rl.Vector2.init(30, 280);
    const bullet_spawn = rl.Vector2.init(50, 72);
    const enemySpawnSpeed: f32 = 2;
    var enemySpawnCooldown: f32 = 0;

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------

        const width = @as(f32, @floatFromInt(texture.width));
        const height = @as(f32, @floatFromInt(texture.height));
        var walk_direction = rl.Vector2.init(0, 0);
        if (rl.isKeyDown(rl.KeyboardKey.key_up) or rl.isKeyDown(rl.KeyboardKey.key_w)) {
            walk_direction.y = -1;
        } else if (rl.isKeyDown(rl.KeyboardKey.key_down) or rl.isKeyDown(rl.KeyboardKey.key_s)) {
            walk_direction.y = 1;
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_right) or rl.isKeyDown(rl.KeyboardKey.key_d)) {
            walk_direction.x = 1;
        } else if (rl.isKeyDown(rl.KeyboardKey.key_left) or rl.isKeyDown(rl.KeyboardKey.key_a)) {
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
        //
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
        attack_cooldown += rl.getFrameTime();
        //
        if (rl.isKeyDown(rl.KeyboardKey.key_space) and attack_cooldown >= 1.0 / attack_speed) {
            const bullet_entity = Entity{ .Bullet = Bullet.init(rmath.vector2Add(player_pos, bullet_spawn), bullet_texture, Team.Player) };

            try entities.append(bullet_entity);
            attack_cooldown = 0.0;
        }
        //
        enemySpawnCooldown += rl.getFrameTime();

        if (enemySpawnCooldown >= 1.0 / enemySpawnSpeed) {
            const enemy_entity = Entity{ .Enemy = Enemy{ .BasicEnemy = BasicEnemy.init(rl.Vector2{ .x = 800, .y = @as(f32, @floatFromInt(rl.getRandomValue(60, 390))) }, winton) } };
            try entities.append(enemy_entity);
            enemySpawnCooldown = 0.0;
        }

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
        var index: usize = 0;
        while (index < entities.items.len) {
            const entity = &entities.items[index];
            switch (entity.*) {
                inline else => |*one_entity| {
                    one_entity.update();
                    const circle_collider: CircleCollider = one_entity.getCircleCollider();
                    for (index + 1..entities.items.len) |j| {
                        const other = &entities.items[j];
                        switch (other.*) {
                            inline else => |*other_entity| {
                                const other_circle_collider: CircleCollider = other_entity.getCircleCollider();
                                const distance = rmath.vector2Distance(circle_collider.pos, other_circle_collider.pos);

                                if (distance <= circle_collider.radius + other_circle_collider.radius) {
                                    //std.debug.print("\nColidiu aui {d}", .{distance});
                                    entity.onCollideWith(other);
                                    other.onCollideWith(entity);
                                }
                            },
                        }
                    }
                },
            }
            index += 1;
        }

        if (entities.items.len > 0) {
            var index2 = @as(i32, @intCast(entities.items.len)) - 1;
            while (index2 >= 0) {
                const i = @as(usize, @intCast(index2));
                if (entities.items[i].isDead()) {
                    _ = entities.swapRemove(i);
                }

                index2 -= 1;
            }
        }
    }
}
