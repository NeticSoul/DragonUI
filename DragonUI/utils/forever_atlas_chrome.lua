-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local ForeverAtlas = addon.ForeverAtlas
local ForeverUI = addon.ForeverUI
local DIR = ForeverUI.TEXTURE_DIR

ForeverAtlas["!ui-frame-metal-edgeleft"] = { DIR .. "chrome-frame", 95, 128, 4/1024, 194/1024, 4/512, 260/512 }
ForeverAtlas["!ui-frame-metal-edgeright"] = { DIR .. "chrome-frame", 95, 128, 202/1024, 392/1024, 4/512, 260/512 }
ForeverAtlas["_ui-frame-metal-edgebottom"] = { DIR .. "chrome-frame", 128, 100, 400/1024, 656/1024, 4/512, 204/512 }
ForeverAtlas["_ui-frame-metal-edgetop"] = { DIR .. "chrome-frame", 128, 95, 202/1024, 458/1024, 268/512, 458/512 }
ForeverAtlas["ui-frame-metal-cornerbottomleft"] = { DIR .. "chrome-frame", 95, 100, 664/1024, 854/1024, 4/512, 204/512 }
ForeverAtlas["ui-frame-metal-cornerbottomright"] = { DIR .. "chrome-frame", 95, 100, 4/1024, 194/1024, 268/512, 468/512 }
ForeverAtlas["ui-frame-metal-cornertopleft"] = { DIR .. "chrome-frame", 95, 95, 466/1024, 656/1024, 268/512, 458/512 }
ForeverAtlas["ui-frame-metal-cornertopright"] = { DIR .. "chrome-frame", 95, 95, 664/1024, 854/1024, 268/512, 458/512 }

ForeverAtlas["!optionsframe-nineslice-edgeleft"] = { DIR .. "chrome-dialog", 32, 32, 276/512, 308/512, 276/512, 308/512 }
ForeverAtlas["!optionsframe-nineslice-edgeright"] = { DIR .. "chrome-dialog", 32, 32, 316/512, 348/512, 276/512, 308/512 }
ForeverAtlas["!ui-frame-diamondmetal-edgeleft"] = { DIR .. "chrome-dialog", 64, 64, 4/512, 132/512, 4/512, 132/512 }
ForeverAtlas["!ui-frame-diamondmetal-edgeright"] = { DIR .. "chrome-dialog", 64, 64, 140/512, 268/512, 4/512, 132/512 }
ForeverAtlas["_optionsframe-nineslice-edgebottom"] = { DIR .. "chrome-dialog", 32, 32, 356/512, 388/512, 276/512, 308/512 }
ForeverAtlas["_optionsframe-nineslice-edgetop"] = { DIR .. "chrome-dialog", 32, 32, 396/512, 428/512, 276/512, 308/512 }
ForeverAtlas["_ui-frame-diamondmetal-edgebottom"] = { DIR .. "chrome-dialog", 64, 64, 276/512, 404/512, 4/512, 132/512 }
ForeverAtlas["_ui-frame-diamondmetal-edgetop"] = { DIR .. "chrome-dialog", 64, 64, 4/512, 132/512, 140/512, 268/512 }
ForeverAtlas["optionsframe-nineslice-cornerbottomleft"] = { DIR .. "chrome-dialog", 32, 32, 436/512, 468/512, 276/512, 308/512 }
ForeverAtlas["optionsframe-nineslice-cornerbottomright"] = { DIR .. "chrome-dialog", 32, 32, 476/512, 508/512, 276/512, 308/512 }
ForeverAtlas["optionsframe-nineslice-cornertopleft"] = { DIR .. "chrome-dialog", 32, 32, 4/512, 36/512, 412/512, 444/512 }
ForeverAtlas["optionsframe-nineslice-cornertopright"] = { DIR .. "chrome-dialog", 32, 32, 44/512, 76/512, 412/512, 444/512 }
ForeverAtlas["ui-frame-diamondmetal-cornerbottomleft"] = { DIR .. "chrome-dialog", 64, 64, 140/512, 268/512, 140/512, 268/512 }
ForeverAtlas["ui-frame-diamondmetal-cornerbottomright"] = { DIR .. "chrome-dialog", 64, 64, 276/512, 404/512, 140/512, 268/512 }
ForeverAtlas["ui-frame-diamondmetal-cornertopleft"] = { DIR .. "chrome-dialog", 64, 64, 4/512, 132/512, 276/512, 404/512 }
ForeverAtlas["ui-frame-diamondmetal-cornertopright"] = { DIR .. "chrome-dialog", 64, 64, 140/512, 268/512, 276/512, 404/512 }
ForeverAtlas["uiframebackground-nineslice-cornerbottomleft"] = { DIR .. "chrome-dialog", 16, 16, 84/512, 100/512, 412/512, 428/512 }
ForeverAtlas["uiframebackground-nineslice-cornerbottomright"] = { DIR .. "chrome-dialog", 16, 16, 108/512, 124/512, 412/512, 428/512 }

