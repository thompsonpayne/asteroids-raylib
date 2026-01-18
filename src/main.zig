const std = @import("std");

const rl = @import("raylib");

const asteroid_mod = @import("asteroid.zig");
const Asteroid = asteroid_mod.Asteroid;
const bullet_mod = @import("bullet.zig");
const Bullet = bullet_mod.Bullet;
const particles_mod = @import("particles.zig");
const Particle = particles_mod.Particle;
const ship_mod = @import("ship.zig");
const Ship = ship_mod.Ship;
const utils = @import("utils.zig");
const MAX_BULLETS = utils.MAX_BULLETS;
const BULLET_SPEED = utils.BULLET_SPEED;
const SCREEN_WIDTH = utils.SCREEN_WIDTH;
const SCREEN_HEIGHT = utils.SCREEN_HEIGHT;
const MAX_ASTEROIDS = utils.MAX_ASTEROIDS;
const MAX_PARTICLES = utils.MAX_PARTICLES;
const ACCELERATION = utils.ACCELERATION;

pub fn main() !void {
    var bullets: [MAX_BULLETS]Bullet = bullet_mod.init();
    var asteroids: [MAX_ASTEROIDS]Asteroid = asteroid_mod.init();
    var particles: [MAX_PARTICLES]Particle = particles_mod.init();

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "DAsteroids");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const ship_texture = try rl.loadTexture("src/assets/ship.png");
    var ship: Ship = .init(.{ .x = SCREEN_WIDTH / 2.0, .y = SCREEN_HEIGHT / 2.0 }, ship_texture);
    defer ship.deinit();

    // NOTE: Game loop
    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        rl.beginDrawing();
        defer rl.endDrawing();

        ship.handleMovement(dt);

        try ship.draw();
        // debug
        const speed = rl.Vector2.length(ship.velocity);
        rl.drawText(
            rl.textFormat("Speed: %.2f", .{speed}),
            SCREEN_WIDTH - 200.0,
            10,
            20,
            .white,
        );
        rl.drawFPS(10, 10);

        // draw asteroids
        asteroid_mod.draw(&asteroids, dt);
        asteroid_mod.handleCollisionOnEachOther(&asteroids, &particles);

        ship.handleShooting(&bullets, &asteroids, &particles, dt);
        ship.handleAsteroidCollision(&asteroids, &particles);

        particles_mod.update(&particles, dt);

        rl.clearBackground(.black);

        particles_mod.draw(&particles);
    }
}
