const std = @import("std");
const rl = @import("raylib");

const Ship = struct {
    position: rl.Vector2,
    velocity: rl.Vector2, // speed x, speed y
    rotation: f32, // direction facing (degree)
};

const Bullet = struct {
    active: bool,
    position: rl.Vector2,
    velocity: rl.Vector2,
    life_time: f32, // seconds to live
};

const MAX_BULLETS = 50;
const BULLET_SPEED = 500.0;
const BULLET_LIFE = 1.5; // seconds

const ROTATION_SPEED: f32 = 300.0; // degree per second
const ACCELERATION: f32 = 400.0;
const DRAG: f32 = 0.98; // friction (slow down 2% every frame)

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

pub fn main() !void {
    var bullets: [MAX_BULLETS]Bullet = undefined;

    for (0..MAX_BULLETS) |i| {
        bullets[i] = Bullet{
            .active = false,
            .position = rl.Vector2{ .x = 0, .y = 0 },
            .velocity = rl.Vector2{ .x = 0, .y = 0 },
            .life_time = 0,
        };
    }

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Game example");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var ship: Ship = .{
        .position = .{ .x = 100, .y = 200 },
        .rotation = 0,
        .velocity = .{ .x = 0, .y = 0 },
    };

    // NOTE: Game loop here
    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        rl.beginDrawing();
        defer rl.endDrawing();

        if (rl.isKeyDown(.right)) {
            ship.rotation += dt * ROTATION_SPEED;
        }

        if (rl.isKeyDown(.left)) {
            ship.rotation -= dt * ROTATION_SPEED;
        }

        if (rl.isKeyDown(.up)) {
            // thrust and rotation
            const rads = ship.rotation * (std.math.pi / 180.0);

            const force_x = std.math.cos(rads) * ACCELERATION * dt;
            const force_y = std.math.sin(rads) * ACCELERATION * dt;

            ship.velocity.x += force_x;
            ship.velocity.y += force_y;
        }

        ship.position.x += ship.velocity.x * dt;
        ship.position.y += ship.velocity.y * dt;

        // drag down the velocity
        ship.velocity.x *= DRAG;
        ship.velocity.y *= DRAG;

        if (ship.position.x > SCREEN_WIDTH) {
            ship.position.x = 0;
        } else if (ship.position.x < 0) {
            ship.position.x = SCREEN_WIDTH;
        }

        if (ship.position.y > SCREEN_HEIGHT) {
            ship.position.y = 0;
        } else if (ship.position.y < 0) {
            ship.position.y = SCREEN_HEIGHT;
        }

        wrapObject(&ship.position);
        drawShip(ship.position, ship.rotation);

        if (rl.isKeyPressed(.space)) {
            // NOTE: shooting
            blk: for (0..MAX_BULLETS) |i| {
                var bullet = &bullets[i];

                if (!bullet.active) {
                    // wake bullet up
                    bullet.active = true;
                    bullet.life_time = BULLET_LIFE;

                    bullet.position = ship.position;

                    const rads = ship.rotation * (std.math.pi / 180.0);
                    bullet.velocity.x = (std.math.cos(rads) * BULLET_SPEED) + ship.velocity.x;
                    bullet.velocity.y = (std.math.sin(rads) * BULLET_SPEED) + ship.velocity.y;
                    break :blk;
                }
            }
        }

        for (0..MAX_BULLETS) |i| {
            var bullet = &bullets[i];

            if (bullet.active) {
                // Move
                bullet.position.x += bullet.velocity.x * dt;
                bullet.position.y += bullet.velocity.y * dt;

                wrapObject(&bullet.position);

                // age bullet
                bullet.life_time -= dt;

                // kill if too old
                if (bullet.life_time <= 0) {
                    bullet.active = false;
                }
            }
        }

        for (bullets) |b| {
            if (b.active) {
                rl.drawCircleV(b.position, 2.0, .ray_white);
            }
        }

        rl.clearBackground(.black);
    }
}

fn wrapObject(position: *rl.Vector2) void {
    const buffer: f32 = 20.0; // ~ship/asteroid size

    if (position.x > SCREEN_WIDTH + buffer) {
        position.x = -buffer;
    } else if (position.x < -buffer) {
        position.x = SCREEN_WIDTH + buffer;
    }

    if (position.y > SCREEN_HEIGHT + buffer) {
        position.y = -buffer;
    } else if (position.y < -buffer) {
        position.y = SCREEN_HEIGHT + buffer;
    }
}

fn drawShip(position: rl.Vector2, rotaion: f32) void {
    const length: f32 = 25.0; // nose length
    const width: f32 = 12.0; // wings width

    // The three points of our triangle relative to (0,0)
    // We assume 0 degrees is facing RIGHT (Positive X)
    const p1 = rl.Vector2{ .x = length, .y = 0 }; //nose
    const p2 = rl.Vector2{ .x = -length, .y = -width }; //back left
    const p3 = rl.Vector2{ .x = -length, .y = width }; //back left

    const rads = rotaion * (std.math.pi / 180.0);
    const s = std.math.sin(rads);
    const c = std.math.cos(rads);

    // 3. Rotate and Move each point
    // Formula:
    // new_x = (x * cos) - (y * sin) + ship_x
    // new_y = (x * sin) + (y * cos) + ship_y

    const nose = rl.Vector2{
        .x = (p1.x * c) - (p1.y * s) + position.x,
        .y = (p1.x * s) + (p1.y * c) + position.y,
    };

    const left_wing = rl.Vector2{
        .x = (p2.x * c) - (p2.y * s) + position.x,
        .y = (p2.x * s) + (p2.y * c) + position.y,
    };

    const right_wing = rl.Vector2{
        .x = (p3.x * c) - (p3.y * s) + position.x,
        .y = (p3.x * s) + (p3.y * c) + position.y,
    };

    // 4. Draw the lines connecting them
    rl.drawLineV(nose, left_wing, rl.Color.white); // Nose -> Left
    rl.drawLineV(left_wing, right_wing, rl.Color.white); // Left -> Right (The back)
    rl.drawLineV(right_wing, nose, rl.Color.white); // Right -> Nose
}