ForeverAtlas["!options_innerframe_edgeleft"] = { DIR .. "chrome-options", 212, 8, 4/1024, 216/1024, 220/256, 228/256 }
ForeverAtlas["!options_innerframe_edgeright"] = { DIR .. "chrome-options", 40, 8, 224/1024, 264/1024, 220/256, 228/256 }
ForeverAtlas["_options_innerframe_edgebottom"] = { DIR .. "chrome-options", 8, 168, 272/1024, 280/1024, 4/256, 172/256 }
ForeverAtlas["_options_innerframe_edgetop"] = { DIR .. "chrome-options", 8, 88, 556/1024, 564/1024, 4/256, 92/256 }
ForeverAtlas["_options_listexpand_middle"] = { DIR .. "chrome-options", 1, 26, 336/1024, 337/1024, 180/256, 206/256 }
ForeverAtlas["common-button-dropdown-closed"] = { DIR .. "chrome-options", 22, 22, 790/1024, 812/1024, 180/256, 202/256 }
ForeverAtlas["common-button-dropdown-closedpressed"] = { DIR .. "chrome-options", 22, 22, 820/1024, 842/1024, 180/256, 202/256 }
ForeverAtlas["common-button-dropdown-open"] = { DIR .. "chrome-options", 22, 22, 850/1024, 872/1024, 180/256, 202/256 }
ForeverAtlas["common-button-dropdown-openpressed"] = { DIR .. "chrome-options", 22, 22, 880/1024, 902/1024, 180/256, 202/256 }
ForeverAtlas["options_categoryheader_1"] = { DIR .. "chrome-options", 199, 32, 572/1024, 771/1024, 4/256, 36/256 }
ForeverAtlas["options_categoryheader_2"] = { DIR .. "chrome-options", 199, 32, 780/1024, 979/1024, 4/256, 36/256 }
ForeverAtlas["options_categoryheader_3"] = { DIR .. "chrome-options", 199, 32, 4/1024, 203/1024, 180/256, 212/256 }
ForeverAtlas["options_horizontaldivider"] = { DIR .. "chrome-options", 630, 1, 288/1024, 918/1024, 220/256, 221/256 }
ForeverAtlas["options_innerframe_center"] = { DIR .. "chrome-options", 8, 8, 272/1024, 280/1024, 220/256, 228/256 }
ForeverAtlas["options_innerframe_cornerbottomleft"] = { DIR .. "chrome-options", 212, 168, 4/1024, 216/1024, 4/256, 172/256 }
ForeverAtlas["options_innerframe_cornerbottomright"] = { DIR .. "chrome-options", 40, 168, 224/1024, 264/1024, 4/256, 172/256 }
ForeverAtlas["options_innerframe_cornertopleft"] = { DIR .. "chrome-options", 212, 88, 288/1024, 500/1024, 4/256, 92/256 }
ForeverAtlas["options_innerframe_cornertopright"] = { DIR .. "chrome-options", 40, 88, 508/1024, 548/1024, 4/256, 92/256 }
ForeverAtlas["options_list_active"] = { DIR .. "chrome-options", 187, 21, 398/1024, 585/1024, 180/256, 201/256 }
ForeverAtlas["options_list_hover"] = { DIR .. "chrome-options", 187, 21, 594/1024, 781/1024, 180/256, 201/256 }
ForeverAtlas["options_listexpand_left"] = { DIR .. "chrome-options", 12, 26, 284/1024, 296/1024, 180/256, 206/256 }
ForeverAtlas["options_listexpand_right"] = { DIR .. "chrome-options", 28, 26, 212/1024, 240/1024, 180/256, 206/256 }
ForeverAtlas["options_listexpand_right_expanded"] = { DIR .. "chrome-options", 28, 26, 248/1024, 276/1024, 180/256, 206/256 }
ForeverAtlas["options_tab_active_left"] = { DIR .. "chrome-options", 7, 26, 304/1024, 311/1024, 180/256, 206/256 }
ForeverAtlas["options_tab_active_middle"] = { DIR .. "chrome-options", 1, 26, 346/1024, 347/1024, 180/256, 206/256 }
ForeverAtlas["options_tab_active_right"] = { DIR .. "chrome-options", 7, 26, 320/1024, 327/1024, 180/256, 206/256 }
ForeverAtlas["options_tab_left"] = { DIR .. "chrome-options", 7, 23, 356/1024, 363/1024, 180/256, 203/256 }
ForeverAtlas["options_tab_middle"] = { DIR .. "chrome-options", 1, 23, 388/1024, 389/1024, 180/256, 203/256 }
ForeverAtlas["options_tab_right"] = { DIR .. "chrome-options", 7, 23, 372/1024, 379/1024, 180/256, 203/256 }

