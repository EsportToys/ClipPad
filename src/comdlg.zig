const std = @import("std");
const win = std.os.windows;
const WINAPI = win.WINAPI;

const fonts = @import("fonts.zig");

pub extern "comdlg32" fn CommDlgExtendedError() callconv(WINAPI) u32;
pub extern "comdlg32" fn GetOpenFileNameA(*OPENFILENAMEA) callconv(WINAPI) i32;
pub extern "comdlg32" fn GetSaveFileNameA(*OPENFILENAMEA) callconv(WINAPI) i32;
pub extern "comdlg32" fn ChooseFontA(*CHOOSEFONTA) callconv(WINAPI) i32;
pub extern "comdlg32" fn ChooseColorA(*CHOOSECOLORA) callconv(WINAPI) i32;
pub extern "comdlg32" fn FindTextA(*FINDREPLACEA) callconv(WINAPI) ?*const anyopaque;
pub extern "comdlg32" fn ReplaceTextA(*FINDREPLACEA) callconv(WINAPI) ?*const anyopaque;

pub const OFNHOOKPROC = fn (*const anyopaque, u32, usize, isize) callconv(WINAPI) usize;
pub const OPENFILENAMEA = extern struct {
    lStructSize: u32 = @sizeOf(OPENFILENAMEA),
    hwndOwner: ?*const anyopaque = null,
    hInstance: ?*const anyopaque = null,
    lpstrFilter: ?[*:0]const u8 = null,
    lpstrCustomFilter: ?[*:0]u8 = null,
    nMaxCustFilter: u32 = 0,
    nFilterIndex: u32 = 0,
    lpstrFile: [*:0]u8,
    nMaxFile: u32,
    lpstrFileTitle: ?[*:0]u8 = null,
    nMaxFileTitle: u32 = 0,
    lpstrInitialDir: ?[*:0]const u8 = null,
    lpstrTitle: ?[*:0]const u8 = null,
    Flags: u32 = 0,
    nFileOffset: u16 = 0,
    nFileExtension: u16 = 0,
    lpstrDefExt: ?[*:0]const u8 = null,
    lCustData: isize = 0,
    lpfnHook: ?*const OFNHOOKPROC = null,
    lpTemplateName: ?[*:0]const u8 = null,
    // lpEditInfo: ?*const anyopaque = null,
    // lpstrPrompt: ?[*:0]const u8 = null,
    pvReserved: ?*const anyopaque = null,
    dwReserved: u32 = 0,
    FlagsEx: u32 = 0,
};

pub const CFHOOKPROC = fn (*const anyopaque, u32, usize, isize) callconv(WINAPI) usize;
pub const CHOOSEFONTA = extern struct {
    lStructSize: u32 = @sizeOf(@This()),
    hwndOwner: ?*const anyopaque = null,
    hDC: ?win.HDC = null,
    lpLogFont: *fonts.LOGFONTA,
    iPointSize: i32 = 0,
    Flags: u32 = 0,
    rgbColors: u32 = 0,
    lCustData: isize = 0,
    lpfnHook: ?*const CFHOOKPROC = null,
    lpTemplateName: ?[*:0]const u8 = null,
    hInstance: ?*const anyopaque = null,
    lpszStyle: ?[*:0]u8 = null,
    nFontType: u16 = 0,
    ___MISSING_ALIGNMENT__: u8 = 0,
    nSizeMin: i32 = 0,
    nSizeMax: i32 = 0,
};

pub const CCHOOKPROC = fn (*const anyopaque, u32, usize, isize) callconv(WINAPI) usize;
pub const CHOOSECOLORA = extern struct {
    lStructSize: u32 = @sizeOf(@This()),
    hwndOwner: ?*const anyopaque = null,
    hInstance: ?*const anyopaque = null,
    rgbResult: u32 = 0,
    lpCustColors: *[16]u32,
    Flags: u32 = 0,
    lCustData: isize = 0,
    lpfnHook: ?*const CCHOOKPROC = null,
    lpTemplateName: ?[*:0]const u8 = null,
};

pub const FRHOOKPROC = fn (*const anyopaque, u32, usize, isize) callconv(WINAPI) usize;
pub const FINDREPLACEA = extern struct {
    lStructSize: u32 = @sizeOf(@This()),
    hwndOwner: *const anyopaque,
    hInstance: ?*const anyopaque = null,
    Flags: u32 = 0,
    lpstrFindWhat: [*:0]const u8,
    lpstrReplaceWith: ?[*:0]const u8 = null,
    wFindWhatLen: u16,
    wReplaceWithLen: u16 = 0,
    lCustData: isize = 0,
    lpfnHook: ?*const FRHOOKPROC = null,
    lpTemplateName: ?[*:0]const u8 = null,
};
