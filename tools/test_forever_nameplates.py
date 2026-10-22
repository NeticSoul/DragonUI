"""Offline Lua 5.1 regression tests. Requires lupa and Pillow; no WoW launch."""
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s, name) local f, e = loadstring(s, name); assert(f, e); return true end')
files = list((root / 'DragonUI/modules/nameplates').rglob('*.lua'))
files += [root / 'DragonUI/database.lua', root / 'DragonUI_Options/panel/tab_nameplates.lua']
LANGUAGE_FILES = ('deDE', 'enUS', 'esES', 'esMX', 'frFR', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW')
files += [root / ('DragonUI_Options/Locales/' + lang + '.lua') for lang in LANGUAGE_FILES]
for path in files:
    compile_lua(path.read_text(encoding='utf-8-sig'), str(path))
print('Lua 5.1 syntax:', len(files), 'files OK')
FOREVER_STRINGS = (
    'Forever (Thin)',
    'Highlight target and focus with the original Forever borders.',
    'Heritage uses DragonUI art. Modern uses retail chrome. Forever uses original WoW Forever borders, cast bars and a separate level badge. Each style remembers its layout.',
    'Forever displays levels in the original badge on the right. Unknown levels remain hidden until the client can identify the unit.',
)
for lang in LANGUAGE_FILES:
    text = (root / ('DragonUI_Options/Locales/' + lang + '.lua')).read_text(encoding='utf-8-sig')
    for key in FOREVER_STRINGS:
        assert 'L["' + key + '"]' in text, (lang, key)
print('Forever option strings present in all', len(LANGUAGE_FILES), 'locales')
for child in ET.parse(root / 'DragonUI/modules/nameplates/nameplates.xml').getroot():
    path = root / 'DragonUI/modules/nameplates' / child.attrib['file'].replace('\\', '/')
    assert path.is_file(), path
for path in (root / 'DragonUI/Textures/Nameplates/Forever').glob('*.tga'):
    im = Image.open(path)
    im.load()
    assert im.mode == 'RGBA', path
    assert all(n > 0 and n & (n-1) == 0 for n in im.size), path
print('XML load order and RGBA power-of-two textures OK')
lua.globals().TEST_ROOT = root.as_posix()
lua.execute((root / 'tools/test_forever_nameplates.lua').read_text(encoding='utf-8'))