ForeverAtlas["128-redbutton-exit"] = { DIR .. "chrome-buttons", 128, 128, 312/512, 376/512, 76/512, 140/512 }
ForeverAtlas["128-redbutton-exit-disabled"] = { DIR .. "chrome-buttons", 128, 128, 384/512, 448/512, 76/512, 140/512 }
ForeverAtlas["128-redbutton-exit-pressed"] = { DIR .. "chrome-buttons", 128, 128, 4/512, 68/512, 148/512, 212/512 }
ForeverAtlas["128-redbutton-highlight"] = { DIR .. "chrome-buttons", 441, 128, 4/512, 224/512, 4/512, 68/512 }
ForeverAtlas["128-redbutton-left"] = { DIR .. "chrome-buttons", 114, 128, 364/512, 421/512, 148/512, 212/512 }
ForeverAtlas["128-redbutton-left-disabled"] = { DIR .. "chrome-buttons", 114, 128, 430/512, 487/512, 148/512, 212/512 }
ForeverAtlas["128-redbutton-left-pressed"] = { DIR .. "chrome-buttons", 114, 128, 4/512, 61/512, 220/512, 284/512 }
ForeverAtlas["128-redbutton-right"] = { DIR .. "chrome-buttons", 292, 128, 232/512, 378/512, 4/512, 68/512 }
ForeverAtlas["128-redbutton-right-disabled"] = { DIR .. "chrome-buttons", 292, 128, 4/512, 150/512, 76/512, 140/512 }
ForeverAtlas["128-redbutton-right-pressed"] = { DIR .. "chrome-buttons", 292, 128, 158/512, 304/512, 76/512, 140/512 }
ForeverAtlas["_128-redbutton-center"] = { DIR .. "chrome-buttons", 64, 128, 70/512, 102/512, 220/512, 284/512 }
ForeverAtlas["_128-redbutton-center-disabled"] = { DIR .. "chrome-buttons", 64, 128, 110/512, 142/512, 220/512, 284/512 }
ForeverAtlas["_128-redbutton-center-pressed"] = { DIR .. "chrome-buttons", 64, 128, 150/512, 182/512, 220/512, 284/512 }
ForeverAtlas["redbutton-exit"] = { DIR .. "chrome-buttons", 32, 32, 76/512, 140/512, 148/512, 212/512 }
ForeverAtlas["redbutton-exit-disabled"] = { DIR .. "chrome-buttons", 32, 32, 148/512, 212/512, 148/512, 212/512 }
ForeverAtlas["redbutton-exit-pressed"] = { DIR .. "chrome-buttons", 32, 32, 220/512, 284/512, 148/512, 212/512 }
ForeverAtlas["redbutton-highlight"] = { DIR .. "chrome-buttons", 32, 32, 292/512, 356/512, 148/512, 212/512 }

