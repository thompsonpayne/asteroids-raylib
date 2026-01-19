const rl = @import("raylib");

pub const MAX_BULLETS = 50;
pub const MAX_MISSLES = 10;
pub const MAX_ASTEROIDS = 60;
pub const INIT_ASTEROIDS = 8;
pub const BULLET_SPEED = 200.0;
pub const BULLET_LIFE = 5.5; // seconds

pub const ROTATION_SPEED: f32 = 300.0; // degree per second
pub const ACCELERATION: f32 = 400.0;
pub const DRAG: f32 = 0.98; // friction (slow down 2% every frame)

pub const MAX_PARTICLES = 200;

pub const SCREEN_WIDTH = 1280;
pub const SCREEN_HEIGHT = 720;

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

pub fn lerpColor(c1: rl.Color, c2: rl.Color, t: f32) rl.Color {
    const rt = @as(f32, 1.0) - t;
    return .{
        .r = @intFromFloat(@as(f32, @floatFromInt(c1.r)) * rt + @as(f32, @floatFromInt(c2.r)) * t),
        .g = @intFromFloat(@as(f32, @floatFromInt(c1.g)) * rt + @as(f32, @floatFromInt(c2.g)) * t),
        .b = @intFromFloat(@as(f32, @floatFromInt(c1.b)) * rt + @as(f32, @floatFromInt(c2.b)) * t),
        .a = @intFromFloat(@as(f32, @floatFromInt(c1.a)) * rt + @as(f32, @floatFromInt(c2.a)) * t),
    };
}
