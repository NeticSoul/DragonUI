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
L["Click to reset"] = "Clique para redefinir"
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

-- Bag Sort (Sell Scrap)
L["Sell Scrap"] = "Vender Sucata"
L["Click to sell all gray (poor) items to vendor."] = "Clique para vender todos os itens cinzas (ruins) ao vendedor."
L["A merchant window must be open."] = "Uma janela de vendedor deve estar aberta."
L["Open a merchant window first to sell scrap items."] = "Abra uma janela de vendedor primeiro para vender sucata."
L["Sold %d scrap item(s) for %s."] = "Vendido(s) %d item(ns) de sucata por %s."
L["No scrap items to sell."] = "Nenhum item de sucata para vender."

-- Guild Bank Sort
L["You must be at the guild bank."] = "Você precisa estar no banco da guilda."
L["Could not determine the current guild bank tab."] = "Não foi possível determinar a aba atual do banco da guilda."
L["You need full deposit and withdraw access to this tab to sort it."] = "Você precisa de acesso total de depósito e retirada nesta aba para organizá-la."
L["This guild bank tab is already sorted!"] = "Esta aba do banco da guilda já está organizada!"
L["Sort this guild bank tab? Depending on your server, this may be logged and count against your guild's shared withdrawal allowance, the same as moving items by hand."] = "Organizar esta aba do banco da guilda? Dependendo do seu servidor, isso pode ser registrado e contar no limite de retirada compartilhado da sua guilda, assim como mover itens manualmente."
L["Sort"] = "Organizar"
L["Click to sort items in the currently open guild bank tab."] = "Clique para organizar os itens na aba do banco da guilda atualmente aberta."
L["Never moves items between tabs."] = "Nunca move itens entre abas."
L["Sort Guild Bank Tab"] = "Organizar aba do banco da guilda"

L["Bag Skin"] = "Visual das bolsas"
L["Retail-style skin for Blizzard bag windows"] = "Visual estilo Retail para as janelas de bolsas da Blizzard"

-- Version Check Module
L["Version Check"] = "Verificação de versão"
L["Broadcast and detect addon version updates across group members"] = "Detecta atualizações de versão do addon entre membros do grupo transmitindo e recebendo a versão"

-- Nameplate addon compatibility popup
L["Reads native nameplate alpha to identify the target's plate; conflicts with DragonUI's default anti-dim behavior."] = "Usa a transparência nativa da placa para identificar a placa do alvo; conflita com o comportamento anti-escurecimento padrão do DragonUI."
L["Parents its cooldown icons to the native health bar; conflicts with DragonUI's default health-bar hiding."] = "Anexa seus ícones de cooldown à barra de vida nativa; conflita com a ocultação padrão dessa barra no DragonUI."
L["Detected |cFFFFFF00%s|r. Enable Nameplate Addon Compatibility so it works correctly?"] = "|cFFFFFF00%s|r detectado. Ativar a Compatibilidade de Addons de Placas para que funcione corretamente?"
L["Detected |cFFFFFF00%s|r. Enable Nameplate Health Bar Compatibility so it works correctly?"] = "|cFFFFFF00%s|r detectado. Ativar a Compatibilidade da Barra de Vida das Placas para que funcione corretamente?"
L["Enable"] = "Ativar"

-- Extra Bar (issue #330)
L["ExtraBar1"] = "Barra Extra"
L["Extra Bar"] = "Barra Extra"
L["A standalone action bar, independent of any class bonus bar"] = "Uma barra de ação independente, não vinculada à barra de bônus de nenhuma classe"
L["Drag a spell, item or macro here."] = "Arraste uma magia, item ou macro para cá."


-- Quest nameplate icons wizard (Questie coexistence)
L["Quest Icons on Nameplates"] = "Ícones de missão nas placas"
L["Which quest icons do you want on your nameplates?"] = "Quais ícones de missão você quer nas suas placas?"
L["Kill"] = "Matar"
L["Loot"] = "Saque"
L['Pointer mode (just "!")'] = 'Modo ponteiro (só "!")'
L["Use Questie"] = "Usar Questie"
L["Applying quest icon settings needs a UI reload."] = "Aplicar as configurações de ícones de missão requer recarregar a interface."
L["Reload"] = "Recarregar"

-- Item Level
L["Item Level"] = "Nível de Item"
L["Show item level on gear icons in bags, character panel, bank, and more"] = "Mostrar o nível de item nos ícones de equipamento em bolsas, painel do personagem, banco e mais"
L["Item Level: %d"] = "Nível de item: %d"