ForeverUI.ChromeLayouts = {
    metalframe = {
        corners = {
            TopLeft = { "ui-frame-metal-cornertopleft", -8, 16 },
            TopRight = { "ui-frame-metal-cornertopright", 2, 16 },
            BottomLeft = { "ui-frame-metal-cornerbottomleft", -8, -8 },
            BottomRight = { "ui-frame-metal-cornerbottomright", 2, -8 },
        },
        edges = { Top = "_ui-frame-metal-edgetop", Bottom = "_ui-frame-metal-edgebottom", Left = "!ui-frame-metal-edgeleft", Right = "!ui-frame-metal-edgeright" },
    },
    diamond = {
        corners = {
            TopLeft = { "ui-frame-diamondmetal-cornertopleft", -9, 9 },
            TopRight = { "ui-frame-diamondmetal-cornertopright", 9, 9 },
            BottomLeft = { "ui-frame-diamondmetal-cornerbottomleft", -9, -9 },
            BottomRight = { "ui-frame-diamondmetal-cornerbottomright", 9, -9 },
        },
        edges = { Top = "_ui-frame-diamondmetal-edgetop", Bottom = "_ui-frame-diamondmetal-edgebottom", Left = "!ui-frame-diamondmetal-edgeleft", Right = "!ui-frame-diamondmetal-edgeright" },
    },
    optionsbox = {
        corners = {
            TopLeft = { "optionsframe-nineslice-cornertopleft", -14, 13 },
            TopRight = { "optionsframe-nineslice-cornertopright", 14, 13 },
            BottomLeft = { "optionsframe-nineslice-cornerbottomleft", -14, -13 },
            BottomRight = { "optionsframe-nineslice-cornerbottomright", 14, -13 },
        },
        edges = { Top = "_optionsframe-nineslice-edgetop", Bottom = "_optionsframe-nineslice-edgebottom", Left = "!optionsframe-nineslice-edgeleft", Right = "!optionsframe-nineslice-edgeright" },
    },
    innerframe = {
        corners = {
            TopLeft = { "options_innerframe_cornertopleft", 0, 0 },
            TopRight = { "options_innerframe_cornertopright", 0, 0 },
            BottomLeft = { "options_innerframe_cornerbottomleft", 0, 0 },
            BottomRight = { "options_innerframe_cornerbottomright", 0, 0 },
        },
        edges = { Top = "_options_innerframe_edgetop", Bottom = "_options_innerframe_edgebottom", Left = "!options_innerframe_edgeleft", Right = "!options_innerframe_edgeright" },
        center = "options_innerframe_center",
    },
}

ForeverUI.ChromeMetrics = {
    window = { bgLeft = 7, bgTop = -18, bgRight = -3, bgBottom = 3, titleY = 0, titleSide = 60, closeX = -2, closeY = 1, closeSize = 24, insetLeft = 17, insetTop = -64, insetRight = -17, insetBottom = 42, plainLeft = 12, plainTop = -32, plainRight = -12, plainBottom = 12, titleBarHeight = 18 },
    dialog = { bgInset = 7, titleY = -21, closeX = 0, closeY = 0, railInset = 9, contentLeft = 24, contentTop = -48, contentRight = -24, contentBottom = 24 },
    optionsbox = { railInsetX = 14, railInsetY = 13, railThickness = 1, fillInset = 1, defaultLeft = -16, defaultTop = 15, defaultRight = 16, defaultBottom = -15 },
    button = { sliceHeight = 128, pushedX = -2, pushedY = -1, defaultWidth = 96, defaultHeight = 22 },
    category = { headerWidth = 175, headerHeight = 30, headerLabelX = 20, headerLabelY = -1, rowWidth = 175, rowHeight = 20, labelLeft = 36, labelY = 1, toggleX = 9, toggleSize = 22 },
    tab = { height = 37, textPad = 40, textY = 4, textYSelected = 6 },
    divider = { ornateWidth = 330, ornateHeight = 16 },
}

ForeverUI.ChromeColors = {
    gold = { 1, 0.8200, 0 },
    white = { 1, 1, 1 },
    gray = { 0.5, 0.5, 0.5 },
    lightGray = { 0.6000, 0.6000, 0.6000 },
    panel = { 0.1216, 0.1176, 0.1294, 0.9300 },
    dialog = { 0, 0, 0, 0.9300 },
    dialogSolid = { 0, 0, 0, 1 },
}
