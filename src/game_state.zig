const std = @import("std");

const rl = @import("raylib");

const utils = @import("utils.zig");
const SCREEN_WIDTH = utils.SCREEN_WIDTH;
const SCREEN_HEIGHT = utils.SCREEN_HEIGHT;

pub const GameState = enum {
    game_over,
    title,
    playing,
};

pub const TitleScreenItem = enum {
    start,
    quit,

    pub fn label(self: TitleScreenItem) []const u8 {
        return switch (self) {
            .start => "Start game",
            .quit => "Quit",
        };
    }
};

pub const LIST_MENU_ITEMS = [_]TitleScreenItem{ .start, .quit };
const FONT_SIZE: f32 = 40.0;
const SPACING: f32 = 2.0;
const SPACING_BETWEEN_ITEMS: f32 = 60.0;
const TITLE = "DAsteroids";

pub const TitleScreen = struct {
    current_index: usize,

    pub fn init() TitleScreen {
        return .{ .current_index = 0 };
    }

    pub fn handleNavigate(self: *TitleScreen) ?GameState {
        // navigate up
        if (rl.isKeyPressed(.up) or rl.isKeyPressed(.w)) {
            if (self.current_index > 0) {
                self.current_index -= 1;
            } else {
                self.current_index = LIST_MENU_ITEMS.len - 1;
            }
        }

        if (rl.isKeyPressed(.down) or rl.isKeyPressed(.s)) {
            if (self.current_index < LIST_MENU_ITEMS.len - 1) {
                self.current_index += 1;
            } else {
                self.current_index = 0;
            }
        }

        if (rl.isKeyPressed(.enter) or rl.isKeyPressed(.kp_enter)) {
            if (LIST_MENU_ITEMS[self.current_index] == .start) {
                return .playing;
            }

            if (LIST_MENU_ITEMS[self.current_index] == .quit) {
                return null;
            }
        }

        return .title;
    }

    pub fn draw(self: *TitleScreen) !void {
        const title_dim = rl.measureTextEx(
            try rl.getFontDefault(),
            TITLE,
            FONT_SIZE * 2,
            SPACING,
        );

        rl.drawTextEx(
            try rl.getFontDefault(),
            TITLE,
            .{ .x = (SCREEN_WIDTH - title_dim.x) / 2.0, .y = (SCREEN_HEIGHT - title_dim.y) / 2.0 },
            FONT_SIZE * 2,
            SPACING,
            .ray_white,
        );

        var y_offset: f32 = SCREEN_HEIGHT * 0.6;
        for (LIST_MENU_ITEMS, 0..) |item, index| {
            const is_selected = index == self.current_index;
            const color: rl.Color = if (is_selected) .yellow else .white;
            const prefix: []const u8 = if (is_selected) ">" else "";

            var buf: [2048]u8 = undefined;
            const text = try std.fmt.bufPrintZ(
                &buf,
                "{s}{s}",
                .{ prefix, @tagName(item) },
            );

            const dim = rl.measureTextEx(try rl.getFontDefault(), text, FONT_SIZE, SPACING);
            rl.drawTextEx(
                try rl.getFontDefault(),
                text,
                .{ .x = (SCREEN_WIDTH - dim.x) / 2.0, .y = y_offset },
                FONT_SIZE,
                SPACING,
                color,
            );
            y_offset += SPACING_BETWEEN_ITEMS;
        }
    }
};
