--[[
 DragonUI - Portuguese (Brazil) Locale (ptBR)
 Community translation — Edit this file to contribute!

 Guidelines:
 - Use `true` for strings you haven't translated yet (falls back to English)
 - Keep format specifiers like %s, %d, %.1f intact
 - Keep slash commands untranslated (/dragonui, /dui, /rl)
 - Keep "DragonUI" as addon name untranslated
 - Keep color codes |cff...|r outside of L[] strings
]]

local L = LibStub("AceLocale-3.0"):NewLocale("DragonUI", "ptBR")
if not L then return end

-- Example:
-- L["Cannot toggle editor mode during combat!"] = "Não é possível alternar o modo editor durante o combate!"

-- UnitFrameLayers compatibility popup
L["TooltipWidget"] = true
L["DragonUI - UnitFrameLayers Detected"] = true
L["DragonUI already includes Unit Frame Layers functionality (heal prediction, absorb shields, and animated health loss)."] = true
L["Choose how to resolve this overlap:"] = true
L["Use DragonUI: disable external UnitFrameLayers and enable DragonUI layers."] = true
L["Disable Both: disable external UnitFrameLayers and keep DragonUI layers disabled."] = true
L["Use DragonUI"] = true
L["Disable Both"] = true
L["DragonUI - D3D9Ex Warning"] = "DragonUI - Aviso de D3D9Ex"
L["DragonUI detected that your client is using D3D9Ex."] = "DragonUI detectou que seu cliente está usando D3D9Ex."
L["DragonUI's action bar system is not compatible with D3D9Ex."] = "O sistema de barras de ação do DragonUI não é compatível com D3D9Ex."
L["Some DragonUI action bar textures will be missing while this mode is active."] = "Algumas texturas das barras de ação do DragonUI vão ficar ausentes enquanto este modo estiver ativo."
L["If you want to disable this mode, open WTF\\Config.wtf."] = "Se quiser desativar este modo, abra WTF\\Config.wtf."
L["Delete this line:"] = "Apague esta linha:"
L["Or replace it with:"] = "Ou substitua por esta:"
L["Hide Gryphons"] = "Esconder grifos"
L["Understood"] = "Entendi"
L["Buttons"] = "Botões"
L["Main Bars"] = "Barras principais"
L["Stance Button %d"] = true
L["Pet Action Button %d"] = true
L["Multicast Button %d"] = true
L["Totem Call Button"] = true
L["Totem Recall Button"] = true

L["Copy Text"] = "Copiar texto"

-- Minimap tooltip strings
L["Minimap Buttons"] = "Botoes do minimapa"
L["Minimap Buttons Collector"] = "Botoes do minimapa"
L["Left-click to show or hide minimap addon buttons."] = "Clique com o botao esquerdo para abrir os botoes de addons do minimapa."
L["Right-click to open DragonUI settings."] = "Clique com o botao direito para abrir as configuracoes do DragonUI."
L["Drag to move"] = "Arraste para mover"
L["Animated minimap border effects for DragonUI."] = "Efeitos animados de borda do minimapa para DragonUI."

-- Labels do modo editor
L["TargetCastbar"] = "Barra de lançamento do Alvo"
L["FocusCastbar"] = "Barra de lançamento do Foco"
L["Right-click to reset"] = "Clique com o botão direito para redefinir"
L["Status Tooltip:"] = "Tooltip de status:"
L["Top"] = "Topo"
L["Bottom"] = "Baixo"
L["Left"] = "Esquerda"
L["Right"] = "Direita"
L["Error Messages"] = "Mensagens de erro"
L["ErrorMessages"] = "Mensagens de erro"
L["Nameplates"] = "Placas de nome"
L["Apply DragonUI nameplate styling."] = "Aplica o estilo DragonUI as placas de nome."

-- Position presets (edit mode)
L["Position Presets"] = "Predefinicoes de Posicao"
L["Position Preset"] = "Predefinicao de Posicao"
L["Save"] = "Salvar"
L["Import"] = "Importar"
L["Cancel"] = "Cancelar"
L["Load"] = "Carregar"
L["Delete"] = "Excluir"
L["Select All"] = "Selecionar Tudo"
L["Click to load"] = "Clique para carregar"
L["No position presets saved yet."] = "Nenhuma predefinicao de posicao salva ainda."
L["Load position preset '%s'? This will overwrite your current element positions."] = "Carregar predefinicao '%s'? Isso substituira as posicoes atuais dos elementos."
L["Delete position preset '%s'? This cannot be undone."] = "Excluir predefinicao '%s'? Esta acao nao pode ser desfeita."
L["Enter a name for the imported position preset:"] = "Digite um nome para a predefinicao importada:"
L["Imported Position Preset"] = "Predefinicao Importada"
L["Position preset saved: "] = "Predefinicao de posicao salva: "
L["Position preset loaded: "] = "Predefinicao de posicao carregada: "
L["Position preset deleted: "] = "Predefinicao de posicao excluida: "
L["Position preset imported: "] = "Predefinicao de posicao importada: "
L["Export Position Preset"] = "Exportar Predefinicao de Posicao"
L["Import Position Preset"] = "Importar Predefinicao de Posicao"
L["Invalid position preset string."] = "String de predefinicao de posicao invalida."
L["Not a valid DragonUI position preset string."] = "Nao e uma string de predefinicao DragonUI valida."
L["Failed to export position preset."] = "Falha ao exportar predefinicao de posicao."
L["Save New Preset"] = "Salvar Nova Predefinicao"
L["Load Preset"] = "Carregar Predefinicao"
L["Delete Preset"] = "Excluir Predefinicao"
L["Export Preset"] = "Exportar Predefinicao"
L["Import Preset"] = "Importar Predefinicao"

L["Version Check"] = "Verificacao de versao"
L["Notifies when other players have a different addon version"] = "Notifica quando outros jogadores tem uma versao diferente do addon"
