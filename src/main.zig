const std = @import("std");
const rl = @import("raylib");
const utils = @import("utils.zig");
const ship_mod = @import("ship.zig");
const bullet_mod = @import("bullet.zig");
const asteroid_mod = @import("asteroid.zig");

const Asteroid = asteroid_mod.Asteroid;
const Ship = ship_mod.Ship;
const Bullet = bullet_mod.Bullet;

const wrapObject = utils.wrapObject;

const MAX_BULLETS = utils.MAX_BULLETS;
const BULLET_SPEED = utils.BULLET_SPEED;
const SCREEN_WIDTH = utils.SCREEN_WIDTH;
const SCREEN_HEIGHT = utils.SCREEN_HEIGHT;

pub fn main() !void {
    var bullets: [MAX_BULLETS]Bullet = Bullet.init();
    const asteroids = asteroid_mod.initAsteroids();
    _ = asteroids;

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "DAsteroids");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var ship: Ship = .{
        .position = .{ .x = 100, .y = 200 },
        .rotation = 0,
        .velocity = .{ .x = 0, .y = 0 },
    };

    // NOTE: Game loop
    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        rl.beginDrawing();
        defer rl.endDrawing();

        ship.handleMovement(dt);
        wrapObject(&ship.position);
        ship.draw();
        ship.handleShooting(&bullets, dt);

        rl.clearBackground(.black);
    }
}
