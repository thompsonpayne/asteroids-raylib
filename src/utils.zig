const rl = @import("raylib");

pub const MAX_BULLETS = 50;
pub const MAX_ASTEROIDS = 60;
pub const BULLET_SPEED = 500.0;
pub const BULLET_LIFE = 1.5; // seconds

pub const ROTATION_SPEED: f32 = 300.0; // degree per second
pub const ACCELERATION: f32 = 400.0;
pub const DRAG: f32 = 0.98; // friction (slow down 2% every frame)

pub const SCREEN_WIDTH = 800;
pub const SCREEN_HEIGHT = 450;

pub fn wrapObject(position: *rl.Vector2) void {
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
