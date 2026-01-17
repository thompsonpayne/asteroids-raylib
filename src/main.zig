const std = @import("std");
const rl = @import("raylib");
const utils = @import("utils.zig");
const ship_mod = @import("ship.zig");
const bullet_mod = @import("bullet.zig");
const asteroid_mod = @import("asteroid.zig");
const particles_mod = @import("particles.zig");

const Asteroid = asteroid_mod.Asteroid;
const Ship = ship_mod.Ship;
const Bullet = bullet_mod.Bullet;
const Particle = particles_mod.Particle;

const MAX_BULLETS = utils.MAX_BULLETS;
const BULLET_SPEED = utils.BULLET_SPEED;
const SCREEN_WIDTH = utils.SCREEN_WIDTH;
const SCREEN_HEIGHT = utils.SCREEN_HEIGHT;
const MAX_ASTEROIDS = utils.MAX_ASTEROIDS;
const MAX_PARTICLES = utils.MAX_PARTICLES;
const ACCELERATION = utils.ACCELERATION;
const DRAG = utils.DRAG;
const SPREAD_DEGREE = 180.0;

pub fn main() !void {
    var bullets: [MAX_BULLETS]Bullet = bullet_mod.init();
    var asteroids: [MAX_ASTEROIDS]Asteroid = asteroid_mod.init();
    var particles: [MAX_PARTICLES]Particle = particles_mod.init();

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "DAsteroids");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const ship_texture = try rl.loadTexture("src/assets/11.png");
    var ship: Ship = .init(.{ .x = SCREEN_WIDTH / 2.0, .y = SCREEN_HEIGHT / 2.0 }, ship_texture);
    defer ship.deinit();

    // NOTE: Game loop
    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        rl.beginDrawing();
        defer rl.endDrawing();

        ship.handleMovement(dt);

        ship.draw();

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
