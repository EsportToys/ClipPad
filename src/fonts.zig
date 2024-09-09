const std = @import("std");
const win = std.os.windows;
const WINAPI = win.WINAPI;

pub const HFONT = *opaque {};
pub const LOGFONTA = extern struct {
    lfHeight: i32,
    lfWidth: i32,
    lfEscapement: i32,
    lfOrientation: i32,
    lfWeight: i32,
    lfItalic: u8,
    lfUnderline: u8,
    lfStrikeOut: u8,
    lfCharSet: u8,
    lfOutPrecision: u8,
    lfClipPrecision: u8,
    lfQuality: u8,
    lfPitchAndFamily: u8,
    lfFaceName: [32]u8,
};

pub extern "gdi32" fn CreateFontA(i32, i32, i32, i32, i32, u32, u32, u32, u32, u32, u32, u32, u32, [*:0]const u8) callconv(WINAPI) ?HFONT;
pub extern "gdi32" fn CreateFontIndirectA(*const LOGFONTA) callconv(WINAPI) ?HFONT;

pub const default_consolas: LOGFONTA = .{
    .lfHeight = -@as(i32, @intFromFloat(@round(11.0 * 96.0 / 72.0))), // TODO: dpi-awareness
    .lfWidth = 0,
    .lfEscapement = 0,
    .lfOrientation = 0,
    .lfWeight = 0,
    .lfItalic = 0,
    .lfUnderline = 0,
    .lfStrikeOut = 0,
    .lfCharSet = 0,
    .lfOutPrecision = 0,
    .lfClipPrecision = 0,
    .lfQuality = 0,
    .lfPitchAndFamily = 0,
    .lfFaceName = "Consolas".* ++ .{0} ** 24,
};
